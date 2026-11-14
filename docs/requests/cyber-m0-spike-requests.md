# cyber 요청: M0 스파이크에서 남은 것

보내는 곳: soomtong/cyber. 기준: 로컬 master 5de6c83a (`Cyber 0.4.10-DEV build-0-5de6c83a`). 확인일 2026-11-14.

tars-agent는 libcyber를 정적 링크해 모델이 쓴 Cyber 스크립트를 세션 VM(persist_main, deny_raw_ptrs, deny_spawn, 검증 뒤 실행)에서 돌린다. 이 커밋으로 스파이크(호스트 경계 검사, 모델 셋의 CodeAct 비교)를 다시 돌렸고 아래가 남았다. 1, 2가 tars-agent 본체 첫 단계의 선행 조건이다. 3~6은 그다음이다.

재현에 쓴 것: tars-agent의 spike/s1(`zig build && ./zig-out/bin/s1`. `s1 order <n>`은 호출 경로 하나를 프로세스 하나에서 돌린다. `s1 replay <파일>`은 `=====` 줄로 나눈 스크립트를 한 세션에서 검증 뒤 실행한다)과 이 커밋의 CLI.

## 1. 매개변수를 먼저 읽으면 직접 호출이 아닌 경로에서 다른 값을 읽는다

cyber.h는 "`cl_thread_ret` may be called before or after the parameters are read"라고 적는다. 직접 호출에서는 맞다. 호스트 함수를 값으로 부르는 경로에서는 매개변수를 먼저 읽으면 오류 없이 다른 값을 읽는다.

호스트 함수 둘(`first(s str) -> int`는 길이를 돌려주고, `less(a str, b str) -> bool`은 비교한다)은 `cl_thread_str`을 먼저 부르고 그다음 `cl_thread_ret`을 부른다. 대조군은 같은 함수에서 `cl_thread_ret`을 먼저 부른다.

~~~text
경로                                  매개변수 먼저   반환 슬롯 먼저(대조군)
직접 호출 order.first('hello')         5              5
함수 포인터 값 var f F = order.first    0              5
함수 union 값 var g Func[F] = ...       0              5
sort가 부르는 함수 xs.sort(order.less)  {'a', 'c', 'b'}  {'a', 'b', 'c'}
~~~

(`type F = fn(str) -> int`, `xs := {'b', 'c', 'a'}`. 모두 `CL_SUCCESS`로 끝난다.)

원인으로 보이는 곳: src/vm.c의 `CALL_HOST`는 호스트 함수를 부르기 전에 `t->c.fp_end = stack + base + 4`를 둔다. src/thread.zig의 `callPtrInst`, `callUnionInst`, `callFunc2`(표준 메서드가 함수 값을 부를 때), `callTraitSymInst`는 `fp`와 호출 정보만 두고 `fp_end`를 두지 않는다. 그래서 첫 `param`이 앞선 호출이 남긴 `fp_end`에서 읽는다. `callTraitSymInst`는 코드로만 보았고 실행해 보지 않았다.

요청:

- 호스트 함수를 부르는 모든 경로에서 `fp_end`를 매개변수의 시작에 둔다(한곳의 도우미로 모으면 경로가 늘어도 빠지지 않는다).
- 위 세 모양(함수 포인터 값, 함수 union 값, 표준 메서드가 부르는 호스트 함수)을 매개변수를 먼저 읽는 호스트 함수로 확인하는 테스트.

tars-agent의 능력은 반환 슬롯을 먼저 받는다. 그래도 cyber.h가 허용한다고 적은 순서가 경로에 따라 오류 없이 틀린 값을 주는 것은 결함이라 선행 조건에 둔다.

## 2. 커밋을 원격에 올린다

bf5967db, 5de6c83a가 soomtong/cyber 원격에 없다. tars-agent 스파이크는 지금 로컬 경로 의존(`.path = "../../../cyberscript"`)으로 받는다. 본체와 docs/deps.md는 URL과 해시로 고정한다.

요청: 1절의 수정과 함께 push한다. 릴리스(0.4.11 등)나 태그가 정해지면 tars-agent는 그것으로 고정한다.

## 3. `str`의 `len` 필드에 제안이 없다

~~~cy
s := 'abc'
print(s.len)
~~~

``Type `str` does not have a field named `len`.``로 끝난다. `[]int`의 `xs.len`은 이제 ``Did you mean the method `len()`?``를 낸다. 회신의 변경 기록은 `str`도 고쳤다고 적었는데, 이 커밋의 CLI와 세션 양쪽에서 위 문구다. `s.length`는 메서드 제안을 낸다.

요청: `str`에서도 필드 이름과 같은 메서드(`len()`)를 제안한다.

## 4. `cl_vm_validate`가 쓰는 설정

`cl_vm_validate(vm, src)`는 설정 인자가 없고 마지막 eval의 설정(`persist_main`, `deny_raw_ptrs`, `deny_spawn`)을 쓴다(src/vm.zig `validate`: `ValidateConfig`는 `_ = config`로 버린다). 그래서 eval을 한 번도 하지 않은 VM에서 `spawn`이 든 스크립트를 검증하면 `CL_SUCCESS`이고, 같은 VM에서 `deny_spawn` eval을 한 번 한 뒤에는 `CL_ERROR_COMPILE`이다. cyber.h의 `cl_vm_validate` 설명에는 이것이 없다.

tars-agent는 머리말을 eval한 뒤에만 검증하므로 지금 문제가 되지는 않는다.

요청: cyber.h에 "마지막 eval의 설정으로 검증한다"를 적는다. 또는 `cl_vm_validate`가 설정을 받는다.

## 5. 순서가 반대인 섞인 목록의 문구

`{1, 'a'}`는 ``Expected type `int`, got `str`. A list literal without a type takes the type of its first element and does not convert the others. Write the element type: `[]T{...}`.``를 낸다. `{'a', 1}`은 ``Expected type `str`, got `int`.``로 끝나 설명이 없다.

요청: 타입 없는 목록 리터럴의 원소 오류에는 순서와 관계없이 같은 설명을 붙인다.

## 6. 비교 회차에서 모델이 만난 문구

이 커밋으로 CodeAct 비교를 두 번 돌렸다. 첫 회차는 돌던 중 cyber 작업 트리에 커밋하지 않은 변경(클로저 고정)이 생겨 그것이 섞였으므로 숫자에서 뺐고, `git archive 5de6c83a`로 푼 소스로 다시 돌렸다(과제 27개, 컴파일 오류 26건). 아래는 두 회차에서 문구가 고치는 법을 말하지 않아 모델이 안내나 짐작으로 고친 것이다. 모두 이 커밋의 CLI로 다시 확인했다.

(a) 보간 안의 보간이 줄바꿈 오류가 된다.

~~~cy
n := 'x'
print('%{'L%{n}'.len()}')
~~~

``TokenError: Encountered new line in single line literal.`` 줄에 줄바꿈이 없다. 보간 안의 문자열 리터럴(`'%{'a b'.len()}'`)은 되고, 그 안에 다시 `%{}`가 있을 때만 이렇다. 모델(deepseek-chat)은 `'%{name}: %{fs.read('logs/%{name}')!.split('\n').len()}'`를 썼다. 요청: 보간 안의 보간을 지원하거나, ``An interpolated string can not contain another interpolated string. Assign the inner string to a variable first.``처럼 원인을 말한다. docs.md에도 적는다.

(b) `elif`가 이름으로 읽힌다.

``ParseError: Expected end of line or file. Got ident.``(`elif x == 2:`의 `x` 자리). `else if`는 ``Write `else cond:` ...``를 낸다. 모델(qwen3.8-flash)이 두 회차 모두에서 썼다. 요청: `elif`에도 같은 안내를 낸다.

(c) 최상위 `!else |e|:` 블록의 끝.

~~~cy
fn f() -> !str:
    return error.Bad
v := f() !else |e|:
    print('failed %{e}')
print(v)
~~~

``Expected unreachable block end.`` 요청: 무엇으로 끝나야 하는지(`return`, `panic`, 반복 안이면 `continue`, `break`)와 최상위에서는 `try:` 블록이나 `!else 기본값`을 쓰라는 것을 말한다.

(d) `trimStart`, `trimEnd`, `trim_start`, `trim_end`에 제안이 없다. `lstrip`은 ``Did you mean `trim`?``을 낸다. 모델(qwen3.8-flash)이 `trimStart`를 썼다. 요청: 이 이름들을 제안 표에 넣는다(한쪽만 자르는 메서드가 없으면 `trim`과 그 사실을).

(e) 옵션 풀기를 `and`로 묶으면 원인을 말하지 않는다.

~~~cy
t := 'a=1'
ok := true
if ok and t.index('=') |i|:
    print(i)
~~~

``Expected type `bool`, got `?int`.`` 모델(qwen3.8-flash)이 다시 돈 회차에서 세 번 썼다. 안내의 `if s.index(x) |i|:`를 다른 조건과 묶은 것이다. 요청: `|v|` 풀기는 조건 전체에만 붙는다는 것과 `if` 안에 `if`를 두라는 것을 말한다(또는 `and`의 오른쪽에서 풀기를 지원한다).

(f) 보간 안의 `\"`.

~~~cy
s := 'ab'
print("ends: %{s.ends_with(\"b\")}")
~~~

``TokenError: unknown character: \ (92) at 37`` 위치는 맞지만(2:28) 문구가 바이트 오프셋과 문자 코드를 말한다. 모델(qwen3.8-flash)이 큰따옴표 문자열의 보간 안에서 `\"`를 썼다. 요청: ``A backslash is not allowed inside `%{}`. Use the other quote: `'b'`.``처럼 말한다.

## 회신에서 확인을 부탁한 것

- `#include "cyber.h"`: 아티팩트의 include 경로로 받는다. s1에 C 파일 하나를 넣어 `#include "cyber.h"`로 컴파일하고 `sizeof(CLEvalConfig)`, `sizeof(CLCompileConfig)`(둘 다 12)가 translate-c 쪽과 같은 것을 확인했다.
- 의존 인자: `b.dependency("cyber", .{ .target, .optimize, .static = true, .commit })`와 `artifact("cyber")`로 macOS arm64와 x86_64-linux-gnu 교차 빌드가 된다. 버전 문자열은 `Cyber 0.4.10-DEV build-0-5de6c83a`다.

## 확인을 마친 것

이 커밋에서 다음이 통과했다(s1 검사 39개 모두 통과).

- 이스케이프 오류(`\|`, `\xZZ`)는 위치 있는 컴파일 오류이고 세션의 변수, 함수, use가 남는다. `cl_vm_reset_pending`은 false다.
- VM의 첫 컴파일이 실패하면 `cl_vm_reset_pending`이 true이고 다음 eval부터 세션이 이어진다.
- panic 뒤에는 함수와 use가 남고 앞선 eval의 지역도 사라지며 `cl_vm_reset_pending`은 false다. tars-agent는 이것을 모델에게 알리는 쪽으로 간다.
- `'\0'`은 NUL이다.
- `deny_spawn`: eval과 검증에서 `spawn`이 컴파일 오류이고, scope 블록의 동시 승인 검사는 그대로 통과한다.
- 직접 호출에서 매개변수를 먼저 읽어도 된다.
- 오류 문구: 세션의 캡처 오류("Inside a function, you can also borrow ..."), `xs.len`, `not`을 `?int`에 쓴 것, `to_upper`, `to_lower`, `uppercase`, `to_split`.
- `{1, 'a'}`, `{1.5, 2}`는 컴파일 오류이고 `[]int{1, 'a'}`는 `{1, 97}`이다.
- 안내 문서의 코드 블록 11개는 CLI와 세션 양쪽에서 통과했다.
- 비교 회차(deny_spawn을 켠 세션, 과제 27개 모두 통과)에서 세션 reset, panic, 상한에 걸린 실행은 없었다.
