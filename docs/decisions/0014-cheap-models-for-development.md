# 0014 개발 중에는 저렴한 모델을 쓴다

상태: 사용자 지시 (2026-11-12). 전송 형식과 평가 모델은 아직 정하지 않았다.

## 결정

- 개발하는 동안 쓰는 LLM은 저렴한 모델이다.
- 키는 사용자의 콘솔 환경 변수 OPENROUTER_API_KEY와 DEEPSEEK_API_KEY를 쓴다. ANTHROPIC_API_KEY는 없다.

## 확인한 것 (2026-11-12, curl로 도구 하나를 준 스트리밍 요청)

- DeepSeek에는 Anthropic Messages 호환 엔드포인트가 있다: https://api.deepseek.com/anthropic/v1/messages, 인증은 x-api-key 헤더. message_start, content_block_delta 등 같은 SSE 이벤트가 온다.
- OpenRouter에도 있다: https://openrouter.ai/api/v1/messages, 인증은 Authorization: Bearer 헤더. 모델 이름은 deepseek/deepseek-chat 꼴이다.
- 호환이 완전하지 않다. OpenRouter(상류 DeepInfra)는 tool_use 블록을 냈는데 stop_reason이 tool_use가 아니라 end_turn이었다. 루프는 stop_reason만 믿지 말고 응답에 tool_use 블록이 있는지를 본다.
- usage의 모양이 다르다. OpenRouter는 cost를 준다. 캐시 필드는 null일 수 있다.

## 아직 정하지 않은 것

- 전송 형식: 명세(01, 02)는 Anthropic Messages API다. 두 제공자 모두 호환 엔드포인트가 있어 형식을 그대로 두고 기준 주소, 인증 헤더, 모델 이름만 설정으로 뺄 수 있다. 다른 길은 OpenAI Chat Completions 형식이다.
- 평가(TODO M0)의 모델: 지금은 Claude 모델 셋이다. CodeAct 판정의 "기본 모델"을 무엇으로 볼지.
- 적응형 사고, effort, 캐시 지점 같은 Anthropic 전용 기능(TODO M1 provider)의 자리
