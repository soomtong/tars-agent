# 보고: 루트 맥락의 중단과 재개 (CL_AWAIT, 코루틴 로드맵 단계 1)

soomtong/cyber에서 2026-11-12에 받은 보고 원문이다. 요청은 docs/requests/cyber-cl-await.md, 반영은 docs/spec/08-cyber-implementation.md와 ADR 0011.

요청서 `cyber-cl-await-request.md`에 대한 답이다. 2026-11-12 구현, soomtong/cyber의 master 로컬 커밋 `8de18b05`
(push 전). 릴리스는 0.4.8 예정이고 tars-agent의 피드백을 확인한 뒤에 낸다. 그때까지는 master를 빌드해서 쓴다.

원본 기록은 cyber 저장소의 `docs/decisions/project_coroutines.md` "단계 1 구현 (2026-11-12)" 절, 계약은 `src/include/cyber.h`의
"Suspended evals and host futures" 절, 동작하는 호스트는 `examples/libcyber/host_await.c`다.

## 1. 최종 C API

~~~c
typedef struct CLFuture CLFuture;   // FutureValue[T] 힙 객체. Future[T]가 가리키는 공유 상태

CLFuture*    cl_future_new(CLThread* t, CLType* future_t);
bool         cl_future_complete(CLVM* vm, CLFuture* future, const void* value);
bool         cl_future_complete_error(CLVM* vm, CLFuture* future, int64_t err);
CLFuture*    cl_vm_pending_future(CLVM* vm);
CLResultCode cl_vm_resume(CLVM* vm, CLEvalResult* res);
void         cl_vm_abandon(CLVM* vm);

// 새 결과 코드 (CL_ERROR_INTERRUPT 뒤에 추가)
CL_ERROR_SUSPENDED
~~~

요청서의 예시 이름을 그대로 썼고 `cl_future_new` · `cl_future_complete_error` · `CL_ERROR_SUSPENDED`를 더했다.

### cl_future_new

- 호스트 함수 안에서 미완료 Future를 만든다. main 스레드에서만 부른다.
- `future_t`는 `Future[T]` 타입이다. `cl_find_type(vm, CL_BYTES("Future[!void]"))`로 얻는다. 이미 확장된 템플릿 인스턴스만
  찾으므로 스크립트가 그 타입을 이름 지은 뒤여야 한다. 호스트 함수의 `#[bind]` 선언이 그 역할을 하니 호스트 함수 안에서
  부르면 항상 찾는다. 타입 포인터는 `cl_vm_reset` 뒤에 무효다.
- 반환 슬롯은 `CLValue`(모든 타깃에서 8바이트)다. 포인터 크기로 쓰지 않는다.

~~~c
CLValue* ret = cl_thread_ret(t, sizeof(CLValue));   // 매개변수를 읽기 전에 먼저
/* 매개변수 읽기 */
CLFuture* f = cl_future_new(t, future_t);
*ret = (CLValue)(uintptr_t)f;
~~~

- 소유권: 반환 슬롯이 참조를 소유한다. 호스트가 포인터를 비교 이상으로 쓰려면 `cl_thread_retain(t, (CLValue)(uintptr_t)f)`로
  잡고 나중에 `cl_thread_release`한다. 잡지 않은 포인터는 스크립트가 Future를 버리면 무효다.
- `future_t`가 `Future[T]`가 아니거나 할당이 실패하면 `NULL`.

### cl_future_complete / cl_future_complete_error

- `value`는 `T`를 가리킨다. 호스트 함수의 반환값과 같은 크기 · 모양이다(`int`는 8바이트, `str`은 `CLstr`, `[]T`는 `CLSlice`).
  값은 복사되고 Future가 소유한다. 완료 뒤에 호스트가 해제하지 않는다.
- `Future[!U]`는 `U`를 넘긴다. API가 `Result`로 감싼다. `Future[!void]`처럼 크기 없는 타입이면 `value`를 읽지 않는다(`NULL` 가능).
- 오류로 완료: `cl_future_complete_error(vm, f, cl_error(vm, CL_BYTES("Denied")))`. 스크립트는 `error.Denied`를 받는다.
  `Future[!U]`가 아니면 `false`.
- 이미 완료됐거나 `spawn`이 만든 Future면 `false`를 돌려주고 아무것도 가져가지 않는다.
- 호스트 함수 안에서 바로 완료해도 된다. 그 Future의 await는 빠른 경로이고 eval을 탈출하지 않는다.

### cl_vm_pending_future

- 멈춘 eval이 기다리는 Future. 멈춘 eval이 없으면 `NULL`.
- 빌린 포인터다. `cl_vm_resume` 또는 `cl_vm_abandon`까지 유효하다.
- 호스트는 `cl_future_new`가 돌려준 포인터와 비교해 어느 요청인지 찾는다.

### cl_vm_resume

- 멈춘 `await`에서 이어 실행한다. 결과 코드와 `res`는 `cl_vm_evalx`와 같은 규칙이다. 다음 await에서 다시 `CL_AWAIT`.
- Future를 완료하지 않고 부르면 다시 `CL_AWAIT`다(같은 Future).
- 멈춘 동안 들어온 interrupt 요청을 지운다(새 eval의 시작과 같은 규칙). resume을 부른 뒤에 도착한 요청만 eval을 멈춘다.
  그래서 승인 대기 중에 발동한 벽시계 타이머는 스크립트를 끊지 않는다. 타이머는 resume 직전에 다시 시작한다.
  멈춘 eval을 끊으려면 `cl_vm_abandon`을 부른다.
- 연료는 다시 채우지 않는다. 한 eval 전체의 검사점 수를 센다.
- 멈춘 eval이 없으면 `CL_ERROR_UNKNOWN`.

### cl_vm_abandon

- 멈춘 eval을 버린다. 결과는 interrupt와 같다: main 지역 변수는 사라지고(`persist_main`으로 이월된 것 포함) 선언은 남고
  VM은 다음 eval을 받는다. 누수가 없다.
- `cl_vm_error_summary`가 `panic: Abandoned while awaiting a future.`와 await 지점의 트레이스를 돌려준다.
- 멈춘 eval이 없으면 아무 일도 하지 않는다.

### 스레드 규칙

위 함수는 모두 그 VM의 eval을 돌리는 스레드에서 부른다. 기존과 같이 다른 스레드에서 불러도 되는 것은 `cl_vm_interrupt`뿐이다.

## 2. 요청서 항목별 결과

| 번호 | 결과 |
| --- | --- |
| 1 | 구현. pc · fp · 스택 · 지역 변수 · `persist_main` 상태 · 현재 fiber가 그대로 남는다 |
| 2 | 구현. 호출 깊이 제약 없음. 래퍼 함수, generator 본문 안의 await가 같은 경로다 |
| 3 | 구현. 한 eval 안에서 await와 resume을 몇 번이든 반복한다 |
| 4 | 구현. 완료된 Future는 탈출하지 않는다 |
| 5 | `cl_vm_abandon` |
| 6 | `cl_vm_eval*` · `cl_vm_validate` · `cl_vm_compile*`이 `CL_ERROR_SUSPENDED`. `cl_vm_reset` · `cl_vm_deinit`은 멈춘 eval을 먼저 버리고 진행한다 |
| 7 | 연료 · 스택 상한 · 메모리 상한이 이어진다. 멈춘 동안 연료는 줄지 않는다. 멈춘 동안의 interrupt 요청은 resume이 지운다. resume 뒤의 panic · interrupt · OutOfMemory는 평소 eval과 같다 |
| 8 | 탈출 허용. fiber 안의 await도 `CL_AWAIT`로 나가고 resume은 그 fiber 안에서 이어진다 |
| 9 | panic으로 막음. `Cannot wait in a spawned thread for a future that the host or another context completes.` 교착 · abort 없음 |
| 10 | `cl_future_new`. `Future[!T]` 포함 |
| 11 | `cl_future_complete` · `cl_future_complete_error`. 소유권은 반환 슬롯과 같은 규칙 |
| 12 | eval을 돌리는 스레드에서만 완료한다. 다른 스레드에서의 완료는 지원하지 않는다(힙은 스레드 소유이고 원자 연산을 넣지 않았다) |
| 13 | await하지 않은 Future, 미완료로 남은 Future는 일반 객체처럼 해제된다. 누수 · abort 없음 |

## 3. tars-agent가 알아야 할 동작

- 스크립트가 만든 미완료 Future(`FutureResolver.new(T)`를 완료 전에 await)도 `CL_AWAIT`가 된다. 호스트 Future와 구조가 같아
  VM이 구분하지 않는다. 호스트는 `cl_vm_pending_future`가 자기가 만든 Future가 아니면 `cl_vm_abandon`한다.
- 켜는 옵션은 없다. 미완료 Future의 await는 항상 `CL_AWAIT`다(이전에는 `panic: Local future will never complete.`).
- 호스트 함수가 스크립트를 다시 부른 안쪽의 await는 `panic: Cannot await across a host call.`이다. 공개 C API에는 호스트가
  스크립트 함수를 부르는 수단이 없어 tars-agent의 능력 함수에서는 닿지 않는다.
- `fn main() -> !T`가 돌려준 오류는 이제 `panic: Unwrapped error ...`이고 호스트는 `CL_ERROR_PANIC`을 받는다(이전에는
  `!T` 값이 조용히 결과로 왔다). 같은 0.4.8에 들어간다.
- wasm32에서 `cl_thread_retain` 등 `CLValue`를 값으로 주고받는 함수 일곱 개의 ABI가 헤더와 달랐던 것을 고쳤다. 64비트
  타깃은 영향이 없다.

## 4. 남은 제약과 알려진 문제

- 호스트는 한 번에 Future 하나만 본다. 여러 Future를 동시에 기다리는 수단(`wait_any`, 단계 4)이 없어 도구 여러 개를 동시에
  돌리는 스크립트는 쓸 수 없다. await는 순서대로 하나씩 호스트에 온다.
- fiber 안의 await는 eval 전체를 멈춘다. 다른 fiber에 양보하지 않는다(단계 3).
- 한 식 안에 임시 값을 수신자로 하는 메서드 호출이 둘 이상이면 수신자를 먼저 전부 만든다(F-98, 미수정).
  `host.ask(2).await() + host.ask(3).await()`는 요청 둘이 모두 나간 뒤 첫 await에 닿는다. 래퍼 함수를 거치면
  (`ask(2) + ask(3)`) 순서가 지켜지고, 문장을 나눠도 지켜진다. 머리말의 래퍼만 모델에 보이는 tars-agent 방식에서는 드러나지 않는다.
- `spawn`한 스레드 안의 호스트 Future await는 panic이다.
- 임베딩용 `CL_YIELD`(루트 맥락의 `suspend`)와 AOT(C 백엔드) 지원은 없다.
- 호스트 함수 안에서 막힌 호출을 interrupt로 끊지 못하는 것(F-42)은 그대로다. 이번 변경은 막히는 대신 Future를 돌려주게 해서
  그 상황을 피하는 방법이다.

## 5. 검증

- lib 테스트 `src/lib_test/await.zig` 10개(누수 검사 할당자). 요청서의 검증 목록 전체를 다룬다: 기본 · 연속 await, 깊은 호출 ·
  generator 본문 · fiber, 값 · 오류 완료와 `!else`, 완료된 Future의 빠른 경로, await하지 않은 · 미완료 Future,
  `persist_main` 지역 이월, 버리기 뒤 재사용 · 멈춘 동안의 거부, resume 뒤 연료 · interrupt · 메모리 상한 · panic, spawn 스레드.
- 예제 `examples/libcyber/host_await.c`: `fs.write`를 승인 · 거부 · 취소하는 호스트. `zig build lib-standalone-test`가 실행한다.
- 저장소의 13단계 검증(Debug · ReleaseFast · ReleaseSafe · notrace, lib, standalone C, wasm32-wasi) 전부 rc=0.

## 6. 커밋과 릴리스

- `8de18b05` Suspend an eval at an await of a host future and resume it (CL_AWAIT)
- 같은 범위의 앞선 커밋: `a14e33c7`(main이 돌려준 오류를 panic으로).
- 릴리스 버전: 0.4.8 예정. 아직 태그하지 않았다.
