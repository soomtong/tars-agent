# M0 스파이크 검토 결과 (2026-11-13)

스파이크 셋을 Claude가 혼자 구현하고 검토했다 (ADR 0012의 덧붙임). 이 문서는 무엇을 만들었고, 무엇이 확인됐고, 무엇이 깨졌고, 본체의 아키텍처에 어떤 뜻이 있는지를 적는다. 코드는 spike/에 있고 버릴 것이다. 숫자는 모두 이 날 실제로 돌려서 얻은 것이다.

읽는 순서: 1절(한 장 요약), 2절(에이전트는 어떻게 도는가), 그 뒤는 필요한 절만.

## 1. 한 장 요약

| 질문 | 답 | 근거 |
|---|---|---|
| Zig 호스트가 libcyber를 링크해 VM을 돌릴 수 있는가 | 된다 | 스파이크 1, 검사 31개 통과 (macOS, tars 게스트) |
| cyber를 build.zig.zon 의존으로 쓸 수 있는가 | 받아지지만 아티팩트를 내보내지 않는다. 우회로 링크했다 | 3.1 |
| 승인 대기를 VM 밖에서 하는 설계(ADR 0011, 0016)가 실제로 도는가 | 돈다. 승인, 거부, 취소, 동시 요청 모두 | 3.3 |
| 상한 넷(연료, 벽시계, 스택, 메모리)이 폭주를 멈추는가 | 멈춘다. VM은 계속 쓸 수 있다 | 3.4 |
| Zig std.http로 모델 API에 스트리밍 요청을 보낼 수 있는가 | 된다. macOS와 tars 게스트 모두, TLS와 CA 묶음 포함 | 4.3, 6 |
| 전송 형식 둘을 메시지 모델 하나로 받을 수 있는가 (ADR 0015) | 된다. 블록 넷과 불투명 칸 하나로 충분했다 | 4.2 |
| CodeAct가 실제 과제를 푸는가 | 푼다. 다만 모델에 따라 차이가 크다 | 5 |
| x86_64-linux-gnu 교차 빌드가 tars에서 도는가 | 돈다. 에이전트 루프까지 게스트 안에서 돌렸다 | 6 |

가장 무거운 발견 셋:

1. cyber 0.4.9는 실패한 컴파일 뒤에 다음 컴파일에서 프로세스가 죽는 경우가 있다. 첫 CodeAct 세션의 일곱 번째 스텝에서 났고, 스크립트 두 개로 재현된다 (7.1). 에이전트에서 컴파일 실패는 일상이므로 이것은 드문 경로가 아니다.
2. cyber 0.4.9는 `!str` 값을 복사하지 못한다 (컴파일 오류). 그래서 능력이 `Future[!str]`을 돌려주는 ADR 0011의 모양을 그대로 쓸 수 없었다 (7.2). 스파이크는 손잡이(handle) 우회로 갔다.
3. CodeAct의 성패는 모델이 Cyber를 얼마나 정확히 쓰느냐에 달려 있고, 작은 모델(qwen3.8-flash)은 과제당 6~10번 컴파일에 실패했다. deepseek-chat과 qwen3.8-max는 0~3번이었다 (5).

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

- 모델은 상태가 없다. 매 스텝마다 대화 전체를 다시 보낸다. 실제 기록: 스텝 1의 요청은 609바이트(메시지 1개), 스텝 2는 971바이트(메시지 3개). 대화가 길어질수록 요청이 커지고, 그래서 캐시와 컴팩션이 필요해진다.
- 모델은 아무것도 실행하지 않는다. "이 도구를 이 인자로 불러 달라"는 글을 낼 뿐이다. 실행은 호스트가 하고, 그래서 권한 게이트를 호스트에 둘 수 있다.
- 응답은 조각으로 온다. 도구의 인자도 JSON 조각으로 나뉘어 온다(`{"`, `cmd`, `"`, `: "`, `wc`, ` -`, `l` ...). 다 모은 뒤에야 해석할 수 있다. 그래서 코드를 써지는 대로 화면에 보이는 것과 실행하는 것은 다른 시점이다.
- 도구 결과는 사용자 역할의 메시지로 돌아간다. 모델에게는 결과도 대화의 한 줄이다. 오류도 결과다: 실패를 글로 돌려주면 모델이 읽고 고친다.
- 끝은 모델이 정한다. 도구 호출 없이 글만 내면 그것이 답이다. 호스트는 한도(스텝 수)로만 끊는다.

direct와 CodeAct의 차이는 도구 하나의 모양뿐이다.

| | direct | CodeAct |
|---|---|---|
| 도구 | sh(cmd) | run(code) |
| 모델이 쓰는 것 | 셸 명령 한 줄 | Cyber 스크립트 |
| 호스트가 하는 것 | 프로세스 실행 | 검증(컴파일만), 상한을 걸고 VM에서 실행, 능력 호출마다 승인 |
| 한 스텝에 할 수 있는 일 | 명령 하나 (셸 파이프로 묶기는 가능) | 호출 여럿, 분기, 반복, 중간값 가공 |
| 권한을 거는 자리 | 명령 문자열 전체 | 능력 호출 하나하나 (경로, 명령이 인자로 보인다) |

실제 CodeAct 스텝 하나의 기록 (deepseek-chat):

~~~text
[도구 호출] run {"code": "type Row:\n    name str\n    count int\n\nnames := []str{'app.log', 'db.log', 'web.log'}\nrows := []Row{}\nfor names |n|:\n    text := fs.read('logs/%{n}')!\n    c := 0\n    ..."}
    [승인] write report.txt
    [승인] exec cat report.txt
    [실행] 종류=ok 능력 호출 7회
[도구 결과] --- report.txt ---
web.log: 23
db.log: 8
app.log: 7
~~~

스크립트 하나가 파일 셋을 읽고, 세고, 정렬하고, 쓰고, 확인했다. 능력 호출은 일곱 번이었고 모델 왕복은 한 번이었다. 승인이 필요한 호출(write, exec)마다 스크립트가 멈추고 루프가 결정했다.

## 3. 스파이크 1: 호스트 경계

코드: spike/s1 (main.zig 747줄). 실행: `zig build && ./zig-out/bin/s1`. 검사 31개가 PASS/FAIL로 찍힌다.

### 3.1 링크

- `zig fetch --save=cyber "git+https://github.com/soomtong/cyber#0.4.9"`로 받아진다. Zig 0.17.1은 받은 패키지를 프로젝트의 zig-pkg/에 푼다.
- `b.dependency("cyber").artifact("cyber")`는 실패한다(panic: unable to find artifact "cyber"). cyber의 build.zig가 라이브러리를 `lib` 스텝 아래에서만 설치하고 의존 쪽에 내보내지 않기 때문이다. C1 "빌드 내보내기"가 필요하다는 증거다.
- 우회: build.zig에서 받은 패키지 폴더를 작업 폴더로 `zig build lib -Doptimize=ReleaseFast -Dffi=false -Dstatic=true -Dtarget=...`를 실행하고 그 산출물(libcyber.a)을 링크한다(spike/s1/build.zig). 동작하고, 교차 빌드도 대상 삼중항만 넘기면 된다. 처음 한 번 35초, 그 뒤는 캐시된다.
- 이 우회로 만든 라이브러리의 버전 문자열은 `Cyber 0.4.9-DEV build-0-local`이다. 릴리스 표기를 얻으려면 -Ddev=false와 빌드 번호를 넘겨야 한다.
- Zig 0.17.1에는 `@cImport`가 없다. cyber.h를 Zig에서 쓰는 길은 둘이다: translate-c 패키지(cyber가 쓰는 것, 빌드 의존이 하나 는다)로 모듈을 만들거나, 쓰는 함수 약 50개의 extern 선언을 손으로 쓴다. 스파이크는 앞의 것을 썼다. 본체의 추천은 8절.
- libcyber.a는 2.36 MB다. mimalloc 심볼은 없다(FFI를 끈 라이브러리 빌드에는 들어가지 않는다). deps.md의 mimalloc 행은 틀렸다.

### 3.2 능력 바인딩

- 호스트 함수는 `fn (t: *CLThread) callconv(.c) CLRet` 하나의 모양이다. 인자는 커서처럼 읽는다: 반환 슬롯(cl_thread_ret)을 먼저, 그다음 매개변수를 선언 순서대로(cl_thread_str, cl_thread_int). 순서를 어기면 프로세스가 죽는다. 스파이크 2에서 반환 슬롯을 나중에 잡았다가 cl_thread_str에서 Segmentation fault가 났다.
- 값 매개변수(str)는 호스트가 소유하므로 cl_str_deinit으로 놓는다.
- 뜻: ADR 0006의 "Cyber 값 변환과 소유권 해제는 생성된 바인딩 층 한 곳에서만 한다"가 편의가 아니라 안전 장치다. 손으로 쓴 호스트 함수가 여럿이면 이 실수는 반드시 난다.
- `#[bind]` 함수에 기본값 매개변수는 쓸 수 없다(ParseError: Expected `,`). Cyber에 기본값 매개변수 자체가 없다. 필요하면 머리말에 인자 수가 다른 래퍼를 둔다. 08 문서의 미확인 항목이 닫혔다.
- 점 표기(`use fs`, `fs.read`)는 호스트 로더가 "fs"라는 이름에 모듈 소스를 돌려주는 것으로 그대로 된다.

### 3.3 승인 대기 (ADR 0011, 0016)

모양: 능력은 일을 하지 않고 요청을 표에 적은 뒤 미완료 Future를 돌려준다. 머리말의 래퍼가 await하고, eval이 CL_AWAIT로 돌아오면 루프가 결정한다.

| 검사 | 결과 |
|---|---|
| 승인 둘, 거부 하나 | 스크립트는 거부를 error.Denied 값으로 받아 계속 돈다. CL_AWAIT 3회 |
| 두 번째 승인에서 취소 | cl_vm_abandon. 두 번째 파일은 만들어지지 않고 VM은 다음 스크립트를 받는다 |
| 승인이 필요 없는 read | 호스트 함수 안에서 Future를 바로 완료한다. CL_AWAIT 0회. 스크립트 쪽 모양은 같다 |
| await하지 않고 버린 요청 | 아무 일도 하지 않는다. 물은 요청 번호는 2 하나였다 (승인 우회 없음) |
| 스크립트가 만든 미완료 Future | 태그 0이라 abandon, 결과는 INTERRUPT |
| scope 블록의 요청 둘 | 번호 순(1, 2)으로 하나씩 물었다 |
| 하나를 거부 | 나머지는 묻지 않은 채 버려졌다. 완료 안 된 요청 1개가 표에 남고, eval 끝에 비운다 |
| 중첩 scope 블록 (cyber F-111) | 번호 순 1, 2, 3으로 끝까지 갔다 |
| proc.exec | 승인 뒤 루프가 프로세스를 돌리고 stdout을 돌려준다 |

ADR 0011과 0016의 설계는 고칠 것 없이 돈다. 한 가지만 다르다: `Future[!str]`을 쓸 수 없어(7.2) 문자열 결과는 `Future[!int]`로 손잡이를 돌려주고 래퍼가 `take(h)`로 꺼낸다.

### 3.4 상한

| 상한 | 스크립트 | 결과 |
|---|---|---|
| 연료 100,000 | `while true` | INTERRUPT (panic: Out of fuel.), 1ms 안 |
| 벽시계 200ms (타이머 스레드의 cl_vm_interrupt) | `while true` | INTERRUPT, 210ms 뒤 |
| 스택 1 MiB | 끝없는 재귀 | PANIC (Stack overflow. The stack limit is 1048576 bytes.) |
| 메모리 +8 MiB | 끝없는 추가 | PANIC (OutOfMemory). VM 메모리 1938 KiB에서 2013 KiB로 돌아왔다 |

상한에 걸린 뒤: 함수 선언은 남고 지역 변수는 사라진다(직접 확인: 함수 호출은 되고 변수는 Undeclared). 명세 02의 "variables were reset" 문구가 맞다.

### 3.5 세션과 검증

- persist_main: 변수, 함수, use가 다음 eval로 이어진다.
- validate: 세션의 변수를 보면서 컴파일만 한다. 구조화된 오류가 온다(kind=2, line=1, col=6, len=4, "Undeclared variable `totl`."). validate한 선언은 넘어가지 않는다.
- validate에는 설정 인자가 없는데 raw 포인터를 거부했다. 세션의 설정(deny_raw_ptrs)을 따른다.
- 비용 (macOS arm64): validate 200회 2ms, eval 200회 2ms. VM 생성과 첫 eval은 개당 2ms, VM 하나가 쥔 메모리 약 1.9 MiB. tars 게스트(QEMU의 소프트웨어 에뮬레이션)에서는 개당 53ms였다. 실기에서는 그 사이일 것이다.

### 3.6 샌드박스 경계

| 시도 | 결과 |
|---|---|
| `use c` | 호스트 로더가 false를 돌려준다. CompileError: Failed to load module: c |
| `use os` | 라이브러리에 없다. 같은 오류 |
| `Ptr[int](0)` | CompileError: Raw pointer type ... is not allowed (deny_raw_ptrs) |
| deny_raw_ptrs와 호스트 모듈 | 함께 동작한다. 호스트 모듈의 선언은 막히지 않는다 |
| `@bitCast` | CompileError: internal to the builtin modules |
| `use io` | 기본 로더가 준다. io 모듈에 무엇이 있는지는 보지 못했다. 본체에서 허용 목록으로 뒤집어야 한다 |
| `spawn(work, {21})` | 된다. 막는 장치가 없다 |
| spawn 스레드 안의 능력 호출 | 된다. 능력 함수가 스레드에서 불린다 |
| spawn 스레드 안의 무한 루프 | 연료와 타이머가 멈춘다 (INTERRUPT, 501ms) |

spawn에 대해: 폭주는 멈추지만, 능력 함수가 메인 스레드가 아닌 곳에서 불리므로 요청 표와 승인 흐름이 스레드에 안전하지 않다. cyber.h도 Future 생성은 메인 스레드에서 하라고 적는다. C3 "spawn 차단"이 필요하다는 증거다. 그 전의 가장 싼 방법은 능력 함수 첫머리에서 메인 스레드인지 확인하고 아니면 panic을 돌려주는 것이다.

로더는 지금 "c와 test만 거부"하는 차단 목록이다. 기본 로더에 모듈이 더해지면 그대로 스크립트에 열린다. 본체는 허용 목록(core, math, 그리고 우리 모듈)으로 가야 한다.

## 4. 스파이크 2: 제공자

코드: spike/s2a (curl 스크립트와 원문 응답), spike/s2/src/provider.zig (407줄).

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

- OpenRouter의 Anthropic 형식에서 deepseek-chat(상류 DeepInfra)은 tool_use 블록을 내면서 stop_reason을 end_turn으로 줬다. qwen3.8-flash는 tool_use로 줬다. 상류 제공자에 따라 다르다.
- DeepSeek의 Anthropic 형식에서 deepseek-reasoner는 thinking 블록을 내지만 사고 글은 비어 있고 signature에 메시지 id가 들어 있었다.
- 사용량의 뜻이 다르다. DeepSeek의 Anthropic 형식은 input_tokens가 캐시되지 않은 몫이고 캐시된 몫은 cache_read_input_tokens에 따로 온다. OpenAI 형식의 prompt_tokens는 캐시된 몫을 포함하고 그중 얼마가 캐시인지는 prompt_tokens_details.cached_tokens에 온다. OpenRouter는 요청별 cost를 준다.
- DeepSeek은 요청에 캐시 지점을 표시하지 않아도 앞부분을 자동으로 캐시한다. CodeAct 세션에서 입력의 90% 이상이 캐시로 잡혔다.

### 4.2 메시지 모델과 어댑터 (ADR 0015의 확인)

provider.zig가 ADR 0015의 방향을 그대로 옮겼다.

~~~text
Block   = text | thinking{text, raw} | tool_call{id, name, args_json} | tool_result{id, content, is_error}
Message = {role: user | assistant, blocks}
Provider(데이터) = {name, format, url, auth, key_env, model}
어댑터 = buildBody(형식, 히스토리) -> 요청 본문,  스트림 누적기(형식) -> 내부 이벤트와 Message
~~~

- 블록 넷으로 두 형식, 제공자 둘, 모델 셋의 응답을 모두 받았다. 다섯 번째 블록은 필요하지 않았다.
- 불투명 칸(thinking.raw)은 필요하다. Anthropic 형식의 signature가 거기 들어가고 다음 요청에 그대로 되돌아간다. 사고가 켜진 qwen으로 여러 스텝을 돌 때 두 형식 모두 사고를 되돌려 보냈고 거절(400)은 없었다. OpenAI 형식에서는 reasoning_content 필드로 되돌렸다.
- 끝난 이유를 내용에서 다시 계산하는 규칙(도구 호출이 있으면 tool_use)이 위의 어긋남을 흡수했다.
- 제공자 넷이 표의 네 줄이다. 어댑터 코드는 형식 수만큼인 둘이다.
- OpenAI 형식으로 내보낼 때 블록 목록을 풀어야 한다: tool_result는 별도 메시지로 나가고, text, thinking, tool_call은 assistant 메시지 하나의 필드 셋으로 흩어진다. 한 메시지 안의 블록 순서(글 다음 도구인지, 도구 다음 글인지)는 OpenAI 형식에서 사라진다.
- 내부 이벤트는 넷으로 충분했다: 글 조각, 사고 조각, 도구 시작, 인자 조각.

보지 못한 것: 한 응답에 도구 호출 여럿(코드는 다루지만 모델이 그렇게 낸 적이 없다), max_tokens로 잘린 응답, 세션 중간에 형식을 바꾸는 것, 스트림 중간에 끊긴 연결.

### 4.3 Zig의 HTTP

- std.http.Client로 요청을 보내고 응답 본문을 줄 단위로 읽는다. SSE 해석은 `data:`로 시작하는 줄만 JSON으로 푸는 것으로 충분했다. `event:` 줄은 쓰지 않았다(Anthropic 형식도 data 안에 type이 있다).
- TLS와 CA 묶음은 macOS와 tars 게스트(Debian trixie의 /etc/ssl/certs/ca-certificates.crt) 모두에서 됐다. curl 프로세스 대안은 필요 없다.
- accept-encoding은 identity로 고정했다. 압축을 받으면 줄 단위 읽기 앞에 풀기 단계가 필요하다.
- SSE의 한 줄이 버퍼보다 길면 읽기가 실패한다(StreamTooLong). 스파이크는 1 MiB 버퍼를 줬다. 본체는 조각 단위로 읽는 해석기가 필요하다.
- Zig 0.17.1의 std는 Io 인터페이스를 인자로 받는 모양이다(파일, 프로세스, 시계, http 모두). main이 받은 io를 끝까지 넘겨야 한다.

## 5. direct 대 CodeAct: 작은 비교

과제 셋, 각 1회. 평가가 아니라 감을 잡기 위한 것이다. 판정(ADR 0006)은 과제 20개를 3회씩 돌린 뒤에 한다. 원자료는 spike/s2/out/*.tsv.

- T1: 로그 파일 셋에서 ERROR 줄을 세어 정렬해 보고서 파일로 쓰기
- T2: .py 파일들에서 대문자 TODO를 찾아 파일별 개수를 쓰기
- T3: 설정 파일의 한 구획에서만 값을 바꾸고 줄을 더하기

| 모델 | 모드 | T1 | T2 | T3 | 스텝 (T1/T2/T3) | 컴파일 오류 (T1/T2/T3) | 걸린 시간 합 |
|---|---|---|---|---|---|---|---|
| deepseek-chat | direct | 통과 | 통과 | 통과 | 6 / 7 / 7 | | 22초 |
| deepseek-chat | codeact | 통과 | 통과 | 통과 | 6 / 5 / 3 | 2 / 1 / 0 | 18초 |
| qwen3.8-flash | direct | 통과 | 통과 | 통과 | 4 / 6 / 8 | | 69초 |
| qwen3.8-flash | codeact | 통과 | 실패 | 통과 | 13 / 15 / 14 | 6 / 10 / 8 | 177초 |
| qwen3.8-max | codeact | 통과 | 통과 | 통과 | 5 / 8 / 15 | 0 / 1 / 3 | 401초 |

읽는 법:

- deepseek-chat에서는 CodeAct가 direct보다 스텝이 적었다(14 대 20). 한 스크립트에 여러 일을 담는 이점이 실제로 나타났다.
- qwen3.8-flash에서는 반대다. Cyber를 틀리는 횟수가 과제를 덮었다. T2는 스텝 한도(15)에 걸려 실패했다.
- 시스템 프롬프트의 크기가 다르다. direct는 330바이트, CodeAct는 Cyber 안내를 포함해 14,026바이트(약 4,450 토큰)다. 매 스텝 다시 보내므로 캐시가 없으면 스텝마다 그만큼이 든다. DeepSeek은 자동 캐시가 이것을 덮었다.
- 모델이 틀린 Cyber의 예 (실제 기록):

| 모델이 쓴 것 | 오류 | 원인 |
|---|---|---|
| `for 'a','b','c' \|p\|:` | ParseError: Expected :. | 목록 리터럴을 쓰지 않음 |
| `for ['a.py','b.py'] \|f\|:` | ParseError: Expected `]`. | Python의 목록 리터럴 |
| `Map[str, int]{'app': 7}` | ParseError: Expected closing brace. | Map 리터럴이 없다 |
| `names.sort(\|a, b\| counts[a] > counts[b])` | Can only capture variables declared with the reference types | 클로저 캡처 규칙 |
| `'\n'.join(out)` | Can not find the symbol `join` in `str`. | Python의 메서드 방향 |
| `out.pop()`, `names.find(x)`, `s.startswith(x)` | Can not find the symbol ... | 없는 메서드를 추측 |
| `print(proc.exec('...'))` (! 없이) | Expected type instance of `Result`, found `Ptr[!str]`. core:2918:49 | 7.2의 결함이 엉뚱한 문구로 드러났다 |

  앞의 넷은 안내 문서에 이미 있는 내용이다. 모델이 읽고도 틀렸다. 뒤의 것들은 "str과 목록에 어떤 메서드가 있는가"를 안내가 알려 주지 않아서다. 모델은 표준 라이브러리 소스를 찾으려고 `find / -name "str.cy"`를 돌리기까지 했다. 메서드 목록을 보여 주는 길(안내의 표나 help 능력)이 필요하다.
- 검증(validate)은 제 몫을 했다. 비교 실행에서 틀린 스크립트 31개가 한 줄도 실행되지 않았고, 오류의 줄과 열이 모델에게 돌아가 대부분 다음 스텝에 고쳐졌다.

스파이크를 돌리며 겪은 운영상의 사실 둘:

- 모델이 쓴 명령을 그대로 실행하는 것은 위험하다. qwen이 `ls ~`와 `find /`를 돌렸다. 쓰기는 이미 막혀 있었지만 읽기는 열려 있어서, 실행이 끝났다면 홈 폴더 목록이 도구 결과로 제공자에게 갔을 것이다. 결과가 돌아가기 전에 프로세스를 끊었고 나간 것은 없다. 그 뒤 샌드박스에 사용자 폴더 읽기 차단을 더했다(spike/s2/src/jail.zig). 뜻: 읽기 능력도 권한의 대상이다. 읽은 것은 모두 모델 제공자에게 간다.
- 같은 명령(`find /`)은 끝나지 않았다. 스크립트의 벽시계 타이머는 VM을 멈추지만, 승인 뒤 루프가 돌리는 프로세스는 VM 밖이라 타이머가 닿지 않는다. 프로세스 실행에는 자체 시간 상한과 중단 수단이 있어야 한다.

## 6. 스파이크 3: 교차 빌드와 tars 게스트

- `zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseFast`가 macOS arm64에서 43초에 끝난다. 산출물은 glibc 동적 링크 ELF다(s1 6.3 MB, s2 12.6 MB, 둘 다 디버그 정보 포함, strip 전).
- tars-linux의 산출물(커널 6.18.60, initrd)을 고치지 않고 썼다: initrd 사본 뒤에 스파이크 바이너리를 담은 gzip cpio를 이어 붙여 QEMU로 부팅했다. 압축하지 않은 cpio를 이어 붙이면 풀리지 않는다.
- 게스트에서 s1의 검사 31개가 모두 통과했다. 상한, 승인 흐름, 프로세스 실행(proc.exec) 포함.
- 게스트에 e1000e NIC를 붙이고 `dhcpcd -w eth0`로 주소를 받은 뒤 s2를 돌렸다. direct(Anthropic 형식)와 CodeAct(OpenAI 형식) 모두 DeepSeek과 통신해 과제를 끝냈다. 즉 에이전트 루프 전체가 tars 안에서 돈다.
- 게스트를 모는 방법: 시리얼을 유닉스 소켓으로 열고 명령을 보낸다. 시리얼의 셸은 fish라 Enter는 CR이다. 구동 스크립트는 spike/s3/guest.py.
- tars 게스트에 없는 것: perl, free. 있는 것: curl, dhcpcd, CA 묶음.

보지 못한 것: 실기 노트북, tars 터미널 패널 안에서의 화면 출력(시리얼 셸로만 돌렸다), Landlock(M5).

## 7. cyber의 결함과 요청

요청서는 docs/requests/cyber-m0-spike-findings.md에 따로 썼다.

### 7.1 실패한 컴파일 뒤 다음 컴파일에서 죽는다

같은 VM에서 차례로 돌린다(validate든 eval이든 같다).

~~~cy
names := []str{'a', 'b'}
counts := Map[str, int]{}
names.sort(|a, b| counts[a] > counts[b])
~~~

이것은 CompileError(Can only capture variables...)로 끝난다. 정상이다. 이어서

~~~cy
counts := Map[str, int]{}
counts['a'] = 1
print(counts['a'])
~~~

를 컴파일하면 Segmentation fault at address 0x0이다. 재현: `spike/s1/zig-out/bin/s1 replay spike/s1/crash-validate.txt`.

같은 계열로 보이는 것 하나 더: 호스트 모듈의 소스가 컴파일에 실패하면, 그 모듈을 세 번째로 들이는 eval에서 죽는다(`s1 crash 1`, `s1 crash 2`). 실패한 컴파일이 남긴 반쯤 만들어진 상태(템플릿 인스턴스나 모듈)를 다음 컴파일이 밟는 것으로 추정한다. 추정이고 확인하지 않았다.

스파이크의 우회: 검증을 fork한 자식 프로세스에서 한다(spike/s2/src/vm.zig의 validateInChild). 자식은 세션 VM의 복사본을 보므로 세션의 변수가 보이고, 실패하거나 죽어도 부모의 VM은 그대로다. 부모는 검증을 통과한 코드만 컴파일한다. 이 우회를 넣은 뒤 CodeAct 세션 열한 번(컴파일 실패 31회)에서 부모가 죽은 적은 없고, 자식이 죽은 적도 없었다. 자식은 매번 부모의 깨끗한 상태에서 시작하므로 실패가 쌓이지 않는다.

### 7.2 `!str` 값을 복사하지 못한다

~~~cy
fn g() -> !str:
    return 'a'
x := g()
y := x
~~~

CompileError: Expected type instance of `Result`, found `Ptr[!str]`. 위치는 core:2918:49. `!int`는 된다. `Future[!str]`의 await가 안에서 값을 복사하므로 `Future[!str]`을 쓸 수 없다. 모델이 `!`를 빠뜨리고 `print(proc.exec(...))`를 써도 같은 오류가 core의 줄 번호와 함께 나와서 모델이 원인을 알 수 없다.

### 7.3 그 밖

- 빌드 내보내기(3.1), 의존으로 빌드할 때의 버전 표기
- spawn 차단 옵션(3.6)
- 호스트 함수의 인자 읽기 순서를 어기면 죽는다(3.2). 문서에 순서를 적거나 디버그 빌드에서 확인
- str과 목록의 메서드 목록을 기계가 읽을 수 있게 내는 수단(5)

## 8. 본체 아키텍처에 주는 뜻 (추천, 확정은 본체를 만들 때 사용자가)

| 번호 | 추천 | 근거 |
|---|---|---|
| 1 | 구성요소와 경계(명세 01)는 그대로 간다 | 스파이크 2의 세 파일(provider, vm, main)이 명세의 provider, runtime+caps, loop와 같은 선으로 자연히 갈렸다 |
| 2 | 능력은 모두 `Future[!T]`를 돌려주고 머리말 래퍼가 await한다. 승인이 필요 없으면 호스트 함수 안에서 바로 완료한다 | 3.3. 능력의 모양이 하나가 되고, 등급이 바뀌어도 선언이 바뀌지 않는다 |
| 3 | 7.2가 고쳐질 때까지 문자열 결과는 손잡이로 돌려준다. 고쳐지면 걷어 낸다 | 3.3 |
| 4 | 검증을 자식 프로세스에서 하는 것을 7.1의 임시 대응으로 본체에 넣을지 정한다. 넣지 않으려면 7.1의 수정이 M1의 선행 조건이다 | 7.1. ADR 0009의 "실행 프로세스 분리"를 되살리는 조건(죽는 비율이 측정된 문제)에 해당한다 |
| 5 | 호스트 로더는 허용 목록으로 쓴다 | 3.6 |
| 6 | 능력 함수는 메인 스레드가 아니면 panic을 돌려준다 (spawn 차단 옵션이 생길 때까지) | 3.6 |
| 7 | 프로세스 실행 능력은 자체 시간 상한, 표준 입력 차단, 출력 크기 상한, 취소를 가진다 | 5 |
| 8 | 읽기 능력도 권한 프로파일의 대상으로 둔다 (작업 폴더 밖 읽기는 승인) | 5 |
| 9 | cyber.h는 손으로 쓴 extern 선언으로 감싼다 (runtime/cy.zig 한 파일) | 3.1. 빌드 의존이 줄고, 쓰는 표면이 한눈에 보이고, 명세의 "cl_*를 cy.zig 한 파일이 감싼다"와 같다. 대가는 cyber가 구조체 배치를 바꾸면 손으로 따라가야 하는 것이다 |
| 10 | 메시지 모델은 스파이크의 모양(블록 넷, thinking에 불투명 칸)에서 시작한다 | 4.2 |
| 11 | 끝난 이유와 사용량은 어댑터가 정규화한다. 사용량은 "전체 입력, 그중 캐시, 출력" 셋으로 맞춘다 | 4.1 |
| 12 | SSE는 줄 버퍼에 기대지 않는 조각 단위 해석기로 쓴다 | 4.3 |
| 13 | 안내 문서에 str, 목록, Map의 메서드 표를 더하고, 평가 전에 한 번 더 다듬는다 | 5 |
| 14 | 평가의 모델 목록에 크기가 다른 모델을 함께 넣는다 (deepseek-chat, qwen flash, qwen max) | 5. CodeAct의 성패가 모델 크기에 크게 달려 있다 |
| 15 | direct 모드를 대조군으로만 두지 말고 작은 모델용 기본값 후보로 본다 | 5. ADR 0006의 판정 규칙이 이미 이 길을 열어 두었다 |

## 9. 아직 모르는 것

- CodeAct 판정. 과제 셋, 1회로는 말할 수 없다. 평가 도구(eval/)가 필요하다.
- 7.1의 범위. 재현 둘을 찾았을 뿐 어떤 실패가 상태를 남기는지 모른다.
- json 모듈 없이 돌렸다. JSON을 다루는 과제는 넣지 않았다.
- 긴 세션(수십 스텝)에서의 VM 메모리와 히스토리 크기, 컴팩션.
- 대화형 프런트엔드. 스파이크는 한 번 묻고 끝나는 헤드리스였고 승인은 자동이었다.
- 인터럽트(Esc)로 스트림과 실행을 끊는 것.
- Claude 모델. 키가 없어 돌리지 않았다.

## 10. 스파이크 코드 지도

| 경로 | 내용 | 실행 |
|---|---|---|
| spike/s1 | 호스트 경계 검사 31개, 죽는 경로 재현 | `zig build && ./zig-out/bin/s1`, `s1 replay crash-validate.txt`, `s1 crash 1`, `s1 spawn` |
| spike/s2a | 두 형식의 원문 응답 받기 | `./run.sh`, 결과는 out/*.sse |
| spike/s2 | 최소 에이전트 루프 (direct, codeact), 제공자 넷 | `./zig-out/bin/s2 --provider ds-anth --mode codeact "질문"`, `./compare.sh ds-anth` |
| spike/s3 | tars 게스트 구동 스크립트 | 문서 6절 |

읽을 가치가 있는 순서: s2/src/main.zig(루프, 236줄), s2/src/provider.zig(메시지 모델과 어댑터), s2/src/vm.zig(검증, 실행, 승인), s1/src/main.zig(검사 목록).
