# tars-agent

Cyber 언어로 만드는 tars-linux용 AI 에이전트 하네스.

상태: 설계 단계. 코드는 아직 없고 명세(docs/spec)와 할 일(docs/TODO.md)만 있다.

## 문서

- docs/spec/00-overview.md: 목표, 비목표, 대상 환경, 용어
- docs/spec/01-architecture.md: 구성요소와 데이터 흐름
- docs/spec/02-agent-loop.md: 에이전트 루프와 메시지 형식
- docs/spec/03-tool-system.md: 도구 정의, 레지스트리, 스키마, 실행기, 결과 처리
- docs/spec/04-builtin-tools.md: 내장 도구 목록과 설명 초안
- docs/spec/05-permissions-security.md: 권한 게이트와 샌드박스
- docs/spec/06-mcp-and-context.md: MCP 통합과 컨텍스트 비용 관리
- docs/spec/07-observability.md: 세션 로그와 추적
- docs/spec/08-cyber-implementation.md: Cyber 구현 제약과 위험
- docs/TODO.md: 단계별 작업 목록
- docs/decisions/: 결정 기록
- MEMORY.md: 결정 요약 색인

## 설계 원칙

- 모든 실패는 도구 결과로 돌아간다. 루프는 예외로 죽지 않는다.
- 빈 결과는 없다. 부작용만 있는 도구도 완료 요약을 돌려준다.
- 결과는 상한을 두고 절단하며 절단 사실을 표시한다.
- 권한 판단은 코어에 두고 UI와 분리한다.
- 도구 설명은 문서가 아니라 모델이 읽는 사양이다.

## 라이선스

미정 (TODO 참고).
