# HANDOFF: tars-agent 명세와 TODO 작성 완료, P0 스파이크 대기 (2026-11-10)

## 목표

Cyber 언어로 만드는 tars-linux용 내장 AI 에이전트 하네스. 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이고, 도구는 호스트(Zig 데몬 agentd)가 Cyber에 열어 주는 능력(capability) 함수다. 현재 단계는 명세와 TODO만 있고 코드는 없다 (사용자 지시: "no code yet. only specs and to-dos").

## 현재 브랜치

`main` = origin/main (https://github.com/soomtong/tars-agent, public). 작업 트리 깨끗. 최근 커밋: 446623b, 7aac178, c99aae9.

## 관련 저장소 (모두 사용자 소유)

- tars-linux: https://github.com/soomtong/tars-linux (로컬 /Users/dp/Repository/tars-linux). 직접 빌드한 커널 + Zig init(PID 1) + Zig 터미널 + fish. x86_64 전용, Debian glibc 동적 링크, Zig 0.17. 도구는 sha256 고정 미리 빌드 바이너리로 devlayer에 들인다. cyber 0.4.4가 이미 devlayer/manifest.toml:581 부근에 있다.
- cyber (fork of fubark/cyber): https://github.com/soomtong/cyber (로컬 /Users/dp/Repository/cyberscript). 에이전트 관련 결정 문서는 docs/decisions/project_tars_agent_runtime_review.md, project_embedding_agent_loop.md, project_direction.md.

## 완료된 작업

- [x] public GitHub 저장소 생성 (gh), 라이선스 BSD 3-Clause (사용자 지시), 저작권자 soomtong
- [x] docs/spec/00~09 명세 작성: 개요, 아키텍처, 루프, 도구 시스템, 내장 능력, 권한/보안, MCP/컨텍스트, 관측, Cyber 런타임 사실, 초기 요구사항 대조
- [x] docs/TODO.md (P0~P6, tars 통합, 언어 문서/평가, 테스트 계획)
- [x] docs/decisions 0001(CodeAct + Cyber), 0002(호스트 방식 A 확정), 0003(BSD), MEMORY.md 색인
- [x] 사용자가 준 legacy 요구사항(0.3 기준)을 현재 사실과 대조해 09 문서로 정리

## 확정된 설계 결정

- 실행 모델: API 도구는 run 하나(Cyber 코드). 나머지는 능력 함수. 능력 이름은 점 표기(fs.read, proc.exec, tars.terminal.send 등), 등급 read/write/exec/net/ui. 허용 안 된 능력은 거부가 아니라 이름 자체를 주입하지 않는다.
- 호스트: Zig 0.17 데몬 agentd + libcyber 링크 (방식 A). 순수 Cyber CLI(방식 B)는 선택적 일회성 스파이크.
- 승인 대기: 파이버가 없으므로 호스트 함수가 동기 블록, VM당 OS 스레드 하나.
- 샌드박스: libcyber -Dffi=false, c 모듈 필터, deny_raw_ptrs=true, 연료(cl_vm_set_fuel) + 벽시계 interrupt, 할당자 상한.

## 시도했으나 실패/폐기한 접근

- 처음 쓴 명세(커밋 c99aae9)는 JSON tool_use 중심 일반 하네스로 썼다: tars-linux/cyber 정보를 받기 전이라 틀렸고 7aac178에서 CodeAct로 전면 재작성했다.
- legacy 요구사항의 파이버(coyield/coresume), JIT 제거 작업, Zig 업그레이드를 첫 작업으로 둔 부분: Cyber 0.4에서 파이버는 삭제됐고 나머지는 fork에서 이미 끝났다. 09 문서 참고.
- 별도 이름의 두 번째 fork 생성: cyber 검토 문서가 같은 변경을 두 번 유지하게 된다며 비권고. 열린 질문으로 남김.

## 남은 작업 (docs/TODO.md가 정본)

- [ ] P0 스파이크 2 (방식 A): Zig에서 libcyber 링크, 호스트 함수 2개, 연료/interrupt, 승인 대기 블록 동작 증명. 통과하면 사용자에게 보고
- [ ] 모델의 Cyber 코드 작성 정확도 측정 (부분집합 프롬프트, 대표 작업 20개)
- [ ] libcyber를 tars-linux x86_64 glibc 환경에 배포하는 경로 확인
- [ ] 산출 문서: docs/design.md, docs/fork-plan.md, docs/deps.md
- [ ] 이후 P1 코어 뼈대 이후는 TODO.md 참고

## 열린 질문 (09 문서 하단에 8개)

우선 정할 것: Zig 전용 API 표면 vs C ABI 래핑, agentd 저장소 위치(이 저장소 vs tars-linux), 승인 대기 스레드 점유가 수십 세션에서 문제인지, 런타임 제품명.

## 핵심 파일

- `docs/spec/09-legacy-requirements.md` — 초기 요구사항과의 대조, 채택/변경/열린 질문
- `docs/spec/02-agent-loop.md` — 한 턴 절차(validate -> eval -> 결과 조립), 실패 분류, 승인 대기
- `docs/spec/08-cyber-implementation.md` — 확인된 Cyber 런타임 수치와 제약
- `docs/spec/05-permissions-security.md` — 샌드박스 1층, 정책 게이트 2층
- `docs/TODO.md` — 단계별 작업
- `docs/decisions/` — ADR, `MEMORY.md` — 색인

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg/fd. 문서 코드 펜스는 ~~~ 사용.
2. 아직 코드 작성 지시는 없다. 사용자가 구현을 시작하라고 하기 전까지 문서만 다룬다. 시작하면 TODO P0 스파이크 2부터, 그 전에 /Users/dp/Repository/cyberscript의 examples/libcyber/host_tool.c와 위 cyber 결정 문서 세 개를 읽는다.
3. tars-linux는 단계별 보고 후 확인(feedback_stepwise_report), 설계 중 선택지를 계속 묻지 말고 추천안으로 진행하는 협업 방식을 쓴다(그 저장소의 MEMORY.md 참고).
4. tars-linux, cyber 저장소는 읽기 전용으로만 다뤘다. 수정하지 않았다.
