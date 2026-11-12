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
