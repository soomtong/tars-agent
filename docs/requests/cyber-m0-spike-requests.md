# cyber 요청: M0 스파이크에서 남은 것

보내는 곳: soomtong/cyber. 기준: 로컬 master 6a155275 (`Cyber 0.4.10-DEV build-0-6a155275`). 확인일 2026-11-14.

tars-agent는 libcyber를 정적 링크해 모델이 쓴 Cyber 스크립트를 세션 VM(persist_main, deny_raw_ptrs, deny_spawn, 검증 뒤 실행)에서 돌린다. 이 커밋으로 스파이크와 CodeAct 비교를 다시 돌렸다. 1절이 tars-agent 본체 첫 단계의 선행 조건이다. 2절은 그다음이다.

재현에 쓴 것: tars-agent의 spike/s1(`zig build && ./zig-out/bin/s1`. `s1 replay <파일>`은 `=====` 줄로 나눈 스크립트를 한 세션에서 검증 뒤 실행한다)과 이 커밋의 CLI(`zig build cli -Doptimize=ReleaseFast -Dcommit=6a155275`).

## 1. 커밋을 원격에 올린다

6a155275와 그 앞의 커밋들(118f0c62, 5de6c83a, bf5967db 등)이 soomtong/cyber 원격에 없다. tars-agent 스파이크는 지금 로컬 경로 의존(`.path = "../../../cyberscript"`)으로 받는다. 본체와 docs/deps.md는 URL과 해시로 고정한다.

요청: push한다. 릴리스(0.4.11 등)나 태그가 정해지면 tars-agent는 그것으로 고정한다.

## 2. 비교 회차에서 모델이 만난 문구

이 커밋과 새 안내로 CodeAct 비교를 다시 돌렸다(과제 셋, DeepSeek-V4.1-Flash 3회, qwen3.8-flash 5회, qwen3.8-max 1회, 과제 27개 모두 통과, 컴파일 오류 33건). 아래는 문구가 고치는 법을 말하지 않은 것이다. 모두 이 커밋의 CLI로 다시 확인했다. 건수는 이 회차의 것이다.

(a) `#`로 쓴 주석 (2건, qwen3.8-flash).

~~~cy
x := 1
if x == 1:
    # note here
    print(x)
~~~

``ParseError: Expected end of line or file. Got ident.`` 최상위의 `# comment`는 ``Could not find the symbol `comment`.``, 줄 끝의 `x := 1 # comment`는 ``Expected end of line or file. Got pound.``다. 안내에는 `# comment`를 `-- comment`로 쓰라고 적혀 있는데도 나왔다. 요청: `#` 뒤에 공백이 오면 ``A comment starts with `--`, not `#`.``처럼 말한다.

(b) `for`의 값과 이름의 자리를 바꿈 (2건, qwen3.8-flash. 앞 빌드의 회차에도 1건).

~~~cy
for f |{'a', 'b'}|:
    print(f)
~~~

``ParseError: Expected ident.`` 요청: `|...|` 안에 이름이 아닌 식이 오면 ``The values come first and the name goes in `|x|`: `for {a, b} |x|:`.``처럼 말한다.

(c) 튜플 반환 타입 (1건, qwen3.8-flash).

~~~cy
fn f() -> (int, int):
    return 1, 2
~~~

``ParseError: Expected `)`.`` 요청: 반환 타입 자리의 `(`에는 튜플 타입이 없다는 것과 대신 쓸 것(필드를 가진 `type`을 돌려준다)을 말한다.

(d) 홑따옴표 문자열 안의 실제 줄바꿈 (1건, qwen3.8-flash).

~~~cy
xs := 'a
b'
~~~

``TokenError: Encountered new line in single line literal.`` 요청: 고치는 법(`\n`을 쓰거나 `'''...'''`로 여러 줄 문자열을 쓴다)을 붙인다.

(e) 슬라이스 경계에 `?int` (1건, qwen3.8-flash).

~~~cy
s := 'a#b'
h := s.index('#')
print(s[h..])
~~~

``CompileError: Expected argument `int`, found `?int`, when calling `fn @slice(&str, int) -> str`.`` 타입은 맞게 말하지만 모델이 모르는 내부 이름(`@slice`)을 보이고 푸는 법이 없다. 요청: 슬라이스나 인덱스 자리의 `?T`에는 ``A slice bound must be `int`, got `?int`. Unwrap it first: `if s.index(x) |i|:` or `x.?`.``처럼 말한다.

## 확인을 마친 것

이 커밋에서 다음이 통과했다.

- s1 검사 40개 모두 통과. 새 검사 6m: 매개변수를 반환 슬롯보다 먼저 읽는 호스트 함수가 직접 호출, 함수 포인터 값, 함수 union 값, sort가 부르는 경로에서 모두 맞는 값이다. 버전 문자열의 커밋과 `#include "cyber.h"`의 구조체 크기(검사 0)도 통과했다.
- 오류 문구: 아래가 CLI와 세션(검증) 양쪽에서 회신에 적힌 그대로 나온다. `s.len`의 `len()` 제안, `{'a', 1}`과 `{1, true}`의 설명, 보간 안의 보간, `elif`(변수 이름 `elif`는 그대로 쓸 수 있다), 최상위와 반복 안의 `!else` 블록 끝, 최상위 `?else` 블록 끝, `trimStart`/`trim_end`/`lstrip`의 제안, `and`로 묶은 옵션 풀기, 보간 안의 백슬래시.
- 인자 없는 `trimLeft()`와 `trimRight()`는 공백, 탭, 줄바꿈을 자른다.
- `var b byte = 1` 뒤 `{b, 2}`, `{true, false}`, `{1.5, 2.5}`는 전처럼 된다. 보간 안의 문자열 뒤에 같은 층의 보간이 오는 `'%{' '.repeat(2)}%{k}'`도 된다.
- cyber.h의 `cl_vm_validate` 설명에 마지막 eval의 설정으로 검사한다는 것이 있다.
- 안내 문서의 코드 블록 11개와 오류 목록의 첫 줄 21개가 이 커밋의 CLI와 세션에서 맞다.
- macOS arm64(libcyber.a 2.53 MB, 공개 `cl_` 함수 135개)와 x86_64-linux-gnu 교차 빌드.
- 비교 회차: 세션 reset, panic, 상한에 걸린 실행은 없었다. 앞 빌드(5de6c83a) 회차와 견주면 과제당 컴파일 오류가 DeepSeek-V4.1-Flash 0.44 → 0, qwen3.8-flash 2.44 → 2.13, qwen3.8-max 0 → 0.33이다. 고친 문구가 겨눈 실수 가운데 보간 안의 보간만 한 번 나왔고, 모델은 문구가 권한 대로 안쪽 문자열을 변수로 빼서 다음 스텝에 고쳤다. 나머지(`and`로 묶은 풀기, `elif`, 보간 안의 `\"`, `trimStart`, 최상위 `!else` 블록 끝)는 다시 나오지 않아 효과를 잴 수 없었다.
- 가장 흔한 오류는 여전히 ``Can not print `!str`. Unwrap it with `!` first ...``다(33건 중 18). 문구는 정확하고 모델은 한 스텝에 고친다. tars-agent 쪽(능력의 모양과 안내)에서 다룬다.
