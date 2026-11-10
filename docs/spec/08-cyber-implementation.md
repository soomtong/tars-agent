# Cyber 런타임 사실과 제약

출처: soomtong/cyber의 src/include/cyber.h와 docs/decisions (project_tars_agent_runtime_review, project_embedding_agent_loop, project_vm_interrupt, project_stack_limit, project_memory_limit, project_compile_alloc_failure, project_spawn_nested_await, project_compiler_limits). 0.4.4, 확인일 2026-11-10. 구현을 시작하기 전에 다시 확인한다.

## 확인된 사실

- fork 용도: 스크립트 CLI와 tars 에이전트 루프의 실행 언어. 백엔드는 바이트코드 VM이고 JIT, LLVM 백엔드는 제거했다. minimum_zig_version은 0.17.1이다.
- 언어 0.4: 정적 타입과 값 소유권(move, &T 빌림, ^T ARC). 에러는 !T와 error.Name 값. 보간은 %{}. 파이버는 없고 #[generator](stackless)와 spawn Thread + Future가 있다.
- 임베딩 수치 (macOS arm64, ReleaseFast, FFI 끔): libcyber.a 2.1 MB, cl_vm_init 0.2 ms, 첫 eval 2.8 ms, 같은 VM의 두 번째 eval 0.01 ms. VM당 RSS 약 2 MB, 첫 VM만 약 7 MB.
- 상태 유지: persist_main으로 함수, 타입, use, main 지역 변수가 eval 사이에 이어진다. 같은 이름을 다시 선언하면 새 선언이 이긴다. panic과 interrupt에서는 지역 변수가 버려진다. 빌림 타입 지역은 맨 위에서 선언할 수 없다.
- 검증: cl_vm_validate는 세션을 지우지 않고 현재 세션 위에서 컴파일만 한다. 검증한 소스의 선언은 다음 eval로 넘어가지 않는다.
- 상한: cl_vm_set_fuel(검사점은 역방향 점프와 호출), cl_vm_interrupt(다른 스레드에서 호출 가능), cl_vm_set_stack_limit, cl_vm_set_memory_limit, cl_vm_memory_used. 상한에 걸리면 CL_ERROR_INTERRUPT 또는 panic(Stack overflow, OutOfMemory)이고 VM은 계속 쓸 수 있다.
- 할당 실패: 컴파일 중 할당 실패는 다음 eval 앞의 reset으로 처리한다. 컴파일러의 고정 한계(지역 256, 매개변수 255, 필드 255)는 CompileError다.
- 실패한 첫 컴파일 뒤에는 VM이 스스로 reset한다. 성공 뒤 실패한 eval의 선언은 넘어가지 않는다.
- 능력 바인딩: #[bind] 선언과 cl_mod_add_func. 값 매개변수(str, []T, 관리 필드를 가진 구조체)는 호스트가 소유하고 cl_str_deinit, cl_slice_deinit으로 해제한다. [&]T로 선언하면 빌리기만 한다.
- 출력은 cl_vm_set_printer로 가로챈다. 결과 값은 CLEvalResult.res, res_t와 cl_value_desc. persist_main에서는 마지막 맨 표현식이 결과다.
- 기본 로더는 core, meta, math, cy, c, io, test 일곱 모듈을 안다. os, libc, cli는 CLI 전용이다. cl_vm_set_loader로 호스트 로더를 끼우면 이 표를 줄일 수 있다.
- spawn 스레드의 await는 main과 같이 블록한다 (2026-11-08 수정). 예전의 @panic(TODO) 경로는 없다. 연료는 스레드마다 따로 센다.
- tars devlayer에 있는 것은 CLI 번들(cyber-linux-x64.tar.gz)이다. tars-agent는 이것을 쓰지 않고 libcyber를 정적 링크한다.

## 없는 것

- JSON, 정규식, 날짜 라이브러리. cyber 표준 모듈로 만든다 (아래 목록).
- 능력 함수 안에서 멈췄다 재개하는 수단. 승인 대기는 동기 블록이다. 세션당 프로세스 하나라 문제가 되지 않는다 (ADR 0004).
- c 모듈을 끄는 옵션과 spawn을 끄는 옵션. 지금은 호스트 로더에서 거부하고 deny_raw_ptrs를 켠다.
- 스택형 Fiber.

## M0에서 확인할 것

- cyber를 build.zig.zon 의존으로 받아 Zig 모듈 또는 정적 라이브러리로 링크할 수 있는가. 안 되면 fork의 build.zig에 내보내기를 더한다.
- 점이 든 모듈 이름(fs.read)이 use fs와 호스트 모듈 등록으로 그대로 되는가. 기본값 매개변수가 #[bind] 함수에서 되는가. 안 되면 Cyber 쪽 래퍼 함수를 머리말에 둔다.
- 호스트 로더에서 core의 일부 함수(예: 스크립트가 쓰면 안 되는 것)를 가릴 필요가 있는가.
- spawn을 막는 가장 싼 방법.
- deny_raw_ptrs와 호스트 모듈 선언이 함께 동작하는가 (호스트 모듈은 표준 모듈이 아니다).
- x86_64-linux-gnu 교차 빌드와 tars 게스트에서의 실행.

## cyber에서 만들 것 (ADR 0010)

필요한 것은 cyber에 만든다. 두 번째 fork는 만들지 않고 soomtong/cyber 한 곳에서 한다. 항목마다 필요의 증거를 적는다. 증거 없는 항목은 올리지 않는다.

| 순서 | 항목 | 필요의 증거 | 메모 |
|---|---|---|---|
| C1 | json 모듈: parse, stringify, 값 트리 | 평가 과제의 다수가 JSON을 다룬다. 설정 파일, API 응답, 도구 출력 | 깊이와 크기 상한. 값 타입은 복사 가능한 부분집합 안에서 다룰 수 있어야 한다 |
| C1 | 빌드 내보내기: build.zig.zon 의존으로 쓰는 모듈 또는 아티팩트 | M0 스파이크 1 | 스파이크에서 필요가 확인되면 |
| C2 | regex 모듈 | 로그와 명령 출력에서 값 뽑기. str 메서드만으로는 스크립트가 길어진다 | 역추적 없는 엔진(선형 시간), 직접 쓴다. 문법은 ripgrep 기본 문법의 부분집합 |
| C2 | time 모듈 | 파일 시각 비교, 기록의 날짜 계산 | 시계 읽기는 넣지 않는다 (능력 clock.now). 시간대는 UTC와 고정 오프셋부터 |
| C3 | 임베딩 옵션: 모듈 허용 표, spawn 차단 | 05 문서 1층. 호스트 로더로 되면 올리지 않는다 | CLEvalConfig 필드 |
| C3 | Attributes(#[bind]) 문서 | 능력 바인딩 생성기를 쓰는 데 참고할 문서가 없다 | |
| 수시 | 프로세스를 죽이는 경로 수정 | 세션의 crash/ 디렉터리가 재현 사례를 준다 | cyber의 발견 이슈 기록 절차를 따른다 |
| 조건부 | 문자열, Array, Map 보강 | 평가의 실패 유형에서 "있을 줄 알고 부른 메서드"가 반복되면 | 모델의 기대에 맞추는 쪽이 안내로 가르치는 것보다 싸다 |
| 조건부 | 스택형 Fiber | agentd에서 스레드 점유가 측정된 문제일 때 | |
| 조건부 | spec --for-agents | 다른 프로젝트가 같은 안내 문서를 쓸 때 | |

표준 모듈의 조건: 신뢰하지 않는 스크립트가 부르므로 입력 크기에 대해 시간과 메모리가 예측 가능해야 한다. 할당은 VM 메모리 상한 아래, 긴 루프는 연료 검사점을 지난다. 누수 검사 allocator 테스트를 붙인다. 라이브러리 로더와 CLI 양쪽에 같은 이름으로 싣는다.

## 위험과 대응

| 위험 | 대응 |
|---|---|
| 모델이 Cyber를 틀린다 | 부분집합 안내, validate 뒤 오류 되돌림, M0 평가와 통과 기준, 못 넘으면 direct 모드 |
| 컴파일러 abort가 남아 있다 | 실행 전 기록, crash/ 보관, --continue. 비율을 재서 프로세스 분리 판단 |
| 능력 안에서 막히면 못 끊는다 | 능력마다 시간 제한과 취소 플래그 확인 |
| upstream이 멈춰 있다 | fork가 유일한 유지 주체다. 없는 것은 직접 만든다 (ADR 0010). cyber 버전을 태그와 해시로 고정하고 올릴 때 예제 테스트와 평가를 돌린다 |
| 표준 모듈을 만드는 일이 에이전트 일정을 민다 | 필요의 증거가 있는 것만, 평가가 필요로 하는 순서로 (C1이 M0 평가 앞) |
