# 아키텍처

## 구성요소

~~~text
frontend (TUI / headless CLI)
   |
core
   +-- session        히스토리, 컴팩션, 저장
   +-- agent loop     모델 호출 - 도구 실행 반복
   +-- provider       모델 API 어댑터 (스트리밍, 스키마 방언 변환)
   +-- tool registry  내장/플러그인/MCP 도구 등록과 조회
   +-- executor       검증, 권한, 실행, 절단, 취소
   +-- permission     정책 판단, 승인 기억
   +-- observability  세션 로그, 스팬
~~~

## 경계 규칙

- frontend는 입출력과 승인 UI만 그린다. 정책 판단은 core에 둔다 (헤드리스 일관성).
- provider는 모델별 차이(스키마 키워드, 스트리밍 이벤트)를 흡수한다. core는 공통 메시지 형식만 본다.
- 도구 실행 함수는 레지스트리 밖에서 실행 환경(cwd, env, 시그널)을 직접 바꾸지 않는다. ExecCtx로만 받는다.

## 데이터 흐름

1. frontend가 사용자 입력을 session에 추가한다.
2. agent loop가 provider에 히스토리와 도구 정의를 보낸다.
3. 응답에 tool_use 블록이 있으면 executor가 실행하고 tool_result를 히스토리에 추가한다.
4. tool_use 블록이 없으면 턴을 끝내고 frontend에 최종 응답을 전달한다.

## 모듈 후보 (디렉터리 구조 초안)

~~~text
src/
  main.cy
  core/{loop,session,message}.cy
  provider/{anthropic,adapter}.cy
  tools/{registry,executor,schema}.cy
  tools/builtin/*.cy
  permission/{policy,store}.cy
  mcp/{client,transport}.cy
  ui/{tui,headless}.cy
  log/{session_log,trace}.cy
~~~

실제 구조는 Cyber의 모듈 시스템 검증 후 확정한다 (08 문서).
