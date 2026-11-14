# Cyber 런타임 사실과 제약

출처: soomtong/cyber의 src/include/cyber.h, docs/docs.md, docs/decisions (project_tars_agent_runtime_review, project_embedding_agent_loop, project_vm_interrupt, project_stack_limit, project_memory_limit, project_compile_alloc_failure, project_spawn_nested_await, project_compiler_limits, project_coroutines, project_sigils, project_compile_error_report, project_fmt, project_sort_closures). 기준은 soomtong/cyber 로컬 master의 커밋 b450f535 (버전 문자열 `0.4.10-DEV`, 원격에는 아직 없다), 확인일 2026-11-14. 구현을 시작하기 전에 다시 확인한다.

## 확인된 사실

- fork 용도: 스크립트 CLI와 tars 에이전트 루프의 실행 언어. 백엔드는 바이트코드 VM이고 JIT, LLVM 백엔드는 없다. minimum_zig_version은 0.17.1이다.
- 언어: 정적 타입과 값 소유권(move, &T 빌림, ^T ARC). 에러는 !T와 error.Name 값. 보간은 %{}. 코루틴은 둘이다. generator fn(stackless, 값을 낸다)과 fiber/suspend(stackful, 기다린다). 그 밖에 spawn Thread + Future가 있다. symbol 리터럴은 symbol.name이다. 모델에게 가르치는 부분집합은 prompt/cyber-subset*.md.
- 임베딩 수치 (macOS arm64, ReleaseFast, FFI 끔, M0 스파이크 1): libcyber.a 2.53 MB, 공개 `cl_` 함수 135개, VM 생성과 첫 eval 개당 2 ms, VM 하나가 쥔 메모리 약 2.6 MiB, 같은 VM의 validate와 eval은 200회에 각 2 ms.
- 상태 유지: persist_main으로 함수, 타입, use, main 지역 변수가 eval 사이에 이어진다. 같은 이름을 다시 선언하면 새 선언이 이긴다. panic과 interrupt에서는 지역 변수가 버려진다. 빌림 타입 지역은 맨 위에서 선언할 수 없다(`Cannot persist local ... of borrow type`).
- 검증: cl_vm_validate는 세션을 지우지 않고 현재 세션 위에서 컴파일만 한다. 검증한 소스의 선언은 다음 eval로 넘어가지 않는다. 설정 인자가 없고 마지막 eval의 설정(persist_main, deny_raw_ptrs, deny_spawn)을 쓴다(cyber.h에 적혀 있다). 첫 eval 전에는 모두 꺼져 있으므로 머리말을 eval한 뒤에 검증한다.
- 실패한 컴파일 뒤: 같은 VM의 다음 검증, 컴파일, eval이 그대로 되고 세션이 남는다(문자열 이스케이프 오류 포함). 실패한 컴파일이 펼친 템플릿 인스턴스는 다음 컴파일이 다시 검사하고, 실패한 컴파일이 처음 불러온 모듈은 다음 use에서 다시 불러온다. VM의 첫 컴파일이 실패하거나 컴파일러, 지역 이월 중에 할당이 실패하면 다음 eval이나 검증이 reset된 VM에서 시작한다. cl_vm_reset_pending(vm)이 그것을 알려 준다. panic과 interrupt는 reset이 아니다: 최상위 지역은 모두 사라지고 함수와 use는 남으며 cl_vm_reset_pending은 false다. 성공 뒤 실패한 eval의 선언은 넘어가지 않는다.
- 구조화된 컴파일 오류: cl_vm_compile_error(vm, &err)가 마지막 eval, compile, validate의 오류를 CLCompileError로 준다. kind(토큰, 파싱, 컴파일), msg(위치 없는 메시지), uri, has_loc, line, col(0부터, 바이트), len. 기본으로 컴파일러는 첫 오류에서 멈춘다. 문맥(이전 선언, 템플릿 호출 지점)은 요약 문자열(cl_vm_compile_error_summary)에만 있다. 요약에는 기본으로 터미널 이스케이프 코드가 없다(cl_vm_set_error_color로 켠다).
- 오류 모아 받기: cl_vm_set_error_recovery(vm, true)면 컴파일러가 본문(main 블록, 함수, 메서드)마다 첫 오류를 내고 나머지 본문을 계속 검사한다. 구문 오류와 선언의 오류는 컴파일을 끝낸다. cl_vm_compile_report_count, cl_vm_compile_report(vm, idx, &rep)가 오류 전부를 CLReport(시작과 끝의 줄, 열, 바이트 오프셋)로 준다. 스파이크에서는 시험하지 않았다.
- 오류 문구: 흔한 실수(Python식 문법과 `elif`, 없는 메서드 이름, 같은 이름 메서드가 있는 필드 자리, 풀지 않은 `!T`, 참조의 연산자, `?else`의 우선순위, 타입 없는 목록 리터럴의 섞인 원소, `and`로 묶은 옵션 풀기, 보간 안의 보간과 백슬래시, 끝에 닿는 `!else`/`?else` 블록)에는 고치는 법이 붙는다. 예: ``Can not find the symbol `startsWith` in `str`. Did you mean `starts_with`?``. 안내 문서는 고치는 법이 붙지 않는 오류만 따로 적는다.
- 포매터: cl_vm_format(vm, src, &out)은 cyber fmt와 같은 공백 정리를 한다. 파서만 돌고 VM 상태를 바꾸지 않는다. 결과는 OK, SYNTAX_ERROR(out은 line:col: message), INTERNAL_ERROR, NO_MEMORY.
- 상한: cl_vm_set_fuel(검사점(checkpoint)은 역방향 점프와 호출), cl_vm_interrupt(다른 스레드에서 호출 가능), cl_vm_set_stack_limit, cl_vm_set_memory_limit, cl_vm_memory_used. 상한에 걸리면 CL_ERROR_INTERRUPT 또는 panic(Stack overflow, OutOfMemory)이고 VM은 계속 쓸 수 있다. 메모리 상한은 VM이 쥔 전체 바이트 기준이라 스크립트에 N 바이트를 주려면 cl_vm_memory_used(vm) + N으로 건다. spawn 스레드도 같은 상한을 쓴다.
- 할당 실패: eval 중 호스트 할당자가 실패해도 프로세스는 죽지 않는다. 컴파일 중이면 CL_ERROR_COMPILE이고 다음 eval 앞에서 VM을 reset한다(persist_main의 지역 변수와 선언은 사라지고 연료(fuel), 상한, 프린터 같은 호스트 설정은 남는다). 실행 중이면 panic: OutOfMemory다. VM을 만드는 함수와 호스트가 값을 만드는 함수(cl_str_init 등)의 할당 실패는 abort다. cl_vm_init_mem(CLMemFuncs)으로 VM의 모든 메모리를 호스트의 alloc/free로 돌릴 수 있다. 컴파일러의 고정 한계(지역 256, 매개변수 255, 필드 255)는 CompileError다.
- 능력 바인딩: #[bind] 선언과 cl_mod_add_func. 호스트 함수는 `fn (t: *CLThread) callconv(.c) CLRet` 하나의 모양이고, 매개변수는 커서처럼 선언 순서대로 읽는다(cl_thread_str, cl_thread_int). 반환 슬롯(cl_thread_ret)은 매개변수 앞이나 뒤에 받는다. 직접 호출, 함수 포인터 값, 함수 union 값, 표준 메서드가 부르는 경로 모두 같다(검사 6m. trait 호출은 cyber의 lib 테스트가 본다). 값 매개변수(str, []T, 관리 필드를 가진 구조체)는 호스트가 소유하고 cl_str_deinit, cl_slice_deinit으로 해제한다. [&]T로 선언하면 빌리기만 한다. `#[bind]` 함수에 기본값 매개변수는 쓸 수 없다(Cyber에 기본값 매개변수가 없다).
- 출력은 cl_vm_set_printer로 가로챈다. print, eprint 콜백의 첫 인자는 CLThread*다(VM은 cl_thread_vm(t)). 결과 값은 CLEvalResult.res, res_t와 cl_value_desc. persist_main에서는 마지막 맨 표현식이 결과다. fn main() -> T의 결과는 VM이 소유하고 다음 eval, cl_vm_reset, cl_vm_deinit까지 유효하다. cl_vm_release_result(vm)가 바로 해제한다. cl_thread_rc로 누수를 세는 호스트(평가 도구)는 먼저 이것을 부른다.
- 로더: 기본 로더는 core, meta, math, cy, c, io, test 일곱 모듈을 안다. os, libc, cli는 CLI 전용이다. cl_vm_set_loader로 호스트 로더를 끼우면 이 표를 줄일 수 있다. 점 표기(`use fs`, `fs.read`)는 호스트 로더가 그 이름에 모듈 소스를 돌려주는 것으로 된다.
- builtin 모듈(core, meta, cy, c, math, io, test)의 intrinsic(@memcpy, @bitCast, @retain 등)과 #[unsafe], #[consteval], #[reserve] 속성은 스크립트에서 쓸 수 없다. 런타임 내부를 드러내는 길이 컴파일 단계에서 닫혀 있다. 호스트 모듈과 os, libc, cli는 스크립트와 같은 규칙을 받는다. @로 시작하는 함수 이름은 정해진 hook만 선언할 수 있다.
- fiber: 자기 스택을 가진 stackful 코루틴이고 같은 스레드의 힙을 공유한다. 전환은 VM 명령이라 C 스택이 끼지 않는다. 호스트 함수를 건너 suspend하면 panic(Cannot suspend across a host call.)이고, 루트 맥락의 suspend는 no-op이다. fiber로는 능력 함수 안에서 스크립트를 멈췄다 재개할 수 없다. 아래 CL_AWAIT가 그 수단이다.
- 언어의 평가 규칙: 피연산자는 왼쪽에서 오른쪽으로 평가한다(인덱스 대입 a[f()] = g()와 레코드의 키, 값 사이는 예외). a.await() + b.await()에서 두 번째 요청은 첫 await 뒤에 나간다. fn main() -> !T가 돌려준 오류는 panic이고 호스트는 CL_ERROR_PANIC을 받는다.
- CL_AWAIT: main 스레드의 Future.await()가 미완료 호스트 Future를 만나면 eval이 CL_AWAIT로 돌아온다. 스택, 지역 변수, persist_main 상태, 남은 연료, 현재 fiber가 그대로 남는다. 호출 깊이와 generator 본문에 제약이 없다. API:
  - cl_future_new(t, future_t, tag): 호스트 함수가 돌려줄 미완료 Future[T]. tag는 호스트의 요청 번호이고 cl_future_tag(f)로 다시 읽는다. 호스트가 만들지 않은 Future(spawn, 스크립트의 FutureResolver)의 태그는 0이라 요청 번호는 1부터 쓴다. future_t는 cl_find_type(vm, "Future[!str]")로 얻는다. 호스트 함수 선언이 그 타입을 이름 지은 뒤에만 찾히고 cl_vm_reset 뒤에는 무효라 호출마다 찾는다. 반환 슬롯은 CLValue(8바이트)이고 (CLValue)(uintptr_t)f로 쓴다.
  - cl_future_complete(vm, f, &value): 값으로 완료. value는 T를 가리킨다(int는 8바이트, str은 CLstr, []T는 CLSlice). Future[!U]면 U를 넘기고 void면 NULL. 값은 복사되고 Future가 소유하므로 호스트가 놓지 않는다. 문자열 결과는 `CLstr s = cl_str_init(main_thread, bytes)` 뒤 `cl_future_complete(vm, f, &s)`. cl_future_complete_error(vm, f, cl_error(vm, "Denied")): 오류 값으로 완료(Future[!U]만).
  - cl_vm_pending_future(vm): 기다리는 Future(빌린 포인터). cl_vm_pending_futures(vm, out, cap): 기다리는 Future 목록과 개수. 보통의 await는 1개, 스크립트의 Future.wait_any(futures [&]Future[T]) -> int로 멈췄으면 목록 전체, Fiber.wait_ready()나 scope 블록의 합류로 멈췄으면 멈춘 fiber들이 기다리는 Future 전부다(순서 없음, 태그로 식별). 호스트는 아무것이나, 여러 개를 완료시키고 resume한다. cl_vm_resume(vm, &res): 이어 실행, 결과는 cl_vm_evalx와 같은 규칙. 완료하지 않고 resume하면 다시 CL_AWAIT.
  - cl_vm_abandon(vm): 멈춘 eval을 버린다. 결과는 interrupt와 같다(지역 변수는 사라지고 선언은 남는다). cl_vm_reset, cl_vm_deinit도 먼저 버린다.
  - 멈춘 동안의 cl_vm_eval*, cl_vm_validate, cl_vm_compile*은 CL_ERROR_SUSPENDED.
  - 규칙: 모든 호출과 완료는 eval을 돌리는 스레드에서 한다. 연료는 다시 채워지지 않는다(한 eval 전체를 센다). 멈춘 동안 들어온 interrupt 요청은 resume이 지운다. 그래서 승인 대기 중에 벽시계(wall-clock) 타이머가 울려도 스크립트를 끊지 않는다. 타이머는 resume 직전에 다시 시작하고, 멈춘 eval을 끊는 길은 cl_vm_abandon 하나다. cl_vm_interrupt 말고는 다른 스레드에서 부를 수 있는 함수가 없다. spawn 스레드 안의 await와 호스트 함수가 부른 스크립트 안의 await는 panic이다.
  - 스크립트가 직접 만든 미완료 Future(FutureResolver)도 CL_AWAIT가 된다. pending future의 태그가 0이면(우리 능력이 만든 것이 아니면) abandon한다.
  - 요청은 태그로 찾고 포인터로 찾지 않는다. 스크립트가 await하지 않고 버린 미완료 Future는 바로 해제되고 그 주소가 다음 cl_future_new에 다시 쓰일 수 있다. 완료시킬 Future는 cl_vm_pending_future(s)가 주므로 호스트는 포인터를 보관하지 않는다. tars-agent v1은 eval이 지금 기다리는 Future만 완료시키므로 retain이 필요 없다. 기다리지 않는 Future를 미리 완료시키려면 retain하고, 완료 뒤나 CL_SUCCESS 뒤에 놓고, panic, interrupt, abandon, reset 뒤에는 놓지 않고 잊는다(그 eval의 힙이 통째로 해제된다).
  - 취소 알림은 없다. 스크립트가 버린 요청은 호스트가 모른 채 남는다. 태그로 찾는 호스트는 eval이 끝날 때 요청 표를 비운다.
  - 래퍼 함수는 호스트 로더가 돌려주는 모듈 소스에 #[bind] 선언과 함께 둔다 (cyber examples/libcyber/host_await.c).
- fiber 안의 await와 scope 블록:
  - fiber 안에서 호스트 Future를 await해도 eval이 CL_AWAIT로 나가지 않는다. 그 fiber만 멈추고 resume은 .suspended를 돌려준다. eval이 나가는 것은 루트 맥락이 기다릴 때다: 루트의 await, Future.wait_any, Fiber.wait_ready(), scope 블록의 합류(Scope.join 포함). fiber를 직접 resume하는 루프가 Fiber.wait_ready()를 부르지 않으면 호스트는 Future를 완료할 기회를 얻지 못하고 스크립트는 연료, 시간 상한까지 돈다.
  - tars-agent에 주는 뜻: 모델이 능력 호출(머리말의 동기 래퍼)을 fiber에 넣으면 승인 요청이 여럿 동시에 걸릴 수 있다. cl_vm_pending_futures가 그 전부를 준다. 하나를 완료하고 resume하면 남은 것으로 다시 CL_AWAIT가 온다. 루트가 기다리지 않고 스크립트가 끝나면 fiber는 취소되고 그 요청은 await되지 않은 채 남으므로, eval이 끝날 때 호스트가 완료하지 않은 요청을 버린다. 작업은 승인 뒤 호스트가 하므로 버려진 요청은 아무 일도 하지 않는다(승인 우회 없음). 결정은 ADR 0016.
  - scope |s|: 블록(구조적 동시성): s.start(func, {args})로 fiber를 시작하고 블록 끝에서 모두 끝나기를 기다린다. 하나가 오류를 내면 나머지를 취소하고 오류가 블록 밖으로 나간다. 블록의 s.start만 빌림 인자(&T, &&T)를 받고 그 밖의 Scope.start와 fiber f(&x)는 컴파일 오류다. scope는 예약어다.
  - resume 뒤에는 목록을 다시 읽는다. 완료한 Future의 fiber가 다음 요청을 내면 새 Future가 들어온다. 중첩된 scope 블록의 Future도 같은 목록에 평평하게 들어오고 어느 것을 먼저 완료해도 된다.
  - 모델이 쓰는 코드의 함정: out.* += fut.await()는 await 전에 out.*를 읽어 여러 fiber가 같은 값에 더하면 덮어쓴다(v := fut.await() 뒤에 out.* += v). suspend만 반복하는 fiber와 Future를 기다리는 fiber가 한 블록에 섞이면 eval이 나가지 않고 연료 상한까지 돈다. @deinit 안에서 suspend, await를 쓰지 않는다.
  - Fiber.cancel(), Fiber.waiting(), Fiber.wait_ready(), Scope(new, start, join, active, abort). 진행 중인 fiber의 소멸은 panic이 아니라 취소다(들어가 있는 호출이 바로 반환하고 값은 해제, @deinit 포함). ^T 참조의 @deinit 안에서 멈춘 fiber는 취소할 수 없고 소멸은 panic이다.
- spawn 스레드의 await는 main과 같이 블록한다. 연료는 스레드마다 따로 센다. CLEvalConfig, CLCompileConfig의 deny_spawn을 켜면 표준 모듈이 아닌 chunk의 spawn이 컴파일 오류이고 호스트 함수는 eval 스레드에서만 불린다. fiber와 scope 블록은 그대로 쓴다.
- 심볼 조회(cl_vm_set_symbol_info, cl_vm_symbol_at 등)는 언어 서버용이다. tars-agent는 쓰지 않는다.
- CLI는 표준 모듈을 실행 파일에 내장해 cyber 파일 하나다. 오류 위치는 core:196:5처럼 모듈 이름으로 찍힌다. tars-agent는 CLI를 쓰지 않고 libcyber를 정적 링크한다. tars devlayer의 CLI 번들은 기준 빌드보다 옛 판이다.

## 없는 것

- JSON, 정규식, 날짜 라이브러리. cyber 표준 모듈로 만든다 (아래 목록).
- c 모듈을 끄는 옵션. 지금은 호스트 로더에서 거부하고 deny_raw_ptrs를 켠다.

## M0에서 확인한 것 (2026-11-14, 스파이크 1과 2. 상세는 docs/spikes/2026-11-14-m0-spikes-review.md)

- build.zig.zon 의존에서 `b.dependency("cyber", .{ .target, .optimize, .static = true, .commit }).artifact("cyber")`로 정적 라이브러리를 받고, cyber.h는 그 아티팩트의 include 경로로 따라온다(C 파일의 `#include "cyber.h"`로 확인). 버전 문자열은 `Cyber 0.4.10-DEV build-0-b450f535`처럼 commit 인자를 찍는다(소스에서 읽지 않는다). ffi는 기본 false다. Zig 0.17.1에는 @cImport가 없어 Zig 쪽 바인딩은 translate-c 패키지나 손으로 쓴 extern으로 만든다.
- 능력이 `Future[!str]`을 돌려주고 str 값이나 오류로 완료한다.
- 검증은 세션 VM에서 바로 한다. 보통의 컴파일 실패 뒤에는 같은 VM의 다음 검증과 실행이 된다. 모듈 소스가 실패한 뒤 다음 use에서 다시 불러온다. 이스케이프 오류(`\|`, `\xZZ`)는 위치 있는 컴파일 오류이고 세션이 남는다.
- `'\0'`은 NUL이다. 타입 없는 목록 리터럴은 원소를 첫 원소의 타입으로 바꾸지 않는다(`{1, 'a'}`는 컴파일 오류).
- 목록 참조에 대한 `+=`(`out := ^[]str{}` 뒤 `out += 'x'`)는 검증이 잡는 컴파일 오류이고 `out.* += 'x'`로 쓴다.
- core의 함수를 가릴 필요는 보이지 않았다. 다만 로더는 차단 목록이 아니라 허용 목록으로 써야 한다(기본 로더가 io 모듈을 준다).
- deny_spawn으로 spawn은 eval과 검증에서 컴파일 오류이고, scope 블록의 동시 승인은 그대로 된다. 호스트 함수가 매개변수를 반환 슬롯보다 먼저 읽어도 직접 호출, 함수 포인터 값, 함수 union 값, sort가 부르는 경로에서 맞는 값이다(검사 6m).
- deny_raw_ptrs와 호스트 모듈 선언은 함께 동작한다.
- 최상위 빌림(`b := &counts`)은 persist_main 세션에서 `Cannot persist local` 오류다. 세션의 캡처 오류 문구는 `^T` 선언을 권하고 빌림은 함수 안에서 하라고 한다.
- x86_64-linux-gnu 교차 빌드가 macOS에서 의존의 아티팩트로 된다. tars 게스트에서의 실행은 이 기준 빌드로 확인하지 않았다.
- mimalloc은 FFI를 끈 라이브러리 빌드에 들어가지 않는다.
- cyber에 낸 요청: docs/requests/cyber-m0-spike-requests.md.

## cyber에서 만들 것 (ADR 0010)

필요한 것은 cyber에 만든다. 두 번째 fork는 만들지 않고 soomtong/cyber 한 곳에서 한다. 항목마다 필요의 증거를 적는다. 증거 없는 항목은 올리지 않는다.

| 순서 | 항목 | 필요의 증거 | 메모 |
|---|---|---|---|
| C0 | 커밋을 원격에 올리기 | URL과 해시로 고정하려면 필요하다 | 요청서 1절. 본체 첫 단계의 선행 조건 |
| C0 | `a[i] = v`의 값 쪽 불일치에 남은 내부 이름(`@set_index`) | M0 확인(b450f535). 회차에서는 나오지 않았다 | 요청서 2절. 회차의 문구 다섯은 b450f535에서 고쳐졌다 |
| C1 | json 모듈: parse, stringify, 값 트리 | 평가 과제의 다수가 JSON을 다룬다. 설정 파일, API 응답, 도구 출력 | 깊이와 크기 상한. 값 타입은 복사 가능한 부분집합 안에서 다룰 수 있어야 한다 |
| C1 | toon 모듈: stringify, parse | 토큰 절약. 스크립트가 구조화된 결과(파일 목록, 검색 결과 같은 균일한 객체 배열)를 모델에게 돌려줄 때 JSON보다 적은 토큰으로 싣는다 | 값 트리는 json 모듈의 것을 쓴다. 깊이와 크기 상한. parse를 C1에 넣을지는 요청서를 쓸 때 정한다 |
| C2 | regex 모듈 | 로그와 명령 출력에서 값 뽑기. str 메서드만으로는 스크립트가 길어진다 | 역추적 없는 엔진(선형 시간), 직접 쓴다. 문법은 ripgrep 기본 문법의 부분집합 |
| C2 | time 모듈 | 파일 시각 비교, 기록의 날짜 계산 | 시계 읽기는 넣지 않는다 (능력 clock.now). 시간대는 UTC와 고정 오프셋부터 |
| C3 | 임베딩 옵션: 모듈 허용 표 | 05 문서 1층. 호스트 로더로 되면 올리지 않는다 | CLEvalConfig 필드 |
| 수시 | 프로세스를 죽이는 경로 수정 | 세션의 crash/ 디렉터리가 재현 사례를 준다 | cyber의 발견 이슈 기록 절차를 따른다 |
| 조건부 | 문자열, Array, Map 보강 | 평가의 실패 유형에서 "있을 줄 알고 부른 메서드"가 반복되면 | 모델의 기대에 맞추는 쪽이 안내로 가르치는 것보다 싸다 |
| 조건부 | spec --for-agents | 다른 프로젝트가 같은 안내 문서를 쓸 때 | |

표준 모듈의 조건: 신뢰하지 않는 스크립트가 부르므로 입력 크기에 대해 시간과 메모리가 예측 가능해야 한다. 할당은 VM 메모리 상한 아래, 긴 루프는 연료 검사점을 지난다. 누수 검사 allocator 테스트를 붙인다. 라이브러리 로더와 CLI 양쪽에 같은 이름으로 싣는다.

## 위험과 대응

| 위험 | 대응 |
|---|---|
| 모델이 Cyber를 틀린다 | 부분집합 안내, validate 뒤 구조화된 오류(cl_vm_compile_error) 되돌림, M0 평가와 통과 기준, 못 넘으면 direct 모드 |
| 컴파일러 abort가 남아 있을 수 있다 | 실행 전 기록, crash/ 보관, --continue. 비율을 재서 프로세스 분리 판단 |
| 능력 안에서 막히면 못 끊는다 | 능력마다 시간 제한과 취소 플래그 확인. 승인 대기는 VM 밖에서 한다 (ADR 0011) |
| upstream이 멈춰 있다 | fork가 유일한 유지 주체다. 없는 것은 직접 만든다 (ADR 0010). cyber 버전을 커밋과 해시로 고정하고 올릴 때 예제 테스트와 평가를 돌린다 |
| 표준 모듈을 만드는 일이 에이전트 일정을 민다 | 필요의 증거가 있는 것만, 평가가 필요로 하는 순서로 (C1이 M0 평가 앞) |
