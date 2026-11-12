# Cyber 런타임 사실과 제약

출처: soomtong/cyber의 src/include/cyber.h와 docs/decisions (project_tars_agent_runtime_review, project_embedding_agent_loop, project_vm_interrupt, project_stack_limit, project_memory_limit, project_compile_alloc_failure, project_spawn_nested_await, project_compiler_limits, project_coroutines, project_sigils, project_compile_error_report, project_fmt)와 docs/releases/0.4.5~0.4.7. 0.4.7, 확인일 2026-11-12. 구현을 시작하기 전에 다시 확인한다.

## 확인된 사실

- fork 용도: 스크립트 CLI와 tars 에이전트 루프의 실행 언어. 백엔드는 바이트코드 VM이고 JIT, LLVM 백엔드는 제거했다. minimum_zig_version은 0.17.1이다.
- 언어 0.4: 정적 타입과 값 소유권(move, &T 빌림, ^T ARC). 에러는 !T와 error.Name 값. 보간은 %{}. 코루틴은 둘이다. generator fn(stackless, 값을 낸다)과 fiber/suspend(stackful, 기다린다, 0.4.7). 그 밖에 spawn Thread + Future가 있다. symbol 리터럴은 symbol.name이다.
- 임베딩 수치 (macOS arm64, ReleaseFast, FFI 끔): libcyber.a 2.1 MB, cl_vm_init 0.2 ms, 첫 eval 2.8 ms, 같은 VM의 두 번째 eval 0.01 ms. VM당 RSS 약 2 MB, 첫 VM만 약 7 MB.
- 상태 유지: persist_main으로 함수, 타입, use, main 지역 변수가 eval 사이에 이어진다. 같은 이름을 다시 선언하면 새 선언이 이긴다. panic과 interrupt에서는 지역 변수가 버려진다. 빌림 타입 지역은 맨 위에서 선언할 수 없다.
- 검증: cl_vm_validate는 세션을 지우지 않고 현재 세션 위에서 컴파일만 한다. 검증한 소스의 선언은 다음 eval로 넘어가지 않는다.
- 구조화된 컴파일 오류 (0.4.5): cl_vm_compile_error(vm, &err)가 마지막 eval, compile, validate의 오류를 CLCompileError로 준다. kind(토큰, 파싱, 컴파일), msg(위치 없는 메시지), uri, has_loc, line, col(0부터, 바이트), len. 컴파일러는 첫 오류에서 멈추므로 컴파일당 하나다. 문맥(이전 선언, 템플릿 호출 지점)은 요약 문자열(cl_vm_compile_error_summary)에만 있다. 요약에는 기본으로 터미널 이스케이프 코드가 없다(cl_vm_set_error_color로 켠다).
- 포매터 (0.4.6): cl_vm_format(vm, src, &out)은 cyber fmt와 같은 공백 정리를 한다. 파서만 돌고 VM 상태를 바꾸지 않는다. 결과는 OK, SYNTAX_ERROR(out은 line:col: message), INTERNAL_ERROR, NO_MEMORY.
- 상한: cl_vm_set_fuel(검사점은 역방향 점프와 호출), cl_vm_interrupt(다른 스레드에서 호출 가능), cl_vm_set_stack_limit, cl_vm_set_memory_limit, cl_vm_memory_used. 상한에 걸리면 CL_ERROR_INTERRUPT 또는 panic(Stack overflow, OutOfMemory)이고 VM은 계속 쓸 수 있다. 메모리 상한은 VM이 쥔 전체 바이트 기준이라 스크립트에 N 바이트를 주려면 cl_vm_memory_used(vm) + N으로 건다. spawn 스레드도 같은 상한을 쓴다.
- 할당 실패: eval 중 호스트 할당자가 실패해도 프로세스는 죽지 않는다. 컴파일 중이면 CL_ERROR_COMPILE이고 다음 eval 앞에서 VM을 reset한다(persist_main의 지역 변수와 선언은 사라지고 연료, 상한, 프린터 같은 호스트 설정은 남는다). 실행 중이면 panic: OutOfMemory다. VM을 만드는 함수와 호스트가 값을 만드는 함수(cl_str_init 등)의 할당 실패는 여전히 abort다. cl_vm_init_mem(CLMemFuncs)으로 VM의 모든 메모리를 호스트의 alloc/free로 돌릴 수 있다. 컴파일러의 고정 한계(지역 256, 매개변수 255, 필드 255)는 CompileError다.
- 실패한 첫 컴파일 뒤에는 VM이 스스로 reset한다. 성공 뒤 실패한 eval의 선언은 넘어가지 않는다.
- 능력 바인딩: #[bind] 선언과 cl_mod_add_func. 값 매개변수(str, []T, 관리 필드를 가진 구조체)는 호스트가 소유하고 cl_str_deinit, cl_slice_deinit으로 해제한다. [&]T로 선언하면 빌리기만 한다.
- 출력은 cl_vm_set_printer로 가로챈다. print, eprint 콜백의 첫 인자는 CLThread*다(0.4.5에서 고쳐짐, VM은 cl_thread_vm(t)). 결과 값은 CLEvalResult.res, res_t와 cl_value_desc. persist_main에서는 마지막 맨 표현식이 결과다.
- 기본 로더는 core, meta, math, cy, c, io, test 일곱 모듈을 안다. os, libc, cli는 CLI 전용이다. cl_vm_set_loader로 호스트 로더를 끼우면 이 표를 줄일 수 있다.
- builtin 모듈(core, meta, cy, c, math, io, test)의 intrinsic(@memcpy, @bitCast, @retain 등)과 #[unsafe], #[consteval], #[reserve] 속성은 스크립트에서 쓸 수 없다 (0.4.7). 런타임 내부를 드러내는 길이 컴파일 단계에서 닫혔다. 호스트 모듈과 os, libc, cli는 스크립트와 같은 규칙을 받는다. @로 시작하는 함수 이름은 정해진 hook만 선언할 수 있다.
- fiber (0.4.7): 자기 스택을 가진 stackful 코루틴이고 같은 스레드의 힙을 공유한다. 전환은 VM 명령이라 C 스택이 끼지 않는다. 호스트 함수를 건너 suspend하면 panic(Cannot suspend across a host call.)이고, 루트 맥락의 suspend는 no-op이며, 임베딩용 CL_YIELD와 CL_AWAIT는 없다. Future.await()는 fiber 안에서도 양보하지 않고 spin한다. 그래서 능력 함수 안에서 스크립트를 멈췄다 재개하는 수단은 0.4.7에는 없다. 아래 CL_AWAIT가 그 수단이다.
- CL_AWAIT (cyber master 8de18b05, 미릴리스, 2026-11-12 검토): main 스레드의 Future.await()가 미완료 호스트 Future를 만나면 eval이 CL_AWAIT로 돌아온다. 스택, 지역 변수, persist_main 상태, 남은 연료, 현재 fiber가 그대로 남는다. 호출 깊이, generator 본문, fiber 안 모두 된다. API:
  - cl_future_new(t, future_t): 호스트 함수가 돌려줄 미완료 Future[T]. future_t는 cl_find_type(vm, "Future[!void]")로 얻는다. 호스트 함수 선언이 그 타입을 이름 지은 뒤에만 찾히고 cl_vm_reset 뒤에는 무효라 호출마다 찾는다. 반환 슬롯에 (CLValue)(uintptr_t)f로 쓴다.
  - cl_future_complete(vm, f, &value): 값으로 완료. Future[!U]면 U를 넘기고 void면 NULL. 값은 복사되고 Future가 소유한다. cl_future_complete_error(vm, f, cl_error(vm, "Denied")): 오류 값으로 완료.
  - cl_vm_pending_future(vm): 기다리는 Future(빌린 포인터). cl_vm_resume(vm, &res): 이어 실행, 결과는 cl_vm_evalx와 같은 규칙. 완료하지 않고 resume하면 다시 CL_AWAIT.
  - cl_vm_abandon(vm): 멈춘 eval을 버린다. 결과는 interrupt와 같다(지역 변수는 사라지고 선언은 남는다). cl_vm_reset, cl_vm_deinit도 먼저 버린다.
  - 멈춘 동안의 cl_vm_eval*, cl_vm_validate, cl_vm_compile*은 CL_ERROR_SUSPENDED.
  - 규칙: 모든 호출과 완료는 eval을 돌리는 스레드에서 한다. 연료는 다시 채워지지 않고 interrupt 요청도 지워지지 않아 resume 뒤로 이어진다. 그래서 멈춘 동안에는 cl_vm_interrupt를 부르지 않는다(벽시계 타이머를 멈추고, 취소는 abandon으로). spawn 스레드 안의 await와 호스트 함수가 부른 스크립트 안의 await는 panic이다. 한 번에 Future 하나만 기다린다.
  - 스크립트가 직접 만든 미완료 Future(FutureResolver)도 CL_AWAIT가 된다. pending future가 우리 능력이 만든 것이 아니면 abandon한다.
  - 래퍼 함수는 호스트 로더가 돌려주는 모듈 소스에 #[bind] 선언과 함께 둔다 (cyber examples/libcyber/host_await.c). F-98(한 식 안 임시 수신자의 평가 순서)은 래퍼 본문 안에 갇혀 모델 코드에 드러나지 않는다.
- spawn 스레드의 await는 main과 같이 블록한다 (2026-11-08 수정). 예전의 @panic(TODO) 경로는 없다. 연료는 스레드마다 따로 센다.
- tars devlayer에 있는 것은 CLI 번들(cyber-linux-x64.tar.gz)이고 2026-11-12 기준 0.4.6이다. 0.4.7부터 CLI는 표준 모듈을 실행 파일에 내장해 번들이 cyber 파일 하나다(옆의 src/를 읽지 않는다). 오류 위치는 core:196:5처럼 모듈 이름으로 찍힌다. tars-agent는 CLI를 쓰지 않고 libcyber를 정적 링크한다.

## 없는 것

- JSON, 정규식, 날짜 라이브러리. cyber 표준 모듈로 만든다 (아래 목록).
- 0.4.7까지: 능력 함수 안에서 멈췄다 재개하는 수단. master에 CL_AWAIT로 들어왔고 다음 릴리스를 기다린다 (ADR 0011).
- c 모듈을 끄는 옵션과 spawn을 끄는 옵션. 지금은 호스트 로더에서 거부하고 deny_raw_ptrs를 켠다.

## M0에서 확인할 것

- cyber를 build.zig.zon 의존으로 받아 Zig 모듈 또는 정적 라이브러리로 링크할 수 있는가. 안 되면 fork의 build.zig에 내보내기를 더한다.
- 점이 든 모듈 이름(fs.read)이 use fs와 호스트 모듈 등록으로 그대로 되는가: 된다(cyber host_await.c의 use fs, fs.write). 기본값 매개변수가 #[bind] 함수에서 되는가. 안 되면 Cyber 쪽 래퍼 함수를 머리말에 둔다.
- 호스트 로더에서 core의 일부 함수를 가릴 필요가 있는가. 0.4.7에서 intrinsic이 스크립트에서 막혀 남은 후보는 적다. fiber는 스레드를 만들지 않으므로 막을 대상이 아니다.
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
| C3 | Attributes(#[bind]) 문서 | 능력 바인딩 생성기를 쓰는 데 참고할 문서가 없다 | 0.4.5에서 됐다. docs/docs.md의 Attributes 절(속성 표)과 #[bind] hooks 절 |
| 수시 | 프로세스를 죽이는 경로 수정 | 세션의 crash/ 디렉터리가 재현 사례를 준다 | cyber의 발견 이슈 기록 절차를 따른다 |
| 조건부 | 문자열, Array, Map 보강 | 평가의 실패 유형에서 "있을 줄 알고 부른 메서드"가 반복되면 | 모델의 기대에 맞추는 쪽이 안내로 가르치는 것보다 싸다 |
| C3 | 루트 맥락 중단과 재개: CL_AWAIT, cl_vm_resume, 버리기 API, 호스트 Future C API (코루틴 로드맵 단계 1) | 승인 대기가 VM 호출 스택 안에서 UI를 돌리고, 막힌 승인을 interrupt로 끊지 못한다 (ADR 0011) | 2026-11-12 요청, 같은 날 master 8de18b05에 구현. 검토 통과, 릴리스 대기. 요청 원문 docs/requests/cyber-cl-await.md |
| 조건부 | fiber 안 Future.await의 양보 (로드맵 단계 3) | agentd에서 한 스레드에 여러 세션을 돌릴 때 | |
| 조건부 | spec --for-agents | 다른 프로젝트가 같은 안내 문서를 쓸 때 | |

표준 모듈의 조건: 신뢰하지 않는 스크립트가 부르므로 입력 크기에 대해 시간과 메모리가 예측 가능해야 한다. 할당은 VM 메모리 상한 아래, 긴 루프는 연료 검사점을 지난다. 누수 검사 allocator 테스트를 붙인다. 라이브러리 로더와 CLI 양쪽에 같은 이름으로 싣는다.

## 위험과 대응

| 위험 | 대응 |
|---|---|
| 모델이 Cyber를 틀린다 | 부분집합 안내, validate 뒤 구조화된 오류(cl_vm_compile_error) 되돌림, M0 평가와 통과 기준, 못 넘으면 direct 모드 |
| 컴파일러 abort가 남아 있다 | 실행 전 기록, crash/ 보관, --continue. 비율을 재서 프로세스 분리 판단 |
| 능력 안에서 막히면 못 끊는다 | 능력마다 시간 제한과 취소 플래그 확인. 승인 대기는 VM 밖으로 옮긴다 (ADR 0011) |
| upstream이 멈춰 있다 | fork가 유일한 유지 주체다. 없는 것은 직접 만든다 (ADR 0010). cyber 버전을 태그와 해시로 고정하고 올릴 때 예제 테스트와 평가를 돌린다 |
| 표준 모듈을 만드는 일이 에이전트 일정을 민다 | 필요의 증거가 있는 것만, 평가가 필요로 하는 순서로 (C1이 M0 평가 앞) |
