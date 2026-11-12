# HANDOFF: cyber 0.4.8(CL_AWAIT) 반영과 ADR 0011 완료, 다음은 M0와 cyber C1 (2026-11-12)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 현재는 명세, 결정, TODO, 프롬프트 안내만 있고 코드는 없다.

이번 세션의 흐름: cyber 0.4.5~0.4.7 변경을 문서에 반영했다. 승인 대기를 VM 밖으로 옮기는 결정(ADR 0011)을 내리고 cyber에 CL_AWAIT 구현을 요청했다. draft를 여러 차례 검토했고, cyber 0.4.8 릴리스에 맞춰 고정 버전과 안내를 갱신했다.

## 현재 브랜치

`main` = origin/main (마지막 184b6aa). 작업 트리는 깨끗하다. 커밋과 push는 Claude에게 위임돼 있다: 의미 있는 변경은 묻지 않고 커밋하고 push한다 (docs/decisions/feedback-commit-delegation.md).

## 완료된 작업

- [x] cyber 0.4.7 반영: generator fn, fiber/suspend, symbol.name, intrinsic 금지, cl_vm_compile_error, cl_vm_format (08, 02, 05, 0009, 09, 00, deps, 프롬프트 안내)
- [x] ADR 0011 승인 대기는 VM 밖에서: 능력은 미완료 Future를 돌려주고, 머리말의 Cyber 래퍼가 await해 모델에게는 동기 API만 보인다. eval이 CL_AWAIT로 돌아오면 루프가 승인 후 완료하고 resume. 거부는 error.Denied, 취소는 cl_vm_abandon
- [x] cyber에 요청서 전달(docs/requests/cyber-cl-await.md), 보고 수령(docs/requests/cyber-cl-await-report.md)
- [x] draft 검토: 요청 13개 항목 충족, `zig build test` 82단계 123개 통과. 검토 중 지적해 cyber가 고친 것: interrupt 요청을 resume이 지움(034fae2c), 버린 Future의 주소 재사용 문제를 태그로 해결(cl_future_tag, 94350e31). cyber가 더 넣은 것: Future.wait_any, cl_vm_pending_futures, 피연산자 왼쪽에서 오른쪽 평가(F-98 수정)
- [x] cyber 0.4.8(태그 0.4.8 → 2dfc061d, build-815) 고정, 08 문서를 0.4.8 기준으로, CL_AWAIT 임시 방식(동기 블록) 삭제
- [x] 프롬프트 안내(prompt/cyber-subset.md, .en.md) 0.4.8 기준: 슬라이스 생략과 `s[:-1]` 대응, trim 여러 구분자, 최상위 오류는 panic이고 최상위에서는 try: 블록으로 받기. 예제 20개(한/영)와 새 문장을 0.4.8 릴리스 바이너리로 실행해 확인

## 시도했으나 실패한 접근

- fiber로 승인 대기 해결: 호스트 함수를 건너 suspend할 수 없다(Cannot suspend across a host call.). 그래서 CL_AWAIT를 요청했다.
- 호스트가 Future 포인터로 요청을 찾기: 버린 Future의 주소가 다음 Future에 재사용된다(cyber 재현: 8개 모두 같은 주소). retain 권고도 대조 문제는 못 막는다. 태그(cl_future_new의 tag, cl_future_tag)로 찾는다. 요청 번호는 1부터(0은 호스트가 만들지 않은 Future).
- 안내에 "최상위에서 !else로 받아 출력": 최상위 !else 블록은 return으로 끝낼 수 없어 컴파일 오류다. try: ... else |e|: 로 고쳤다.
- 이전 세션의 실패 기록(정규식/JSON을 호스트 능력으로, agentd 중심, VM 재생 재개, 히스토리 중간 요약, 셸 분류기, tars.* 모의, 방식 B)은 docs/decisions 0004~0010에 있다. 다시 제안하지 않는다.

## 남은 작업

정본은 docs/TODO.md다. 2026-11-12에 사용자가 페어 코딩으로 M0를 시작하기로 했다 (ADR 0012, CLAUDE.md). 범위에 tars 자기 조작과 tars-linux 개선이 더해졌다 (ADR 0013).

- [ ] M0 스파이크 1: cyber 0.4.8을 build.zig.zon 의존으로 링크, 능력 2개, 호스트 로더, deny_raw_ptrs, 상한 넷, validate, persist_main, CL_AWAIT 승인 흐름(태그로 요청 찾기). 확인 목록 `docs/spec/08-cyber-implementation.md:43`
- [ ] M0 스파이크 2: Zig std.http로 Anthropic Messages API 스트리밍. 스파이크 3: x86_64-linux-gnu 교차 빌드와 tars 게스트(QEMU) 실행
- [ ] cyber C1: json 표준 모듈과 빌드 내보내기 (M0 평가보다 먼저). C2: regex(역추적 없는 엔진), time. C3: 임베딩 옵션(모듈 허용 표, spawn 차단)
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6
- [ ] 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5), 기본값 매개변수가 #[bind]에서 되는지 (M0). 점 표기 모듈(use fs, fs.write)은 cyber host_await.c로 된다고 확인됨
- [ ] tars-linux devlayer의 cyber는 0.4.6이다(`/Users/dp/Repository/tars-linux/devlayer/manifest.toml:581`). 주석 "실행 파일이 옆의 src/를 읽는다"는 0.4.7부터 틀렸다. tars-linux는 사용자 지시 없이 고치지 않는다
- [ ] 로컬 `/usr/local/bin/cyber`는 0.4.7이다. 시스템 설치라 건드리지 않았다. 검증은 scratchpad에 받은 릴리스 바이너리로 했다

## 핵심 파일

- `docs/spec/08-cyber-implementation.md:23` — CL_AWAIT API와 규칙(태그, interrupt 지움, abandon, 스레드), `:43` M0 확인 목록, `:52` cyber에서 만들 것
- `docs/decisions/0011-approval-wait-outside-vm.md:5` — 결정, `:53` 바인딩 층 설계(게이트 판정, 승인 요청, 실제 작업을 세 함수로), `:59` cyber가 고른 동작
- `docs/spec/02-agent-loop.md:29-31` — validate(구조화된 컴파일 오류)와 CL_AWAIT 실행 단계
- `docs/requests/cyber-cl-await.md`, `docs/requests/cyber-cl-await-report.md` — 요청과 보고 원문
- `prompt/cyber-subset.md:5` — 기준 버전, `:75` 슬라이스 규칙. 영문판 `prompt/cyber-subset.en.md`는 같은 구조
- `docs/TODO.md:17` — M0, `:33` — C 줄기
- `/Users/dp/Repository/cyberscript/src/include/cyber.h:438` — "Suspended evals and host futures" 절
- `/Users/dp/Repository/cyberscript/examples/libcyber/host_await.c` — tars-agent 방식 그대로의 호스트 예제(래퍼, 승인, 거부, 취소)
- `/Users/dp/Repository/cyberscript/docs/releases/0.4.8.md` — 0.4.8 호환성과 알려진 문제

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 파일로 남기고 MEMORY.md에 한 줄. 사용자가 용어 옆에 원어를 괄호로 붙이는 표기(연료(fuel), 벽시계(wall-clock))를 쓰기 시작했다.
2. 초기 구간(M0와 아키텍처 뼈대)은 페어 코딩이다 (CLAUDE.md, ADR 0012). 단계마다 결정, 편집, 기능을 나눠 공유하고, 구조에 관한 결정은 사용자가 정한다. 사소한 선택만 추천안으로 간다. 이전 확정을 바꾸면 눈에 띄게 보고한다. 근거가 약해진 주장은 스스로 바로잡아 알린다.
3. cyber 쪽 작업은 요청서를 써서 사용자가 cyber 저장소에 전달하는 흐름이다. 보고가 오면 원문을 docs/requests에 두고, draft를 직접 빌드하고 테스트해(`zig build test`, 약 4분) 요청과 대조한 뒤 08, ADR, TODO에 반영한다. cyber 저장소와 tars-linux는 사용자 지시 없이 직접 편집하지 않는다. tars-linux에 필요한 것도 같은 요청서 흐름을 기본으로 한다 (ADR 0013).
4. cyber 릴리스가 나오면: 태그와 GitHub 릴리스 확인, 검토 커밋 이후 diff 확인, 릴리스 바이너리를 scratchpad에 받아 안내 예제 20개 재실행, deps.md 고정 버전과 08, 안내 기준 버전 갱신.
5. 구현을 시작하라는 지시가 오면 docs/TODO.md의 M0부터. 먼저 cyber.h, host_await.c, cyber의 docs/decisions/project_embedding_agent_loop.md를 읽는다. Anthropic API 세부는 구현할 때 최신 문서로 다시 확인한다.
