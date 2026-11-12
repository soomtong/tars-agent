# HANDOFF: cyber 0.4.9 반영과 ADR 0016 완료, 다음은 M0 스파이크와 cyber C1 (2026-11-12)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 현재는 명세, 결정, TODO, 프롬프트 안내만 있고 코드는 없다.

이번 세션의 흐름: cyber 0.4.9 릴리스(fiber 안 await의 양보, 취소, scope 블록)를 문서에 반영했다. 처음에는 태그가 없어 로컬 빌드(82877718)로 확인했고, cyber가 결함 수정 둘을 더해 태그를 단 뒤 고정 버전을 올렸다. cyber의 안내 보고를 받아 저장소에 넣었고, 보고가 남긴 결정 셋을 ADR 0016으로 정했다.

그 앞 세션들(이 문서의 이전 판 이후): 페어 코딩과 범위(ADR 0012, 0013), 개발 중 저렴한 모델과 전송 형식 둘(ADR 0014), 제공자 설계(ADR 0015), cyber 작업 줄기에 toon 모듈 추가.

## 현재 브랜치

`main` = origin/main. 작업 트리는 깨끗하다. 이번 세션의 커밋은 29e3fa3, 364c849, f28e508과 이 문서의 갱신이다. 커밋과 push는 Claude에게 위임돼 있다: 의미 있는 변경은 묻지 않고 커밋하고 push한다 (docs/decisions/feedback-commit-delegation.md).

## 완료된 작업

- [x] cyber 0.4.9(태그 0.4.9 → 03d24f4e, build-833) 고정: deps.md, 안내 기준 버전(한/영), 00과 09의 버전 표기
- [x] 08 문서에 0.4.9 항목: fiber 안의 await는 CL_AWAIT로 나가지 않는다, cl_vm_pending_futures가 멈춘 fiber들의 Future 전부를 준다, resume 뒤 목록을 다시 읽는다, 취소된 요청은 알림 없이 버려진다, cl_vm_release_result, 모델 코드의 함정 셋
- [x] ADR 0011과 05의 fiber 서술을 0.4.9에 맞춤. 08의 "cyber에서 만들 것" 표에서 fiber 양보(로드맵 단계 3)를 끝남으로
- [x] 안내: scope를 예약어 목록에 추가, "fiber와 scope 블록은 쓰지 않는다: 능력 호출은 한 번에 하나씩 차례로 한다" 한 줄
- [x] 확인: 태그와 GitHub 릴리스, 82877718 이후 두 커밋(06b0cd7b, 03d24f4e), cyber.h는 두 커밋에서 바뀌지 않음. 안내 예제 20개를 설치된 0.4.9(build-833)로 실행해 모두 통과. scope 블록에 빌림 인자를 넘기는 예제도 실행해 확인
- [x] cyber의 안내 보고를 docs/requests/cyber-0.4.9-report.md로 저장
- [x] ADR 0016: 동시 승인은 요청 번호가 가장 작은 것부터 하나씩 묻고 resume, v1 안내는 fiber와 scope를 가르치지 않음(막는 장치도 없음), 취소된 요청은 eval 끝의 요청 표 비우기로. 02의 실행 단계와 MEMORY.md 색인에 반영
- [x] (앞 세션들) ADR 0012 페어 코딩, 0013 범위, 0014 저렴한 모델과 전송 형식 둘, 0015 제공자 설계

## 시도했으나 실패한 접근

- 태그 없이 고정 버전 올리기: 첫 알림 때 origin에 0.4.9 태그가 없었고 릴리스 노트의 해시와 빌드 번호가 자리표시자였다. 고정은 0.4.8에 두고 동작 서술만 먼저 반영했다. 실제로 태그는 커밋 둘이 더 들어간 뒤에 달렸다. 릴리스 알림을 받으면 태그부터 확인한다.
- 로컬 빌드로 동시 승인 흐름을 믿기: 82877718에는 중첩 scope 블록에서 그룹 밖 요청을 먼저 완료하면 끝없이 도는 결함(F-111)이 있었다. 호스트가 없어 이 흐름은 아직 직접 돌려 보지 못했다. 스파이크 1의 확인 항목이다.
- fiber로 승인 대기 해결: 호스트 함수를 건너 suspend할 수 없다(Cannot suspend across a host call.). 그래서 CL_AWAIT를 요청했다. 0.4.9에서도 그대로다.
- 호스트가 Future 포인터로 요청을 찾기: 버린 Future의 주소가 다음 Future에 재사용된다. 태그(cl_future_new의 tag, cl_future_tag)로 찾는다. 요청 번호는 1부터(0은 호스트가 만들지 않은 Future).
- 안내에 "최상위에서 !else로 받아 출력": 최상위 !else 블록은 return으로 끝낼 수 없어 컴파일 오류다. try: ... else |e|: 로 쓴다.
- 버린 대안은 ADR에 있다. 다시 제안하지 않는다: 승인 요청을 한 화면에 모아 묻기, v1에서 scope 블록 가르치기, fiber와 scope를 호스트가 막기(0016. 되살리는 조건이 적혀 있다), Anthropic 형식만 유지(0014), 그 밖의 것은 0004~0010.

## 남은 작업

정본은 docs/TODO.md다. 초기 구간은 페어 코딩이고 스파이크의 순서는 페어 첫 단계에서 사용자가 정한다 (ADR 0012).

- [ ] M0 스파이크 1, 호스트 경계: cyber 0.4.9를 build.zig.zon 의존으로 링크, 능력 2개, 호스트 로더, deny_raw_ptrs, 상한 넷, validate, persist_main, CL_AWAIT 승인 흐름(태그로 요청 찾기). 확인 목록 `docs/spec/08-cyber-implementation.md:53`
- [ ] 스파이크 1에서 동시 승인 확인 (ADR 0016): scope 블록으로 요청 둘을 걸고 번호 순으로 하나씩 완료, 중첩 블록에서 그룹 밖 요청 먼저 완료(F-111), 하나를 거부하면 나머지가 버려지고 요청 표가 비는지
- [ ] M0 스파이크 2, 제공자: 전송 형식 둘(Anthropic Messages, OpenAI Chat Completions)을 DeepSeek으로 확인 (ADR 0014). 그 뒤 ADR 0015의 "2a 뒤에 정할 것" 넷. 스파이크 3: x86_64-linux-gnu 교차 빌드와 tars 게스트(QEMU) 실행
- [ ] cyber C1: json 모듈, toon 모듈(json 다음에 요청서), 빌드 내보내기. C2: regex(역추적 없는 엔진), time. C3: 임베딩 옵션(모듈 허용 표, spawn 차단)
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록. 평가 도구가 cl_thread_rc로 누수를 세면 먼저 cl_vm_release_result를 부른다
- [ ] M1~M6
- [ ] 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5), 기본값 매개변수가 #[bind]에서 되는지 (M0)
- [ ] tars-linux devlayer의 cyber는 0.4.7이다(`/Users/dp/Repository/tars-linux/devlayer/manifest.toml:580`). tars-linux는 사용자 지시 없이 고치지 않는다

## 핵심 파일

- `docs/spec/08-cyber-implementation.md:23` — CL_AWAIT API와 규칙, `:35` 0.4.9의 변경, `:53` M0 확인 목록, `:62` cyber에서 만들 것
- `docs/decisions/0016-concurrent-approvals-and-fibers-in-v1.md:13` — 결정 셋, `:35` 되살리는 조건
- `docs/decisions/0011-approval-wait-outside-vm.md:5` — 결정, `:53` 바인딩 층 설계, `:59` cyber가 고른 동작(0.4.9 주석 포함)
- `docs/decisions/0015-provider-message-model-and-adapters.md:16` — 메시지 모델과 어댑터의 방향, `:26` 2a 뒤에 정할 것
- `docs/spec/02-agent-loop.md:30` — 실행 단계(CL_AWAIT, 요청이 여럿일 때)
- `docs/requests/cyber-0.4.9-report.md` — cyber의 0.4.9 안내 원문. `docs/requests/cyber-cl-await.md`와 `-report.md` — CL_AWAIT 요청과 보고
- `prompt/cyber-subset.md:5` — 기준 버전, `:79` 예약어와 fiber 금지 줄. 영문판 `prompt/cyber-subset.en.md`는 같은 구조
- `docs/TODO.md:21` — M0, `:40` — C 줄기
- `/Users/dp/Repository/cyberscript/src/include/cyber.h:441` — "Suspended evals and host futures" 절
- `/Users/dp/Repository/cyberscript/examples/libcyber/host_await.c` — tars-agent 방식 그대로의 호스트 예제(래퍼, 승인, 거부, 취소)
- `/Users/dp/Repository/cyberscript/docs/releases/0.4.9.md` — 0.4.9 호환성과 알려진 문제

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 파일로 남기고 MEMORY.md에 한 줄. 용어 옆에 원어를 괄호로 붙이는 표기(연료(fuel), 벽시계(wall-clock))를 쓴다.
2. 초기 구간(M0와 아키텍처 뼈대)은 페어 코딩이다 (CLAUDE.md, ADR 0012). 단계마다 결정, 편집, 기능을 나눠 공유하고, 구조에 관한 결정은 사용자가 정한다. 추천안과 근거를 내면 사용자가 받거나 바꾼다. 이전 확정을 바꾸면 눈에 띄게 보고한다.
3. cyber 쪽 작업은 요청서를 써서 사용자가 cyber 저장소에 전달하는 흐름이다. 보고가 오면 원문을 docs/requests에 두고 08, ADR, TODO에 반영한다. cyber 저장소와 tars-linux는 사용자 지시 없이 직접 편집하지 않는다. cyber 저장소에서는 다른 세션이 동시에 작업할 수 있다(이번에 커밋되지 않은 변경이 보였다).
4. cyber 릴리스가 나오면: origin의 태그와 GitHub 릴리스부터 확인(`git ls-remote --tags origin`, `gh release list`), 앞서 본 커밋 이후의 diff와 cyber.h 변경 확인, `cyber version`이 태그와 맞는지 확인, 안내 예제 20개 재실행, deps.md 고정 버전과 08, 안내 기준 버전 갱신. 예제는 안내의 cy 코드 펜스를 파일로 뽑아 하나씩 실행한다.
5. 로컬 `/usr/local/bin/cyber`는 사용자가 릴리스마다 올린다(지금 0.4.9 build-833). cyberscript의 `zig-out/bin/cyber`는 버전 표시가 DEV인 작업 중 빌드라 릴리스 확인에 쓰지 않는다.
6. 구현을 시작하라는 지시가 오면 docs/TODO.md의 M0부터. 먼저 cyber.h, host_await.c, cyber의 docs/decisions/project_embedding_agent_loop.md를 읽는다. 제공자 API 세부는 구현할 때 최신 문서로 다시 확인한다.
