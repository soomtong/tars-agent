# tars-agent

tars-linux용 내장 AI 코딩 에이전트. Claude Code를 본보기로 하되, 에이전트가 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이다. 호스트는 Zig이고 libcyber를 정적 링크한다.

상태: 설계 단계. 코드는 아직 없고 명세(docs/spec)와 할 일(docs/TODO.md)만 있다. 다음 단계는 M0(증명과 판정)이다.

## v1의 모양

- 실행 파일 하나, 세션당 프로세스 하나. 대화형 REPL과 헤드리스(-p)
- API 도구는 run 하나. 파일, 프로세스, 네트워크는 Cyber 안에서 능력 함수로 부른다
- 보안 세 층: VM 구성(모듈 제한, 연료, 스택과 메모리 상한), 정책 게이트(프로파일, 모드, 규칙, 승인), 실행 프로세스의 Landlock 샌드박스
- 세션은 JSONL 파일 하나. 재개와 컴팩션
- 의존은 Zig 표준 라이브러리와 libcyber

## 문서

- docs/spec/00-overview.md: 목표, 기준, v1 범위, 대상 환경, 용어
- docs/spec/01-architecture.md: 프로세스 모델, 구성요소, 능력 표, 배포
- docs/spec/02-agent-loop.md: 모델 요청, 스텝 절차, 실패 분류, 컴팩션, 재개
- docs/spec/03-tool-system.md: 능력 정의, 사양 쓰는 법, 본체 규칙, 결과 상한
- docs/spec/04-builtin-tools.md: 내장 능력 목록
- docs/spec/05-permissions-security.md: 위협 모델, 세 층, 규칙, 비밀, 프롬프트 인젝션
- docs/spec/06-mcp-and-context.md: 시스템 프롬프트, AGENTS.md, 프런트엔드, 컨텍스트 비용, 후속 확장
- docs/spec/07-observability.md: 세션 파일, 리플레이, 비용
- docs/spec/08-cyber-implementation.md: Cyber 런타임 사실과 제약
- docs/spec/09-legacy-requirements.md: 초기 요구사항과의 대조 (이력)
- docs/TODO.md: 단계별 작업과 게이트
- docs/decisions/: 결정 기록
- docs/deps.md: 의존과 라이선스
- MEMORY.md: 결정 요약 색인

## 설계 원칙

- 모든 실패는 결과로 돌아간다. 루프는 스크립트 때문에 죽지 않는다.
- 빈 결과는 없다. 큰 결과는 파일로 보내고 머리와 꼬리만 싣는다.
- 히스토리는 덧붙이기만 한다.
- 능력은 표 하나에서 정의한다. 사양은 문서가 아니라 모델이 읽는 계약이다.
- 권한 판단은 코어에 두고 화면과 분리한다. 깨지기 쉬운 장치에 안전을 맡기지 않는다.
- 주장은 측정으로 한다. CodeAct를 기본으로 둘지는 평가가 정한다.

## 관련 저장소

- tars-linux: https://github.com/soomtong/tars-linux (대상 OS, 소개 https://soomtong.github.io/tars-linux/)
- cyber (fork): https://github.com/soomtong/cyber (런타임, 문서 https://soomtong.github.io/cyber/)

## 라이선스

BSD 3-Clause. LICENSE 참고. 런타임인 cyber는 MIT이고, FFI를 끈 빌드(-Dffi=false)에서만 LGPL인 tcc가 링크되지 않아 BSD 호환이 성립한다.
