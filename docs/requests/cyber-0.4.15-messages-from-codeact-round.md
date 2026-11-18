# 요청: 0.4.15 비교 회차에서 고치는 법을 말하지 않은 문구 셋 (cyber 0.4.15, 93a9ca4f)

상태: 열림 (2026-11-18). 결함이 아니라 문구에 관한 요청이다. 모두 컴파일 오류로 멈추고 아무것도 실행되지 않는다. tars-agent 본체의 첫 단계를 막지 않는다.

## 배경

tars-agent의 스파이크 2로 direct 대 CodeAct 비교를 0.4.15로 다시 돌렸다(과제 셋, 회차 14개, 과제 42개, 2026-11-18). 모델이 낸 컴파일 오류는 41건이고 대부분은 문구가 고치는 법을 말해 모델이 다음 스텝에 고쳤다. 아래 셋은 고치는 법을 말하지 않는다. tars-agent는 "문구가 고치는 법을 말하지 않는 오류가 회차에서 되풀이되면 요청한다"는 기준을 쓴다(검토 문서 5.1). 1과 2는 서로 다른 회차나 모델에서 되풀이됐다. 3은 0.4.15의 제자리 메서드와 함께 생긴 빈틈이라 한 건이지만 함께 낸다.

재현은 모두 설치된 `/usr/local/bin/cyber`(`Cyber 0.4.15 build-969-93a9ca4`)에서 했다. tars-agent 세션(`persist_main`, 검증 뒤 실행)에서도 같은 문구다.

## 1. `!T`를 돌려주지 않는 함수 안의 `!`

DeepSeek(deepseek-chat) 한 번, qwen3.8-flash 한 번.

~~~cy
use os
fn size(p str) -> int:
    t := os.read_file(p)!
    return t.len()
~~~

~~~
CompileError: Expected `Result` or `error` return type for enclosing function.
~~~

- `Result`는 모델이 가이드에서 배우는 이름이 아니다. 가이드와 다른 문구는 `!T`라고 쓴다.
- 고치는 꼴이 없다. 바라는 것: 고칠 꼴 둘을 말한다. 예: ``... The function `size` returns `int`, so `!` can not pass the error on. Declare it `-> !int`, or handle the error here with `!else` or `try`.``

## 2. `?T`를 `.!`로 풀기

qwen3.8-flash, 서로 다른 회차에서 두 번.

~~~cy
line := 'ab#c'
idx := line.index('#')
print(line[idx.!])
~~~

~~~
ParseError: Expected ident.
~~~

- 같은 뜻의 `idx!`는 ``... For `?int`, use `.?` or `?else`.``로 고치는 법을 말한다. `.!`는 파서에서 멈춰 그 문구에 닿지 않는다.
- 바라는 것: `.` 뒤의 `!`를 알아보고 ``Unwrap an option with `.?`, and an error with `!` after the call (`f()!`).``처럼 두 꼴을 말한다.

## 3. `^[]T`(참조)에 제자리 `Slice` 메서드

qwen3.8-flash 한 번. 0.4.15에서 `append`, `insert`, `remove`가 제자리 메서드(`&&Slice`)가 된 뒤의 꼴이다.

~~~cy
rows := ^[]str{}
rows.append('a')
~~~

~~~
CompileError: Expected type `&>[]str`. Found `^[]str`.
~~~

`insert`도 같다: ``Expected argument `&>[]str`, found `^[]str`, when calling `fn insert(&>[]str, int, str) -> void`.``

- 고치는 꼴은 `rows.*.append('a')`이고 돈다.
- `&>`는 모델이 가이드에서 보지 못하는 표기다(가이드는 `&T`, `^T`만 가르친다).
- 같은 자리의 `+=`는 이미 고치는 법을 말한다: ``Expected type `^[]str`, got `[]str`. To change the value that `rows` points to, write `rows.* += ...`.`` 같은 꼴의 문구를 바란다. 예: ``To change the list that `rows` points to, write `rows.*.append('a')`.`` 받는 쪽이 `^T`일 때 메서드 호출을 자동으로 역참조할지는 cyber가 정한다.

## 내지 않은 것

- Python 슬라이스 `s[:3]`(``Expected element expression.``): 한 건이다. 되풀이되면 낸다.
- ``Return statement is not allowed in the main block.``: 무엇이 틀렸는지는 말한다. 한 건이다.

## 확인 방법

tars-agent 쪽에서 새 빌드를 받으면 위 세 스크립트를 CLI와 세션(`s1 replay`)에서 돌려 문구를 본다. 비교 회차를 다시 돌릴 때 같은 오류가 몇 스텝에 고쳐지는지 본다.

## cyber 응답 (2026-11-18, cyber master `1ed147a7`, 미릴리스)

셋 다 문구를 고쳤다. 동작은 그대로다. 테스트는 cyber `src/test`의 `control_flow/bang_in_non_result_*_error.cy`,
`syntax/dot_bang_without_case_error.cy`, `vars/ref_slice_{append,insert}_error.cy`.

1. ``CompileError: Expected a `!T` or `error` return type for `!`. The function `size` returns `int`, so `!` can not pass the error on. Declare it `-> !int`, or handle the error here with `!else` or `try`.`` 람다 안이면 ``The lambda returns `int`, ...``.
2. ``ParseError: Expected a choice case name after `.!` (`c.!line`). Unwrap an option with `.?`, and an error with `!` after the call (`f()!`).``
3. 원래 문구 뒤에 힌트를 붙인다. ``CompileError: Expected type `&>[]str`. Found `^[]str`. To change the value that `rows` points to, write `rows.*.append(...)`.`` `insert` · `remove` 등도 같은 꼴(``... when calling `fn insert(&>[]str, int, str) -> void`. To change the value that `rows` points to, write `rows.*.insert(...)`.``). 자동 역참조는 하지 않는다. 수신자 변환에서 `^T`를 `&&T`로 바꾸지 않는 것은 다른 참조가 같은 목록을 나눠 가질 수 있어서다.

`prompt/cyber-subset.md` · `.en.md`의 참조 항목에 `out.*.append('x')` 꼴을 더했다. 다음 cyber 릴리스(또는 latest 빌드)로 확인 뒤 이 요청을 닫는다.

## tars-agent 쪽 미리 확인 (2026-11-18, cyber 로컬 master `1ed147a7`)

릴리스 전이라 s1을 `zig build --fork=<cyber 저장소>`로 스크래치에 빌드해 세션(`s1 replay`)에서 봤다. spike/의 의존은 0.4.15 그대로다.

- 1: `fs.read(p)!`를 쓴 `-> int` 함수와 람다가 회신의 문구대로다(``The function `size` returns `int`, ...``, ``The lambda returns `int`, ...``).
- 2: `line[idx.!]`이 ``Expected a choice case name after `.!` ... Unwrap an option with `.?`, ...``다.
- 3: `rows.append('a')`, `rows.insert(0, 'a')`가 원래 문구 뒤에 ``To change the value that `rows` points to, write `rows.*.append(...)`.``(`insert`도 같은 꼴)를 붙인다.
- 안내에 더한 줄의 꼴(`out.*.append('x')`, `out.*.remove(0)`)은 0.4.15와 master 모두에서 돈다.
- 회귀: master 빌드에서 s1 47개, 안내 코드 블록 34개(세션)가 모두 통과한다.

남은 것: 이 커밋이 든 릴리스(또는 latest 빌드)를 받아 같은 확인을 하고 요청서를 지운다.
