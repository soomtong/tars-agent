# cyber에 보내는 요청: M0 스파이크에서 나온 것 (2026-11-13)

보내는 쪽: tars-agent. 대상: soomtong/cyber 0.4.9 (태그 0.4.9, 03d24f4e). 배경과 전체 결과는 tars-agent의 docs/spikes/2026-11-13-m0-spikes-review.md.

호스트는 Zig 0.17.1, macOS arm64와 x86_64-linux-gnu(tars 게스트). 라이브러리는 받은 패키지에서 `zig build lib -Doptimize=ReleaseFast -Dffi=false -Dstatic=true`로 만들었다. eval 설정은 persist_main과 deny_raw_ptrs를 켰다.

우선순위 순이다. 1과 2가 tars-agent M1의 선행 조건이다.

## 1. 실패한 컴파일 뒤 다음 컴파일에서 프로세스가 죽는다

재현 A. 한 VM에서 차례로 cl_vm_validate(또는 cl_vm_evalx)한다.

첫 스크립트:

~~~cy
names := []str{'a', 'b'}
counts := Map[str, int]{}
names.sort(|a, b| counts[a] > counts[b])
~~~

결과는 CL_ERROR_COMPILE(Can only capture variables declared with the reference types `^T` or `&T`.)이다. 여기까지는 맞다.

둘째 스크립트:

~~~cy
counts := Map[str, int]{}
counts['a'] = 1
print(counts['a'])
~~~

결과는 Segmentation fault at address 0x0이다. 스택의 맨 위는 컴파일 경로다(릴리스 빌드라 심볼은 cl_vm_validate 근처로만 찍힌다). 둘째 스크립트를 다음으로 바꿔도 죽는다: `names := []str{'a', 'b'}` 뒤에 `names.sort(|a, b| a.less(b))`. 다음으로 바꾸면 죽지 않는다: 목록의 len, 인덱스 대입, 문자열 덧붙이기.

재현 B. 호스트 로더가 돌려주는 모듈 소스가 컴파일에 실패하는 경우다. 모듈 소스:

~~~cy
fn read(path str) -> !str:
    return undefined_thing
~~~

한 VM에서 `use fs`가 든 스크립트와 `print('plain')`을 번갈아 eval하면 결과는 COMPILE, SUCCESS, COMPILE, SUCCESS, 그리고 세 번째 `use fs`에서 Segmentation fault다. persist_main을 꺼도 같다.

요청: 실패한 컴파일이 남긴 상태를 다음 컴파일이 밟지 않게 한다. 컴파일 실패 뒤의 VM이 실패 전과 같은 상태라는 것을 테스트로 고정한다(실패하는 스크립트 여러 종류 뒤에 성공하는 스크립트를 컴파일).

왜 급한가: 에이전트에서 컴파일 실패는 정상 경로다. 과제 셋을 모델 셋으로 돌린 비교 실행에서 컴파일 실패가 31번 있었다. 첫 세션의 일곱 번째 스텝에서 이 결함으로 죽었다.

tars-agent의 임시 대응: 검증을 fork한 자식에서 하고 부모는 통과한 코드만 컴파일한다.

## 2. `!T`의 T가 관리되는 타입이면 값을 복사하지 못한다

~~~cy
fn g() -> !str:
    return 'a'
x := g()
y := x
print(y!)
~~~

CompileError: Expected type instance of `Result`, found `Ptr[!str]`. 위치는 core:2918:49 (`return meta.access_result_error(src)`). `!int`는 된다.

결과: `Future[!str]`의 await가 컴파일되지 않는다(await가 값을 복사한다). 호스트가 문자열을 돌려주는 능력을 `Future[!str]`로 선언할 수 없다. ADR 0011의 모양이 문자열 결과에서 막힌다. `print(f())`처럼 `!`를 빠뜨린 스크립트도 같은 오류가 core의 위치로 나와 작성자가 원인을 알 수 없다.

요청: 수정, 그리고 lib_test/await.zig에 `Future[!str]`과 `Future[![]int]` 경우를 더한다.

tars-agent의 임시 대응: `Future[!int]`로 손잡이를 돌려주고 래퍼가 동기 함수 take(h)로 문자열을 꺼낸다.

## 3. 빌드 내보내기 (C1)

`b.dependency("cyber", .{}).artifact("cyber")`가 panic한다(unable to find artifact "cyber"). 라이브러리가 `lib` 스텝 아래에서만 설치되기 때문이다.

요청: 의존으로 쓰는 쪽이 정적 라이브러리와 헤더를 얻는 길을 낸다. 예: 옵션(target, optimize, ffi=false)을 받아 `b.installArtifact`로 라이브러리를 내보내고 `installHeader`로 cyber.h를 싣는다. 실행 파일과 이름이 겹치지 않게 한다. 의존으로 빌드할 때 버전 문자열이 `0.4.9-DEV build-0-local`이 되지 않게 한다.

tars-agent의 임시 대응: build.zig에서 받은 패키지 폴더를 작업 폴더로 `zig build lib`를 실행하고 산출물을 링크한다.

## 4. spawn 차단 옵션 (C3)

`spawn(work, {x})`가 임베딩에서 그대로 되고, 스레드 안에서 호스트 함수가 불린다. cyber.h는 cl_future_new를 메인 스레드에서 부르라고 적는다. 호스트의 요청 표가 스레드에 안전하지 않다.

요청: 스크립트의 spawn을 컴파일 오류로 만드는 eval 설정(deny_raw_ptrs와 같은 자리).

## 5. 작은 것

- 호스트 함수에서 cl_thread_ret보다 cl_thread_str을 먼저 부르면 Segmentation fault다. cyber.h에 "반환 슬롯 먼저, 매개변수는 선언 순서"를 적어 주기를 요청한다.
- str, 목록, Map의 메서드 목록을 기계가 읽는 형태로 얻는 수단. 모델이 없는 메서드(join, pop, find, startswith)를 추측해 컴파일 오류를 낸다. 프롬프트 안내에 넣을 표의 원본이 필요하다.

## 확인된 것 (참고)

승인, 거부, 취소, 버린 Future, 태그 0, scope 블록의 요청 둘, 중첩 scope(F-111), 연료, interrupt, 스택과 메모리 상한, persist_main, validate와 구조화된 오류, deny_raw_ptrs, 호스트 로더: 모두 문서대로 동작했다. macOS와 tars 게스트(Linux 6.18.60, x86_64)에서 같은 검사 31개가 통과했다.
