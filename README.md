# tars-agent

Cyber 언어로 만드는 tars-linux용 AI 에이전트 하네스. 에이전트가 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이다.

상태: 설계 단계. 코드는 아직 없고 명세(docs/spec)와 할 일(docs/TODO.md)만 있다.

## 문서

- docs/spec/00-overview.md: 목표, 비목표, 대상 환경, 용어
- docs/spec/01-architecture.md: 구성요소와 데이터 흐름
- docs/spec/02-agent-loop.md: 에이전트 루프와 메시지 형식
- docs/spec/03-tool-system.md: 호스트 함수 정의, 레지스트리, 실행기, 결과 처리
- docs/spec/04-builtin-tools.md: 내장 호스트 함수 목록과 사양 초안
- docs/spec/05-permissions-security.md: 권한 게이트와 샌드박스
- docs/spec/06-mcp-and-context.md: MCP 통합과 컨텍스트 비용 관리
- docs/spec/07-observability.md: 세션 로그와 추적
- docs/spec/08-cyber-implementation.md: Cyber 런타임 사실과 제약
- docs/spec/09-legacy-requirements.md: 초기 요구사항 지시서와의 대조, 열린 질문
- docs/TODO.md: 단계별 작업 목록
- docs/decisions/: 결정 기록
- MEMORY.md: 결정 요약 색인

## 설계 원칙

- 모든 실패는 도구 결과로 돌아간다. 루프는 예외로 죽지 않는다.
- 빈 결과는 없다. 부작용만 있는 도구도 완료 요약을 돌려준다.
- 결과는 상한을 두고 절단하며 절단 사실을 표시한다.
- 권한 판단은 코어에 두고 UI와 분리한다.
- 도구 설명은 문서가 아니라 모델이 읽는 사양이다.
- 스크립트는 호스트 함수로만 세계에 닿는다. 샌드박스는 런타임 구성(1층)과 정책 게이트(2층)로 나눈다.

## 관련 저장소

- tars-linux: https://github.com/soomtong/tars-linux (대상 OS, 소개 https://soomtong.github.io/tars-linux/)
- cyber (fork): https://github.com/soomtong/cyber (런타임, 문서 https://soomtong.github.io/cyber/)

## 라이선스

BSD 3-Clause. LICENSE 참고. 런타임이 되는 cyber는 MIT이고, FFI를 끈 빌드(-Dffi=false)에서만 LGPL인 tcc가 링크되지 않아 BSD 호환이 성립한다.
