# 아키텍처

## 프로세스 모델 (ADR 0004)

세션 하나에 프로세스 하나다. tars-agent 실행 파일이 코어를 링크하고 프런트엔드(대화형 또는 헤드리스)를 하나 고른다. 데몬은 없다.

- 스레드: 메인 스레드가 루프와 VM을 돈다. 보조 스레드는 둘이다. 입력 스레드(키 입력, 인터럽트)와 타이머 스레드다. 타이머 스레드는 벽시계(wall-clock) 상한에서 cl_vm_interrupt를 부른다.
- 승인 대기는 VM 밖, 루프의 바닥에서 한다 (ADR 0011). 승인이 필요한 능력은 미완료 Future를 돌려주고, eval이 CL_AWAIT로 돌아오면 루프가 승인을 받고 resume한다. CL_AWAIT는 cyber 0.4.8부터 있다. 세션이 하나이므로 "다른 세션이 막히지 않는다"는 불변식은 프로세스 격리로 성립한다.
- 여러 세션이 필요하면 패널마다 tars-agent를 하나씩 띄운다. VM당 약 2 MB, 첫 VM 약 7 MB라 부담이 없다.
- 데몬(agentd)이 필요해지는 때는 tars 터미널 제어 채널이나 MCP 서버 방향을 만들 때다. 그때 데몬은 헤드리스 stream-json 프로토콜을 말하는 프런트엔드 하나로 얹는다 (06).

## 구성요소

~~~text
frontend    repl (대화형) / headless (-p, text | json | stream-json)
   |        이벤트 스트림 (코어 -> 프런트엔드), 명령 (프런트엔드 -> 코어)
core
   +-- session      히스토리, 기록(JSONL), 재개, 컴팩션
   +-- loop         모델 호출 - 검증 - 실행 반복 (02)
   +-- provider     전송 형식 둘: Anthropic Messages, OpenAI Chat Completions (ADR 0014). SSE 스트리밍, 재시도
   +-- prompt       시스템 프롬프트 조립: 규칙, Cyber 안내, 능력 사양, 환경, AGENTS.md
   +-- runtime      libcyber VM: 로더, validate, eval, 연료(fuel), 스택/메모리 상한, 중단
   +-- caps         능력 표 (단일 소스) 와 본체 (03, 04)
   +-- permission   프로파일, 모드, 규칙, 승인 요청 (05)
   +-- sandbox      실행 프로세스의 Landlock 제한 (Linux)
~~~

## 핵심 설계 선택 1: CodeAct

- API 수준의 도구는 run 하나다. 읽기, 검색, 편집, 실행은 모두 Cyber 안에서 능력 함수로 부른다.
- 장점: 한 스텝에 여러 호출과 분기, 반복, 중간값 가공을 모델 왕복 없이 처리한다. 큰 결과를 모델에 보내지 않고 스크립트 안에서 줄인다. 도구 정의 토큰이 도구 수에 비례하지 않는다.
- 단점: 모델이 Cyber를 써야 한다. 학습 데이터가 적고 정적 타입과 소유권이 있어 틀리기 쉽다. 대응은 복사 가능한 타입(int, str, []T)만 쓰는 부분집합을 가르치고, eval 전에 cl_vm_validate로 검증해 오류를 되돌리는 것이다.
- 이 단점은 프로젝트의 가장 큰 위험이라 측정으로 판정한다. M0의 평가에서 기준(TODO M0)을 넘지 못하면 기본 모드를 direct로 바꾼다.

## 핵심 설계 선택 2: 능력 표 단일 소스 (ADR 0006)

능력은 Zig comptime 표 하나에 정의한다. 항목은 이름, 매개변수 타입, 반환 타입, 등급, 사양 문서, 본체 함수다. 이 표에서 넷을 만든다.

- Cyber 선언 (#[bind] fn) 과 cl_mod_add_func 바인딩
- 시스템 프롬프트의 능력 사양
- JSON Schema: direct 모드의 API 도구 정의, 후속의 MCP 서버 방향
- 권한 게이트의 등급 표

본체는 VM을 모른다. 인자를 Zig 값으로 받고 Zig 값이나 오류를 돌려준다. Cyber 값 변환과 소유권 해제(cl_str_deinit 등)는 생성된 바인딩 층 한 곳에서만 한다. 능력을 하나 더하는 일이 표에 한 항목을 더하는 일이 된다.

direct 모드는 같은 표를 API 도구 여럿으로 노출하고 VM을 쓰지 않는다. 평가의 대조군이고, CodeAct가 기준에 못 미칠 때의 기본값이다.

## 경계 규칙

- 스크립트는 능력으로만 세계에 닿는다. 로더는 os 모듈을 모르고, c 모듈은 호스트 로더가 거부하고, raw 포인터는 deny_raw_ptrs로 막는다 (05).
- 프런트엔드는 입출력과 승인 화면만 그린다. 정책 판단은 코어에 둔다. 코어는 터미널을 직접 만지지 않고 이벤트를 낸다.
- provider는 제공자 차이를 흡수한다. 코어는 내부 메시지 형식만 본다. 단 히스토리의 assistant 블록은 받은 그대로 보관한다 (02). 코어가 보는 것은 자체 메시지 모델이고, 형식마다 어댑터가 있고, 제공자는 설정 데이터다 (ADR 0015). 받은 원문은 블록의 불투명 칸에 실어 같은 형식 안에서 그대로 되돌린다.
- libcyber는 runtime 모듈 밖으로 새지 않는다. cl_* C ABI를 runtime/cy.zig 한 파일이 감싼다. fork에 Zig 전용 표면을 만들지 않는다.
- Cyber 컴파일러에 남은 abort 경로는 fork의 버그로 다룬다. 프로세스가 죽으면 그 스크립트가 세션 디렉터리에 남아 재현 사례가 되고, 세션은 --continue로 잇는다. 실행 프로세스 분리는 죽는 비율을 재 본 뒤 판단한다.

## 저장소와 배포 (ADR 0005)

- 코드는 이 저장소(tars-agent)에 둔다. cyber는 build.zig.zon의 의존으로 태그와 해시를 고정해 소스에서 빌드하고 정적 링크한다 (-Dffi=false). libcyber를 따로 배포하지 않는다.
- 산출물은 x86_64-linux-gnu 동적 링크(glibc) 실행 파일 하나다. GitHub 릴리스에 올리고 tars-linux가 devlayer/manifest.toml에 url과 sha256으로 들인다. cyber, cci와 같은 길이다.
- 개발용으로 aarch64-macos 빌드도 유지한다.

## 디렉터리

~~~text
src/
  main.zig                인자 해석, 프런트엔드 선택
  core/{loop,session,message,compact}.zig
  provider/{anthropic,openai,sse,http}.zig
  prompt/{build.zig, rules.md, cyber-subset.md}
  runtime/{cy,vm,loader,limits}.zig
  caps/{table,bind,fs,search,edit,proc,net,ui,memo,clock}.zig
  permission/{profile,rules,gate}.zig
  sandbox/landlock.zig
  frontend/{repl,headless}.zig
eval/                     과제와 채점기 (M0)
test/                     모의 provider 시나리오
~~~
