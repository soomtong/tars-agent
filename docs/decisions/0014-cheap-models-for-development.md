# 0014 개발 중에는 저렴한 모델을 쓴다

상태: 사용자 지시 (2026-11-12)

## 결정

- 개발하는 동안 쓰는 LLM은 저렴한 모델이다.
- 전송 형식은 둘 다 지원하는 아키텍처로 간다: Anthropic Messages와 OpenAI Chat Completions. Claude가 추천한 "Anthropic 형식만 유지"는 받지 않았다.
- 개발 기본 제공자는 DeepSeek이다.
- 테스트와 평가는 OpenRouter의 Qwen 계열로 해 본다. Qwen4가 나오면 그것으로 한다. 사용자: "이걸로 돈 벌기 아니어서".
- 키는 사용자의 콘솔 환경 변수 OPENROUTER_API_KEY와 DEEPSEEK_API_KEY를 쓴다. ANTHROPIC_API_KEY는 없다.

## 확인한 것 (2026-11-12, curl로 도구 하나를 준 스트리밍 요청)

- DeepSeek에는 Anthropic Messages 호환 엔드포인트가 있다: https://api.deepseek.com/anthropic/v1/messages, 인증은 x-api-key 헤더. message_start, content_block_delta 등 같은 SSE 이벤트가 온다.
- OpenRouter에도 있다: https://openrouter.ai/api/v1/messages, 인증은 Authorization: Bearer 헤더. 모델 이름은 deepseek/deepseek-v4.1-flash-1017 꼴이다. 날짜가 붙은 ID로 고정한다(`~...-latest`와 DeepSeek API의 옛 별칭 deepseek-chat은 가리키는 모델이 바뀐다).
- 호환이 완전하지 않다. OpenRouter(상류 DeepInfra)는 tool_use 블록을 냈는데 stop_reason이 tool_use가 아니라 end_turn이었다. 루프는 stop_reason만 믿지 말고 응답에 tool_use 블록이 있는지를 본다.
- usage의 모양이 다르다. OpenRouter는 cost를 준다. 캐시 필드는 null일 수 있다.

- OpenRouter의 Qwen (2026-11-12 모델 목록): Qwen4는 아직 없다. 지금 최신은 qwen3.8 계열이고 모두 도구 호출을 지원한다. qwen/qwen3.8-flash는 백만 토큰당 입력 0.15달러, 출력 0.47달러, qwen/qwen3.8-max-0902는 2달러, 6달러다.

## 바뀌는 것

- 명세 01의 provider: 어댑터가 둘이다 (provider/anthropic.zig, provider/openai.zig).
- TODO M0 평가의 모델: Claude 셋에서 DeepSeek과 OpenRouter의 Qwen으로 바꾼다. 정확한 목록과 CodeAct 판정의 "기본 모델"은 평가를 설계할 때 정한다.
- 스파이크 2는 두 형식을 모두 본다.

## 열린 질문 (방향은 ADR 0015가 정했다. 세부는 페어의 메시지 모델 단계에서 정한다)

- 명세 02는 assistant 응답을 받은 그대로 보관하고 되돌려 보낸다. 형식이 둘이면 "받은 그대로"가 형식마다 다르다. 내부 형식 하나로 정규화할지, 형식별 원문을 함께 둘지, 세션 중간에 제공자를 바꿀 수 있게 할지.
- 사고(thinking, reasoning) 블록을 두 형식에서 어떻게 보관하고 되돌릴지. DeepSeek과 Qwen은 reasoning_content 필드를 쓴다.
- Anthropic 전용 기능(적응형 사고, effort, 캐시 지점)의 자리: 공통 설정으로 올릴 것과 어댑터 안에 둘 것
