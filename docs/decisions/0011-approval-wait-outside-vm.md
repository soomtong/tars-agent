# 0011 승인 대기는 VM 밖에서 한다 (cyber CL_AWAIT)

상태: 확정 (2026-11-12). 0009의 "능력 안에서 스크립트를 멈추고 재개하기" 행을 바꾼다. cyber 쪽 구현을 요청했다 (docs/requests/cyber-cl-await.md). 2026-11-12 cyber master 8de18b05~de98510f에 구현됐고(0.4.8 예정, 보고 docs/requests/cyber-cl-await-report.md) 검토를 통과했다(전체 테스트 82단계 통과, 요청 13개 항목 충족). 최종 API는 spec/08. cyber 릴리스가 나와 고정 버전을 올리기 전까지는 아래 "도입 전까지"를 따른다.

## 결정

승인이 필요한 능력은 승인을 기다리지 않는다. 미완료 Future를 바로 돌려주고, 머리말의 Cyber 래퍼가 그 Future를 await한다. 스크립트가 미완료 Future에서 멈추면 eval이 CL_AWAIT로 돌아오고, 루프가 승인을 받고 실제 작업을 한 뒤 Future를 완료시키고 cl_vm_resume으로 이어 간다.

~~~cy
-- 호스트 모듈. 모델에게는 보이지 않는 이름
#[bind] fn write_async(path str, text str) -> Future[!void]

-- 머리말의 래퍼. 모델이 보는 API는 동기다
fn write(path str, text str) -> !void:
    return write_async(path, text).await()
~~~

- 게이트 판정은 능력이 Future를 만들 때 한다. 규칙이 허용하면 바로 작업하고 완료된 Future를 돌려준다. 이 경우 await는 빠른 경로라 VM을 빠져나오지 않는다. 규칙이 거부하면 error.Denied로 완료된 Future를 돌려준다. 물어야 할 때만 미완료 Future가 된다.
- 부작용은 승인 뒤에만 일어난다. 미완료 Future를 만드는 단계에서는 아무 작업도 하지 않는다.
- 사용자가 거부하면 Future를 error.Denied로 완료하고 resume한다. 02의 denied 행(VM 유지, 오류 값으로 돌아간다)과 같다.
- 사용자가 취소(Esc)하면 resume하지 않고 멈춘 eval을 버린다. 결과는 interrupted와 같다(지역 변수 초기화).
- 벽시계(wall-clock) 상한은 eval이 도는 동안만 센다. 멈춘 동안 타이머는 멈춘다.

## 근거

- 제어의 방향이 맞는다. 지금 방식에서는 승인 화면을 그리고 키를 받는 일이 능력 함수 안, 즉 VM 호출 스택 한가운데서 일어난다. 01의 원칙(코어는 이벤트를 내고 프런트엔드가 그린다, 루프가 흐름을 쥔다)을 지키려면 능력 함수가 UI 루프를 대신 돌려야 한다. CL_AWAIT로는 승인이 항상 루프의 바닥에서 일어난다. 헤드리스 stream-json과 대화형이 같은 경로를 쓴다.
- 취소가 하나의 길이 된다. 막힌 호스트 호출은 interrupt로 끊지 못한다(cyber F-42). 지금은 승인 대기를 포함한 막힐 수 있는 능력마다 취소 플래그를 확인해야 한다. 승인은 이제 VM 밖이라 "resume하지 않고 버린다"로 끝난다.
- 벽시계 상한이 사용자가 생각하는 시간을 세지 않는다. 지금 방식에서도 타이머를 손으로 멈출 수는 있지만, 경계가 eval의 시작과 끝으로 저절로 맞는다.
- 다중 세션(agentd, 06)으로 갈 때 세션마다 스레드를 블록시키지 않아도 된다. v1의 이유는 아니지만 같은 구조가 그대로 쓰인다.
- 모델에게 보이는 표면이 바뀌지 않는다. 래퍼가 await를 감추므로 프롬프트 안내와 평가(0006)에 영향이 없다.
- cyber에 이미 설계가 있다. 코루틴 스펙(cyber docs/specs/2026-11-03-generator-and-fiber-coexistence.md)의 로드맵 단계 1이고, CL_AWAIT는 cyber.h에 결과 코드로 있지만 만드는 곳이 없다. 0.4.7의 fiber가 C 스택 없이 실행 상태를 저장하고 바꾸는 일을 이미 VM 명령으로 하므로, 같은 방식을 루트 맥락에 적용하는 일이다. 0010(없는 것은 Cyber에 만든다)에 맞는다.

## 버린 대안

| 대안 | 버린 이유 |
|---|---|
| 동기 블록 유지 (지금 방식) | 위 근거의 첫째와 둘째. 도입 전까지의 임시 방식으로만 쓴다 |
| fiber로 해결 | 호스트 함수를 건너 suspend할 수 없다(Cannot suspend across a host call.). 루트 맥락의 suspend는 no-op이다 |
| 거부 후 재시도: 능력이 error.NeedsApproval을 돌려주고 턴 사이에 묻는다 | cyber 변경이 없어 가장 싸지만, 승인마다 모델 왕복과 토큰이 든다. 모델이 다시 쓰는 코드가 처음과 같다는 보장도 없다. CL_AWAIT가 크게 늦어질 때의 대안으로 남긴다 |
| 스크립트 단위 사전 승인 | 인자가 런타임에 정해져 정밀하지 않다. 대기 횟수를 줄이는 보조 UX로는 나중에 검토할 수 있다 |
| VM마다 OS 스레드 하나 | 스레드 점유 문제만 푼다. 제어 방향과 취소 문제는 그대로다 |

## cyber에 요청한 것

전문은 docs/requests/cyber-cl-await.md에 있다. 요지는 다음과 같다.

- 루트 맥락의 await가 미완료 호스트 Future에서 eval을 CL_AWAIT로 빠져나온다. 실행 상태와 persist_main 상태를 보존한다. 호출 깊이와 generator 본문에 제약이 없다.
- cl_vm_resume, 멈춘 eval을 버리는 API, 멈춘 동안의 eval과 validate 거부.
- 호스트 Future C API: 호스트 함수가 Future[T](T가 !T인 경우 포함)를 반환하고, 값 또는 오류로 완료한다.
- fiber 안과 spawn 스레드 안의 호스트 Future await는 교착이나 abort 없이 정해진 동작을 갖는다.
- 범위 밖: fiber 안 await의 양보(단계 3), 취소와 wait_any(단계 4), CL_YIELD, AOT, 문법 변경.

## 도입 전까지

- 승인 대기는 지금처럼 능력 함수 안에서 동기적으로 블록한다. 대기는 취소 플래그를 확인하고, 그동안 벽시계 타이머를 멈춘다.
- 능력의 바인딩 층은 결과를 돌려주는 방식만 바꾸면 되도록 짠다. 게이트 판정, 승인 요청, 실제 작업을 세 함수로 나누어 두면 CL_AWAIT가 들어왔을 때 앞의 두 단계와 뒤의 한 단계 사이만 Future로 끊으면 된다.

## cyber가 고른 동작 (요청의 열린 항목)

- fiber 안의 await도 eval을 탈출하고, 재개는 그 fiber 안에서 이어진다.
- spawn 스레드 안의 호스트 Future await는 panic이다.
- Future 완료는 eval을 돌리는 스레드에서만 한다.
- 완료하지 않고 resume하면 다시 CL_AWAIT다.
- 스크립트가 만든 미완료 Future도 CL_AWAIT가 된다. 우리 Future가 아니면 abandon한다.
- 멈춘 동안 들어온 interrupt 요청은 resume이 지운다(034fae2c. 처음 구현은 이어 갔다). 멈춘 eval을 끊는 길은 abandon 하나다.

## 결과

- 01의 "승인 대기는 능력 함수 안에서 메인 스레드가 그대로 블록한다"를 이 결정으로 바꾼다 (도입 전까지는 임시 방식으로 남는다).
- 08의 "cyber에서 만들 것" 표에서 이 항목을 조건부에서 M3 전 순서로 올린다.
- TODO의 C 줄기에 넣고 M6 항목을 지운다. M3의 승인 프롬프트와 인터럽트가 이것을 쓴다.
- cyber의 보고가 오면 최종 API를 08에 옮기고, 이 문서의 상태 줄에 들어간 cyber 버전을 적는다.
- 같은 경로는 오래 막히는 다른 능력(proc 대기, net.fetch)에도 쓸 수 있다. v1에서는 승인만 옮기고, 나머지는 취소 플래그 확인으로 둔다.
- cyber는 Future.wait_any와 cl_vm_pending_futures도 넣었다(de98510f). 능력의 비동기 판(Future를 돌려주는 것)을 모델에게 보이면 스크립트가 여러 능력을 동시에 돌릴 수 있다. v1은 보이지 않는다: 안내는 동기 래퍼만 가르치고, 동시 실행은 0009의 spawn 행이 말한 "호스트 쪽 병렬 능력" 자리에서 평가 결과를 보고 판단한다.
- 능력이 만든 Future는 retain해 두고 완료하거나 eval이 끝날 때 놓는다. 스크립트가 버린 Future의 주소가 재사용되어 요청 표 대조가 틀리는 일을 막는다.
