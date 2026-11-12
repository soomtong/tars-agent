# MEMORY

결정 요약 색인. 상세는 docs/decisions 참고.

- [0001 구현 언어와 실행 모델](docs/decisions/0001-implementation-language.md) — CodeAct, 실행 언어 Cyber fork
- [0002 호스트 구현 방식](docs/decisions/0002-host-implementation.md) — Zig + libcyber (방식 A)
- [0003 라이선스](docs/decisions/0003-license.md) — BSD 3-Clause
- [0004 프로세스 모델](docs/decisions/0004-process-model.md) — 세션당 프로세스 하나, 데몬은 후속
- [0005 저장소, 런타임 링크, 배포](docs/decisions/0005-repository-and-distribution.md) — 이 저장소, cyber 정적 링크, sha256 릴리스
- [0006 능력 표와 CodeAct 판정](docs/decisions/0006-capability-table-and-codeact-gate.md) — comptime 표 단일 소스, direct 대조군, 통과 기준
- [0007 권한 모델](docs/decisions/0007-permission-model.md) — 프로파일과 모드, proc.exec와 proc.sh, Landlock
- [0008 세션 기록, 재개, 컴팩션](docs/decisions/0008-session-and-history.md) — 덧붙이기만, VM은 복원하지 않음
- [0009 v1에서 뺀 것](docs/decisions/0009-v1-scope-cuts.md) — 뺀 항목과 되살리는 조건
- [0010 없는 것은 Cyber에 만든다](docs/decisions/0010-build-what-cyber-lacks.md) — 순수 계산은 cyber 표준 모듈, 세계에 닿는 것만 능력
- [0011 승인 대기는 VM 밖에서](docs/decisions/0011-approval-wait-outside-vm.md) — 능력은 Future를 돌려주고 CL_AWAIT로 루프가 승인, cyber에 요청
- [커밋과 push 위임](docs/decisions/feedback-commit-delegation.md) — 의미 있는 변경은 묻지 않고 커밋하고 push
- [초기 요구사항 대조](docs/spec/09-legacy-requirements.md) — 이력, 재검토에서 바꾼 것과 닫은 질문
- [0012 초기 아키텍처는 페어 코딩](docs/decisions/0012-pair-coding-initial-architecture.md) — 결정, 편집, 기능을 나눠 공유, M0 스파이크는 함께 만들고 버림, 구조 결정은 사용자
- [0013 범위](docs/decisions/0013-scope-coding-agent-and-tars-self-operation.md) — 코딩 에이전트, tars 자기 조작(명령 실행, 콘솔 입력), tars-linux 개선 포함
- [0014 개발 중 저렴한 모델](docs/decisions/0014-cheap-models-for-development.md) — 전송 형식 둘(Anthropic Messages, OpenAI Chat Completions) 지원, 기본 제공자 DeepSeek, 평가는 OpenRouter의 Qwen, stop_reason 어긋남
- [0015 제공자 설계](docs/decisions/0015-provider-message-model-and-adapters.md) — 자체 메시지 모델(블록 기반), 형식별 어댑터, 제공자는 설정 데이터, 원문은 불투명 칸
