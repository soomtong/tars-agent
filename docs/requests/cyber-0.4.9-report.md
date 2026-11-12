# 보고: cyber 0.4.9의 호환성 변경 (fiber 양보, 취소, scope 블록)

soomtong/cyber에서 2026-11-12에 쓴 안내 초안이다. 0.4.9는 태그 `0.4.9` → `03d24f4e`, 빌드 `build-833-03d24f4`다. 요청에 대한 답이 아니라 cyber가 먼저 넣은 변경의 안내다. 반영할 곳은 docs/spec/08-cyber-implementation.md의 0.4.9 항목, docs/deps.md의 고정 버전, 프롬프트 안내다.

원본 기록은 cyber 저장소의 `docs/releases/0.4.9.md`(호환성 절과 알려진 문제 절), `docs/decisions/project_coroutines.md`의 "단계 3 구현"부터 "전체 리뷰"까지의 절, 계약은 `src/include/cyber.h`다.

## 1. 먼저 볼 것: 82877718과 태그는 다르다

tars-agent는 로컬 빌드 `82877718`로 예제 20개를 돌려 0.4.8과 출력이 같음을 확인했다. 태그는 그 뒤 커밋 둘(`06b0cd7b`, `03d24f4e`)이 더 들어간 `03d24f4e`다. 두 커밋은 0.4.9를 내기 전의 전체 리뷰에서 찾은 결함의 수정이고, fiber와 scope를 쓰지 않는 스크립트의 동작은 바꾸지 않는다. 릴리스 바이너리로 예제를 다시 돌릴 때 달라질 것은 없어야 한다.

`82877718`에는 있었고 태그에서 고쳐진 것:

| 번호 | `82877718`의 동작 | 태그의 동작 |
|---|---|---|
| F-111 | 자기 scope 블록에서 Future를 기다리는 fiber가, 블록 밖의 fiber가 기다리던 Future가 끝나면 양보하지 않고 CPU 100%로 끝없이 돈다. 호스트가 중첩 그룹 밖의 요청 하나를 먼저 완료하고 cl_vm_resume해도 같다 | fiber 안의 Fiber.wait_ready()는 한 번 양보한 뒤 돌아온다 |
| F-107 | core의 메서드가 사용자 함수에 인라인된 자리 아래에서 멈춘 fiber는 취소되지 않는다. 자기 scope 블록에서 자식을 기다리는 fiber가 형제의 실패에도 계속 기다린다 | 취소된다 |
| F-108 | 취소되는 fiber가 가진 Scope가 자식을 합류하려다 panic: A fiber was suspended while it was cancelled. | 그 Scope는 자식을 취소한다 |
| F-110 | scope 블록을 return, break, continue로 나간 뒤 fiber가 오류를 돌려주면 panic: Unwrapped error | 출구 문장 앞에서 합류하고 오류는 `!`처럼 블록 밖으로 나간다 |
| F-109 | Scope가 끝난 fiber를 라운드마다 다시 훑는다. 짧은 fiber 2만 개와 2만 번 양보하는 fiber 하나가 11.2초 | 끝난 fiber는 그 라운드에서 해제한다. 같은 사례 0.02초 |
| (번호 없음) | fiber가 오류를 돌려준 뒤에도 같은 라운드의 뒤쪽 fiber가 한 번 더 돈다. 시작 전이던 fiber는 그 한 번에 끝까지 갈 수 있다 | 오류 직후부터 나머지를 취소한다 |

F-111이 tars-agent에 가장 가깝다. 승인 요청을 여럿 동시에 걸고 그중 하나를 먼저 완료하는 흐름이 그 모양이다. `82877718`로 그 흐름을 시험했다면 태그로 다시 본다.

## 2. 호스트(임베딩) 쪽 호환성 변경

0.4.8에서 돌던 호스트의 동작이 달라지는 것만 적는다.

### 2.1 fiber 안의 await는 eval을 나가지 않는다

0.4.8에서는 fiber 안에서 호스트 Future를 await하면 eval이 CL_AWAIT로 돌아왔다. 0.4.9에서는 그 fiber만 멈추고 `resume`이 `.suspended`를 돌려준다. eval이 CL_AWAIT로 나가는 것은 루트 맥락이 기다릴 때뿐이다.

- 루트의 `Future.await()`와 `Future.wait_any`
- 루트의 `Fiber.wait_ready()`
- 루트에 있는 scope 블록의 합류와 `Scope.join()`

fiber를 직접 resume하는 루프가 `Fiber.wait_ready()`를 부르지 않으면 호스트는 Future를 완료할 기회를 얻지 못한다. 그 스크립트는 연료와 시간 상한까지 돈다. 모델이 쓰는 코드에서 이 실수를 막으려면 안내에서 fiber를 직접 돌리는 루프 대신 scope 블록을 쓰게 한다.

### 2.2 한 번의 CL_AWAIT에 요청이 여럿 걸린다

`Fiber.wait_ready()`나 scope 블록의 합류로 멈춘 eval에서 `cl_vm_pending_futures`는 멈춘 fiber들이 기다리는 Future 전부를 돌려준다. 순서는 없고 태그(`cl_future_tag`)로 식별한다. `cl_vm_pending_future`(단수)는 그중 하나만 준다.

- 아무것이나, 여러 개를 완료하고 `cl_vm_resume`한다. 남은 것이 있으면 다시 CL_AWAIT다.
- 완료하지 않고 resume하면 같은 목록으로 다시 CL_AWAIT다.
- 완료한 Future의 fiber가 다음 요청을 내면 목록에 새 Future가 들어온다. resume 뒤에는 목록을 다시 읽는다.

중첩 그룹(scope 블록 안의 fiber가 자기 scope 블록을 가진 경우)의 Future도 같은 목록에 평평하게 들어온다. 어느 그룹의 것이든 먼저 완료해도 된다. cyber의 lib 테스트 `A scope block at the root waits for the host futures of nested groups, and an abandon frees them.`가 이 흐름이다(그룹 밖의 요청을 먼저 완료, 그 뒤 그룹의 둘).

### 2.3 완료되지 않은 채 버려지는 요청

스크립트가 기다리지 않은 Future는 완료되지 않은 채 남는다. 세 경우다.

- scope 블록의 fiber 하나가 오류를 돌려주면 나머지 fiber는 취소된다. 취소된 fiber가 기다리던 요청은 더는 await되지 않는다.
- 루트가 기다리지 않고 스크립트가 끝나면 남은 fiber는 소멸하며 취소된다.
- `cl_vm_abandon`은 멈춘 eval과 그 fiber를 통째로 버린다.

cyber는 버려진 요청을 호스트에 알리지 않는다. 호스트는 eval이 끝났을 때(CL_SUCCESS, panic, abandon) 자기 요청 표에 남은 항목을 버린다. Future의 포인터를 보관하는 호스트의 retain 규칙은 0.4.8과 같다: panic, interrupt, abandon, reset 뒤에는 힙이 이미 해제됐으니 release하지 않는다.

### 2.4 진행 중인 fiber의 소멸은 취소다

0.4.8에서는 `panic: Fiber is still in progress.`였다. 0.4.9에서는 fiber가 들어가 있는 호출들이 안쪽부터 바로 반환하고 값은 해제된다(`@deinit` 호출 포함). 나머지 코드는 실행되지 않는다. 호스트가 볼 수 있는 차이는 CL_ERROR_PANIC으로 끝나던 스크립트가 CL_SUCCESS로 끝난다는 것이다.

취소할 수 없는 경우가 둘 남아 있고 그 fiber의 소멸은 여전히 panic이다: `^T` 참조의 `@deinit` 안에서 멈춘 fiber, 제너레이터가 끝날 때 도는 `@deinit` 안에서 멈춘 fiber.

### 2.5 main 결과의 소유

`fn main() -> T`의 결과(`CLEvalResult`의 값)는 VM이 소유한다. 다음 eval, `cl_vm_reset`, `cl_vm_deinit`까지 유효하다. `cl_vm_release_result(vm)`가 바로 해제하고 그 뒤에는 `res->res`를 읽을 수 없다. `cl_thread_rc`로 누수를 세는 호스트(평가 도구)는 먼저 이것을 부른다. 0.4.8에서는 힙 결과가 해제되지 않고 남았다.

## 3. 스크립트 쪽 호환성 변경

0.4.8에서 컴파일되거나 돌던 스크립트가 달라지는 것이다.

- `scope`는 예약어다. 변수 이름으로 쓰면 ParseError다(이미 안내에 반영됨).
- `Scope.start`에 빌림 인자(`&T`, `&&T`)를 넘기면 컴파일 오류다: `Cannot borrow a stack value across fibers.` scope 블록 이름의 `s.start(func, {&x})`만 받는다. `fiber T.method(&obj)`처럼 타입 경로로 댄 진입점의 빌림 매개변수도 컴파일 오류다.
- `r64` → `float` 변환이 부호 없는 값으로 읽는다. `0xFFFFFFFFFFFFFFFF`를 담은 `r64`는 `-1.0`이 아니라 `18446744073709551615.0`이다.
- `cyber fmt`와 `cl_vm_format`이 리터럴 필드의 `=` 양쪽을 띄운다(`Vec2{x = 1}`). 이미 포맷한 텍스트도 다시 바뀔 수 있다.

## 4. 새로 쓸 수 있는 것

### 4.1 scope 블록

~~~cy
fn fetch(n int, out &int) -> !void:
    v := ask(n).await()
    out.* += v

fn run() -> !int:
    total := 0
    scope |s|:
        s.start(fetch, {1, &total})
        s.start(fetch, {2, &total})
    return total
~~~

- 블록을 나갈 때 모든 fiber가 끝나 있다. 본문이 끝에 닿으면 기다린다.
- 진입 함수는 `void`나 `!void`를 돌려준다. fiber가 오류를 돌려주면 나머지를 취소하고 그 오류가 `!`처럼 블록 밖으로 나간다(함수가 반환, 바깥 `try`의 `else`, 최상위에서는 panic).
- 본문의 `!`가 실패해도 시작한 fiber를 취소하고 같은 길로 나간다.
- `return`, `break`, `continue`는 fiber가 끝난 뒤 블록을 나간다. `return expr`의 식은 합류 뒤에 계산되므로 fiber가 한 일을 본다. 그때 fiber의 오류도 같은 길로 나간다.
- 함수 안의 블록은 `!T`나 `error` 반환 타입, 또는 바깥 `try` 블록이 필요하다.
- 블록의 fiber는 블록보다 먼저 선언된 값을 빌릴 수 있다. 본문 안에서 선언한 값은 못 빌린다. 빌림은 블록 끝까지 이어지고, 인자는 호출 자리의 리터럴로 쓴다.

### 4.2 Fiber와 Scope의 API

- `Fiber.cancel() -> bool`, `Fiber.waiting() -> bool`, `Fiber.wait_ready() -> bool`
- `Scope.new()`, `start(func, {args})`, `join() -> !void`, `active() -> int`, `abort()`
- 제너레이터 본문 안에서 멈춘 fiber도 취소된다.

## 5. 모델이 쓰는 코드에서 조심할 것

안내에 넣을 만한 함정이다.

- `out.* += fut.await()`는 await 전에 `out.*`를 읽는다(0.4.8의 왼쪽에서 오른쪽 평가). 여러 fiber가 같은 값에 더하면 뒤의 것이 앞의 결과를 덮는다. `v := fut.await()` 뒤에 `out.* += v`로 쓴다. cyber의 리뷰 중에도 탐침 스크립트 하나가 이것으로 틀린 합을 냈다.
- 양보만 하는 fiber(`suspend`를 반복)와 Future를 기다리는 fiber가 한 블록에 섞이면 블록은 쉬지 않고 돈다. 호스트 Future를 기다리는 동안에도 eval이 나가지 않으므로 연료 상한에 닿는다.
- `@deinit` 안에서 `suspend`나 `await`를 쓰지 않는다. 취소할 수 없는 fiber가 되거나, 취소 도중이면 `panic: A fiber was suspended while it was cancelled.`다.
- 자기를 돌리고 있는 Scope의 `join`을 그 fiber 안에서 부르면 `panic: The scope is already running its fibers.`다.

## 6. 알려진 한계

- 취소로 끊긴 `@deinit`의 값은 필드가 해제되지 않는다.
- 식 중간의 임시 값 중 연산자의 피연산자, 호출 인자, 리터럴 원소가 아닌 것은 취소 때 해제되지 않고 남는다. 호스트가 `cl_thread_rc`로 세면 누수로 보일 수 있다.
- 루트의 `await`와 `Fiber.wait_ready()`는 spawn한 워커 스레드를 기다릴 때 spin한다(0.4.8 이전부터의 동작). 호스트 Future만 기다릴 때는 해당 없다: eval이 나간다.
- 스택이 옮겨질 때 다른 fiber가 가진 빌림을 보정하는 경로 중 "시작한 뒤 suspend나 await에서 멈춘 fiber"는 테스트로 재현하지 못했다. 확인한 것은 시작 전 fiber의 경로다.
- 취소 정보로 컴파일 메모리가 조금 늘었다. `examples/fmt.cy` 실행 기준 최대 메모리 15.6MB → 16.2MB, 시간은 같았다(두 바이너리의 빌드 모드가 같은지는 확인하지 않았다).

## 7. tars-agent가 정할 것

docs/TODO.md의 0.4.9 항목에 이미 있는 결정과 이어진다.

1. 승인 요청이 여럿 동시에 걸릴 때의 처리 순서. cyber는 순서를 정하지 않는다(목록은 순서 없음, 태그로 식별). 요청 번호 순으로 하나씩 묻고 매번 resume할지, 한 번에 모아 물을지는 호스트의 선택이다.
2. 안내에서 fiber와 scope를 다루는 방식. 추천은 scope 블록만 가르치고 fiber를 직접 돌리는 루프는 다루지 않는 것이다. 2.1의 실수(기다리지 않는 루프)가 구조적으로 생기지 않는다.
3. 거부(error.Denied)가 한 fiber에서 나면 같은 블록의 나머지 요청은 취소된다. 이미 승인 화면에 올라가 있던 요청을 어떻게 닫을지(2.3)를 정한다.

## 8. 커밋

- `34235652` Suspend the fiber at an await and add Fiber.wait_ready and Fiber.waiting
- `5f050c55` Add Scope for groups of fibers and patch every stack pointer when the stack moves
- `9045308b` Add Fiber.cancel
- `e11a34e2` Add the scope block
- `ade55268` Let the fibers of a scope block borrow and patch their pointers when the stack moves
- `46a0a4d1` Cancel a fiber that is suspended in a generator body and fix a double destruct
- `82877718` Prepare 0.4.9: version and release notes
- `06b0cd7b` Fix scope cancel through inlined calls, early exits and the quadratic join
- `03d24f4e` Let a fiber in Fiber.wait_ready give control back before it returns (태그 0.4.9)
