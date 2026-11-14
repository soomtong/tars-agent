# M0 스파이크 검토 결과 (2026-11-14)

스파이크를 Claude가 혼자 구현하고 검토했다 (ADR 0012의 덧붙임). 이 문서는 무엇을 만들었고, 기준 빌드에서 무엇이 확인됐고, 무엇이 남았고, 본체의 아키텍처에 어떤 뜻이 있는지를 적는다. 코드는 spike/에 있고 버릴 것이다.

기준 빌드: soomtong/cyber 0.4.11 (태그 0.4.11 = 커밋 097b831f, `Cyber 0.4.11 build-883-097b831`). 스파이크는 이 태그를 URL과 해시로 고정한 의존으로 받는다. 숫자와 판정은 모두 이 빌드로 이 날(2026-11-14) 돌려서 얻은 것이다. 측정 환경은 macOS arm64.

읽는 순서: 1절(한 장 요약), 2절(에이전트는 어떻게 도는가), 그 뒤는 필요한 절만.

## 1. 한 장 요약

| 질문 | 답 | 근거 |
|---|---|---|
| Zig 호스트가 libcyber를 링크해 VM을 돌릴 수 있는가 | 된다 | 스파이크 1, 검사 40개 모두 통과 |
| cyber를 build.zig.zon 의존으로 쓸 수 있는가 | 된다. URL과 해시로 고정한 의존의 `artifact("cyber")`로 받고 cyber.h가 따라온다 | 3.1 |
| 능력이 `Future[!str]`을 돌려줄 수 있는가 (ADR 0011의 모양) | 된다. str 값이나 오류로 완료한다 | 3.2 |
| 승인 대기를 VM 밖에서 하는 설계(ADR 0011, 0016)가 실제로 도는가 | 돈다. 승인, 거부, 취소, 동시 요청 모두 | 3.3 |
| 상한 넷(연료, 벽시계, 스택, 메모리)이 폭주를 멈추는가 | 멈춘다. VM은 계속 쓸 수 있다 | 3.4 |
| 검증을 세션 VM에서 바로 할 수 있는가 | 된다. 컴파일 실패 뒤에도 세션이 그대로다. 세션이 reset되는 경우는 `cl_vm_reset_pending`으로 안다 | 3.5 |
| Zig std.http로 모델 API에 스트리밍 요청을 보낼 수 있는가 | 된다. TLS와 CA 묶음 포함 | 4.3 |
| 전송 형식 둘을 메시지 모델 하나로 받을 수 있는가 (ADR 0015) | 된다. 블록 넷과 불투명 칸 하나로 충분했다 | 4.2 |
| CodeAct가 실제 과제를 푸는가 | 푼다. 모델 셋이 과제 36개 중 35개를 끝냈다(DeepSeek은 두 모드, direct는 6개 모두). 하나는 모델의 판정 논리 실수다. 컴파일 오류는 작은 모델에 과제당 1.7번, 모두 그 과제 안에서 고쳐졌다 | 5 |
| x86_64-linux-gnu 교차 빌드가 되는가 | 된다. tars 게스트에서의 실행은 이 빌드로 확인하지 않았다 | 6 |

가장 무거운 발견 셋:

1. cyber에 남은 요청은 없다. 스파이크는 릴리스 0.4.11을 URL과 해시로 고정해 받는다. 본체 첫 단계의 선행 조건(ADR 0019)은 닫혔다 (7).
2. 안내 문서와 컴파일러 문구가 CodeAct의 성패를 가른다. 컴파일 오류 34건은 모두 다음 스텝 안팎에서 고쳐졌다. 가장 흔한 것은 여전히 `!str`을 풀지 않고 출력한 것(13건)이고 문구가 고치는 법을 말한다. 문구가 고치는 법을 말하지 않은 여섯은 cyber에 요청했다(선행 조건 아님) (5, 7).
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

실제 CodeAct 스텝 하나의 기록 (DeepSeek-V4.1-Flash 사고 없음, 2회차 T1의 스텝 3):

~~~text
[도구 호출] run {"code": "type Row:\n    name str\n    n int\n\nrows := []Row{}\nfor {'app.log', 'db.log', 'web.log'} |f|:\n    text := fs.read('logs/' + f)!\n ... rows.sort(|a, b| a.n > b.n or (a.n == b.n and a.name < b.name)) ... fs.write('report.txt', out)!\n ..."}
    [승인] write report.txt
    [실행] 종류=ok 능력 호출 5회
[도구 결과] web.log: 23
db.log: 8
app.log: 7

total=38
...
~~~

스크립트 하나가 파일 셋을 읽고, 세고, struct 목록으로 정렬하고, 쓰고, 다시 읽어 보였다. 능력 호출은 다섯 번이었고 모델 왕복은 한 번이었다. 정렬 모양은 안내의 예제 4 그대로다. 앞의 두 스텝은 `print(proc.exec('ls -la logs/ ...')!)`로 둘러본 것이다.

## 3. 스파이크 1: 호스트 경계

코드: spike/s1. 실행: `zig build && ./zig-out/bin/s1`. 검사 40개가 PASS/FAIL로 찍히고 모두 통과한다.

### 3.1 링크

- build.zig.zon의 의존은 `.url = "git+https://github.com/soomtong/cyber?ref=0.4.11#097b831f049c030683c52f5cec8e1b5cec1da276"`, `.hash = "cyber-0.4.11-AW3fkEXwjQClbWIfwyRDrnTCj0k7VNbfWrg4S4Bzkzea"`다. 해시는 `zig fetch <url>`이 찍는 값이다. `zig fetch --save=cyber`는 기존 `.path` 의존을 덮을 때 `.path`에 URL을 넣고 해시를 빼므로 zon을 손으로 고쳤다.
- `b.dependency("cyber", .{ .target = target, .optimize = .ReleaseFast, .static = true, .dev = false, .build = "883", .commit = "097b831" }).artifact("cyber")`를 `linkLibrary`로 링크한다(spike/s1/build.zig). ffi는 기본 false다.
- cyber.h는 아티팩트의 include 경로로 따라온다. s1의 C 파일(src/inc_check.c)이 `#include "cyber.h"`로 컴파일되고, `CLEvalConfig`와 `CLCompileConfig`의 크기(12)가 translate-c 쪽과 같다(검사 0).
- 버전 문자열은 `Cyber 0.4.11 build-883-097b831`이고 설치된 릴리스 CLI(`cyber version`)와 같다(검사 0이 문자열 전체를 비교한다). 버전 번호는 cyber의 build.zig.zon에서 오지만 `-DEV` 표시(`dev`, 기본 true), 빌드 번호(`build`), 커밋(`commit`)은 의존에 넘긴 인자가 찍힌다. 의존의 URL을 올릴 때 이 인자들도 함께 올린다.
- Zig 0.17.1에는 `@cImport`가 없다. cyber.h를 Zig에서 쓰는 길은 둘이다: translate-c 패키지로 모듈을 만들거나, 쓰는 함수의 extern 선언을 손으로 쓴다. 스파이크는 앞의 것을 썼다. 본체의 추천은 9절.
- libcyber.a(arm64, ReleaseFast)는 2.55 MB, 공개 `cl_` 함수는 135개다. mimalloc 심볼은 없다(FFI를 끈 라이브러리 빌드에는 들어가지 않는다).

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
| 메모리 +8 MiB | 끝없는 추가 | PANIC (OutOfMemory). VM 메모리 2689 KiB에서 2769 KiB로 돌아왔다 |

상한에 걸린 뒤: 함수 선언과 use는 남고 최상위 변수는 사라진다(함수 호출은 되고 변수는 Undeclared). panic도 같다(검사 6k). 앞선 eval에서 만든 변수도 사라진다. 둘 다 reset이 아니라 `cl_vm_reset_pending`은 false다. s2는 결과에 "top-level variables were reset (functions and imports are kept)"를 붙인다.

### 3.5 세션과 검증

- persist_main: 변수, 함수, use가 다음 eval로 이어진다.
- validate: 세션의 변수를 보면서 컴파일만 한다. 구조화된 오류가 온다(kind=2, line=1, col=6, len=4, "Undeclared variable `totl`."). validate한 선언은 넘어가지 않는다.
- validate에는 설정 인자가 없고 마지막 eval의 설정(persist_main, deny_raw_ptrs, deny_spawn)을 쓴다. eval 전의 새 VM에서는 spawn이 든 스크립트가 검증을 통과한다(검사 7f). 그래서 머리말을 eval한 뒤에 검증한다. cyber.h의 `cl_vm_validate` 설명에 이 동작이 적혀 있다.
- 실패한 컴파일 뒤: 같은 VM의 다음 검증과 실행이 그대로 된다(6f: 캡처 오류로 실패한 정렬 스크립트 뒤 Map 스크립트가 검증과 실행을 통과). 모듈 소스가 컴파일에 실패하면 다음 use에서 로더를 다시 불러 맞는 소스를 받는다(6g). 그래서 검증은 세션 VM에서 `cl_vm_validate` 한 줄로 한다. 문자열 이스케이프 오류(`\|`, `\xZZ`)도 위치 있는 보통 컴파일 오류이고 세션이 남는다(6i). `'\0'`은 NUL이다(6j).
- reset: VM의 첫 컴파일이 실패하면 `cl_vm_reset_pending`이 true이고 다음 eval부터 세션이 이어진다(6l). 컴파일러나 지역 이월 중의 할당 실패 뒤도 같다(cyber.h). 호스트는 CL_SUCCESS가 아닌 eval과 검증 뒤에 이것을 묻는다. s2는 true면 머리말을 다시 돌리고 모델에게 "the session was reset"을 알린다.
- 목록 참조의 `+=`(`out := ^[]str{}` 뒤 `out += 'x'`)는 검증이 잡는 컴파일 오류이고, 문구가 `out.* += ...`를 알려 준다(6h).
- 최상위 빌림(`c := &x`)은 다음 eval로 넘길 수 없어 ``Cannot persist local `c` of borrow type `&int` across evals.``다. CLI에서는 나지 않는 오류라 안내의 조언은 세션에서 확인해야 한다(8절).
- 비용: validate 200회 1~2ms, eval 200회 2ms. VM 생성과 첫 eval은 개당 2~3ms, VM 하나가 쥔 메모리 약 2.6 MiB(2700 KiB).

### 3.6 샌드박스 경계

| 시도 | 결과 |
|---|---|
| `use c` | 호스트 로더가 false를 돌려준다. CompileError: Failed to load module: c |
| `use os` | 라이브러리에 없다. 같은 오류 |
| `Ptr[int](0)` | CompileError: Raw pointer type `Ptr[int]` is not allowed (deny_raw_ptrs) |
| deny_raw_ptrs와 호스트 모듈 | 함께 동작한다. 호스트 모듈의 선언은 막히지 않는다 |
| `@bitCast` | CompileError: internal to the builtin modules |
| `use io` | 기본 로더가 준다. 본체에서 허용 목록으로 뒤집어야 한다 |
| `spawn(work, {21})` | deny_spawn이면 eval과 검증에서 CompileError: `spawn` is not allowed. The host disabled threads for this script (`deny_spawn`). ... |

spawn에 대해: deny_spawn을 켜지 않으면(`s1 spawn`) 스레드 안에서 능력 함수(`fs.read`)가 그대로 불리고, 연료 상한은 스레드 안의 무한 루프를 502~508ms에 멈춘다(타이머 500ms). deny_spawn을 켜면 표준 모듈이 아닌 chunk의 spawn이 컴파일 오류이고 호스트 함수는 eval 스레드에서만 불린다. s1과 s2는 deny_spawn을 켠 채 돌았고, scope 블록의 동시 승인(3.3)은 그 아래에서 통과했다.

로더는 지금 "c와 test만 거부"하는 차단 목록이다. 기본 로더에 모듈이 더해지면 그대로 스크립트에 열린다. 본체는 허용 목록(core, math, 그리고 우리 모듈)으로 가야 한다.

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

과제 셋. 평가가 아니라 감을 잡기 위한 것이다. 판정(ADR 0006)은 과제 20개를 3회씩 돌린 뒤에 한다. 모든 회차를 기준 빌드(0.4.11)와 8절의 안내로 2026-11-14에 돌렸다. 원자료는 spike/s2/out/0.4.11/(회차별 폴더와 .tsv. 열: 과제, 판정, 제공자, 모델, 모드, 스텝, 도구 호출, 도구 오류, 입력 토큰, 캐시된 입력, 출력 토큰, 밀리초, 컴파일 오류). s2는 본래 모양(능력은 `Future[!str]`, 검증은 세션 VM의 `cl_vm_validate`, deny_spawn, 실패 뒤 `cl_vm_reset_pending` 확인)으로 돌았다. 모델이 쓴 명령은 샌드박스(spike/s2/src/jail.zig) 안에서만 돌았다.

- T1: 로그 파일 셋에서 ERROR 줄을 세어 정렬해 보고서 파일로 쓰기
- T2: .py 파일들에서 대문자 TODO를 찾아 파일별 개수를 쓰기
- T3: 설정 파일의 한 구획에서만 값을 바꾸고 줄을 더하기

| 모델 | 모드 | 과제 (회차) | 통과 | 스텝 평균 | 컴파일 오류 (과제당) | 오류가 난 과제 | 과제당 시간 | 과제당 입력 토큰 | 과제당 출력 토큰 |
|---|---|---|---|---|---|---|---|---|---|
| DeepSeek-V4.1-Flash 사고 없음 | direct | 3 (1) | 3 | 4.3 | | | 5초 | 2.8k (캐시 2.0k) | 302 |
| DeepSeek-V4.1-Flash 사고 없음 | codeact | 9 (3) | 8 | 6.0 | 0.78 | 5 | 9초 | 44.1k (캐시 41.8k) | 892 |
| DeepSeek-V4.1-Flash effort high | codeact | 9 (3) | 9 | 5.1 | 0.22 | 2 | 9초 | 37.0k (캐시 35.2k) | 846 |
| qwen3.8-flash | direct | 3 (1) | 3 | 5.3 | | | 24초 | 14.2k (캐시 5.5k) | 1,603 |
| qwen3.8-flash | codeact | 15 (5) | 15 | 7.7 | 1.67 | 15 | 34초 | 119.9k (캐시 58.0k) | 1,780 |
| qwen3.8-max | codeact | 3 (1) | 3 | 5.3 | 0.00 | 0 | 47초 | 78.3k (캐시 36.4k) | 1,654 |

입력 토큰은 캐시된 몫을 포함한 전체다(DeepSeek의 Anthropic 형식은 둘을 따로 주므로 더했다). DeepSeek은 두 모드로 돌렸다. "사고 없음"은 옛 별칭 `deepseek-chat`으로 요청한 것이다(응답도 별칭을 돌려주므로 원자료의 모델 칸은 `deepseek-chat`). "effort high"는 모델 ID `deepseek-flash`로 요청한 것이고 이것이 모델의 기본값이다(4.1). s2는 `deepseek-flash`로 요청한다. 출력 토큰은 사고를 포함한다(기록에 사고의 몫이 따로 없다). 과제당 컴파일 오류의 회차별 값은 DeepSeek 사고 없음 0.67~1.0, effort high 0~0.33, qwen3.8-flash 1.0~2.67이다.

읽는 법:

- CodeAct 실패 하나(DeepSeek 사고 없음 3회차 T2)는 Cyber 때문이 아니다. 스크립트는 컴파일되고 돌았다. 모델이 TODO 앞이 `#`로 시작할 때만 세어 `pass  # TODO handle errors`처럼 코드 뒤의 주석을 놓쳤고, `a.py 1`(정답 2)을 썼다.
- DeepSeek-V4.1-Flash는 사고를 켠 쪽(기본 effort high)이 컴파일 오류가 적고 스텝이 짧다(0.78 → 0.22, 6.0 → 5.1). 시간은 같고 출력 토큰도 비슷하다. 표본이 작아 방향만 본다.
- qwen3.8-flash는 15개 과제 모두에서 컴파일 오류를 한 번 이상 냈다. 오류의 절반(25건 중 12)이 `!str`을 풀지 않고 출력한 것이다(5.1).
- T1의 "file names without the folder"는 확장자를 뗀 이름(`web`)으로 읽힐 수 있다. 채점은 `web.log`를 기대하므로, 평가 과제(eval/)를 만들 때 이런 문장은 뜻이 하나가 되게 쓴다.
- CodeAct의 대가는 시스템 프롬프트다. direct는 331바이트, CodeAct는 Cyber 안내를 포함해 20,867바이트이고 첫 요청 입력이 6,500토큰 안팎이다. 매 스텝 다시 보내므로 캐시가 없으면 스텝마다 그만큼이 든다. 자동 캐시가 덮은 몫은 DeepSeek이 9할 남짓(95%), OpenRouter의 qwen이 절반 안팎(46~48%)이었다. 캐시가 덮는 몫은 제공자와 회차에 따라 크게 다르다.
- 상한(연료, 벽시계)이 걸린 실행, panic, 세션 reset은 없었다.
- 표본이 작다. 과제 셋, 회차 다섯까지다. 방향을 보는 숫자이지 판정이 아니다.

### 5.1 모델이 틀린 곳

컴파일 오류 34건(DeepSeek-V4.1-Flash 사고 없음 7, effort high 2, qwen3.8-flash 25, qwen3.8-max 0):

| 오류 첫 줄 | 건수 | 문구가 고치는 법을 말하는가 |
|---|---|---|
| ``Can not print `!str`. Unwrap it with `!` first ...`` (`print(proc.exec(...))`) | 13 | 말한다 |
| ``Undeclared variable `x`.`` (Python 내장 `chr`, `repr`, 정의하지 않은 함수 `section_of`, `for p \|x\|:`의 없는 `p` 둘) | 5 | 무엇이 틀렸는지는 말한다. `for p \|x\|:`는 이름 하나라 구별할 수 없다 |
| ``Undeclared variable `orig`. To declare a new variable, write `orig := ...`.`` | 1 | 말한다 |
| `` `type` declarations are not allowed here.`` / `` `fn` declarations are not allowed here.`` (블록 안의 선언) | 2 | 무엇이 틀렸는지는 말한다. 최상위에 선언하라는 것은 안내의 오류 목록(`fn`)에 있다 |
| `elif`, `if` 식의 괄호, `!else` 블록의 끝, 목록 리터럴의 괄호, `pop` | 5 | 말한다 |
| `for p \|s\| in [...]:` (``Expected :.``) | 1 | 말하지 않는다 (요청서 a) |
| `q: byte = 0` (``Unsupported block statement.``) | 1 | 말하지 않는다 (요청서 b) |
| `in_s str = ''` (``Expected end of line or file. Got ident.``) | 1 | 말하지 않는다 (요청서 c) |
| `out == none` (`out`이 옵션이 아님, ``Expected `?T` to infer `none` value, found ...``) | 1 | 말하지 않는다 (요청서 d) |
| `text.ends_with(x) ?else false` (``Expected type instance of `Option`, found `bool`.``) | 1 | 말하지 않는다 (요청서 e) |
| `str`과 `int`의 비교 `i > 0` (``... when calling `fn >(str, str) -> bool`.``) | 1 | 타입은 말하지만 내부 시그니처를 보인다 (요청서 f) |
| ``Expected type instance of `Result`, found `str`. ...`` (풀 것이 없는 `str`에 `!`) | 1 | 말한다 |
| ``Expected type `byte`, got `int`.`` (문자열 원소와 정수 비교) | 1 | 무엇이 틀렸는지는 말한다 |

- 가장 흔한 실수는 여전히 `!T`를 풀지 않고 출력하는 것이다. 안내의 원칙 첫머리에 있는데도 작은 모델이 과제마다 되풀이한다. 문구가 정확해서 한 스텝으로 끝나지만 스텝 하나와 그만큼의 입력 토큰이 든다. 이것은 문구가 아니라 능력의 모양(모델이 받는 `!str`)과 안내의 문제다. 본체의 능력 설계와 안내를 다룰 때 다시 본다.
- 나머지는 대부분 Python 습관(타입 표기 `q: byte`, `for ... in`, `elif`, 내장 함수)이다. 고치는 법을 말하지 않는 여섯은 요청서 docs/requests/cyber-0.4.11-codeact-messages.md에 적었다.

### 5.2 모델은 Cyber를 어떻게 쓰는가

CodeAct 회차의 `run` 호출 205개를 셋으로 나눴다. 규칙은 단순한 정규식이다.

- 셸 위임: `proc.exec`의 결과를 출력하거나 받는 줄뿐
- 입출력만: 능력 호출과 `print`뿐
- 로직: 반복, 분기, 함수, type, Map, 문자열 메서드, 정렬 중 하나라도 쓴 것

| 모델 | run 호출 | 셸 위임 | 입출력만 | 로직 | 로직 스크립트 평균 줄 |
|---|---|---|---|---|---|
| DeepSeek-V4.1-Flash 사고 없음 | 45 | 18 | 4 | 23 | 21.7 |
| DeepSeek-V4.1-Flash effort high | 39 | 21 | 5 | 13 | 19.5 |
| qwen3.8-flash | 106 | 41 | 13 | 52 | 17.9 |
| qwen3.8-max | 15 | 8 | 0 | 7 | 29.6 |

- 모델은 Cyber를 셸 감싸개로만 쓰지 않는다. 첫 한두 스텝은 `print(proc.exec('ls ...')!)`로 둘러보고, 그다음 한 스크립트에 읽기, 세기, 정렬, 쓰기를 다 담는 흐름이 모든 모델에 공통이다. 셸 위임은 run의 4할 안팎(38~54%)이다.
- 집계는 struct 목록과 `sort`로 하는 경우가 많다(예제 4의 모양). `type` 선언은 17개, `sort`는 23개 run에 있었다. Map을 `^Map`으로 선언한 것은 3개다.
- 타입을 적은 빈 목록(`[]str{}`)은 42개, 목록 리터럴로 도는 `for {...} |f|:`는 13개, `try:` 블록은 37개, 최상위 `fn` 선언은 16개 run에 있었다.

## 6. 스파이크 3: 교차 빌드

- `zig build -Dtarget=x86_64-linux-gnu`가 macOS arm64에서 s1, s2 모두 된다(빈 캐시로 s1 46초, s2 71초). cyber는 의존의 아티팩트로 같은 대상에 맞춰 빌드된다(libcyber.a 3.09 MB). 산출물은 glibc 동적 링크 ELF다.
- tars 게스트(QEMU)에서의 실행은 이 빌드로 하지 않았다. tars-linux의 산출물(커널, initrd)이 필요하다. 게스트를 모는 스크립트는 spike/s3/guest.py에 있다: initrd 사본 뒤에 바이너리를 담은 gzip cpio를 이어 붙여 부팅하고, 시리얼을 유닉스 소켓으로 열어 명령을 보낸다(셸이 fish라 Enter는 CR).

보지 못한 것: tars 게스트에서의 실행, 실기 노트북, tars 터미널 패널 안에서의 화면 출력, Landlock(M5).

## 7. cyber에 남은 것

본체 첫 단계의 선행 조건(ADR 0019)은 닫혔다. M0 스파이크에서 cyber에 낸 요청은 모두 릴리스 0.4.11에 들어갔다. 스파이크는 그 태그를 URL과 해시로 고정해 받는다.

모델이 모르는 내부 이름(`@index`, `@slice`, `@set_index`, `@index_addr`)은 인덱스, 슬라이스 경계, 대입 값 어디서든 인자 불일치 문구에 나오지 않는다. 대입 값이 원소 타입과 다르면 ``An element of `[]int` must be `int`, got `str`.``처럼 원소 타입을 말하고, `?T`와 `!T`이면 푸는 법을 붙인다(`Map`도 같다). 정수 원소 자리의 한 글자 리터럴(`xs[0] = 'a'`)은 오류가 아니라 코드 포인트(97)다. 타입이 정해진 자리의 한 글자 리터럴은 코드 포인트라는 언어 규칙이다.

열린 요청: docs/requests/cyber-0.4.11-codeact-messages.md. 0.4.11 회차에서 문구가 고치는 법을 말하지 않은 여섯(5.1)이다. 선행 조건은 아니다.

## 8. 안내 문서 (prompt/cyber-subset*.md)

영문판과 한국어판을 기준 빌드로 다시 썼다. 두 판은 같은 구조이고 코드 블록 11개(정렬 절의 조각 하나, 예제 10개)가 같다. 기준 버전 줄은 `Cyber 0.4.11 build-883-097b831`이다. 안내의 문구와 코드 블록은 설치된 릴리스 CLI(`/usr/local/bin/cyber`)와 세션(`s1 replay`)으로 확인한다.

확인 방법: 안내의 항목마다 탐침 스크립트를 만들어 기준 빌드의 CLI로 돌리고 결과(출력이나 오류 첫 줄)를 받아 적었다. 세션에서만 다른 것(최상위 빌림, 없는 모듈의 문구)은 s1의 `replay`(같은 VM, persist_main, 검증 뒤 실행)로 따로 확인했다. 없는 모듈(`use json`)은 CLI가 `Import path does not exist`, 세션(라이브러리의 기본 로더)이 `Failed to load module: json`을 낸다. 안내는 세션 쪽 문구를 적는다. 코드 블록 11개는 CLI와 `replay` 양쪽에서 통과했다.

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
| 메서드 | str, []T, Map의 있는 메서드 전부(`trim()`, `trimLeft()`, `trimRight()`, `lastIndexOf` 포함)와 Python 이름의 대응 |
| 없는 것 | `abs`, `sum`, `sorted`, `enumerate`, `zip`, `xs.map`, `xs.filter`, json, regex, time |
| 오류 목록 | 문구가 고치는 법을 말하지 않는 오류만 (21줄). 나머지는 "문구대로 고친다" 한 줄 |

크기: 영문판 19.8KB(19,777바이트). 5절 회차는 이 판으로 돌았고, 시스템 프롬프트 전체가 20,867바이트, 첫 요청 입력이 약 6,500토큰이었다. TODO의 "4,000토큰 이하" 목표를 넘는다. 목표를 바꿀지 안내를 줄일지는 사용자가 정한다. 줄일 자리는 오류 목록(cyber가 문구를 보강할 때마다 줄이 빠진다)과 "Python과 다른 것"의 문법 줄이다.

## 9. 본체 아키텍처에 주는 뜻 (추천, 확정은 본체를 만들 때 사용자가)

| 번호 | 추천 | 근거 |
|---|---|---|
| 1 | 구성요소와 경계(명세 01)는 그대로 간다 | 스파이크 2의 세 파일(provider, vm, main)이 명세의 provider, runtime+caps, loop와 같은 선으로 자연히 갈렸다 |
| 2 | 능력은 모두 `Future[!T]`를 돌려주고 머리말 래퍼가 await한다. 승인이 필요 없으면 호스트 함수 안에서 바로 완료한다 | 3.2, 3.3. 능력의 모양이 하나가 되고, 등급이 바뀌어도 선언이 바뀌지 않는다 |
| 3 | 검증은 세션 VM에서 `cl_vm_validate`로 바로 한다. 머리말을 eval한 뒤에 검증한다 | 3.5. 검증은 마지막 eval의 설정을 쓴다(cyber.h에 적혀 있다) |
| 4 | CL_SUCCESS가 아닌 eval과 검증 뒤 `cl_vm_reset_pending`을 묻고, reset이면 머리말을 다시 돌려 모델에게 알린다. panic과 interrupt 뒤에는 최상위 변수가 사라졌다고 알린다 | 3.4, 3.5. s2가 그렇게 돈다 |
| 5 | 호스트 로더는 허용 목록으로 쓴다 | 3.6 |
| 6 | deny_raw_ptrs와 deny_spawn을 켠다 | 3.6 |
| 7 | 프로세스 실행 능력은 자체 시간 상한, 표준 입력 차단, 출력 크기 상한, 취소를 가진다 | VM의 타이머는 승인 뒤 루프가 돌리는 프로세스에 닿지 않는다 |
| 8 | 읽기 능력도 권한 프로파일의 대상으로 둔다 (작업 폴더 밖 읽기는 승인) | 읽은 것은 모두 모델 제공자에게 간다 |
| 9 | cyber.h는 손으로 쓴 extern 선언으로 감싼다 (runtime/cy.zig 한 파일) | 3.1. 빌드 의존이 줄고, 쓰는 표면이 한눈에 보인다. 대가는 cyber가 구조체 배치를 바꾸면 손으로 따라가야 하는 것이다 |
| 10 | 메시지 모델은 스파이크의 모양(블록 넷, thinking에 불투명 칸)에서 시작한다 | 4.2 |
| 11 | 끝난 이유와 사용량은 어댑터가 정규화한다. 사용량은 "전체 입력, 그중 캐시, 출력" 셋으로 맞춘다 | 4.1 |
| 12 | SSE는 줄 버퍼에 기대지 않는 조각 단위 해석기로 쓴다 | 4.3 |
| 13 | 검증에 `cl_vm_set_error_recovery`와 `cl_vm_compile_report`를 켜서 오류를 전부 돌려주는 것을 시험한다 | 모델은 한 스텝에 오류 하나씩 고친다(5절). 스파이크에서는 시험하지 않았다 |
| 14 | 안내 문서의 예제와 조언은 에이전트와 같은 조건(세션 VM, persist_main, 검증 뒤 실행)에서 확인한다. 안내 검사 도구를 둔다면 runtime 경계 위에서 돈다 | 3.5, 8 |
| 15 | 안내는 회차에서 모델이 틀린 곳으로 고친다. 문구가 고치는 법을 말하는 오류는 안내에 넣지 않는다 | 5.1. 안내의 크기를 지키는 기준이 된다 |
| 16 | 평가의 모델 목록에 크기가 다른 모델을 함께 넣는다 (DeepSeek-V4.1-Flash, qwen flash, qwen max). direct 모드는 대조군이면서 작은 모델용 기본값 후보로 본다 | 5 |

## 10. 아직 모르는 것

- CodeAct 판정. 과제 셋으로는 말할 수 없다. 평가 도구(eval/)가 필요하다.
- tars 게스트에서의 기준 빌드.
- json 모듈 없이 돌렸다. JSON을 다루는 과제는 넣지 않았다.
- 긴 세션(수십 스텝)에서의 VM 메모리와 히스토리 크기, 컴팩션.
- 대화형 프런트엔드. 스파이크는 한 번 묻고 끝나는 헤드리스였고 승인은 자동이었다.
- 인터럽트(Esc)로 스트림과 실행을 끊는 것.
- Claude 모델. 키가 없어 돌리지 않았다.

## 11. 스파이크 코드 지도와 다시 돌리는 법

| 경로 | 내용 | 실행 |
|---|---|---|
| spike/s1 | 호스트 경계 검사 40개, 세션 재생, 관찰 하나 | `zig build && ./zig-out/bin/s1`, `s1 replay <파일> [nv]` (스크립트를 `=====` 줄로 나눈다, 검증과 실행 결과, 출력, 오류 첫 줄을 찍는다. `nv`면 검증 없이 실행), `s1 spawn` (deny_spawn 없이) |
| spike/s2a | 두 형식의 원문 응답 받기 | `./run.sh`, 결과는 out/*.sse |
| spike/s2 | 최소 에이전트 루프 (direct, codeact), 제공자 넷 | `./zig-out/bin/s2 --provider ds-anth --mode codeact "질문"`, `./compare.sh <제공자> [모델] [모드] [과제]` |
| spike/s3 | tars 게스트 구동 스크립트 | 6절 |

- 두 스파이크의 cyber 의존은 URL과 해시로 고정한 패키지다(build.zig.zon). 로컬 cyber 저장소의 상태와 상관없이 같은 소스를 빌드한다. 기준 빌드를 올릴 때는 `zig fetch <url>`로 해시를 받아 zon의 `.url`과 `.hash`를 고치고, build.zig의 의존 인자(`dev`, `build`, `commit`)와 s1 검사 0의 버전 문자열도 올린다. 문구를 CLI로 볼 때는 설치된 릴리스(`/usr/local/bin/cyber`, `cyber version`이 고정한 릴리스와 같은지 먼저 본다)를 쓴다.
- 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다. 이 가두기를 풀지 않는다.
- compare.sh는 결과를 out/cmp-*에 덮어쓴다. 회차를 여럿 돌리면 회차마다 기준 빌드 이름의 폴더로 옮긴다(out/0.4.11/<회차>/). 회차는 차례로 돌린다(같은 작업 폴더 /tmp/tars-agent-s2를 쓰므로 겹치면 결과가 섞인다). s2는 실행마다 안내 파일을 읽으므로 회차 도중에 안내를 고치지 않는다.
- cyber의 기준 빌드를 올리면: 의존을 올리고(build.zig의 commit 인자 포함), s1, 안내의 탐침, 코드 블록 11개를 CLI와 `replay`로 다시 돌리고, s2 비교를 다시 돌리고, 문서를 새 빌드의 사실로 고쳐 쓴다.

읽을 가치가 있는 순서: s2/src/main.zig(루프), s2/src/provider.zig(메시지 모델과 어댑터), s2/src/vm.zig(검증, 실행, 승인), s1/src/main.zig(검사 목록).
