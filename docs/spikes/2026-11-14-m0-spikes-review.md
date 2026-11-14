# M0 스파이크 검토 결과 (2026-11-14)

스파이크를 Claude가 혼자 구현하고 검토했다 (ADR 0012의 덧붙임). 이 문서는 무엇을 만들었고, 기준 빌드에서 무엇이 확인됐고, 무엇이 남았고, 본체의 아키텍처에 어떤 뜻이 있는지를 적는다. 코드는 spike/에 있고 버릴 것이다.

기준 빌드: soomtong/cyber master 63e35e88 (`Cyber 0.4.10-DEV`). cyber에 관한 숫자와 판정은 모두 이 빌드로 이 날 돌려서 얻은 것이다. 측정 환경은 macOS arm64.

읽는 순서: 1절(한 장 요약), 2절(에이전트는 어떻게 도는가), 그 뒤는 필요한 절만.

## 1. 한 장 요약

| 질문 | 답 | 근거 |
|---|---|---|
| Zig 호스트가 libcyber를 링크해 VM을 돌릴 수 있는가 | 된다 | 스파이크 1, 검사 35개 중 34 통과 |
| cyber를 build.zig.zon 의존으로 쓸 수 있는가 | 받아지지만 아티팩트를 내보내지 않는다. 받은 패키지에서 `zig build lib`를 돌려 링크했다 | 3.1 |
| 능력이 `Future[!str]`을 돌려줄 수 있는가 (ADR 0011의 모양) | 된다. str 값이나 오류로 완료한다 | 3.2 |
| 승인 대기를 VM 밖에서 하는 설계(ADR 0011, 0016)가 실제로 도는가 | 돈다. 승인, 거부, 취소, 동시 요청 모두 | 3.3 |
| 상한 넷(연료, 벽시계, 스택, 메모리)이 폭주를 멈추는가 | 멈춘다. VM은 계속 쓸 수 있다 | 3.4 |
| 검증을 세션 VM에서 바로 할 수 있는가 | 된다. 보통의 컴파일 실패 뒤에도 세션이 그대로다. 문자열 이스케이프 오류만 세션을 지운다 | 3.5, 7.1 |
| Zig std.http로 모델 API에 스트리밍 요청을 보낼 수 있는가 | 된다. TLS와 CA 묶음 포함 | 4.3 |
| 전송 형식 둘을 메시지 모델 하나로 받을 수 있는가 (ADR 0015) | 된다. 블록 넷과 불투명 칸 하나로 충분했다 | 4.2 |
| CodeAct가 실제 과제를 푸는가 | 푼다. 모델 셋이 과제 21개를 모두 끝냈다(direct도 6개 모두). 컴파일 오류는 작은 모델에 과제당 1.3번, 모두 다음 스텝에 고쳐졌다 | 5 |
| x86_64-linux-gnu 교차 빌드가 되는가 | 된다. tars 게스트에서의 실행은 이 빌드로 확인하지 않았다 | 6 |

가장 무거운 발견 셋:

1. 문자열 이스케이프 오류(`"a\|b"` 같은 grep 패턴)가 세션 VM의 변수, 함수, `use`를 알림 없이 지운다 (7.1). CodeAct 회차에서 모델이 실제로 겪었다. 호스트는 지워진 것을 모르므로 모델에게 알릴 수도 없다. 본체 첫 단계의 선행 조건이다.
2. 안내 문서가 CodeAct의 성패를 가른다. 모델이 틀린 곳의 대부분은 오류 문구가 고치는 법을 말해 다음 스텝에 고쳐졌고, 남은 빈틈(`?int` 다루기, 이스케이프, 블록 안의 `fn`)은 안내에 넣었다 (5, 8).
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

실제 CodeAct 스텝 하나의 기록 (deepseek-chat, T1의 스텝 3, 스크립트 앞부분):

~~~text
[도구 호출] run {"code": "type Row:\n    name str\n    n int\n\nrows := []Row{}\ntotal := 0\nfor {'app.log', 'db.log', 'web.log'} |f|:\n    text := fs.read('logs/%{f}')!\n ... rows.sort(|a, b| a.n > b.n or (a.n == b.n and a.name < b.name)) ..."}
    [승인] write report.txt
    [실행] 종류=ok 능력 호출 5회
[도구 결과] web.log: 23
db.log: 8
app.log: 7
...
total=38
~~~

스크립트 하나가 파일 셋을 읽고, 세고, struct 목록으로 정렬하고, 쓰고, 다시 읽어 보였다. 능력 호출은 다섯 번이었고 모델 왕복은 한 번이었다. 정렬 모양은 안내의 예제 4 그대로다. 앞의 두 스텝은 `print(proc.exec('ls -la logs/ ...')!)`로 둘러본 것이다.

## 3. 스파이크 1: 호스트 경계

코드: spike/s1. 실행: `zig build && ./zig-out/bin/s1`. 검사 35개가 PASS/FAIL로 찍힌다. 34개가 통과하고, 6i(이스케이프 오류 뒤 세션이 남는가)가 실패한다. 6i는 열린 결함(7.1)의 문이다: cyber가 고치면 통과로 바뀐다.

### 3.1 링크

- `zig fetch --save=cyber "git+https://github.com/soomtong/cyber#63e35e88..."`로 커밋을 고정해 받는다.
- `b.dependency("cyber").artifact("cyber")`는 실패한다(panic: unable to find artifact "cyber"). cyber의 build.zig가 라이브러리를 `lib` 스텝 아래에서만 설치하고 의존 쪽에 내보내지 않기 때문이다.
- 스파이크는 build.zig에서 받은 패키지 폴더를 작업 폴더로 `zig build lib -Doptimize=ReleaseFast -Dffi=false -Dstatic=true -Dtarget=...`를 실행하고 그 산출물(libcyber.a)을 링크한다(spike/s1/build.zig). 처음 빌드는 약 40초, 그 뒤는 캐시된다. 본체에는 이 방식을 넣지 않는다(요청서 3절).
- 이렇게 만든 라이브러리의 버전 문자열은 `Cyber 0.4.10-DEV build-0-local`이다. 어느 커밋인지 찍히지 않는다.
- Zig 0.17.1에는 `@cImport`가 없다. cyber.h를 Zig에서 쓰는 길은 둘이다: translate-c 패키지로 모듈을 만들거나, 쓰는 함수의 extern 선언을 손으로 쓴다. 스파이크는 앞의 것을 썼다. 본체의 추천은 9절.
- libcyber.a는 2.49 MB, 공개 `cl_` 함수는 134개다. mimalloc 심볼은 없다(FFI를 끈 라이브러리 빌드에는 들어가지 않는다).

### 3.2 능력 바인딩

- 호스트 함수는 `fn (t: *CLThread) callconv(.c) CLRet` 하나의 모양이다. 인자는 커서처럼 읽는다: 반환 슬롯(cl_thread_ret)을 먼저, 그다음 매개변수를 선언 순서대로(cl_thread_str, cl_thread_int). 순서를 어기면 프로세스가 죽는다(`s1 order`: cl_thread_str에서 Segmentation fault). cyber.h에 이 순서가 적혀 있지 않다(요청서 5절).
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
| 벽시계 200ms (타이머 스레드의 cl_vm_interrupt) | `while true` | INTERRUPT, 201ms 뒤 |
| 스택 1 MiB | 끝없는 재귀 | PANIC (Stack overflow. The stack limit is 1048576 bytes.) |
| 메모리 +8 MiB | 끝없는 추가 | PANIC (OutOfMemory). VM 메모리 2621 KiB에서 2695 KiB로 돌아왔다 |

상한에 걸린 뒤: 함수 선언은 남고 지역 변수는 사라진다(함수 호출은 되고 변수는 Undeclared). 명세 02의 "variables were reset" 문구가 맞다.

### 3.5 세션과 검증

- persist_main: 변수, 함수, use가 다음 eval로 이어진다.
- validate: 세션의 변수를 보면서 컴파일만 한다. 구조화된 오류가 온다(kind=2, line=1, col=6, len=4, "Undeclared variable `totl`."). validate한 선언은 넘어가지 않는다.
- validate에는 설정 인자가 없는데 raw 포인터를 거부했다. 세션의 설정(deny_raw_ptrs)을 따른다.
- 실패한 컴파일 뒤: 같은 VM의 다음 검증과 실행이 그대로 된다(6f: 캡처 오류로 실패한 정렬 스크립트 뒤 Map 스크립트가 검증과 실행을 통과). 모듈 소스가 컴파일에 실패하면 다음 use에서 로더를 다시 불러 맞는 소스를 받는다(6g). 그래서 검증은 세션 VM에서 `cl_vm_validate` 한 줄로 한다. 예외는 문자열 이스케이프 오류다(7.1).
- 목록 참조의 `+=`(`out := ^[]str{}` 뒤 `out += 'x'`)는 검증이 잡는 컴파일 오류이고, 문구가 `out.* += ...`를 알려 준다(6h).
- 최상위 빌림(`c := &x`)은 다음 eval로 넘길 수 없어 ``Cannot persist local `c` of borrow type `&int` across evals.``다. CLI에서는 나지 않는 오류라 안내의 조언은 세션에서 확인해야 한다(8절).
- 비용: validate 200회 2ms, eval 200회 2ms. VM 생성과 첫 eval은 개당 2ms, VM 하나가 쥔 메모리 약 2.6 MiB.

### 3.6 샌드박스 경계

| 시도 | 결과 |
|---|---|
| `use c` | 호스트 로더가 false를 돌려준다. CompileError: Failed to load module: c |
| `use os` | 라이브러리에 없다. 같은 오류 |
| `Ptr[int](0)` | CompileError: Raw pointer type `Ptr[int]` is not allowed (deny_raw_ptrs) |
| deny_raw_ptrs와 호스트 모듈 | 함께 동작한다. 호스트 모듈의 선언은 막히지 않는다 |
| `@bitCast` | CompileError: internal to the builtin modules |
| `use io` | 기본 로더가 준다. 본체에서 허용 목록으로 뒤집어야 한다 |
| `spawn(work, {21})` | 된다. 막는 장치가 없다 |

spawn에 대해(`s1 spawn`): 스레드 안에서 능력 함수(`fs.read`)가 그대로 불린다. 연료 상한은 스레드 안의 무한 루프도 510ms에 멈췄고 VM은 다음 eval을 받았다. 능력 함수가 메인 스레드가 아닌 곳에서 불리므로 요청 표와 승인 흐름이 스레드에 안전하지 않다. cyber.h도 Future 생성은 메인 스레드에서 하라고 적는다. spawn 차단 옵션을 요청했다(요청서 4절). 그 전의 가장 싼 방법은 능력 함수 첫머리에서 메인 스레드인지 확인하고 아니면 panic을 돌려주는 것이다.

로더는 지금 "c와 test만 거부"하는 차단 목록이다. 기본 로더에 모듈이 더해지면 그대로 스크립트에 열린다. 본체는 허용 목록(core, math, 그리고 우리 모듈)으로 가야 한다.

## 4. 스파이크 2: 제공자

코드: spike/s2a (curl 스크립트와 원문 응답), spike/s2/src/provider.zig. 이 절은 cyber와 무관하다. 2a의 원문 응답은 2026-11-13에 받았고, 5절의 회차에서도 두 형식(DeepSeek의 Anthropic 형식, OpenRouter의 OpenAI 형식)이 같은 어댑터로 돌았다.

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

- OpenRouter의 Anthropic 형식에서 deepseek-chat(상류 DeepInfra)은 tool_use 블록을 내면서 stop_reason을 end_turn으로 줬다. 상류 제공자에 따라 다르다.
- DeepSeek의 Anthropic 형식에서 deepseek-reasoner는 thinking 블록을 내지만 사고 글은 비어 있고 signature에 메시지 id가 들어 있었다.
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
- 끝난 이유를 내용에서 다시 계산하는 규칙(도구 호출이 있으면 tool_use)이 위의 어긋남을 흡수했다.
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

과제 셋. 평가가 아니라 감을 잡기 위한 것이다. 판정(ADR 0006)은 과제 20개를 3회씩 돌린 뒤에 한다. 원자료는 spike/s2/out/dev/*.tsv(열: 과제, 판정, 제공자, 모델, 모드, 스텝, 도구 호출, 도구 오류, 입력 토큰, 캐시된 입력, 출력 토큰, 밀리초, 컴파일 오류). 안내는 8절의 최종판이다. s2는 우회 없는 모양(능력은 `Future[!str]`, 검증은 세션 VM의 `cl_vm_validate`)으로 돌았다. 모델이 쓴 명령은 샌드박스(spike/s2/src/jail.zig) 안에서만 돌았다.

- T1: 로그 파일 셋에서 ERROR 줄을 세어 정렬해 보고서 파일로 쓰기
- T2: .py 파일들에서 대문자 TODO를 찾아 파일별 개수를 쓰기
- T3: 설정 파일의 한 구획에서만 값을 바꾸고 줄을 더하기

| 모델 | 모드 | 과제 (회차) | 통과 | 스텝 평균 | 컴파일 오류 (과제당) | 과제당 시간 | 과제당 입력 토큰 |
|---|---|---|---|---|---|---|---|
| deepseek-chat | direct | 3 (1) | 3 | 4.3 | | 5초 | 2.6k (캐시 1.8k) |
| deepseek-chat | codeact | 9 (3) | 9 | 5.4 | 0.2 | 7초 | 39.2k (캐시 37.4k) |
| qwen3.8-flash | direct | 3 (1) | 3 | 6.3 | | 14초 | 8.2k (캐시 5.7k) |
| qwen3.8-flash | codeact | 9 (3) | 9 | 6.9 | 1.3 | 21초 | 58.2k (캐시 54.2k) |
| qwen3.8-max | codeact | 3 (1) | 3 | 5.3 | 0.0 | 48초 | 42.6k (캐시 36.7k) |

입력 토큰은 캐시된 몫을 포함한 전체다(DeepSeek의 Anthropic 형식은 둘을 따로 주므로 더했다).

읽는 법:

- 두 모드 모두 과제 27개를 모두 끝냈다. 이 과제 셋으로는 성공률의 차이가 보이지 않는다.
- CodeAct의 대가는 시스템 프롬프트다. direct는 331바이트, CodeAct는 Cyber 안내를 포함해 21,530바이트이고 첫 요청 입력은 약 6,800~6,900토큰이다(deepseek 6,757, qwen3.8-flash 6,925). 매 스텝 다시 보내므로 캐시가 없으면 스텝마다 그만큼이 든다. 두 제공자 모두 자동 캐시가 입력의 9할 이상을 덮었다.
- 컴파일 오류는 작은 모델(qwen3.8-flash)에 과제당 1.3, deepseek-chat에 0.2, qwen3.8-max에 0이었다. 모두 다음 스텝에 고쳐졌다.
- 상한(연료, 벽시계)이 걸린 실행, panic, 세션 소실은 없었다.
- 표본이 작다. 과제 셋, 회차 셋(direct와 max는 하나)이다. 방향을 보는 숫자이지 판정이 아니다.

### 5.1 모델이 틀린 곳

최종 안내로 돈 회차의 컴파일 오류 14건(deepseek-chat 2, qwen3.8-flash 12, qwen3.8-max 0):

| 오류 | 건수 | 문구가 고치는 법을 말하는가 |
|---|---|---|
| ``Can not print `!str`. Unwrap it with `!` first ...`` (`print(proc.exec(...))`) | 6 | 말한다 |
| ``Can only capture variables ... Declare it with `^T` ...`` (Map 값으로 정렬) | 1 | 말한다. deepseek-chat은 `^Map`으로 고쳐 끝냈다 |
| `for x in xs:`, 처음 쓰는 이름에 `=`, 구문 오류 셋 | 5 | 앞의 둘은 말한다. 구문 오류는 위치만 준다 |
| `to_upper`, `repr` 같은 없는 이름 | 2 | 말하지 않는다(7.4) |

- 가장 흔한 실수는 `!T`를 풀지 않고 출력하는 것이다. 안내의 원칙 첫머리에 있는데도 작은 모델이 되풀이한다. 문구가 정확해서 한 스텝으로 끝난다.
- 안내의 `?int` 줄(`if s.index(x) |i|:`, `idx == none`), 이스케이프 줄, "함수는 최상위에서만" 줄은 같은 날 먼저 돈 회차에서 모델이 틀린 곳(`if not idx:`, `if h ?>= 0:`, 블록 안의 `fn`, grep 패턴의 `\|`)을 보고 더했다. 7.1의 결함도 그 회차에서 드러났다. 그 회차는 지금의 안내로 돈 것이 아니라 원자료를 두지 않았다. 최종 회차에서는 이 넷이 한 번도 나오지 않았다.

### 5.2 모델은 Cyber를 어떻게 쓰는가

run 호출을 셋으로 나눴다(규칙은 단순한 정규식).

- 셸 위임: `proc.exec`와 `print`뿐
- 입출력만: 능력 호출과 `print`뿐
- 로직: 반복, 분기, 함수, type, Map, 문자열 메서드, 정렬 중 하나라도 쓴 것

| 모델 | run 호출 | 셸 위임 | 입출력만 | 로직 | 로직 스크립트 평균 줄 |
|---|---|---|---|---|---|
| deepseek-chat | 41 | 14 | 9 | 18 | 15.2 |
| qwen3.8-flash | 58 | 28 | 11 | 19 | 20.9 |
| qwen3.8-max | 14 | 5 | 3 | 6 | 28.8 |

- 모델은 Cyber를 셸 감싸개로만 쓰지 않는다. 첫 한두 스텝은 `print(proc.exec('ls ...')!)`로 둘러보고, 그다음 한 스크립트에 읽기, 세기, 정렬, 쓰기를 다 담는 흐름이 세 모델에 공통이다. qwen3.8-flash는 셸 위임의 비율이 가장 높다(절반).
- 집계는 대부분 struct 목록과 `sort`로 한다(예제 4의 모양). Map 값으로 정렬한 것은 deepseek-chat의 한 번이고, 캡처 오류 뒤 `^Map`으로 고쳤다.
- 안내가 새로 가르친 문법을 썼다: 타입 없는 목록 리터럴(`for {'app.log', 'db.log'} |f|:`) 113개 run 중 16개, 문자열 `<` 11개, `xs.sort()` 3개. 타입을 적은 목록(`[]str{}`)도 29개로 함께 쓴다.
- `try:` 블록은 23개, 최상위 `fn` 선언은 10개 run에 있었다.

## 6. 스파이크 3: 교차 빌드

- `zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseFast`가 macOS arm64에서 s1 45초, s2 77초에 끝난다. 산출물은 glibc 동적 링크 ELF다.
- tars 게스트(QEMU)에서의 실행은 이 빌드로 하지 않았다. tars-linux의 산출물(커널, initrd)이 필요하다. 게스트를 모는 스크립트는 spike/s3/guest.py에 있다: initrd 사본 뒤에 바이너리를 담은 gzip cpio를 이어 붙여 부팅하고, 시리얼을 유닉스 소켓으로 열어 명령을 보낸다(셸이 fish라 Enter는 CR).

보지 못한 것: tars 게스트에서의 실행, 실기 노트북, tars 터미널 패널 안에서의 화면 출력, Landlock(M5).

## 7. cyber에 남은 것

요청서: docs/requests/cyber-m0-spike-requests.md. 1~5가 본체 첫 단계의 선행 조건이다 (feedback-fix-spike-defects-first.md).

### 7.1 문자열 이스케이프 오류가 세션을 지운다

~~~text
keep := 7            -- 실행 1: 성공
s := "a\|b"          -- 실행 2: CompileError: Error: InvalidEscapeSeq
print(keep)          -- 실행 3: Undeclared variable `keep`.
~~~

검증이든 eval이든 같고, 함수와 `use`도 사라진다. `'\xZZ'`(Error: InvalidCharacter)도 같다. 다른 토큰 오류, 구문 오류, 보통 컴파일 오류 뒤에는 세션이 그대로다. 오류 문구에 위치가 없다.

원인으로 보이는 곳: 이스케이프 해석(src/sema.zig)이 맨 Zig 오류를 돌려주고, 컴파일 실패 처리(src/compiler.zig)가 `error.CompileError`가 아닌 오류를 할당 실패로 보고 다음 eval 앞에서 VM을 reset한다.

CodeAct 회차에서 실제로 일어났다: qwen3.8-flash가 `proc.exec("grep -rn \"TODO\|Todo\" ...")`를 쓴 뒤 `Undeclared variable proc`를 세 번 받았다. 모델은 이유를 몰랐고 호스트도 몰랐다. 안내에 쓸 수 있는 이스케이프와 이 오류 뒤에 할 일을 적었지만(8절) 그것은 피하는 법이다. 고쳐지면 s1의 6i가 통과한다.

### 7.2 `\0`이 큰따옴표가 된다

`'a\0b'`가 오류 없이 `a"b`다. 이스케이프 표의 `'0'` 분기가 `'"'`를 돌려준다. 안내가 `\0`을 쓰지 말라고 적었다.

### 7.3 빌드와 임베딩

- 빌드 내보내기, 의존으로 빌드할 때 버전 문자열에 커밋 (3.1)
- spawn 차단 옵션 (3.6)
- 호스트 함수의 인자 읽기 순서의 문서 (3.2)

### 7.4 모델이 따라가는 오류 문구

- 캡처 오류가 최상위 빌림(`b := &counts`)을 권하는데, 세션에서는 최상위 빌림이 `Cannot persist local` 오류다.
- `xs.len`이 내부 필드 `_len`을 제안한다.
- `?int`에 `not`을 쓰면 ``Can not find the symbol `!` in `?int`.``로 `!`를 말한다. deepseek-chat이 이 모양을 두 번 쓰고 원인을 찾지 못했다.
- Rust식 이름(`to_upper`, `to_lower`)에는 제안이 없다. `toUpperCase`는 `upper`를 제안한다.

### 7.5 판단을 맡긴 것

- `{1, 'a'}`가 `{1, 97}`이다. 타입 없는 목록이 첫 원소 타입을 따르는 규칙과 한 글자 문자열이 정수 자리에서 코드 포인트가 되는 규칙이 겹친다. 안내에 적어 두었다.

## 8. 안내 문서 (prompt/cyber-subset*.md)

영문판과 한국어판을 기준 빌드로 다시 썼다. 두 판은 같은 구조이고 코드 블록 11개(정렬 절의 조각 하나, 예제 10개)가 같다. 기준 버전 줄은 `Cyber 0.4.10-DEV build-0-63e35e88`(커밋 63e35e88)이다.

확인 방법: 안내의 항목마다 탐침 스크립트를 만들어 기준 빌드의 CLI로 돌리고 결과(출력이나 오류 첫 줄)를 받아 적었다. 세션에서만 다른 것(최상위 빌림)은 s1의 `replay`(같은 VM, persist_main, 검증 뒤 실행)로 따로 확인했다. 코드 블록 11개는 CLI와 `replay` 양쪽에서 통과했다.

| 무엇 | 안내가 가르치는 것 |
|---|---|
| 목록 리터럴 | `{1, 2, 3}`은 첫 원소 타입의 `[]int`. 빈 목록은 `[]int{}` |
| Map 리터럴 | `Map[str, int]{a=1}`, 식 키는 `{(k)=1}` |
| 정렬 | `xs.sort()`는 오름차순(숫자, 문자열). 다른 순서는 함수. Map 값으로 정렬하려면 Map을 `^`로 선언해 람다가 캡처한다. 최상위 빌림은 세션에서 안 된다 |
| 문자열 비교 | `<`, `<=`, `>`, `>=`가 바이트 순 |
| `not` | Python과 같은 우선순위 |
| 슬라이스 | `s[1..3]`은 끝 제외, `s[1..=3]`은 끝 포함 |
| `!T` | 출력, 메서드 호출 전에 `!`로 푼다. 어기면 고치는 법이 붙은 컴파일 오류 |
| `?int` | `if s.index(x) \|i\|:`, `idx == none`, `?else`. `not idx`, `idx >= 0`, `idx!`는 오류 |
| 참조의 연산자 | `n.* += 2`, `out.* += 'x'` |
| 문자열 이스케이프 | `\n \t \r \\ \' \" \xHH`만. 그 밖은 세션을 지우는 오류(7.1). `\0`은 쓰지 않는다 |
| 함수 선언 | 최상위에서만 |
| 메서드 | str, []T, Map의 있는 메서드 전부(`trim()`, `lastIndexOf` 포함)와 Python 이름의 대응 |
| 없는 것 | `abs`, `sum`, `sorted`, `enumerate`, `zip`, `xs.map`, `xs.filter`, json, regex, time |
| 오류 목록 | 문구가 고치는 법을 말하지 않는 오류만 (26줄). 나머지는 "문구대로 고친다" 한 줄 |

크기: 영문판 20.4KB, 시스템 프롬프트 전체 21,530바이트(첫 요청 입력 약 6,800~6,900토큰, 5절). TODO의 "4,000토큰 이하" 목표를 넘는다. 목표를 바꿀지 안내를 줄일지는 사용자가 정한다. 줄일 자리는 오류 목록(cyber가 문구를 보강하면 줄이 빠진다)과 "Python과 다른 것"의 문법 줄이다.

## 9. 본체 아키텍처에 주는 뜻 (추천, 확정은 본체를 만들 때 사용자가)

| 번호 | 추천 | 근거 |
|---|---|---|
| 1 | 구성요소와 경계(명세 01)는 그대로 간다 | 스파이크 2의 세 파일(provider, vm, main)이 명세의 provider, runtime+caps, loop와 같은 선으로 자연히 갈렸다 |
| 2 | 능력은 모두 `Future[!T]`를 돌려주고 머리말 래퍼가 await한다. 승인이 필요 없으면 호스트 함수 안에서 바로 완료한다 | 3.2, 3.3. 능력의 모양이 하나가 되고, 등급이 바뀌어도 선언이 바뀌지 않는다 |
| 3 | 검증은 세션 VM에서 `cl_vm_validate`로 바로 한다 | 3.5. 이스케이프 오류의 세션 소실(7.1)이 고쳐지는 것이 선행 조건이다 |
| 4 | 호스트는 세션이 reset된 것을 알아야 하고, 알면 도구 결과에 "variables were reset"을 붙인다 | 7.1. 상한에 걸린 뒤와 같은 문구로 모델에게 알린다. cyber에 알림 길을 요청했다 |
| 5 | 호스트 로더는 허용 목록으로 쓴다 | 3.6 |
| 6 | 능력 함수는 메인 스레드가 아니면 panic을 돌려준다 (spawn 차단 옵션이 생길 때까지) | 3.6 |
| 7 | 프로세스 실행 능력은 자체 시간 상한, 표준 입력 차단, 출력 크기 상한, 취소를 가진다 | VM의 타이머는 승인 뒤 루프가 돌리는 프로세스에 닿지 않는다 |
| 8 | 읽기 능력도 권한 프로파일의 대상으로 둔다 (작업 폴더 밖 읽기는 승인) | 읽은 것은 모두 모델 제공자에게 간다 |
| 9 | cyber.h는 손으로 쓴 extern 선언으로 감싼다 (runtime/cy.zig 한 파일) | 3.1. 빌드 의존이 줄고, 쓰는 표면이 한눈에 보인다. 대가는 cyber가 구조체 배치를 바꾸면 손으로 따라가야 하는 것이다 |
| 10 | 메시지 모델은 스파이크의 모양(블록 넷, thinking에 불투명 칸)에서 시작한다 | 4.2 |
| 11 | 끝난 이유와 사용량은 어댑터가 정규화한다. 사용량은 "전체 입력, 그중 캐시, 출력" 셋으로 맞춘다 | 4.1 |
| 12 | SSE는 줄 버퍼에 기대지 않는 조각 단위 해석기로 쓴다 | 4.3 |
| 13 | 검증에 `cl_vm_set_error_recovery`와 `cl_vm_compile_report`를 켜서 오류를 전부 돌려주는 것을 시험한다 | 모델은 한 스텝에 오류 하나씩 고친다(5절). 스파이크에서는 시험하지 않았다 |
| 14 | 안내 문서의 예제와 조언은 에이전트와 같은 조건(세션 VM, persist_main, 검증 뒤 실행)에서 확인한다. 안내 검사 도구를 둔다면 runtime 경계 위에서 돈다 | 3.5, 8 |
| 15 | 안내는 회차에서 모델이 틀린 곳으로 고친다. 문구가 고치는 법을 말하는 오류는 안내에 넣지 않는다 | 5.1. 안내의 크기를 지키는 기준이 된다 |
| 16 | 평가의 모델 목록에 크기가 다른 모델을 함께 넣는다 (deepseek-chat, qwen flash, qwen max). direct 모드는 대조군이면서 작은 모델용 기본값 후보로 본다 | 5 |

## 10. 아직 모르는 것

- CodeAct 판정. 과제 셋으로는 말할 수 없다. 평가 도구(eval/)가 필요하다.
- tars 게스트에서의 기준 빌드.
- json 모듈 없이 돌렸다. JSON을 다루는 과제는 넣지 않았다.
- 긴 세션(수십 스텝)에서의 VM 메모리와 히스토리 크기, 컴팩션.
- 대화형 프런트엔드. 스파이크는 한 번 묻고 끝나는 헤드리스였고 승인은 자동이었다.
- 인터럽트(Esc)로 스트림과 실행을 끊는 것.
- Claude 모델. 키가 없어 돌리지 않았다.
- 이스케이프 말고도 맨 Zig 오류로 컴파일이 끝나 세션을 지우는 입력이 있는지. 찾은 것은 둘(`InvalidEscapeSeq`, `InvalidCharacter`)이다.

## 11. 스파이크 코드 지도와 다시 돌리는 법

| 경로 | 내용 | 실행 |
|---|---|---|
| spike/s1 | 호스트 경계 검사 35개, 세션 재생, 관찰 둘 | `zig build && ./zig-out/bin/s1`, `s1 replay <파일> [nv]` (스크립트를 `=====` 줄로 나눈다, 검증과 실행 결과, 출력, 오류 첫 줄을 찍는다. `nv`면 검증 없이 실행), `s1 spawn`, `s1 order` (인자 읽기 순서를 어긴다, 죽는다) |
| spike/s2a | 두 형식의 원문 응답 받기 | `./run.sh`, 결과는 out/*.sse |
| spike/s2 | 최소 에이전트 루프 (direct, codeact), 제공자 넷 | `./zig-out/bin/s2 --provider ds-anth --mode codeact "질문"`, `./compare.sh <제공자> [모델] [모드] [과제]` |
| spike/s3 | tars 게스트 구동 스크립트 | 6절 |

- 두 스파이크의 cyber 의존은 커밋 63e35e88로 고정돼 있다(build.zig.zon).
- 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다. 이 가두기를 풀지 않는다.
- compare.sh는 결과를 out/cmp-*에 덮어쓴다. 회차를 여럿 돌리면 회차마다 다른 폴더로 옮긴다(out/dev/<회차>/). 회차는 차례로 돌린다(같은 작업 폴더 /tmp/tars-agent-s2를 쓰므로 겹치면 결과가 섞인다). s2는 실행마다 안내 파일을 읽으므로 회차 도중에 안내를 고치지 않는다.
- cyber의 기준 빌드를 올리면: 의존을 올리고, s1(6i 포함)과 안내의 탐침, 코드 블록 11개를 CLI와 `replay`로 다시 돌리고, 문서를 새 빌드의 사실로 고쳐 쓴다.

읽을 가치가 있는 순서: s2/src/main.zig(루프), s2/src/provider.zig(메시지 모델과 어댑터), s2/src/vm.zig(검증, 실행, 승인), s1/src/main.zig(검사 목록).
