# 초기 요구사항(legacy) 대조

초기 요구사항 지시서(tars-linux 내장 에이전트 시스템)를 현재 명세와 대조한 결과다. 지시서는 Cyber 0.3과 Zig 0.12~0.13 세대를 가정해 쓰였다. soomtong/cyber의 검토 문서(project_tars_agent_runtime_review.md, 2026-11-01)가 이미 차이를 확인했고, 여기서는 이 저장소의 결정으로 정리한다.

## 그대로 채택

- 형태: CodeAct + 능력(capability) 기반 런타임. 스크립트는 능력 함수로만 세계에 닿는다.
- 구현은 Zig 0.17 (minimum_zig_version = 0.17.0), glibc 동적 링크, musl 정적 링크 금지, GPL 계열 의존 금지, BSD 호환 라이선스만.
- agentd: Zig 데몬. session manager, model client, runtime pool, capability broker, mcp client, mcp server. 호스트 방식은 A(Zig + libcyber)로 확정한다.
- 능력 등록 형식: 이름 + 타입 시그니처 + 설명 + 위험 등급. 등급은 최소 read, write, exec, net, ui.
- 세션별 능력 집합: 허용되지 않은 능력은 거부가 아니라 이름 자체가 주입되지 않는다.
- 정책은 데이터 파일. 모든 능력 호출은 감사 로그(시각, 세션, 능력, 인자 요약, 결정, 소요 시간, 결과 크기).
- 승인 UX: tars 터미널의 패널 하나 안에서, 키보드만으로. 한글 입력 상태에서도 눌리도록 숫자 키 또는 라틴 강제. copy mode와 한/영 전환 키와 충돌 금지. 설정은 tars.conf에 둔다.
- MCP 양방향: 클라이언트(stdio, HTTP)와 서버(tars 능력을 외부에 노출, 같은 정책 지점 통과). 위험 등급 미지정 서버는 exec로 간주.
- 세션 히스토리는 JSONL로 저장하고 리플레이 가능해야 한다 (스크립트 전문, 능력 호출 로그, 모델 응답).
- 컨텍스트 예산: 능력 결과는 스크립트 안에서 소비하고, 모델에는 return 값과 짧은 요약만 간다. 큰 결과는 명시적 return + 크기 상한.
- 에이전트용 언어 문서: 런타임 CLI가 생성한다 (new 가 AGENTS.md 생성, spec --for-agents 가 설치 버전과 정확히 일치하는 규칙, 능력 시그니처, 에러 코드를 출력). 4,000 토큰 이하, 예제 10개, 예제는 실행되는 테스트. 사람용 스펙과 한 소스에서 생성.
- 측정 과제 20개와 채점 스크립트(eval/). 문법 변경은 측정 결과에서만 근거를 얻는다.
- 게이트: QEMU에서 자연어 요청 -> 스크립트 -> 승인 프롬프트 -> y -> 파일 생성을 픽셀과 로그로 판정하는 체인 make check CHAIN=agent.
- 서브프로젝트 규율: design doc과 milestone plan, 끝나면 배운 것 기록, 게이트 통과 후 다음으로.
- 비밀: API 키는 환경 변수 또는 권한 0600 설정 파일에서만. 코드와 로그에 남기지 않는다.
- 문서 규약: 코드 블록 펜스는 ~~~ 를 쓴다. 외부 의존은 docs/deps.md 에 이유와 라이선스를 기록한다.
- 비목표: JIT 성능, 수치 라이브러리, 추론 엔진 내장, GUI 승인 창, 멀티유저.

## 사실이 달라서 바꾼 것

- 파이버와 coyield/coresume: 존재하지 않는다. 2025-11 upstream 재설계에서 삭제됐고 지금은 #[generator](stackless)와 spawn Thread + Future다. 호스트 함수 안에서 멈췄다 재개하는 수단이 없다. 대체: 호스트 함수가 동기적으로 블록(승인 대기 포함)하고 VM당 OS 스레드 하나를 쓴다. 불변식("승인 대기 중에도 다른 세션은 계속 돈다")은 유지된다. 스택형 Fiber 구현은 이 방식의 한계가 실제로 드러난 뒤 판단한다 (TODO P6).
- 취소: "파이버를 버린다" 대신 cl_vm_interrupt + 연료 상한 + 호스트 함수 자체의 취소 확인. 호스트 함수 안에서 막힌 호출은 함수가 직접 풀어야 한다.
- 언어 버전: Cyber 0.4.4 (정적 타입 + 소유권, 점진적 타입 아님, 보간은 %{}). 시스템 프롬프트에는 복사 가능한 타입(int, str, []T)만 쓰는 부분집합을 가르친다.
- Zig 업그레이드: 이미 끝났다 (fork가 0.17 사용). 첫 작업은 업그레이드가 아니라 호스트 경계 증명(방식 A)이다.
- JIT: 코드까지 제거됐다. FFI는 -Dffi=false 빌드 옵션이 있고 라이브러리는 기본 꺼짐이다. 임의 모듈 로딩은 고정 표 일곱 모듈(core, meta, math, cy, c, io, test)이 막는다.
- 남은 구멍: c 모듈(raw 포인터)과 use c 없이 쓰는 as[Ptr[int]] 캐스트. 로더에서 c를 거르고 deny_raw_ptrs 를 켠다.
- 표준 라이브러리: JSON, 정규식, 날짜 계산이 없다. 순수 라이브러리로 새로 쓰거나(Cyber 쪽) 호스트가 제공한다. 시계 읽기는 능력.
- 런타임 이름과 포크: 별도 이름의 두 번째 포크를 만들지 않는다. 런타임은 soomtong/cyber 한 곳에서 유지하고, 에이전트 프로파일은 빌드 옵션과 로더 구성으로 나눈다 (cyber 검토 권고). 제품명과 라이브러리명을 따로 두는 안은 열린 질문.
- 링크 방식: 지시서는 Zig->Zig 소스 링크를 요구한다. 현재 공개 API는 export fn cl_* (C ABI) 모양이다. Zig 모듈 import는 가능하나 표면이 C 스타일이다. Zig 전용 표면을 만들지는 열린 질문.
- 메모리 목표(유휴 5 MB 이하): VM당 약 2 MB로 충족, 첫 VM만 약 7 MB.
- 호스트 방식 B(순수 Cyber CLI)는 제품 후보에서 내리고, 루프와 프롬프트 형태를 빨리 보는 일회성 스파이크로만 쓴다.

## 능력 이름 체계 (04 문서에 반영)

지시서의 점 표기를 채택한다: fs.list, fs.read, fs.stat, fs.write, fs.glob, proc.exec, net.http, tars.window.list, tars.window.focus, tars.terminal.send, tars.terminal.read, tars.notify, ui.ask, mcp.call. 04 문서의 이전 이름(read, search, edit, shell 등)은 이 이름의 별칭 또는 하위 함수로 정리한다.

## 열린 질문

- 에이전트 프로파일 런타임의 제품명, 라이브러리명 (이름 변경 요구 vs 단일 fork 유지)
- Zig 전용 API 표면을 만들지, C ABI를 Zig 모듈로 감싸 쓸지
- fork 쪽 non-main await 경로의 @panic(TODO)를 에이전트 프로파일에서 어떻게 막을지
- JSON, 정규식, 날짜를 Cyber 순수 라이브러리로 쓸지 호스트 능력으로 둘지
- agentd를 이 저장소에 둘지 tars-linux 저장소에 둘지 (지시서는 agentd/ 와 런타임 포크의 두 레포)
- 승인 대기의 OS 스레드 점유가 수십 세션 규모에서 문제인지 (측정 필요)
- tars 터미널의 패널 API 존재 여부 (지시서도 모의 구현으로 시작하라고 함)
- 컴파일러 abort 경로 때문에 스크립트 실행을 별도 프로세스로 분리할지
