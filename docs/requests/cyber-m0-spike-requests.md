# cyber 요청: M0 스파이크에서 남은 것

보내는 곳: soomtong/cyber. 기준: master 63e35e88 (`Cyber 0.4.10-DEV`). 확인일 2026-11-14.

tars-agent는 libcyber를 정적 링크해 모델이 쓴 Cyber 스크립트를 세션 VM(persist_main, 검증 뒤 실행)에서 돌린다. M0 스파이크(호스트 경계 검사 34개, 모델 셋의 CodeAct 비교)를 이 커밋으로 돌렸고, 아래가 남았다. 1~5가 tars-agent 본체 첫 단계의 선행 조건이다. 6은 모델이 실제로 따라가는 문구라 그다음이고, 7은 판단을 맡긴다.

재현에 쓴 것: tars-agent의 spike/s1(`zig build && ./zig-out/bin/s1`, `s1 replay <파일>`은 `=====` 줄로 나눈 스크립트를 한 VM에서 검증 뒤 실행한다)과 이 커밋의 CLI.

## 1. 문자열 이스케이프 오류가 세션을 지운다

CodeAct 회차에서 모델(qwen3.8-flash)이 grep 패턴을 `"TODO\|Todo"`로 썼다. 그 스크립트는 컴파일 오류로 끝났는데, 그 뒤 세션의 변수, 함수, `use`가 모두 사라졌다. 모델은 `Undeclared variable proc`를 세 번 받고 나서야 우회했다. 호스트는 세션이 지워진 것을 모른다.

~~~text
keep := 7
fn helper() -> int:
    return 11
=====
s := "a\|b"
=====
print(keep)
=====
print(helper())
=====
print(proc.exec('echo p')!)
~~~

`s1 replay`의 결과(머리말에서 `use fs`, `use proc`를 한 세션):

~~~text
script 0: validate=SUCCESS eval=SUCCESS
script 1: validate=COMPILE | CompileError: Error: InvalidEscapeSeq
script 2: validate=COMPILE | CompileError: Undeclared variable `keep`.
script 3: validate=COMPILE | CompileError: Undeclared variable `helper`.
script 4: validate=COMPILE | CompileError: Undeclared variable `proc`.
~~~

검증 없이 eval만 해도 같다. `\xZZ`도 `Error: InvalidCharacter`로 같은 결과다. 다른 토큰 오류(`1 $ 2`), 구문 오류(`(1`), 보통 컴파일 오류(`print(nope)`) 뒤에는 세션이 그대로다.

원인으로 보이는 곳: src/sema.zig의 이스케이프 해석이 `error.InvalidEscapeSeq`(그리고 `\x`의 `std.fmt.parseInt` 오류)를 맨 Zig 오류로 돌려준다. src/compiler.zig의 컴파일 실패 처리는 `error.CompileError`가 아닌 오류를 할당 실패로 표시하고(`self.alloc_failed = true`), 할당 실패면 다음 eval 앞에서 VM을 reset한다. 문구가 `Error: InvalidEscapeSeq`이고 위치가 없는 것도 같은 경로 때문이다.

요청:

- 이스케이프 오류를 위치가 있는 보통 컴파일 오류로 낸다(예: ``Invalid escape sequence `\|`. A backslash in a string must be one of \n \t \r \\ \' \" \xHH. Write `\\|` for a backslash.``).
- 할당 실패 판정을 실제 할당 실패로 좁힌다. 컴파일러 안의 다른 Zig 오류가 세션을 지우지 않게 한다.
- 세션이 reset됐을 때 호스트가 알 수 있는 길(결과 코드, 조회 함수, 또는 다음 eval의 표시). 호스트는 모델에게 "variables were reset"을 알려야 한다.

## 2. `\0`이 큰따옴표가 된다

~~~cy
s := 'a\0b'
print(s)
print(s[1])
~~~

`a"b`, `0x22`를 찍는다. src/sema.zig의 이스케이프 표에서 `'0'` 분기가 `'"'`를 돌려준다. 오류 없이 다른 값이다. NUL(0)이 맞는지, `\0`을 없애는지는 cyber가 정한다.

## 3. 빌드 내보내기

build.zig.zon 의존으로 받은 cyber에서 라이브러리를 가져올 길이 없다.

~~~zig
const cyber = b.dependency("cyber", .{});
exe.linkLibrary(cyber.artifact("cyber")); // panic: unable to find artifact "cyber"
~~~

build.zig가 라이브러리를 `lib` 스텝 아래(`addInstallArtifact`)에서만 설치하기 때문이다. tars-agent는 지금 받은 패키지 폴더에서 `zig build lib -Dffi=false -Dstatic=true`를 한 번 더 실행해 libcyber.a를 링크한다.

요청:

- 의존 쪽이 `artifact`(또는 모듈)로 정적 라이브러리를 받을 수 있게 내보낸다. 옵션(ffi, static, target, optimize)은 의존 인자로 받는다.
- 의존으로 빌드한 라이브러리의 버전 문자열이 `Cyber 0.4.10-DEV build-0-local`이다. 어느 커밋인지 알 수 없다. 의존으로 빌드할 때도 커밋이 찍히게 한다(예: 의존 인자).

## 4. spawn 차단 옵션

`spawn(work, {21})`을 막는 임베딩 옵션이 없다. 스레드 안에서 호스트 함수(능력)가 불린다(`s1 spawn`: 스레드 안의 `fs.read`가 성공한다). tars-agent의 능력은 요청 표와 승인 흐름을 메인 스레드에서만 다루고, cyber.h도 Future 생성을 메인 스레드에서 하라고 적는다.

~~~cy
use fs
fn work(p str) -> int:
    t := fs.read(p) !else 'ERR'
    return t.len()
f := spawn(work, {'/tmp/in.txt'})
print(f.await())
~~~

요청: `CLEvalConfig`에 spawn을 컴파일 오류로 만드는 필드(예: `deny_spawn`). deny_raw_ptrs와 같은 모양이면 된다. 그 전까지 tars-agent는 능력 함수 첫머리에서 메인 스레드가 아니면 panic을 돌려준다.

## 5. 호스트 함수 인자 읽기 순서의 문서

호스트 함수의 반환 슬롯과 매개변수는 정해진 순서로 읽어야 한다: `cl_thread_ret`을 먼저, 그다음 매개변수를 선언 순서대로(`cl_thread_str`, `cl_thread_int` ...). 매개변수를 먼저 읽으면 `cl_thread_str`에서 `Segmentation fault at address 0x0`으로 죽는다(`s1 order`). cyber.h의 해당 선언(`void* cl_thread_ret(CLThread* t, size_t size);` 근처)에는 "Return and parameters for host functions."만 있다.

요청: 순서와 어겼을 때의 결과를 cyber.h에 적는다. 가능하면 Debug 빌드에서 순서를 어기면 panic 문구로 알린다.

## 6. 세션에 맞는 오류 문구

모델은 오류 문구가 권하는 대로 고친다. 넷이 에이전트 세션에서 틀린 곳으로 이끌거나 원인을 가린다.

(a) 캡처 오류가 최상위 빌림을 권한다.

~~~cy
names := []str{'a', 'b'}
counts := Map[str, int]{a=1, b=2}
names.sort(|a, b| counts[a] > counts[b])
~~~

``Can only capture variables declared with the reference types `^T` or `&T`. Declare it with `^T`, or borrow it before the lambda (`b := &counts`) and use `b` in the lambda.``

권하는 대로 최상위에 `c := &counts`를 쓰면 CLI에서는 되지만 persist_main 세션에서는 ``Cannot persist local `c` of borrow type `&Map[str, int]` across evals.``다. 요청: persist_main일 때는 빌림 제안을 빼거나 "inside a function"을 붙인다. `^T`로 선언하는 제안이 먼저 오면 세션에서도 맞다.

(b) `xs.len`이 내부 필드를 제안한다.

~~~cy
xs := []int{1}
print(xs.len)
~~~

``Field `len` does not exist in `[]int`. Did you mean `_len`?`` 같은 실수의 `s.length`는 ``Did you mean the method `len()`?``를 낸다. 요청: `[]T`에서도 메서드 `len()`을 제안하고, 밑줄로 시작하는 내부 필드는 제안하지 않는다.

(c) `not`을 `?T`에 쓰면 `!`를 말한다.

~~~cy
idx := 'a'.index('b')
if not idx:
    print(1)
~~~

``Can not find the symbol `!` in `?int`.`` 모델(deepseek-chat)이 이 모양을 두 번 썼고, 문구가 `not`이 아니라 `!`를 말해 원인을 찾지 못했다. 요청: `not`이라고 말하고, `?T`면 `if x |v|:`, `x == none`, `?else`를 알려 준다.

(d) Rust식 이름에 제안이 없다. `'a'.to_upper()`, `to_lower()`, `uppercase()`는 ``Can not find the symbol `to_upper` in `str`.``로 끝난다. `toUpperCase`는 ``Did you mean `upper`?``를 낸다. 모델(qwen3.8-flash)이 `to_upper`를 썼다. 요청: `to_` 접두사를 뗀 이름과 `upper`, `lower`를 제안 표에 넣는다.

## 7. (판단을 맡김) 타입 없는 목록의 문자 코드 변환

~~~cy
xs := {1, 'a'}
print(xs)
~~~

`{1, 97}`을 찍는다. 목록이 첫 원소의 타입(`[]int`)을 따르고 한 글자 문자열이 정수 자리에서 코드 포인트가 되는 규칙이 겹친 결과다. `{'a', 1}`은 컴파일 오류다. 모델이 섞인 목록을 쓸 일은 드물어 tars-agent는 안내에 적어 두었다. 타입 없는 목록 리터럴의 원소에서는 이 변환을 하지 않는 쪽이 안전해 보이지만, 언어 규칙이라 cyber가 정한다.

## 확인을 마친 것

이 커밋에서 다음은 스파이크의 본래 모양으로 통과했다: 능력이 `Future[!str]`을 돌려주고 str 값으로 완료하기, 보통의 컴파일 실패 뒤 세션 VM에서 바로 검증하기, 모듈 소스가 실패한 뒤 다시 use하기, 목록 참조의 `+=`가 컴파일 오류로 잡히기. 안내 문서의 예제 10개는 CLI와 세션 양쪽에서 통과했다.
