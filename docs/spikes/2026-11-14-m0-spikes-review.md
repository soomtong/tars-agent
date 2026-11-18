# M0 스파이크 검토 결과 (2026-11-18)

스파이크를 Claude가 혼자 구현하고 검토했다 (ADR 0012의 덧붙임). 이 문서는 무엇을 만들었고, 기준 빌드에서 무엇이 확인됐고, 무엇이 남았고, 본체의 아키텍처에 어떤 뜻이 있는지를 적는다. 코드는 spike/에 있고 버릴 것이다.

기준 빌드: soomtong/cyber 0.4.15. 스파이크는 가장 새 빌드를 따르는 의존으로 받는다(ADR 0023). 스파이크 1, 3과 안내의 확인은 이 빌드로 2026-11-18에 돌렸다. 5절의 비교 회차는 0.4.12(커밋 67a2735c)로 처음 돌렸고, 같은 표를 이 빌드로 다시 돌렸다(5.3, 2026-11-18). 측정 환경은 macOS arm64.

읽는 순서: 1절(한 장 요약), 2절(에이전트는 어떻게 도는가), 그 뒤는 필요한 절만.

## 1. 한 장 요약

| 질문 | 답 | 근거 |
|---|---|---|
| Zig 호스트가 libcyber를 링크해 VM을 돌릴 수 있는가 | 된다 | 스파이크 1, 검사 47개 모두 통과 |
| cyber를 build.zig.zon 의존으로 쓸 수 있는가 | 된다. 태그를 따르는 의존의 `artifact("cyber")`로 받고 cyber.h가 따라온다 | 3.1 |
| 능력이 `Future[!str]`을 돌려줄 수 있는가 (ADR 0011의 모양) | 된다. str 값이나 오류로 완료한다 | 3.2 |
| 승인 대기를 VM 밖에서 하는 설계(ADR 0011, 0016)가 실제로 도는가 | 돈다. 승인, 거부, 취소, 동시 요청 모두 | 3.3 |
| 상한 넷(연료, 벽시계, 스택, 메모리)이 폭주를 멈추는가 | 멈춘다. VM은 계속 쓸 수 있다 | 3.4 |
| 검증을 세션 VM에서 바로 할 수 있는가 | 된다. 컴파일 실패 뒤에도 세션이 그대로다. 세션이 reset되는 경우는 `cl_vm_reset_pending`으로 안다 | 3.5 |
| Zig std.http로 모델 API에 스트리밍 요청을 보낼 수 있는가 | 된다. TLS와 CA 묶음 포함 | 4.3 |
| 전송 형식 둘을 메시지 모델 하나로 받을 수 있는가 (ADR 0015) | 된다. 블록 넷과 불투명 칸 하나로 충분했다 | 4.2 |
| CodeAct가 실제 과제를 푸는가 | 푼다. 0.4.12 회차에서 모델 셋이 과제 36개 중 33개를 끝냈다(DeepSeek은 두 모드, direct는 6개 모두). 실패 둘은 모델의 판정 실수이고, 하나는 cyber의 결함으로 VM이 프로세스째 죽은 것이다(기준 빌드에서는 그 스크립트가 컴파일 오류로 멈춘다). 컴파일 오류는 작은 모델에 과제당 2.8번, 모두 그 과제 안에서 고쳐졌다. 0.4.15 회차(2026-11-18)는 42개 중 41개를 끝냈고 실패 하나는 과제 해석이다. 죽은 실행은 없고 작은 모델의 컴파일 오류는 과제당 2.2번이다 | 5, 5.3 |
| x86_64-linux-gnu 교차 빌드가 되는가 | 된다. tars 게스트에서의 실행은 이 빌드로 확인하지 않았다 | 6 |

가장 무거운 발견 셋:

1. 모델이 쓴 평범한 스크립트가 VM을 죽일 수 있다. 0.4.12 회차에서 `[]str`의 `remove` 결과를 버리고(`_ = out.remove(i)`) 옛 목록을 쓴 스크립트가 해제된 원소를 읽어 s2 프로세스가 세그폴트로 끝났다. 기준 빌드에서는 이 코드가 고치는 법을 말하는 컴파일 오류다. 그래도 본체는 VM이 호스트 프로세스를 죽이는 경우를 전제로 설계해야 한다 (5, 7, 9).
2. 안내 문서와 컴파일러 문구가 CodeAct의 성패를 가른다. 컴파일 오류 51건은 모두 그 과제 안에서 고쳐졌다. 가장 흔한 것은 여전히 `!str`을 풀지 않고 출력한 것(20건)이고 문구가 고치는 법을 말한다. 0.4.15 회차에서는 41건, `!str` 출력 12건이다 (5, 5.3, 7).
3. 능력의 모양(`Future[!T]`와 머리말 래퍼), 세션 VM에서의 검증, VM 밖의 승인 대기가 우회 없이 본래 모양으로 돈다. 본체 설계를 바꿀 것은 없다 (3).

## 2. 에이전트는 어떻게 도는가

스파이크 2의 루프(spike/s2/src/main.zig)가 에이전트의 전부다. 줄이면 이렇다.

~~~text
history = [사용자의 질문]
반복:
    reply = 모델에게 (시스템 프롬프트, 도구 정의, history 전체)를 보낸다
    history에 reply를 덧붙인다
    reply에 도구 호출이 없으면 끝
    도구 호출마다: 호스트가 실행하고 결과를 만든다
    history에 결과를 덧붙인다
~~~

여기서 알아 둘 것 다섯:

- 모델은 상태가 없다. 매 스텝마다 대화 전체를 다시 보낸다. 대부분이 시스템 프롬프트(Cyber 안내)이고, 대화가 길어질수록 요청이 커진다. 그래서 캐시와 컴팩션이 필요해진다. 실제 크기는 5절.
- 모델은 아무것도 실행하지 않는다. "이 도구를 이 인자로 불러 달라"는 글을 낼 뿐이다. 실행은 호스트가 하고, 그래서 권한 게이트를 호스트에 둘 수 있다.
- 응답은 조각으로 온다. 도구의 인자도 JSON 조각으로 나뉘어 온다. 다 모은 뒤에야 해석할 수 있다. 그래서 코드를 써지는 대로 화면에 보이는 것과 실행하는 것은 다른 시점이다.
- 도구 결과는 사용자 역할의 메시지로 돌아간다. 오류도 결과다: 실패를 글로 돌려주면 모델이 읽고 고친다.
- 끝은 모델이 정한다. 도구 호출 없이 글만 내면 그것이 답이다. 호스트는 한도(스텝 15)로만 끊는다.

direct와 CodeAct의 차이는 도구 하나의 모양뿐이다.

| | direct | CodeAct |
|---|---|---|
| 도구 | sh(cmd) | run(code) |
| 모델이 쓰는 것 | 셸 명령 한 줄 | Cyber 스크립트 |
| 호스트가 하는 것 | 프로세스 실행 | 세션 VM에서 검증(컴파일만), 상한을 걸고 실행, 능력 호출마다 승인 |
| 한 스텝에 할 수 있는 일 | 명령 하나 (셸 파이프로 묶기는 가능) | 호출 여럿, 분기, 반복, 중간값 가공 |
| 권한을 거는 자리 | 명령 문자열 전체 | 능력 호출 하나하나 (경로, 명령이 인자로 보인다) |

실제 CodeAct 스텝 하나의 기록 (DeepSeek-V4.1-Flash 사고 없음, 3회차 T1의 스텝 4):

~~~text
[도구 호출] run {"code": "type Row:\n    name str\n    n int\n\nrows := []Row{}\ntotal := 0\nfor {'app.log', 'db.log', 'web.log'} |name|:\n    text := fs.read('logs/' + name)!\n ... rows.sort(|a, b| a.n > b.n) ... fs.write('report.txt', out)!\nprint(out)\nprint('total=%{total}')\nprint(fs.read('report.txt')!)"}
    [승인] write report.txt
    [실행] 종류=ok 능력 호출 5회
[도구 결과] web.log: 23
db.log: 8
app.log: 7

total=38
web.log: 23
...
~~~

스크립트 하나가 파일 셋을 읽고, 세고, struct 목록으로 정렬하고, 쓰고, 다시 읽어 보였다. 능력 호출은 다섯 번이었고 모델 왕복은 한 번이었다. 정렬 모양은 안내의 예제 4 그대로다. 앞의 세 스텝은 `print(proc.exec('ls -la logs/ && ...')!)`, `grep -c`로 둘러보고 센 것이다.

## 3. 스파이크 1: 호스트 경계

코드: spike/s1. 실행: `zig build && ./zig-out/bin/s1`. 검사 47개가 PASS/FAIL로 찍히고 모두 통과한다.

### 3.1 링크

- build.zig.zon의 의존은 `zig fetch --save=cyber "git+https://github.com/soomtong/cyber#latest"`로 넣는다. zig가 `.url = "git+https://github.com/soomtong/cyber?ref=latest#<받은 커밋>"`과 `.hash`를 적는다. 태그가 움직여도 다시 받기 전에는 적힌 커밋을 쓴다.
- `b.dependency("cyber", .{ .target = target, .optimize = .ReleaseFast, .static = true, .dev = false }).artifact("cyber")`를 `linkLibrary`로 링크한다(spike/s1/build.zig). ffi는 기본 false다.
- cyber.h는 아티팩트의 include 경로로 따라온다. s1의 C 파일(src/inc_check.c)이 `#include "cyber.h"`로 컴파일되고, `CLEvalConfig`와 `CLCompileConfig`의 크기(12)가 translate-c 쪽과 같다(검사 0).
- 버전 문자열은 `Cyber 0.4.15 build-0-local`이다. 버전 번호는 cyber의 build.zig.zon에서 오고, `-DEV` 표시는 `dev` 인자로 정한다. 빌드 번호(`build`)와 커밋(`commit`)은 의존 인자로 넘길 때만 찍힌다. 넘기지 않는다. 검사 0은 `Cyber `로 시작하는지와 구조체 크기만 본다.
- Zig 0.17.1에는 `@cImport`가 없다. cyber.h를 Zig에서 쓰는 길은 둘이다: translate-c 패키지로 모듈을 만들거나, 쓰는 함수의 extern 선언을 손으로 쓴다. 스파이크는 앞의 것을 썼다. 본체의 추천은 9절.
- 의존 패키지의 `docs/agent-guide.md`와 `docs/api.json`은 `addAnonymousImport`(`cyber.path(...)`)로 빌드 때 싣는다. 검사 0b가 api.json을 std.json으로 읽어 json, toon, regex, peg, time의 항목(함수 67, 타입 24)만 거른다.
- libcyber.a(arm64, ReleaseFast)는 3.06 MB(3,058,056바이트), 공개 `cl_` 함수는 142개다(0.4.15에 `cl_vm_symbol_hints`가 더해졌다). 표준 모듈 json, toon, regex, peg, time이 들어 있고 각각의 `cl_mod_bind_*`가 있다. mimalloc 심볼은 없다(FFI를 끈 라이브러리 빌드에는 들어가지 않는다).

### 3.2 능력 바인딩

- 호스트 함수는 `fn (t: *CLThread) callconv(.c) CLRet` 하나의 모양이다. 매개변수는 커서처럼 선언 순서대로 읽는다(cl_thread_str, cl_thread_int). 반환 슬롯(cl_thread_ret)은 매개변수 앞이나 뒤에 받는다. 직접 호출, 함수 포인터 값, 함수 union 값, 표준 메서드(sort)가 부르는 경로 모두에서 매개변수를 먼저 읽어도 같은 값이다(검사 6m). 스파이크의 능력은 반환 슬롯을 먼저 받는다.
- 값 매개변수(str)는 호스트가 소유하므로 cl_str_deinit으로 놓는다.
- 뜻: ADR 0006의 "Cyber 값 변환과 소유권 해제는 생성된 바인딩 층 한 곳에서만 한다"가 편의가 아니라 안전 장치다.
- 문자열 결과: 능력은 `Future[!str]`을 돌려주고, 일을 마치면 `CLstr s = cl_str_init(main_thread, bytes)` 뒤 `cl_future_complete(vm, f, &s)`로 완료한다. 값은 Future가 소유한다. 실패는 `cl_future_complete_error(vm, f, cl_error(vm, "NotFound"))`. 모델이 보는 것은 머리말 래퍼의 `fs.read(path) -> !str` 하나다.

~~~cy
#[bind] fn read_async(path str) -> Future[!str]
fn read(path str) -> !str:
    return read_async(path).await()
~~~

- `#[bind]` 함수에 기본값 매개변수는 쓸 수 없다(ParseError: Expected `,`). Cyber에 기본값 매개변수 자체가 없다. 필요하면 머리말에 인자 수가 다른 래퍼를 둔다.
- 점 표기(`use fs`, `fs.read`)는 호스트 로더가 "fs"라는 이름에 모듈 소스를 돌려주는 것으로 그대로 된다.

### 3.3 승인 대기 (ADR 0011, 0016)

모양: 능력은 일을 하지 않고 요청을 표에 적은 뒤 미완료 Future를 돌려준다. 머리말의 래퍼가 await하고, eval이 CL_AWAIT로 돌아오면 루프가 결정한다.

| 검사 | 결과 |
|---|---|
| 승인 둘, 거부 하나 | 스크립트는 거부를 error.Denied 값으로 받아 계속 돈다. CL_AWAIT 3회 |
| 두 번째 승인에서 취소 | cl_vm_abandon. 두 번째 파일은 만들어지지 않고 VM은 다음 스크립트를 받는다 |
| 승인이 필요 없는 read | 호스트 함수 안에서 Future를 바로 완료한다. CL_AWAIT 0회. 스크립트 쪽 모양은 같다 |
| 능력의 오류 | `fs.read(없는 경로) !else 'fallback'`이 fallback을 받는다(error.NotFound) |
| await하지 않고 버린 요청 | 아무 일도 하지 않는다. 물은 요청 번호는 2 하나였다 (승인 우회 없음) |
| 스크립트가 만든 미완료 Future | 태그 0이라 abandon, 결과는 INTERRUPT |
| scope 블록의 요청 둘 | 번호 순(1, 2)으로 하나씩 물었다 |
| 하나를 거부 | 나머지는 묻지 않은 채 버려졌다. 완료 안 된 요청 1개가 표에 남고, eval 끝에 비운다 |
| 중첩 scope 블록 | 번호 순 1, 2, 3으로 끝까지 갔다 |
| proc.exec | 승인 뒤 루프가 프로세스를 돌리고 stdout을 `!str`로 돌려준다 |
| 승인 흐름 뒤 살아 있는 객체 | 0 |

ADR 0011과 0016의 설계는 고칠 것 없이 돈다.

### 3.4 상한

| 상한 | 스크립트 | 결과 |
|---|---|---|
| 연료 100,000 | `while true` | INTERRUPT (panic: Out of fuel.), 1ms 안 |
| 벽시계 200ms (타이머 스레드의 cl_vm_interrupt) | `while true` | INTERRUPT, 205ms 뒤 |
| 스택 1 MiB | 끝없는 재귀 | PANIC (Stack overflow. The stack limit is 1048576 bytes.) |
| 메모리 +8 MiB | 끝없는 추가 | PANIC (OutOfMemory). VM 메모리 2702 KiB에서 2783 KiB로 돌아왔다 |

상한에 걸린 뒤: 함수 선언과 use는 남고 최상위 변수는 사라진다(함수 호출은 되고 변수는 Undeclared). panic도 같다(검사 6k). 앞선 eval에서 만든 변수도 사라진다. 둘 다 reset이 아니라 `cl_vm_reset_pending`은 false다. s2는 결과에 "top-level variables were reset (functions and imports are kept)"를 붙인다.

### 3.5 세션과 검증

- persist_main: 변수, 함수, use가 다음 eval로 이어진다.
- validate: 세션의 변수를 보면서 컴파일만 한다. 구조화된 오류가 온다(kind=2, line=1, col=6, len=4, "Undeclared variable `totl`."). validate한 선언은 넘어가지 않는다.
- validate에는 설정 인자가 없고 마지막 eval의 설정(persist_main, deny_raw_ptrs, deny_spawn)을 쓴다. eval 전의 새 VM에서는 spawn이 든 스크립트가 검증을 통과한다(검사 7f). 그래서 머리말을 eval한 뒤에 검증한다. cyber.h의 `cl_vm_validate` 설명에 이 동작이 적혀 있다.
- 실패한 컴파일 뒤: 같은 VM의 다음 검증과 실행이 그대로 된다(6f: 캡처 오류로 실패한 정렬 스크립트 뒤 Map 스크립트가 검증과 실행을 통과). 모듈 소스가 컴파일에 실패하면 다음 use에서 로더를 다시 불러 맞는 소스를 받는다(6g). 그래서 검증은 세션 VM에서 `cl_vm_validate` 한 줄로 한다. 문자열 이스케이프 오류(`\|`, `\xZZ`)도 위치 있는 보통 컴파일 오류이고 세션이 남는다(6i). `'\0'`은 NUL이다(6j).
- reset: VM의 첫 컴파일이 실패하면 `cl_vm_reset_pending`이 true이고 다음 eval부터 세션이 이어진다(6l). 컴파일러나 지역 이월 중의 할당 실패 뒤도 같다(cyber.h). 호스트는 CL_SUCCESS가 아닌 eval과 검증 뒤에 이것을 묻는다. s2는 true면 머리말을 다시 돌리고 모델에게 "the session was reset"을 알린다.
- 목록 참조의 `+=`(`out := ^[]str{}` 뒤 `out += 'x'`)는 검증이 잡는 컴파일 오류이고, 문구가 `out.* += ...`를 알려 준다(6h).
- 최상위 빌림(`c := &x`)은 다음 eval로 넘길 수 없어 ``Cannot persist local `c` of borrow type `&int` across evals.``다. CLI에서는 나지 않는 오류라 안내의 조언은 세션에서 확인해야 한다(8절).
- 오류 모아 받기(0.4.15, 검사 6n): 세션 VM에서 `cl_vm_set_error_recovery(vm, true)`를 켜고 검증하면 `cl_vm_compile_report`가 구문 오류를 모두 준다(세 줄의 구문 오류가 셋으로 온다. 끄면 하나). 구문 오류가 없으면 본문(main 블록, 함수)마다 첫 오류 하나다(main, 함수 둘에 하나씩이면 셋, main의 것이 먼저 온다). 선언 오류(`fn g() int:`처럼 시그니처가 틀린 것)가 섞이면 하나에서 끝난다. 실패한 검증 뒤에도 앞선 eval의 최상위 지역이 남는다. 결과는 여전히 CL_ERROR_COMPILE이고 아무것도 실행되지 않는다.
- 편집기용 힌트(0.4.15, 검사 7i): `cl_vm_set_symbol_info(vm, true)`를 켜고 검증하면 `cl_vm_symbol_hints`가 추론된 지역 타입, `scope` 블록 출구, 쓰지 않는 지역과 `use`를 위치순으로 준다. `cyber-lsp`의 Warning과 inlay hint가 이 표에서 나온다. `_`로 시작하는 이름은 빠지고, 실패한 검증 뒤에는 쓰지 않는 이름을 내지 않는다. 세션에서 주의할 점: 최상위 지역(`top := f()`)도 unused로 나온다. 다음 eval이 쓸 수 있는 값이므로 호스트가 모델에게 넘길 때는 함수 안 지역만 고르거나 최상위를 거른다.
- 비용: validate 200회 1~2ms, eval 200회 2ms. VM 생성과 첫 eval은 개당 2~3ms, VM 하나가 쥔 메모리 약 2.6 MiB(2700 KiB).

### 3.6 샌드박스 경계

| 시도 | 결과 |
|---|---|
| `use c` | 실린다. math가 c를 쓰므로 허용 목록에 넣는다. 포인터 함수는 deny_raw_ptrs로 컴파일 오류, extern 호출은 -Dffi=false로 panic 결과다 |
| `#[extern]` 함수(`use c` 없이) | CompileError: An `#[extern]` function needs the `c` module. Add `use c`. 세션이 남는다(검사 7h). 0.4.13 릴리스는 검증 중에 프로세스가 죽었다 |
| `use os` | 라이브러리에 없다. 같은 오류 |
| `Ptr[int](0)` | CompileError: Raw pointer type `Ptr[int]` is not allowed (deny_raw_ptrs) |
| deny_raw_ptrs와 호스트 모듈 | 함께 동작한다. 호스트 모듈의 선언은 막히지 않는다 |
| `@bitCast` | CompileError: internal to the builtin modules |
| `use io` (`cy`도) | 허용 목록 밖이라 로더가 거부한다(검사 7a). io는 str의 Reader, Scanner라 세계에 닿지 않는다 |
| `use json` (`toon`, `regex`, `peg`, `time`도) | 세션에서 된다(ADR 0024, 0025). json의 parse, get, stringify, toon.from_json, regex의 is_match, find_all, peg의 compile, match, time.now, time.zone('Asia/Seoul')이 맞고 `use`는 다음 run에 이어진다 |
| `spawn(work, {21})` | deny_spawn이면 eval과 검증에서 CompileError: `spawn` is not allowed. The host disabled threads for this script (`deny_spawn`). ... |

spawn에 대해: deny_spawn을 켜지 않으면(`s1 spawn`) 스레드 안에서 능력 함수(`fs.read`)가 그대로 불리고, 연료 상한은 스레드 안의 무한 루프를 502~508ms에 멈춘다(타이머 500ms). deny_spawn을 켜면 표준 모듈이 아닌 chunk의 spawn이 컴파일 오류이고 호스트 함수는 eval 스레드에서만 불린다. s1과 s2는 deny_spawn을 켠 채 돌았고, scope 블록의 동시 승인(3.3)은 그 아래에서 통과했다.

로더는 허용 목록이다: core, meta, c, math, json, toon, regex, peg, time, path, test와 호스트 능력 모듈(ADR 0026, 0028). 로더와 resolver는 스크립트의 use와 모듈 안의 use를 구별하지 못하므로 의존 모듈 meta(core, json, math가 쓴다)와 c(math가 쓴다)를 넣는다. 이전의 차단 목록은 c를 막아 `use math`가 실패하고 있었다(검사 7a2가 이제 본다). 기본 로더는 os, libc, cli를 모른다. 새 모듈 가운데 `time`은 시계(`time.now()`, `time.monotonic()`)와 시스템 파일(`time.zone(name)`의 zoneinfo 폴더, `time.local()`의 `TZ`와 `/etc/localtime`)을 능력을 거치지 않고 읽는다. 이것을 받아들이고 허용했다. 능력 clock.now는 두지 않는다(ADR 0024). json, toon, regex, peg는 순수 계산이고 연다(ADR 0025). 0.4.14의 `path`는 경로 문자열만 다루고 파일 시스템을 보지 않아 연다(ADR 0027). `test`는 네이티브 바인딩이 없는 순수 Cyber 검사 함수이고 정본 안내가 가르치므로 연다(ADR 0028, 검사 7a4). 실패한 검사는 panic이라 앞선 eval의 최상위 지역이 사라진다(6k).

## 4. 스파이크 2: 제공자

코드: spike/s2a (curl 스크립트와 원문 응답), spike/s2/src/provider.zig. 이 절은 cyber와 무관하다. 2a의 원문 응답은 2026-11-14에 지금의 모델 ID(DeepSeek API의 `deepseek-flash`, OpenRouter의 `qwen/qwen3.8-flash`와 `deepseek/deepseek-v4.1-flash-1017`)로 받았고, 5절의 회차에서도 두 형식(DeepSeek의 Anthropic 형식, OpenRouter의 OpenAI 형식)이 같은 어댑터로 돌았다.

### 4.1 두 형식의 실제 모양 (2a)

같은 질문, 같은 도구 하나를 보냈다. 원문은 spike/s2a/out/.

| | Anthropic Messages | OpenAI Chat Completions |
|---|---|---|
| 시스템 프롬프트 | 최상위 `system` 필드 | `messages`의 첫 항목(role이 system) |
| 도구 정의 | `{name, description, input_schema}` | `{type: function, function: {name, description, parameters}}` |
| 응답의 단위 | 블록. 블록마다 시작, 조각, 끝 이벤트 | 조각(delta) 하나짜리 흐름. 필드가 있으면 그 종류다 |
| 글 | `text_delta.text` | `delta.content` |
| 사고 | thinking 블록, `thinking_delta`와 `signature_delta` | `delta.reasoning_content` (DeepSeek), `delta.reasoning`과 `reasoning_details` (OpenRouter) |
| 도구 호출 | tool_use 블록 시작에 id와 name, 인자는 `input_json_delta.partial_json` | `delta.tool_calls[i]`: 첫 조각에 id와 name, 뒤 조각에 `function.arguments` |
| 인자의 최종 형태 | 객체 (`input: {...}`) | 문자열 (`arguments: "{...}"`) |
| 도구 결과 | user 메시지 안의 tool_result 블록 | role이 tool인 별도 메시지 |
| 끝난 이유 | `stop_reason`: end_turn, tool_use, max_tokens | `finish_reason`: stop, tool_calls, length |
| 사용량 | message_start에 입력, message_delta에 출력 | 마지막 조각의 `usage` (stream_options로 켜야 온다) |
| 흐름의 끝 | message_stop 이벤트 | `data: [DONE]` |

호환 엔드포인트에서 본 어긋남:

- OpenRouter는 같은 모델을 여러 상류 제공자로 보낸다(이번 응답은 qwen이 Alibaba, DeepSeek이 InferenceNet). 끝난 이유와 사용량 칸의 모양은 상류에 따라 달라질 수 있다. 이번 응답에서는 두 형식 모두 도구 호출에 맞는 끝난 이유(tool_use, tool_calls)가 왔다.
- OpenRouter의 OpenAI 형식은 `finish_reason`을 두 조각에 걸쳐 두 번 보낸다. 누적기는 두 번째를 덮어써도 되게 한다.
- DeepSeek API의 `deepseek-flash`(V4.1 Flash)는 기본 effort가 high다(모델 목록의 `default_level`, 고를 수 있는 것은 low, high, max). 요청에 아무것도 넣지 않아도 사고한다. Anthropic 형식에서는 thinking 블록이 오고 signature에 메시지 id가 들어 있다. 쉬운 질문(2a의 도구 질문)에는 사고 글이 비고 thinking_tokens가 0이며, 계산이 필요한 질문에는 수백 토큰을 사고했다. 옛 별칭 `deepseek-chat`은 같은 질문에도 thinking 블록 없이 답한다(사고 없는 모드).
- 사고가 이미 켜져 있으므로 `"thinking":{"type":"enabled"}`(OpenAI 형식)는 응답을 바꾸지 않았다. Anthropic 형식의 `output_config.effort`를 low, max로 준 요청 하나씩은 사고 토큰이 730, 459로 기본(386)과 순서가 맞지 않았다. effort 칸이 받아들여지는지는 표본 하나로 말할 수 없다. 본체에서 제공자를 다룰 때 확인한다.
- 사용량의 뜻이 다르다. DeepSeek의 Anthropic 형식은 input_tokens가 캐시되지 않은 몫이고 캐시된 몫은 cache_read_input_tokens에 따로 온다. OpenAI 형식의 prompt_tokens는 캐시된 몫을 포함한다. OpenRouter는 요청별 cost를 준다.
- DeepSeek은 요청에 캐시 지점을 표시하지 않아도 앞부분을 자동으로 캐시한다. OpenRouter의 Qwen도 캐시가 붙었다(5절).

### 4.2 메시지 모델과 어댑터 (ADR 0015의 확인)

~~~text
Block   = text | thinking{text, raw} | tool_call{id, name, args_json} | tool_result{id, content, is_error}
Message = {role: user | assistant, blocks}
Provider(데이터) = {name, format, url, auth, key_env, model}
어댑터 = buildBody(형식, 히스토리) -> 요청 본문,  스트림 누적기(형식) -> 내부 이벤트와 Message
~~~

- 블록 넷으로 두 형식, 제공자 둘, 모델 셋의 응답을 모두 받았다. 다섯 번째 블록은 필요하지 않았다.
- 불투명 칸(thinking.raw)은 필요하다. Anthropic 형식의 signature가 거기 들어가고 다음 요청에 그대로 되돌아간다. OpenAI 형식에서는 reasoning_content 필드로 되돌렸다. 거절(400)은 없었다.
- 끝난 이유는 내용에서 다시 계산한다(도구 호출이 있으면 tool_use). 상류에 따라 끝난 이유가 어긋나도 루프가 흔들리지 않는다.
- 제공자 넷이 표의 네 줄이다. 어댑터 코드는 형식 수만큼인 둘이다.
- OpenAI 형식으로 내보낼 때 블록 목록을 풀어야 한다: tool_result는 별도 메시지로 나가고, text, thinking, tool_call은 assistant 메시지 하나의 필드 셋으로 흩어진다. 한 메시지 안의 블록 순서는 OpenAI 형식에서 사라진다.
- 내부 이벤트는 넷으로 충분했다: 글 조각, 사고 조각, 도구 시작, 인자 조각.

보지 못한 것: 한 응답에 도구 호출 여럿, max_tokens로 잘린 응답, 세션 중간에 형식을 바꾸는 것, 스트림 중간에 끊긴 연결.

### 4.3 Zig의 HTTP

- std.http.Client로 요청을 보내고 응답 본문을 줄 단위로 읽는다. SSE 해석은 `data:`로 시작하는 줄만 JSON으로 푸는 것으로 충분했다.
- TLS와 CA 묶음은 macOS에서 됐다. curl 프로세스 대안은 필요 없다.
- accept-encoding은 identity로 고정했다. 압축을 받으면 줄 단위 읽기 앞에 풀기 단계가 필요하다.
- SSE의 한 줄이 버퍼보다 길면 읽기가 실패한다(StreamTooLong). 스파이크는 1 MiB 버퍼를 줬다. 본체는 조각 단위로 읽는 해석기가 필요하다.
- Zig 0.17.1의 std는 Io 인터페이스를 인자로 받는 모양이다(파일, 프로세스, 시계, http 모두). main이 받은 io를 끝까지 넘겨야 한다.

## 5. direct 대 CodeAct: 작은 비교

과제 셋. 평가가 아니라 감을 잡기 위한 것이다. 판정(ADR 0006)은 과제 20개를 3회씩 돌린 뒤에 한다. 모든 회차를 0.4.12(커밋 67a2735c)와 그때의 안내(8절의 안내에서 기준 버전 줄, `[]T`의 크기 바꾸기 줄, `let` 오류 줄이 다른 판)로 2026-11-16에 돌렸다. 같은 표를 0.4.15로 다시 돌린 결과는 5.3에 있다. 원자료는 spike/s2/out/0.4.12/(회차별 폴더와 .tsv. 열: 과제, 판정, 제공자, 모델, 모드, 스텝, 도구 호출, 도구 오류, 입력 토큰, 캐시된 입력, 출력 토큰, 밀리초, 컴파일 오류). s2는 본래 모양(능력은 `Future[!str]`, 검증은 세션 VM의 `cl_vm_validate`, deny_spawn, 실패 뒤 `cl_vm_reset_pending` 확인, 표준 모듈 다섯은 로더에서 막음)으로 돌았다. 모델이 쓴 명령은 샌드박스(spike/s2/src/jail.zig) 안에서만 돌았다.

- T1: 로그 파일 셋에서 ERROR 줄을 세어 정렬해 보고서 파일로 쓰기
- T2: .py 파일들에서 대문자 TODO를 찾아 파일별 개수를 쓰기
- T3: 설정 파일의 한 구획에서만 값을 바꾸고 줄을 더하기

| 모델 | 모드 | 과제 (회차) | 통과 | 스텝 평균 | 컴파일 오류 (과제당) | 오류가 난 과제 | 과제당 시간 | 과제당 입력 토큰 | 과제당 출력 토큰 |
|---|---|---|---|---|---|---|---|---|---|
| DeepSeek-V4.1-Flash 사고 없음 | direct | 3 (1) | 3 | 4.7 | | | 5초 | 4.0k (캐시 2.7k) | 351 |
| DeepSeek-V4.1-Flash 사고 없음 | codeact | 9 (3) | 8 | 5.1 | 0.33 | 3 | 7초 | 37.1k (캐시 35.1k) | 690 |
| DeepSeek-V4.1-Flash effort high | codeact | 9 (3) | 8 | 5.1 | 0.33 | 1 | 8초 | 37.2k (캐시 35.3k) | 835 |
| qwen3.8-flash | direct | 3 (1) | 3 | 7.3 | | | 25초 | 18.5k (캐시 7.7k) | 1,121 |
| qwen3.8-flash | codeact | 15 (5) | 14 | 8.3 | 2.80 | 14 | 39초 | 138.0k (캐시 66.6k) | 2,257 |
| qwen3.8-max | codeact | 3 (1) | 3 | 6.7 | 1.00 | 3 | 52초 | 99.7k (캐시 46.6k) | 1,757 |

입력 토큰은 캐시된 몫을 포함한 전체다(두 제공자 모두 기록이 둘을 따로 주므로 더했다). DeepSeek은 두 모드로 돌렸다. "사고 없음"은 옛 별칭 `deepseek-chat`으로 요청한 것이다(응답도 별칭을 돌려주므로 원자료의 모델 칸은 `deepseek-chat`). "effort high"는 모델 ID `deepseek-flash`로 요청한 것이고 이것이 모델의 기본값이다(4.1). s2는 `deepseek-flash`로 요청한다. 출력 토큰은 사고를 포함한다(기록에 사고의 몫이 따로 없다). DeepSeek effort high의 스텝, 시간, 토큰은 s2가 죽은 과제 하나를 뺀 8개의 평균이다. 과제당 컴파일 오류의 회차별 값은 DeepSeek 사고 없음 0~0.67, effort high 0~1.0, qwen3.8-flash 2.33~3.33이다.

읽는 법:

- CodeAct 실패 셋 가운데 둘은 Cyber 때문이 아니다. DeepSeek 사고 없음 1회차 T2는 스크립트가 컴파일되고 돌았고, 모델이 `#`로 시작하는 줄만 세어 `pass  # TODO handle errors`처럼 코드 뒤의 주석을 놓쳤다(`a.py 1`, 정답 2). qwen3.8-flash 1회차 T1은 "file names without the folder"를 확장자를 뗀 이름으로 읽어 `web: 23`을 썼다(채점은 `web.log`를 기대한다).
- 나머지 하나(DeepSeek effort high 2회차 T3)는 cyber의 결함이다. 모델이 Python의 `pop`처럼 `_ = out.remove(out.len() - 1)`로 목록을 줄이려 했고, 결과를 버린 뒤 옛 `out`을 다시 읽다가 VM이 세그폴트로 s2 프로세스째 끝났다. 스크립트는 컴파일을 통과했다. 무한 루프였으므로 원래라면 연료나 벽시계 상한이 멈췄어야 한다. 세션 기록과 대화는 그 자리에서 사라졌다. 기준 빌드에서는 이 스크립트가 CLI와 세션 모두 ``The result of `remove` is the new list, and `out` keeps the old one. Write `out = out.remove(out.len() - 1)`.``로 멈추고, 문구대로 고치면 맞는 결과로 끝난다.
- qwen3.8-flash는 과제당 컴파일 오류가 2.80이고 15개 과제 중 14개에서 한 번 이상 냈다. 오류 42건 중 17건이 `!str`을 풀지 않고 출력한 것이다(5.1). 모두 그 과제 안에서 고쳐졌다.
- DeepSeek-V4.1-Flash는 두 모드의 차이가 이번 회차에서는 보이지 않는다(컴파일 오류 둘 다 0.33, 스텝 둘 다 5.1). 사고를 켠 쪽은 오류 셋이 모두 한 과제에서 났다.
- T1의 "file names without the folder"는 확장자를 뗀 이름(`web`)으로 읽힐 수 있다. 이번에 실제로 실패 하나가 났다. 평가 과제(eval/)를 만들 때 이런 문장은 뜻이 하나가 되게 쓴다.
- CodeAct의 대가는 시스템 프롬프트다. direct는 331바이트, CodeAct는 Cyber 안내를 포함해 20,897바이트이고 첫 요청 입력이 6,500토큰 안팎이다. 매 스텝 다시 보내므로 캐시가 없으면 스텝마다 그만큼이 든다. 자동 캐시가 덮은 몫은 DeepSeek이 9할 남짓(95%), OpenRouter의 qwen이 절반 안팎(47~48%)이었다. 캐시가 덮는 몫은 제공자와 회차에 따라 크게 다르다.
- 상한(연료, 벽시계)이 걸린 실행, panic, 세션 reset은 없었다. 프로세스가 죽은 실행이 하나 있었다(위).
- 표본이 작다. 과제 셋, 회차 다섯까지다. 방향을 보는 숫자이지 판정이 아니다.

### 5.1 모델이 틀린 곳

컴파일 오류 51건(DeepSeek-V4.1-Flash 사고 없음 3, effort high 3, qwen3.8-flash 42, qwen3.8-max 3):

| 오류 첫 줄 | 건수 | 문구가 고치는 법을 말하는가 |
|---|---|---|
| ``Can not print `!str`. Unwrap it with `!` first ...`` (`print(proc.exec(...))`) | 20 | 말한다 |
| ``Undeclared variable `x`.`` (`for p \|x\|:`의 없는 `p` 셋, Java식 `String` 셋, `'...' % 0`의 `s` 하나) | 7 | 무엇이 틀렸는지는 말한다. `for p \|x\|:`는 이름 하나라 구별할 수 없다 |
| ``Undeclared variable `out`. To declare a new variable, write `out := ...`.`` (`report`도) | 3 | 말한다 |
| ``Expected `:` or `\|x\|:`. A `for` loop is written `for xs \|x\|:` ... not `for x in xs:`.`` (`for p in {...}:`) | 3 | 말한다 |
| `?else`의 우선순위, `!else` 블록의 끝 | 4 | 말한다 |
| 세미콜론(``Expected end of line or file. Got semicolon.``) | 2 | 안내의 오류 목록에 있다 |
| 목록 리터럴의 괄호, 보간 안의 보간, 홑따옴표 안의 줄바꿈, `elif`, `key: value` 초기화 | 5 | 말한다 |
| `` `type` declarations are not allowed here.`` (블록 안의 선언) | 1 | 무엇이 틀렸는지는 말한다 |
| ``Expected argument `str`, found `int`, when calling `fn ends_with(&str, str) -> bool`.`` | 1 | 타입은 말한다 |
| ``Expected type `str`, got `byte`.`` (문자열 원소와 문자열 비교) | 1 | 무엇이 틀렸는지는 말한다 |
| ``Expected assignment to a variable or placeholder for `[]str`.`` (`blanks.insert(0, x)`) | 1 | 안내의 오류 목록에 있다 |
| 삼항 `c ? a : b` (``Expected `else`.``) | 1 | 말하지 않는다. 안내의 "없는 것"에 있다 |
| `if (a) >= 0 x else y`처럼 조건의 일부만 괄호 (``Expected conditional true expression.``) | 1 | 말하지 않는다 |
| struct 목록의 `rows.sort()` (``Expected `2` arguments, found `1`, when calling the function `fn sort(&[]Row, &OpaqueFunc[fn(Row, Row) -> bool]) -> void`.``) | 1 | 말하지 않는다. 내부 타입 `OpaqueFunc`가 보인다 |

- 가장 흔한 실수는 여전히 `!T`를 풀지 않고 출력하는 것이다. 안내의 원칙 첫머리에 있는데도 작은 모델이 과제마다 되풀이한다. 문구가 정확해서 한 스텝으로 끝나지만 스텝 하나와 그만큼의 입력 토큰이 든다. 이것은 문구가 아니라 능력의 모양(모델이 받는 `!str`)과 안내의 문제다. 본체의 능력 설계와 안내를 다룰 때 다시 본다.
- `for ... in` 문구가 세 번 나왔고 모두 그 과제 안에서 고쳐졌다. 타입 표기 둘, `none` 비교, 옵션 아닌 값의 `?else`, `str`과 `int`의 비교 문구는 나오지 않았다.
- 문구가 고치는 법을 말하지 않는 셋(삼항, 조건의 일부만 괄호, struct 목록의 `sort()`)은 한 건씩이다. 요청서를 내지 않았다. 평가 회차에서 되풀이되면 낸다.
- 컴파일 오류가 아닌 실패 하나가 더 있었다. 0.4.12에서 `_ = out.remove(i)`는 컴파일을 통과하고 VM을 죽였다. 기준 빌드에서는 컴파일 오류다.

### 5.2 모델은 Cyber를 어떻게 쓰는가

CodeAct 회차의 `run` 호출 220개를 셋으로 나눴다. 규칙은 단순한 정규식이다.

- 셸 위임: 비어 있지 않은 줄이 모두 `proc.exec`를 담은 줄이거나 변수 하나의 `print`
- 입출력만: 능력 호출과 `print`뿐
- 로직: 반복, 분기, 함수, type, try, Map, 문자열 메서드, 정렬 중 하나라도 쓴 것

| 모델 | run 호출 | 셸 위임 | 입출력만 | 로직 | 로직 스크립트 평균 줄 |
|---|---|---|---|---|---|
| DeepSeek-V4.1-Flash 사고 없음 | 39 | 13 | 6 | 20 | 18.2 |
| DeepSeek-V4.1-Flash effort high | 40 | 19 | 8 | 13 | 19.6 |
| qwen3.8-flash | 124 | 40 | 18 | 66 | 17.5 |
| qwen3.8-max | 17 | 6 | 0 | 11 | 19.3 |

- 모델은 Cyber를 셸 감싸개로만 쓰지 않는다. 첫 한두 스텝은 `print(proc.exec('ls ...')!)`로 둘러보고, 그다음 한 스크립트에 읽기, 세기, 정렬, 쓰기를 다 담는 흐름이 모든 모델에 공통이다. 셸 위임은 run의 3할에서 5할(32~48%)이다.
- 집계는 struct 목록과 `sort`로 하는 경우가 많다(예제 4의 모양). `type` 선언은 25개, `sort`는 29개 run에 있었다. Map을 `^Map`으로 선언한 것은 1개다.
- 타입을 적은 빈 목록(`[]str{}`)은 49개, 목록 리터럴로 도는 `for {...} |f|:`는 23개, `try:` 블록은 41개, 최상위 `fn` 선언은 17개 run에 있었다.
- `let`으로 선언한 run은 없었다. 안내의 `let` 우회(8절)는 이번 회차에서 쓰이지 않았다.

### 5.3 0.4.15 회차 (2026-11-18)

같은 과제 셋, 같은 제공자와 모델, 같은 회차 수로 0.4.15(`93a9ca4f`)에서 다시 돌렸다. 원자료는 spike/s2/out/0.4.15/(열은 0.4.12와 같다). 0.4.12 회차와 다른 조건은 셋이다: cyber 0.4.15(제자리 `Slice` 메서드, 버린 결과로 VM이 죽던 결함은 컴파일 오류), 지금의 안내(19,823바이트, 시스템 프롬프트 20,913바이트), 로더가 표준 모듈 일곱(json, toon, regex, peg, time, path, test)을 연다(0.4.12 회차는 다섯을 막았다). direct는 cyber와 상관없지만 모델이 바뀌었을 수 있어 대조군으로 함께 돌렸다.

| 모델 | 모드 | 과제 (회차) | 통과 | 스텝 평균 | 컴파일 오류 (과제당) | 오류가 난 과제 | 과제당 시간 | 과제당 입력 토큰 | 과제당 출력 토큰 |
|---|---|---|---|---|---|---|---|---|---|
| DeepSeek-V4.1-Flash 사고 없음 | direct | 3 (1) | 3 | 6.7 (4.7) | | | 8초 | 5.9k (캐시 4.4k) | 600 |
| DeepSeek-V4.1-Flash 사고 없음 | codeact | 9 (3) | 8 (8) | 6.7 (5.1) | 0.78 (0.33) | 3 (3) | 9초 | 49.4k (캐시 47.9k) | 779 |
| DeepSeek-V4.1-Flash effort high | codeact | 9 (3) | 9 (8) | 5.6 (5.1) | 0.00 (0.33) | 0 (1) | 9초 | 42.4k (캐시 40.1k) | 942 |
| qwen3.8-flash | direct | 3 (1) | 3 | 6.3 (7.3) | | | 25초 | 11.9k (캐시 3.4k) | 1,297 |
| qwen3.8-flash | codeact | 15 (5) | 15 (14) | 7.0 (8.3) | 2.20 (2.80) | 12 (14) | 34초 | 114.0k (캐시 53.4k) | 1,746 |
| qwen3.8-max | codeact | 3 (1) | 3 (3) | 4.7 (6.7) | 0.33 (1.00) | 1 (3) | 33초 | 65.3k (캐시 30.2k) | 1,006 |

괄호는 0.4.12 회차의 값이다. 집계는 0.4.12 원자료에 같은 스크립트를 돌려 위 5절의 표와 숫자가 같게 나오는 것을 먼저 확인했다.

읽는 법:

- 42개 중 41개가 통과했다. 실패 하나(DeepSeek 사고 없음 3회차 T2)는 Cyber 때문이 아니다. 스크립트는 돌았고 개수(a.py 2, c.py 3)도 맞았지만 `a.py 2`가 아니라 `project/src/a.py 2`로 썼다. 0.4.12의 T1("file names without the folder")과 같은 부류의 과제 해석 실패다.
- 프로세스가 죽은 실행, 상한에 걸린 실행, panic, 세션 reset은 없었다. 0.4.12에서 s2를 죽인 꼴(`_ = out.remove(...)`)은 나오지 않았다.
- 컴파일 오류는 51건에서 41건으로 줄었다(DeepSeek 사고 없음 7, effort high 0, qwen3.8-flash 33, qwen3.8-max 1). 회차의 흔들림이 크다. DeepSeek 사고 없음은 한 과제(2회차 T1)가 5건을 냈고 나머지 여덟은 0~1건이다. 방향은 qwen 둘에서 줄고 DeepSeek 사고 없음에서 늘었다. 표본으로는 0.4.15 때문이라고 말할 수 없다.
- 제자리 `append`는 그대로 받아들여졌다. run 호출 206개 가운데 29개가 `.append(`를 썼고(0.4.12는 0개, 그때 안내는 `+=`를 가르쳤다), `xs = xs.append(...)`는 0개, 크기 바꾸기 결과를 버린 꼴도 0개다. 제자리 메서드에서 난 오류는 하나, `^[]str`로 선언한 목록에 `rows.append(...)`를 쓴 것이다(아래).
- 새로 연 모듈은 한 번도 쓰이지 않았다(`use` 0개). 안내가 모듈을 한 줄로만 알린다. 쓰이게 하려면 안내에 예제를 넣어야 한다(TODO C1, C2의 남은 게이트).
- 가장 흔한 오류는 여전히 `!str`을 풀지 않고 출력한 것이다(12건, 0.4.12는 20건). `for x in xs:`가 6건(0.4.12는 3건)이다. 둘 다 문구가 고치는 법을 말하고 그 과제 안에서 고쳐졌다.
- 캐시가 덮은 몫은 DeepSeek 97%, qwen 둘 46~47%로 0.4.12와 같은 모양이다.

문구가 고치는 법을 말하지 않은 것 가운데 되풀이된 것과 0.4.15에서 생긴 것으로 요청서를 냈다(docs/requests/cyber-0.4.15-messages-from-codeact-round.md).

| 오류 첫 줄 | 건수 | 무엇이 문제인가 |
|---|---|---|
| ``Expected `Result` or `error` return type for enclosing function.`` (`!T`가 아닌 함수 안의 `fs.read(p)!`) | 2 (두 모델) | `Result`는 가이드에 없는 이름이고, `-> !T`로 선언하라는 고치는 꼴이 없다. 안내 151행에 규칙이 있다 |
| ``Expected ident.`` (`line[idx.!]`) | 2 (qwen3.8-flash, 두 회차) | `idx!`는 `.?`를 알려 주지만 `.!`는 파서에서 멈춘다 |
| ``Expected type `&>[]str`. Found `^[]str`.`` (`rows := ^[]str{}` 뒤 `rows.append(...)`) | 1 | 0.4.15의 제자리 메서드와 함께 생긴 빈틈이다. `&>`는 가이드에 없는 표기이고, 같은 자리의 `+=`는 `rows.* += ...`를 알려 주는데 메서드는 알려 주지 않는다. 고치는 꼴은 `rows.*.append(...)` |

한 건씩이라 요청서에 넣지 않은 것: Python 슬라이스 `s[:500]`(``Expected element expression.``), 최상위의 `return`(``Return statement is not allowed in the main block.``).

## 6. 스파이크 3: 교차 빌드

- `zig build -Dtarget=x86_64-linux-gnu`가 macOS arm64에서 s1, s2 모두 된다(패키지를 받은 뒤 s1 23초, s2 23초). cyber는 의존의 아티팩트로 같은 대상에 맞춰 빌드된다(libcyber.a 3.62 MB, 3,620,340바이트). 산출물은 glibc 동적 링크 ELF다.
- tars 게스트(QEMU)에서의 실행은 이 빌드로 하지 않았다. tars-linux의 산출물(커널, initrd)이 필요하다. 게스트를 모는 스크립트는 spike/s3/guest.py에 있다: initrd 사본 뒤에 바이너리를 담은 gzip cpio를 이어 붙여 부팅하고, 시리얼을 유닉스 소켓으로 열어 명령을 보낸다(셸이 fish라 Enter는 CR).

보지 못한 것: tars 게스트에서의 실행, 실기 노트북, tars 터미널 패널 안에서의 화면 출력, Landlock(M5).

## 7. cyber에 남은 것

스파이크는 cyber 릴리스 `0.4.15`를 받는다(ADR 0023). M0에서 낸 요청은 모두 닫혔다. 이 빌드의 패키지에는 cyber의 에이전트 안내 `docs/agent-guide.md`(`cyber doc --for-agents`와 같은 문서, ADR 0022)와 모듈 API `docs/api.json`(`cyber doc --api <module>`과 같은 소스)이 들어 있다.

모델이 모르는 내부 이름(`@index`, `@slice`, `@set_index`, `@index_addr`)은 인덱스, 슬라이스 경계, 대입 값 어디서든 인자 불일치 문구에 나오지 않는다. 대입 값이 원소 타입과 다르면 ``An element of `[]int` must be `int`, got `str`.``처럼 원소 타입을 말하고, `?T`와 `!T`이면 푸는 법을 붙인다(`Map`도 같다). 정수 원소 자리의 한 글자 리터럴(`xs[0] = 'a'`)은 오류가 아니라 코드 포인트(97)다. 타입이 정해진 자리의 한 글자 리터럴은 코드 포인트라는 언어 규칙이다.

c가 실리기 전에 `#[extern]` 함수를 쓴 스크립트는 선언 위치의 컴파일 오류다(``An `#[extern]` function needs the `c` module. Add `use c`.``). 0.4.13 릴리스에서는 검증 중에 프로세스를 죽였다.

다른 언어의 선언 키워드는 키워드만 뺀 꼴을 말한다. `let x := 1`(`mut`, `let mut`도)은 ``Cyber has no `let`. Declare with `x := 1`.``이고, `let x = 1`은 ``... Declare with `x := 1`, or `var x int = 1` for a type.``이다. CLI와 세션이 같다.

`Slice`의 크기를 바꾸는 메서드는 0.4.15부터 제자리다(깨지는 변경). `append`, `insert`, `remove`, `clear`, `size_down`, `size_up`은 받는 변수를 바꾸고 아무것도 돌려주지 않는다. 새 목록은 `appended`, `inserted`, `removed`, `+`이고, `xs += v`는 제자리에서 붙인다. `pop() -> ?T`가 생겼다. 옛 꼴은 고칠 꼴을 말하는 컴파일 오류다. `xs = xs.append(3)`은 ``Write `xs.append(3)` as a statement.``, `ys := xs.append(3)`은 `xs.appended(3)`도 알려 준다. 새 목록 메서드의 결과를 버리면(`xs.appended(3)`만 쓴 문장) CLI에서는 제자리 메서드를 알려 주는 오류이고, 세션의 마지막 줄에서는 오류가 아니라 eval 결과다. 세션의 마지막 줄 `xs.append(4)`는 결과 없는 문장이다(0.4.13, 0.4.14에서는 오류). 함수 안에서 전역 목록에 제자리 메서드를 쓸 수 있고(take-and-restore), 인자가 같은 전역을 읽으면(`g.append(g.len())`) ``The method takes `g` out while it runs, so an argument can not read `g`. Read it into a local first.``다. 모두 CLI와 `replay`에서 확인했다(2026-11-18). Python의 `xs.append(v)` 습관이 그대로 맞는 꼴이 됐다. 모델의 오류율에 주는 영향은 비교를 다시 돌려야 안다(5절은 0.4.12 회차).

`os` 파일 함수의 옛 꼴이 새 이름을 말한다(0.4.12 요청의 남은 회신). `os.read_file_str(p)`는 ``Use `os.read_file`. It returns `str`.``, `os.write_file_bytes(p, 'abc')`는 ``Write text with `os.write_file`.``, `os.read_file(p)!`을 담은 지역을 `[]byte` 자리에 쓰면 ``Read bytes with `os.read_file_bytes`.``다. CLI에서 확인했다. 스파이크의 세션은 `os`를 싣지 않으므로(ADR 0026) 모델에게는 ``Failed to load module: os``가 간다. 이 문구들은 tars-agent에서는 CLI로 cyber를 쓰는 사람에게만 닿는다.

언어 서버: 0.4.15의 `cyber-lsp`(설치 경로 `/usr/local/bin/cyber-lsp`)를 stdio로 붙여 확인했다(2026-11-18). 쓰지 않는 지역과 `use`는 Warning(태그 Unnecessary)이고 quick fix가 `_` 붙이기와 `use` 줄 지우기다. `scope` 블록 안의 `return`은 Information(``waits for the fibers of the `scope` block``)과 inlay hint `waits for fibers`다. 컴파일 오류의 고칠 이름(`os.fileExists` → `file_exists`, `out = out.append(3)` → `out.append(3)`)은 quick fix가 된다. hover가 선언 위의 `--|` 문서 주석을 보여 준다. 구문 오류는 전부 진단하고, 구문 오류가 없으면 본문(main 블록, 함수)마다 첫 오류를 낸다(오류 복구를 켠 검사. CLI는 첫 오류에서 멈춘다). tars-agent에는 두 갈래로 닿는다. 사람이 .cy 파일을 고칠 때의 편집기 도구이고, 같은 정보를 호스트가 C API로 받는다(3.5, 검사 7i). 모델에게 경고를 넘길지는 9절 18.

표준 모듈: 기준 빌드에 json, toon, regex, peg, time이 있다(TODO의 C1, C2). 세션의 기본 로더가 다섯을 싣는다. 다섯 모두 s1과 s2의 호스트 로더가 싣는다(3.6, ADR 0024, 0025). tars-agent 쪽에 남은 것은 안내에 예제를 넣을지다(크기는 8절의 결정과 함께).

## 8. 안내 문서 (prompt/cyber-subset*.md)

영문판과 한국어판을 기준 빌드로 맞췄다. 두 판은 같은 구조이고 코드 블록 11개(정렬 절의 조각 하나, 예제 10개)가 같다. 기준 버전 줄은 `Cyber 0.4.15`다. 안내의 문구와 코드 블록은 기준 빌드의 CLI(설치된 `/usr/local/bin/cyber`, `Cyber 0.4.15 build-969-93a9ca4`)와 세션(`s1 replay`)으로 확인한다.

확인 방법: 안내의 항목마다 탐침 스크립트를 만들어 기준 빌드의 CLI와 `replay`(같은 VM, persist_main, 검증 뒤 실행)로 돌리고 결과(출력이나 오류 첫 줄)를 맞춰 봤다. 오류 목록의 첫 줄, "없는 것" 목록, "있는 메서드" 목록, `int('abc')`, 정수 나눗셈, 음수 인덱스가 기준 빌드에서 그대로다. 세션에서만 다른 것은 최상위 빌림과 모듈이다. CLI는 `os`를 싣고, 스파이크의 세션은 싣지 않는다(ADR 0026). `test`는 양쪽에서 실린다(ADR 0028). 안내는 세션 쪽을 적는다. 코드 블록 11개는 CLI와 `replay` 양쪽에서 통과했다. cyber의 agent-guide.md(`cyber doc --for-agents`)의 코드 블록 12개도 CLI에서 모두 통과하고, 세션에서도 모두 통과한다(2026-11-18, 0.4.15, `test`를 연 뒤. ADR 0028).

| 무엇 | 안내가 가르치는 것 |
|---|---|
| 목록 리터럴 | `{1, 2, 3}`은 첫 원소 타입의 `[]int`. 원소의 타입이 다르면 오류이고 `[]T{...}`로 쓴다. 빈 목록은 `[]int{}` |
| Map 리터럴 | `Map[str, int]{a=1}`, 식 키는 `{(k)=1}` |
| 정렬 | `xs.sort()`는 오름차순(숫자, 문자열). 다른 순서는 함수. Map 값으로 정렬하려면 Map을 `^`로 선언해 람다가 캡처한다. 최상위 빌림은 세션에서 안 된다 |
| 문자열 비교 | `<`, `<=`, `>`, `>=`가 바이트 순 |
| `not` | Python과 같은 우선순위 |
| 슬라이스 | `s[1..3]`은 끝 제외, `s[1..=3]`은 끝 포함 |
| `!T` | 출력, 메서드 호출 전에 `!`로 푼다. 어기면 고치는 법이 붙은 컴파일 오류 |
| `?int` | `if s.index(x) \|i\|:`, `idx == none`, `?else`. `not idx`, `idx >= 0`, `idx!`는 오류 |
| 참조의 연산자 | `n.* += 2`, `out.* += 'x'` |
| 문자열 이스케이프 | `\n \t \r \0 \\ \' \" \xHH`. 그 밖은 컴파일 오류이고 백슬래시는 두 번 쓴다 |
| 함수 선언 | 최상위에서만 |
| `[]T`의 크기 바꾸기 | `append`, `insert`, `remove`, `clear`, `pop`은 제자리, 새 목록은 `appended`, `inserted`, `removed`, `+`. 전역 목록에도 제자리 메서드 (0.4.15) |
| 메서드 | str, []T, Map의 있는 메서드 전부(`trim()`, `trim_left()`, `trim_right()`, `last_index` 포함)와 Python 이름의 대응 |
| 없는 것 | `abs`, `sum`, `sorted`, `enumerate`, `zip`, `xs.map`, `xs.filter`. 모듈은 json, toon, regex, peg, time을 싣는다고 한 줄로 알린다 |
| 오류 목록 | 문구가 고치는 법을 말하지 않거나 틀린 고치는 법을 말하는 오류만 (20줄). 나머지는 "문구대로 고친다" 한 줄 |

크기: 영문판 19.8KB(19,823바이트, 0.4.15의 제자리 `Slice` 줄을 넣은 판)이고 시스템 프롬프트 전체는 20,913바이트다(호스트 덧붙임 1,090바이트는 그대로). 5절 회차는 0.4.12 판(19,807바이트, 시스템 프롬프트 20,897바이트)으로 돌았고 첫 요청 입력이 약 6,500토큰이었다. TODO의 "4,000토큰 이하" 목표를 넘는다. 목표를 바꿀지 안내를 줄일지는 사용자가 정한다. 줄일 자리는 오류 목록(cyber가 문구를 보강할 때마다 줄이 빠진다)과 "Python과 다른 것"의 문법 줄이다. json 같은 새 모듈을 가르치면 더 커진다.

## 9. 본체 아키텍처에 주는 뜻 (추천, 확정은 본체를 만들 때 사용자가)

| 번호 | 추천 | 근거 |
|---|---|---|
| 1 | 구성요소와 경계(명세 01)는 그대로 간다 | 스파이크 2의 세 파일(provider, vm, main)이 명세의 provider, runtime+caps, loop와 같은 선으로 자연히 갈렸다 |
| 2 | 능력은 모두 `Future[!T]`를 돌려주고 머리말 래퍼가 await한다. 승인이 필요 없으면 호스트 함수 안에서 바로 완료한다 | 3.2, 3.3. 능력의 모양이 하나가 되고, 등급이 바뀌어도 선언이 바뀌지 않는다 |
| 3 | 검증은 세션 VM에서 `cl_vm_validate`로 바로 한다. 머리말을 eval한 뒤에 검증한다 | 3.5. 검증은 마지막 eval의 설정을 쓴다(cyber.h에 적혀 있다) |
| 4 | CL_SUCCESS가 아닌 eval과 검증 뒤 `cl_vm_reset_pending`을 묻고, reset이면 머리말을 다시 돌려 모델에게 알린다. panic과 interrupt 뒤에는 최상위 변수가 사라졌다고 알린다 | 3.4, 3.5. s2가 그렇게 돈다 |
| 5 | 호스트 로더는 허용 목록으로 쓴다 | 3.6. 기본 로더는 cyber가 표준 모듈을 더할 때마다 넓어진다. 차단 목록이면 정하지 않은 모듈이 그대로 열린다. 표준 모듈 일곱(json, toon, regex, peg, time, path, test)과 의존 모듈 meta, c를 넣는다(ADR 0024, 0025, 0026, 0027, 0028) |
| 6 | deny_raw_ptrs와 deny_spawn을 켠다 | 3.6 |
| 7 | 프로세스 실행 능력은 자체 시간 상한, 표준 입력 차단, 출력 크기 상한, 취소를 가진다 | VM의 타이머는 승인 뒤 루프가 돌리는 프로세스에 닿지 않는다 |
| 8 | 읽기 능력도 권한 프로파일의 대상으로 둔다 (작업 폴더 밖 읽기는 승인) | 읽은 것은 모두 모델 제공자에게 간다 |
| 9 | cyber.h는 손으로 쓴 extern 선언으로 감싼다 (runtime/cy.zig 한 파일) | 3.1. 빌드 의존이 줄고, 쓰는 표면이 한눈에 보인다. 대가는 cyber가 구조체 배치를 바꾸면 손으로 따라가야 하는 것이다 |
| 10 | 메시지 모델은 스파이크의 모양(블록 넷, thinking에 불투명 칸)에서 시작한다 | 4.2 |
| 11 | 끝난 이유와 사용량은 어댑터가 정규화한다. 사용량은 "전체 입력, 그중 캐시, 출력" 셋으로 맞춘다 | 4.1 |
| 12 | SSE는 줄 버퍼에 기대지 않는 조각 단위 해석기로 쓴다 | 4.3 |
| 13 | 검증에 `cl_vm_set_error_recovery`를 켜고 `cl_vm_compile_report`의 오류를 모두 모델에게 돌려주는 것을 평가로 시험한다 | 모델은 한 스텝에 오류 하나씩 고친다(5절). 0.4.15에서 세션 검증이 구문 오류를 모두, 본문마다 하나씩 돌려주는 것은 확인했다(3.5, 검사 6n). 모델의 스텝 수에 주는 효과는 회차를 돌려야 안다 |
| 14 | 안내 문서의 예제와 조언은 에이전트와 같은 조건(세션 VM, persist_main, 검증 뒤 실행)에서 확인한다. 안내 검사 도구를 둔다면 runtime 경계 위에서 돈다 | 3.5, 8 |
| 15 | 안내는 회차에서 모델이 틀린 곳으로 고친다. 문구가 고치는 법을 말하는 오류는 안내에 넣지 않는다 | 5.1. 안내의 크기를 지키는 기준이 된다 |
| 16 | 평가의 모델 목록에 크기가 다른 모델을 함께 넣는다 (DeepSeek-V4.1-Flash, qwen flash, qwen max). direct 모드는 대조군이면서 작은 모델용 기본값 후보로 본다 | 5 |
| 17 | 스크립트가 VM을 죽여 호스트 프로세스가 끝나는 경우를 전제로 둔다. 세션 기록은 실행 전에 쓰고, 재개 때 끝나지 않은 실행을 crashed 결과로 짝 맞춘다(ADR 0021). 실행을 별도 프로세스로 떼어 놓을지는 runtime 단계에서 사용자가 정한다 | 5, 7. 0.4.12 회차에서 모델의 스크립트 하나가 s2를 세그폴트로 끝냈고 대화가 사라졌다 |
| 18 | 검증 뒤 `cl_vm_symbol_hints`의 쓰지 않는 함수 안 지역을 모델에게 넘기는 것을 시험한다(최상위 지역은 거른다). 넘길지는 평가로 정한다 | 3.5, 7. 쓰지 않는 지역은 오타나 빠뜨린 출력의 신호일 수 있지만, 경고가 스텝과 토큰을 더 쓰게 할 수도 있다 |

## 10. 아직 모르는 것

- CodeAct 판정. 과제 셋으로는 말할 수 없다. 평가 도구(eval/)가 필요하다.
- tars 게스트에서의 기준 빌드.
- json 모듈은 기준 빌드에 있지만 안내가 가르치지 않아 막고 돌렸다. JSON을 다루는 과제는 넣지 않았다. 모델이 json, regex를 안내에서 배워 쓸 때의 오류율은 모른다.
- 긴 세션(수십 스텝)에서의 VM 메모리와 히스토리 크기, 컴팩션.
- 대화형 프런트엔드. 스파이크는 한 번 묻고 끝나는 헤드리스였고 승인은 자동이었다.
- 인터럽트(Esc)로 스트림과 실행을 끊는 것.
- Claude 모델. 키가 없어 돌리지 않았다.

## 11. 스파이크 코드 지도와 다시 돌리는 법

| 경로 | 내용 | 실행 |
|---|---|---|
| spike/s1 | 호스트 경계 검사 47개, 세션 재생, 관찰 하나 | `zig build && ./zig-out/bin/s1`, `s1 replay <파일> [nv]` (스크립트를 `=====` 줄로 나눈다, 검증과 실행 결과, 출력, 오류 첫 줄을 찍는다. `nv`면 검증 없이 실행), `s1 spawn` (deny_spawn 없이) |
| spike/s2a | 두 형식의 원문 응답 받기 | `./run.sh`, 결과는 out/*.sse |
| spike/s2 | 최소 에이전트 루프 (direct, codeact), 제공자 넷 | `./zig-out/bin/s2 --provider ds-anth --mode codeact "질문"`, `./compare.sh <제공자> [모델] [모드] [과제]` |
| spike/s3 | tars 게스트 구동 스크립트 | 6절 |

- 두 스파이크의 cyber 의존은 가장 새 빌드의 태그를 따르는 패키지다(build.zig.zon, ADR 0023). 로컬 cyber 저장소의 상태와 상관없다. 새 빌드를 받을 때는 두 스파이크에서 `zig fetch --save=cyber "git+https://github.com/soomtong/cyber#<태그>"`를 돌린다. 문구를 CLI로 볼 때는 받은 빌드와 같은 CLI를 쓴다(릴리스면 설치된 `/usr/local/bin/cyber`). 아직 태그에 없는 cyber 수정은 `zig build --fork=<cyber 저장소>`로 본다.
- 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다. 이 가두기를 풀지 않는다.
- compare.sh는 결과를 out/cmp-*에 덮어쓴다. 회차를 여럿 돌리면 회차마다 기준 빌드 이름의 폴더로 옮긴다(out/0.4.12/<회차>/). 회차는 차례로 돌린다(같은 작업 폴더 /tmp/tars-agent-s2를 쓰므로 겹치면 결과가 섞인다). s2는 실행마다 안내 파일을 읽으므로 회차 도중에 안내를 고치지 않는다.
- cyber의 기준 빌드를 올리면: `zig fetch --save=cyber`로 의존을 다시 받고(릴리스와 프리릴리스에 따라 build.zig의 `dev` 인자), s1, 안내의 탐침, 코드 블록 11개를 CLI와 `replay`로 다시 돌리고, 기본 로더가 새로 주는 모듈이 있는지 보고(있으면 s1과 s2의 로더에서 막거나 안내에 넣는다), s2 비교를 다시 돌리고, 문서를 새 빌드의 사실로 고쳐 쓴다.

읽을 가치가 있는 순서: s2/src/main.zig(루프), s2/src/provider.zig(메시지 모델과 어댑터), s2/src/vm.zig(검증, 실행, 승인), s1/src/main.zig(검사 목록).
