# 제공자

코어와 모델 API 사이의 층이다. 코어(loop, session, 프런트엔드)는 자체 메시지 모델만 보고, 전송 형식의 차이는 형식별 어댑터가, 제공자의 차이는 설정 데이터가 흡수한다 (ADR 0015).

출처: ADR 0014(형식 둘, 개발 제공자, 키), ADR 0015(메시지 모델과 어댑터의 방향), ADR 0017(스파이크의 발견), ADR 0030(재시도 상한, Zig HTTP), ADR 0031(이 문서의 세부), 스파이크 검토 문서 4절과 9절(docs/spikes/2026-11-14-m0-spikes-review.md), spike/s2/src/provider.zig, spike/s2a/out/의 원문 응답, deps.md. 스파이크에서 본 것은 "스파이크에서", 보지 못한 것은 아래 "확인하지 않은 것"에 적는다.

## 형식과 제공자

형식과 제공자는 다른 축이다. 형식은 코드(어댑터)이고 제공자는 데이터다. 새 제공자는 설정 한 항목이고, 어댑터는 형식이 새로 생길 때만 는다.

- 형식은 둘이다: Anthropic Messages, OpenAI Chat Completions (ADR 0014). 어댑터는 provider/anthropic.zig, provider/openai.zig다 (01).
- 개발 기본 제공자는 DeepSeek이다. 테스트와 평가는 OpenRouter의 Qwen 계열로 한다. 평가 모델 목록과 판정의 기본 모델은 13에 있다 (ADR 0014).
- 한 제공자가 두 형식을 다 말할 수 있다. 스파이크에서 확인한 조합은 넷이다.

| 제공자 | 형식 | 주소 | 인증 |
|---|---|---|---|
| DeepSeek | Anthropic | https://api.deepseek.com/anthropic/v1/messages | x-api-key |
| DeepSeek | OpenAI | https://api.deepseek.com/chat/completions | Authorization: Bearer |
| OpenRouter | Anthropic | https://openrouter.ai/api/v1/messages | Authorization: Bearer |
| OpenRouter | OpenAI | https://openrouter.ai/api/v1/chat/completions | Authorization: Bearer |

- 스파이크에서 쓴 모델 ID: DeepSeek API의 `deepseek-flash`, OpenRouter의 `qwen/qwen3.8-flash`, `qwen/qwen3.8-max-0902`, `deepseek/deepseek-v4.1-flash-1017`. 모델 ID는 날짜가 붙은 것으로 고정한다. `~...-latest`와 DeepSeek의 옛 별칭 `deepseek-chat`은 가리키는 모델이 바뀐다 (ADR 0014).
- OpenRouter는 같은 모델을 여러 상류 제공자로 보낸다. 끝난 이유와 사용량 칸의 모양은 상류에 따라 달라질 수 있다.
- 세션 중간에 형식이 바뀌면 다른 형식의 원문은 버린다. 글과 도구 호출은 남고 사고는 빠진다 (ADR 0015).

## 자체 메시지 모델

~~~text
Message = { role: user | assistant, blocks: []Block }
Block   = text
        | thinking    { text, raw: { format, bytes } }
        | tool_call   { id, name, args_json }
        | tool_result { id, content, is_error }
~~~

- 블록 기반이다. Anthropic 형식이 이 모양이고 OpenAI 형식은 이 모양으로 옮길 수 있다. 반대 방향은 정보가 빠진다 (ADR 0015).
- 스파이크에서 블록 넷으로 두 형식, 제공자 둘, 모델 셋의 응답을 모두 받았다. 다섯 번째 블록은 필요하지 않았다.
- 불투명 원문 칸(raw)은 thinking에만 있다. 출처 형식(format)과 원문 바이트(bytes)를 담고, 받은 형식의 어댑터만 해석한다. 코어는 실어 나르기만 한다. Anthropic 형식에서는 signature가 들어가고, OpenAI 형식에서는 bytes가 비고 format만 남는다. 두 형식, 제공자 둘, 모델 셋에서 원문이 필요했던 것은 thinking의 signature뿐이다. 다른 블록의 원문 칸은 필요가 보일 때 더한다.
- 시스템 프롬프트는 히스토리 밖에 따로 둔다. 어댑터가 형식에 맞는 자리에 싣는다.
- args_json은 인자의 JSON 텍스트다. Anthropic 형식은 인자를 객체로, OpenAI 형식은 문자열로 주고받는다. 어댑터가 옮긴다.

## 어댑터

인터페이스는 작게 둘이다 (ADR 0015).

1. 요청 만들기: 시스템 프롬프트, 히스토리, 도구 정의, 옵션 -> 요청 본문(JSON)과 형식별 헤더.
2. 스트림 풀기: 응답의 SSE -> 내부 이벤트, 그리고 끝에서 assistant 메시지 하나, 끝난 이유, 사용량.

인터페이스가 두 형식의 사정에 묶이지 않았는지만 확인한다. 제3의 형식(후보는 OpenAI Responses API, Gemini)은 미리 만들지 않는다.

Zig에서는 형식 enum(`Format = enum { anthropic, openai }`)에 대한 switch로 고른다. provider.zig의 두 함수(요청 만들기, 스트림 풀기)가 format으로 갈라 provider/anthropic.zig, provider/openai.zig의 함수를 부른다. 스트림 누적기의 형식별 상태는 tagged union이다. vtable과 comptime 매개변수는 쓰지 않는다. 형식은 닫힌 집합이고, 런타임에 어댑터를 더할 일이 없다. 스파이크가 이 모양으로 갈렸다.

### 요청 만들기

스파이크 2a에서 본 두 형식의 모양이다.

| | Anthropic Messages | OpenAI Chat Completions |
|---|---|---|
| 시스템 프롬프트 | 최상위 `system` 필드 | `messages`의 첫 항목(role이 system) |
| 도구 정의 | `{name, description, input_schema}` | `{type: function, function: {name, description, parameters}}` |
| tool_call | assistant 메시지의 tool_use 블록, `input`은 객체 | assistant 메시지의 `tool_calls[]`, `function.arguments`는 문자열 |
| tool_result | user 메시지의 tool_result 블록(`tool_use_id`, `content`, `is_error`) | role이 tool인 별도 메시지(`tool_call_id`, `content`) |
| thinking | thinking 블록(`thinking`, `signature`) | assistant 메시지의 `reasoning_content` |
| 사용량 받기 | 기본으로 온다 | `stream_options: {include_usage: true}`로 켠다 |
| 추가 헤더 | `anthropic-version: 2023-06-01` | 없음 |

- OpenAI 형식으로 내보낼 때 블록 목록을 푼다. tool_result는 별도 메시지로 나가고, assistant의 text, thinking, tool_call은 메시지 하나의 필드 셋(`content`, `reasoning_content`, `tool_calls`)으로 흩어진다. 한 메시지 안의 블록 순서는 사라진다.
- user 메시지에 tool_result와 text가 함께 있으면(steering 입력, 02) OpenAI 형식에서는 tool 메시지들 뒤에 user 메시지 하나로 나간다.
- tool_result의 is_error는 OpenAI 형식에 자리가 없다. 실패는 결과 본문의 문구로 전달된다 (02 "실패는 모두 결과").

### 스트림 풀기와 내부 이벤트

스트리밍만 쓴다. 어댑터는 조각이 올 때마다 내부 이벤트를 내고, 끝에서 블록 목록을 조립한다.

| 내부 이벤트 | Anthropic | OpenAI |
|---|---|---|
| 글 조각 | `content_block_delta`의 `text_delta.text` | `delta.content` |
| 사고 조각 | `thinking_delta.thinking` (서명은 `signature_delta`로 모아 raw에) | `delta.reasoning_content`(DeepSeek), `delta.reasoning`(OpenRouter) |
| 도구 호출 시작 | tool_use 블록의 `content_block_start` (id, name) | `delta.tool_calls[i]`의 첫 조각 (id, name) |
| 인자 조각 | `input_json_delta.partial_json` | `delta.tool_calls[i].function.arguments` |
| 끝 | `message_delta`의 `stop_reason`, 그리고 `message_stop` | `finish_reason`, 그리고 `data: [DONE]` |
| 사용량 | `message_start`와 `message_delta`의 `usage` | 마지막 조각의 `usage` |

- 스파이크에서 앞의 넷(글, 사고, 도구 시작, 인자)으로 화면에 흘리기에 충분했다. 끝과 사용량은 스파이크에서 이벤트가 아니라 반환값이었다.
- OpenAI 형식의 도구 호출 조각은 `index`로 이어 붙인다. 첫 조각에만 id와 name이 온다.
- OpenRouter의 OpenAI 형식은 `finish_reason`을 두 조각에 걸쳐 두 번 보낸다. 누적기는 덮어써도 되게 한다.
- OpenRouter의 Anthropic 형식은 `message_start`의 사용량이 0이고 실제 값은 `message_delta`에 온다.
- 조립 순서는 thinking, text, tool_call이다. 인자 조각이 하나도 없으면 args_json은 `{}`다.

## 끝난 이유

제공자가 준 필드를 옮겨 적지 않고 내용에서 다시 계산한다 (ADR 0015). OpenRouter(상류 DeepInfra)에서 tool_use 블록이 있는데 stop_reason이 end_turn으로 온 사례가 있다 (ADR 0014).

- 잘림 신호(Anthropic `max_tokens`, OpenAI `length`)가 오면 도구 호출이 있어도 잘림이다. 잘린 인자는 실행하지 않는다 (02).
- 그 밖에 도구 호출 블록이 하나라도 있으면 도구 호출이다.
- 나머지는 제공자 값으로 가른다: Anthropic `end_turn`, OpenAI `stop`은 끝. Anthropic `refusal`, `pause_turn`은 02의 해당 분기로 간다.
- 그 밖의 값(모르는 값, 빈 값)은 other다. 루프는 턴 끝으로 보고 제공자가 준 원값을 사용자에게 보인다. 상류가 새 값을 보내도 루프가 멈추지 않는다.
- 제공자가 준 값은 따로 보관한다(기록과 진단용).
- 스파이크는 도구 호출을 잘림보다 먼저 보았다. 잘린 도구 호출은 스파이크에서 나오지 않았다.

| 내용과 제공자 값 | 다시 계산한 값 | 02의 분기 |
|---|---|---|
| 잘림 신호 | max_tokens | 잘렸다는 오류 결과 |
| 도구 호출 있음 | tool_use | 검증과 실행 |
| `end_turn`, `stop` | end_turn | 턴 끝 |
| `refusal` (Anthropic) | refusal | 실행하지 않고 턴 끝 |
| `pause_turn` (Anthropic) | pause_turn | 그대로 이어서 요청 |
| 그 밖의 값 | other | 턴 끝, 원값을 보인다 |

Zig의 내부 종류는 `enum { end_turn, tool_use, max_tokens, refusal, pause_turn, other }`다.

## 사고의 보관과 되돌리기

- assistant의 사고는 thinking 블록으로 히스토리에 남고, 같은 형식으로 보낼 때는 늘 되돌린다 (02 "받은 그대로"). 어댑터는 raw.format이 자기 형식인 thinking만 싣는다.
- Anthropic 형식: thinking 블록의 글과 signature를 그대로 되돌린다. signature는 raw에 든다. DeepSeek의 Anthropic 형식에서 signature에는 메시지 id가 들어 있었다. 사고 글이 빈 thinking 블록도 온다(쉬운 질문).
- OpenAI 형식: DeepSeek은 `reasoning_content`, OpenRouter는 `reasoning`과 `reasoning_details`로 준다. 사고 글을 assistant 메시지의 `reasoning_content` 필드로 되돌린다. 스파이크에서 거절(400)은 없었다. `reasoning_details`는 담지도 되돌리지도 않는다. 그것이 필요한 모델이 나오면 thinking의 raw에 담는다.
- 다른 형식으로 보낼 때는 사고를 뺀다. raw.format이 다른 thinking 블록은 요청에 싣지 않는다 (ADR 0015).
- 컴팩션의 요약 요청에는 사고를 넣지 않는다 (02).

## 힌트 옵션

한쪽 형식이나 일부 모델에만 있는 기능은 힌트 옵션이다. 지원하는 어댑터는 쓰고 못 하는 어댑터는 무시한다 (ADR 0015).

| 힌트 | Anthropic 형식 | OpenAI 형식 | 확인한 것 |
|---|---|---|---|
| max_tokens | `max_tokens` | `max_tokens` | 두 형식 모두 받는다. 스파이크는 4096 |
| effort | `output_config.effort` | 제공자별 필드 | DeepSeek `deepseek-flash`는 기본 effort가 high이고(고를 수 있는 것은 low, high, max) 아무것도 넣지 않아도 사고한다. effort 칸이 받아들여지는지는 표본 하나로 말할 수 없었다 |
| 캐시 지점 | 블록의 `cache_control` | 없음 | DeepSeek은 표시 없이 앞부분을 자동으로 캐시한다. OpenRouter의 Qwen도 캐시가 붙었다 |
| 인자 조각 스트리밍 | run 도구에 `eager_input_streaming`과 strict 스키마 | 기본으로 조각이 온다 | 스파이크는 쓰지 않았다 |

- 캐시 지점을 쓰는 어댑터는 시스템 프롬프트 끝에 하나, 대화의 마지막 블록에 하나를 두고 마지막 것은 요청마다 옮긴다. 렌더 순서는 tools, system, messages다. 컴팩션의 요약 요청에는 두지 않는다.
- 자동 캐시가 덮는 몫은 제공자마다 크게 다르다. 스파이크 회차에서 DeepSeek은 95%, OpenRouter의 qwen은 47~48%였다.
- Claude 모델에 보낼 때(Anthropic 형식): 사고는 adaptive이고 강도는 effort로 정한다. budget_tokens, temperature, 응답 프리필, 강제 도구 선택은 모델이 거부한다. 키가 없어 이 저장소에서 돌려 보지 않았다.
- DeepSeek에서 `"thinking":{"type":"enabled"}`(OpenAI 형식)는 응답을 바꾸지 않았다. 사고가 이미 켜져 있기 때문이다.

## 하네스 알림

세션 중 바뀌는 지시(모드 변경, 할 일 알림, 재개 뒤 VM이 새로 시작됐다는 알림)는 시스템 프롬프트를 고치지 않고 히스토리에 덧붙인다. 캐시된 앞부분을 지키기 위해서다 (02). 이것을 하네스 알림이라 부른다. 사용자가 친 말과 구분된다.

- 하네스 알림은 user 메시지의 text 블록이다. 코어가 본문을 표시로 감싸 만든다. 블록 종류나 역할을 더하지 않는다.

~~~text
<harness-notice>Permission mode changed to plan.</harness-notice>
~~~

- 알림은 코어가 다음에 보내는 user 메시지에 든다. 턴을 여는 메시지에서는 사용자 입력 앞에, 도구 결과 메시지에서는 tool_result 블록들 뒤, steering 입력 앞에 둔다. 알림 하나가 text 블록 하나이고, 여럿이면 생긴 순서대로 둔다.
- 어댑터의 일은 없다. 두 형식 모두 보통의 user text로 나간다. OpenAI 형식에서는 tool 메시지들 뒤의 user 메시지에 든다(위 "요청 만들기"). 중간 system 메시지와 Anthropic의 최상위 system은 쓰지 않는다. 세션 중간에 형식이 바뀌어도 뜻이 같다.
- 시스템 프롬프트가 이 표시의 뜻(사용자가 아니라 하네스가 보낸 것)을 알린다 (06). 모델이 알림을 사용자의 말로 읽을 수 있다. 지시를 따르는지는 평가에서 본다 (13).
- 세션 파일에는 notice 줄로 쓴다 (07).

## 제공자 설정

제공자 하나는 아래 칸을 가진 데이터 항목이다 (ADR 0015). 설정 파일의 제공자 항목도 이 이름을 쓴다 (11). 이름은 스파이크의 표(spike/s2/src/provider.zig)를 따른다.

| 키 | 값 | 예 |
|---|---|---|
| name | 항목 이름. 고를 때 쓴다 | `ds-anth` |
| format | `anthropic` 또는 `openai`. 어떤 어댑터를 쓸지 | `anthropic` |
| url | 요청을 보낼 전체 주소 | `https://api.deepseek.com/anthropic/v1/messages` |
| auth | `x-api-key` 또는 `bearer`. 키를 싣는 헤더 | `x-api-key` |
| key_env | 키를 담은 환경 변수의 이름 | `DEEPSEEK_API_KEY` |
| model | 모델 ID | `deepseek-flash` |

- 키 자체는 항목에 두지 않는다. 항목은 key_env로 이름만 가리킨다 (05 "비밀").
- 형식별 고정 헤더(`anthropic-version`, `content-type`, `accept-encoding`)는 어댑터의 코드다. 항목에 두지 않는다.
- 항목은 실행 파일에 내장한 기본 항목과 settings.json의 `providers` 배열에서 온다. settings.json의 항목은 같은 name의 내장 항목을 통째로 덮고, 새 name이면 더해진다. 칸 일부만 덮지 않는다.
- 내장 기본 항목은 위 "형식과 제공자" 표의 넷이다: `ds-anth`, `ds-oai`(모델 `deepseek-flash`), `or-anth`, `or-oai`(모델 `qwen/qwen3.8-flash`). 설정이 없으면 `ds-anth`를 쓴다. 개발 기본(DeepSeek)이 설정 없이 돈다.
- url은 전체 주소다. 기준 주소에 형식별 경로를 붙이지 않는다. DeepSeek은 두 형식의 경로가 앞부분부터 달라(`/anthropic/v1/messages`, `/chat/completions`) 기준 주소 하나로 두 형식을 덮지 못한다.
- 힌트의 기본값: max_tokens는 4096(스파이크의 값), effort는 보내지 않는다(제공자의 기본을 쓴다. DeepSeek `deepseek-flash`는 high). 항목에는 힌트 칸이 없다.
- 어느 항목을 쓸지, 모델과 힌트를 덮는 설정 키는 11에 있다.

## 키

- 키는 고른 제공자 항목의 key_env가 가리키는 환경 변수, 또는 권한 0600인 $XDG_CONFIG_HOME/tars-agent/credentials(기본 ~/.config, 11)에서 읽는다 (05). 환경 변수가 있으면 그것을 쓰고, 없으면 credentials 파일을 본다. 지금 쓰는 변수는 DEEPSEEK_API_KEY, OPENROUTER_API_KEY다. ANTHROPIC_API_KEY는 없다 (ADR 0014).
- credentials 파일은 한 줄에 키 하나, `변수이름=값` 꼴이다. 변수 이름은 key_env와 같다. 빈 줄과 `#`으로 시작하는 줄은 건너뛴다.

~~~text
DEEPSEEK_API_KEY=sk-...
OPENROUTER_API_KEY=sk-or-v1-...
~~~

- 키 꼴: DeepSeek 키는 `sk-`, OpenRouter 키는 `sk-or-v1-`로 시작한다.
- 키가 없으면 요청 전에 멈추고 어느 변수가 필요한지 말한다.
- 모든 제공자 항목의 key_env 변수는 자식 프로세스 환경에서 지운다 (03, 05).

## 오류와 재시도

재시도 정책(횟수, 백오프, 상한, 히스토리를 어떻게 두는지)은 형식과 무관하고 02 "제공자 오류"에 있다. 이 절은 어댑터가 응답을 그 정책의 어느 종류로 가르는지다.

| 종류 | 무엇으로 아는가 | 02의 처리 |
|---|---|---|
| 재시도할 오류 | HTTP 429, 5xx(Anthropic의 529 과부하 포함), 연결 끊김, 스트림 중간 끊김 | 백오프로 재시도 |
| 요청 오류 | HTTP 400, 401, 403, 404 | 재시도하지 않고 보인다 |
| 컨텍스트 초과 | 요청 오류 가운데 컨텍스트 길이를 넘었다는 응답 | 컴팩션 한 번 뒤 다시 보낸다 |

- 상태가 200이 아니면 응답 본문을 오류 본문으로 모은다(스파이크). 401과 403은 어느 key_env를 썼는지 함께 보인다.
- 컨텍스트 초과는 형식과 제공자마다 문구가 다르다. 어댑터가 오류 본문으로 가른다.
- 스트림 중간 끊김은 그 응답을 버린다. 끊긴 스트림의 정리는 아래 "HTTP와 SSE"의 주의를 따른다.
- 스파이크에는 재시도가 없었다. 스트림 중간의 오류 이벤트, 끊긴 연결은 스파이크에서 나오지 않았다.

## 사용량과 비용

어댑터가 사용량을 한 모양으로 맞춘다: 입력, 그중 캐시 읽기, 캐시 쓰기, 출력. 입력은 캐시 몫을 포함한 전체이고 캐시 읽기와 쓰기는 그 안의 몫이다. 비용과 캐시 비율이 이 뜻에서 한 번에 나온다. 06의 json usage와 07의 기록이 이 뜻을 따른다. 비용은 제공자가 주면 그 값을 쓰고, 없으면 모델별 가격표로 계산한다 (07 "비용과 통계").

| | Anthropic 형식 | OpenAI 형식 |
|---|---|---|
| 입력 | `input_tokens` + `cache_read_input_tokens` + `cache_creation_input_tokens`. `input_tokens`는 캐시되지 않은 몫이다(DeepSeek) | `prompt_tokens`. 캐시된 몫을 포함한다 |
| 캐시 읽기 | `cache_read_input_tokens` | `prompt_tokens_details.cached_tokens` |
| 캐시 쓰기 | `cache_creation_input_tokens` | `prompt_tokens_details.cache_write_tokens`(OpenRouter) |
| 출력 | `output_tokens` | `completion_tokens` |
| 사고 몫 | `output_tokens_details.thinking_tokens` | `completion_tokens_details.reasoning_tokens` |
| 비용 | OpenRouter: `usage.cost` (달러) | OpenRouter: `usage.cost` (달러) |

- 캐시 필드는 null일 수 있다. OpenRouter의 Anthropic 형식은 `cache_creation_input_tokens`가 null로 왔다. null과 없는 필드는 0이 아니라 "모름"으로 다룬다. Anthropic 형식에서 입력의 합을 낼 때는 모르는 캐시 필드를 더하지 않는다.
- 출력 토큰은 사고를 포함한다.
- 06의 캐시 경고(캐시 읽기가 0으로 이어지면 경고)는 맞춘 사용량의 캐시 읽기로 본다.

## HTTP와 SSE (Zig 0.17.1)

- Zig std.http로 스트리밍 요청이 된다. TLS와 CA 묶음은 macOS에서 됐다. curl 대안은 필요 없다 (ADR 0017).
- `accept-encoding`은 identity로 고정한다. 압축을 받으면 줄 단위 읽기 앞에 풀기 단계가 필요하다.
- SSE는 `data:`로 시작하는 줄만 JSON으로 푼다. `event:`, 주석(`:`), 빈 줄은 건너뛴다. 스파이크는 한 줄을 1 MiB 버퍼로 읽었고 더 길면 실패한다(StreamTooLong). 줄 버퍼에 기대지 않는 조각 단위 해석기를 쓴다 (검토 9절 12).
- std는 Io 인터페이스를 인자로 받는다. main이 받은 io를 provider까지 넘긴다.
- 스트림을 중간에 끊을 때(Esc, 재시도) `std.http.Client.Request.deinit` 전에 연결을 닫음으로 표시한다(`connection.closing = true`). 그러지 않으면 deinit이 열린 SSE 스트림을 끝까지 읽으려다 멈춘다. 스파이크는 `keep_alive = false`로 요청했다 (deps.md, ADR 0030).
- macOS의 `std.Io.Threaded`에서 `std.Io.Select`를 작업이 도는 중에 취소하면 다음 connect가 `EISCONN`으로 panic한다. 보조 작업을 먼저 멈추고 결과를 받은 뒤에 Select를 취소한다 (deps.md).
- 끝까지 읽은 원문 SSE를 남기는 기록 칸을 스파이크에 두었다. 진단에 쓴다.

## 확인하지 않은 것

- 한 응답에 도구 호출 여럿, max_tokens로 잘린 응답, 세션 중간에 형식을 바꾸는 것, 스트림 중간에 끊긴 연결 (검토 4.2).
- effort 칸을 DeepSeek의 두 형식이 받아들이는지.
- 모델이 하네스 알림을 사용자의 말과 구분해 따르는지 (13).
- max_tokens 4096이 긴 스크립트를 자르는 빈도.
- 스트림 중간의 오류 이벤트의 모양(두 형식 모두).
- 컨텍스트 초과의 실제 오류 문구.
- Claude 모델. 키가 없다.
- 컴팩션에서 최근 구간을 원문으로 남길 때, 앞부분이 바뀐 대화에 남긴 사고 블록을 제공자가 받는지 (ADR 0021, TODO M4).
- deps.md의 Zig 주의 둘(HTTP 정리, connect panic)은 우리 빌드에서 재현하지 않았다.
