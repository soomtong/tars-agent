# 요청: 루트 맥락의 중단과 재개 (CL_AWAIT, 코루틴 로드맵 단계 1)

soomtong/cyber에 2026-11-12에 전달한 요청 원문이다. 결정은 docs/decisions/0011-approval-wait-outside-vm.md.

## 배경

tars-agent(soomtong/tars-agent)는 libcyber를 정적 링크해 모델이 쓴 Cyber 스크립트를 실행하는 에이전트다. 스크립트는 호스트가 등록한 능력 함수(fs.write, proc.exec 등)로만 바깥에 닿고, 일부 능력은 실행 전에 사용자 승인이 필요하다.

지금은 승인을 능력 함수 안에서 동기적으로 블록해 기다린다. 이 방식에는 v1에서 실제로 부딪히는 문제가 둘 있다.

1. 벽시계 상한(타이머 스레드가 cl_vm_interrupt)이 사용자가 승인을 고민하는 시간까지 센다.
2. 승인 중 사용자가 취소(Esc)해도 VM을 끊을 수 없다. 호스트 함수 안에서 막힌 호출은 interrupt와 fuel로 끊지 못한다(F-42). 그래서 능력마다 취소 플래그를 직접 확인해야 한다.

0.4.7의 fiber로는 풀리지 않는다. 호스트 함수를 건너 suspend할 수 없고(Cannot suspend across a host call.), 루트 맥락의 suspend는 no-op이며, Future.await()는 spin한다.

이 저장소의 docs/specs/2026-11-03-generator-and-fiber-coexistence.md 3.3절, 5.2절, 6절 로드맵의 단계 1(루트 맥락 중단과 재개, CL_AWAIT, cl_vm_resume, 호스트 Future C API)이 바로 이 문제의 해법이다. CL_AWAIT는 cyber.h의 결과 코드에 이미 있지만 만드는 곳이 없다. 이번 요청은 단계 1의 구현이다.

## tars-agent가 쓰려는 방식

능력 함수는 승인을 기다리지 않고 미완료 Future를 바로 돌려준다. 모델에게는 동기 API만 보이도록 호스트가 넣는 머리말에 Cyber 래퍼를 둔다.

~~~cy
-- 호스트 모듈 (cl_mod_add_func로 등록)
#[bind] fn write_async(path str, text str) -> Future[!void]

-- 머리말의 래퍼. 모델은 이것만 본다
fn write(path str, text str) -> !void:
    return write_async(path, text).await()
~~~

~~~c
CLResultCode r = cl_vm_evalx(vm, uri, src, cfg, &res);
while (r == CL_AWAIT) {
    CLFuture* f = cl_vm_pending_future(vm);
    /* 벽시계 타이머를 멈추고, 승인을 받고, 실제 작업을 한다 */
    if (user_cancelled) { cl_vm_abandon(vm); break; }
    cl_future_complete(vm, f, &value);
    r = cl_vm_resume(vm, &res);
}
~~~

함수 이름은 예시다. 스펙 5.2절의 이름을 기준으로 하되 더 나은 이름이 있으면 바꿔도 된다. 최종 시그니처를 보고에 적어 달라.

## 요구사항

### 동작

1. 루트 맥락(fiber 밖, main 스레드)의 `Future.await()`가 미완료 호스트 Future를 만나면 eval이 CL_AWAIT로 돌아온다. 이때 pc, fp, 스택, 지역 변수, persist_main 상태를 그대로 보존한다.
2. 대기 지점의 호출 깊이에 제약이 없다. 여러 단계 함수 호출 안, 그리고 루트에서 소비하는 generator 본문 안의 await도 같은 경로로 멈춘다. 래퍼 함수를 거치는 위 사용 방식이 동작해야 한다.
3. cl_vm_resume은 멈춘 지점에서 이어 실행하고, 결과는 cl_vm_evalx와 같은 규칙(CLEvalResult, 결과 코드)을 따른다. 한 eval 안에서 await와 resume이 여러 번 반복될 수 있다.
4. 이미 완료된 Future의 await는 지금과 같은 빠른 경로다. 탈출하지 않는다.
5. 호스트가 멈춘 eval을 버리는 API가 있다. 결과는 interrupt와 같다: 지역 변수는 버려지고 선언은 남고 VM은 다음 eval에 쓸 수 있다. 누수가 없어야 한다.
6. 멈춘 동안 VM에 새 eval, validate, compile을 부르면 오류 코드로 거부한다. abort하면 안 된다.
7. 연료, 스택 상한, 메모리 상한은 resume 뒤에도 그대로 이어진다. 멈춘 동안에는 연료가 줄지 않는다. resume 뒤의 panic, interrupt, OutOfMemory는 평소 eval과 같이 처리된다.
8. fiber 안에서 미완료 호스트 Future를 await하는 경우의 동작을 정한다. 단계 3 전이라 지금은 영원히 spin해 교착한다. fiber 전환도 VM 명령이라 eval 탈출이 가능하다면 탈출을 허용하고, 어렵다면 위치가 붙은 panic으로 막는다. 둘 중 무엇을 골랐는지 결정 문서에 적는다.
9. spawn 스레드 안의 호스트 Future await는 이번 범위가 아니다. 지금 동작을 유지하거나 panic으로 막고, 교착이나 abort가 없어야 한다.

### 호스트 Future C API

10. 호스트 함수가 `Future[T]`를 반환값으로 만들 수 있다. T가 `!T`(오류 값)인 경우를 포함한다. tars-agent는 거부를 error.Denied 같은 오류 값으로 돌려준다.
11. 호스트가 값 또는 오류로 Future를 완료시킨다. 값의 소유권 규칙(str, []T 등)은 기존 호스트 함수 반환값 규칙과 맞추고 cyber.h 주석에 적는다.
12. 완료는 resume 전에 호스트 스레드에서 한다. 다른 스레드에서 완료해도 되는지는 정하고 문서에 적는다(필수 아님).
13. 스크립트가 Future를 await하지 않고 버리는 경우, 미완료 Future가 남은 채 eval이 끝나는 경우에도 누수나 abort가 없어야 한다.

### 범위 밖

- 단계 3(fiber 안 await를 양보로), 단계 4(취소, wait_any), 임베딩용 CL_YIELD, AOT(C 백엔드) 지원.
- 언어 문법 변경. 스크립트 쪽 표면은 기존 `Future.await()` 그대로다.

## 검증

lib 테스트(누수 검사 할당자)로 다음을 확인한다.

- 기본: 호스트 Future를 await, 완료, resume, 결과 값 확인
- 한 eval 안의 연속 await 여러 번, 깊은 호출 안의 await, generator 본문 안의 await
- 오류 값으로 완료, 스크립트가 !else로 받음
- persist_main: 멈췄다 재개한 eval의 지역 변수가 다음 eval로 이어짐
- 버리기 API 뒤 VM 재사용, 지역 변수 초기화
- 멈춘 동안 eval, validate 호출이 오류로 거부됨
- resume 뒤 fuel 소진, interrupt, 메모리 상한 panic
- 완료된 Future의 빠른 경로
- fiber 안 await의 정한 동작(8번)
- await하지 않은 Future, 미완료로 남은 Future의 정리

예제: examples/libcyber에 이 흐름을 보여 주는 호스트 예제 하나(host_tool.c를 확장하거나 새 파일).

## 문서와 절차

이 저장소의 절차를 따른다: 테스트, 발견 이슈 기록, docs/releases/unreleased.md, docs/docs.md의 임베딩 절, cyber.h 주석, docs/decisions/project_coroutines.md에 구현 절 추가, 스펙 문서의 상태 줄 갱신.

## 보고

끝나면 다음을 알려 달라. tars-agent 문서(docs/spec/08-cyber-implementation.md)에 그대로 옮긴다.

- 최종 C API 시그니처와 각 함수의 소유권, 스레드 규칙
- 8, 9, 12번에서 고른 동작
- 남은 제약과 알려진 문제
- 들어간 커밋과 릴리스 버전
