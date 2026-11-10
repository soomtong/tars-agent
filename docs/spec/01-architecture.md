# 아키텍처

## 구성요소

~~~text
frontend (tars terminal 안의 TUI / headless CLI)
   |
agentd (core)
   +-- session        히스토리, 컴팩션, 저장
   +-- loop           모델 호출 - 코드 실행 반복 (02)
   +-- provider       모델 API 어댑터 (스트리밍)
   +-- runtime        libcyber VM 관리: eval, 검증, 중단, 연료
   +-- host api       Cyber에 열어 주는 호스트 함수 모음 (03, 04)
   +-- permission     호스트 함수 안의 정책 게이트 (05)
   +-- observability  세션 로그 (07)
~~~

## 핵심 설계 선택: CodeAct

- API 수준의 도구는 하나다 (가칭 run: Cyber 소스 문자열을 받는다). 읽기, 검색, 편집, 셸은 모두 Cyber 안에서 호스트 함수로 부른다.
- 장점: 한 턴에 여러 도구 호출과 분기, 반복, 중간값 가공을 모델 왕복 없이 처리한다. 대량 결과를 모델에 보내지 않고 스크립트 안에서 줄인다. 도구 정의 토큰이 API 도구 수에 비례하지 않는다.
- 단점: 모델이 Cyber를 써야 한다. Cyber는 학습 데이터가 적고 정적 타입과 소유권이 있어 틀리기 쉽다. 대응은 복사 가능한 타입(int, str, []T)만 쓰는 부분집합을 시스템 프롬프트에 가르치고, eval 전에 cl_vm_validate로 검증해 오류를 되돌려 주는 것이다.
- 폴백: API 수준 도구를 JSON으로 직접 노출하는 모드도 같은 호스트 함수 위에 얇게 얹을 수 있게 설계한다 (후속).

## 호스트 구현 방식 (결정 필요, ADR 0002)

- 방식 A: Zig 호스트 + libcyber. agentd는 Zig로 쓰고 libcyber를 Zig 모듈 또는 C API로 링크한다. 중단(cl_vm_interrupt), 연료(cl_vm_set_fuel), 출력 가로채기(cl_vm_set_printer), 할당자 교체, deny_raw_ptrs를 모두 쓸 수 있다. tars-linux 코드베이스와 같은 언어다.
- 방식 B: 순수 Cyber CLI 스크립트. cyber 실행 파일이 이미 tars에 있어 설치가 필요 없고 os 모듈(프로세스, 파일, fetchUrl)을 쓴다. 대신 JSON, SSE 스트리밍, 중단/연료, 샌드박스 제어가 없다.
- 권고: 프로토타입은 B로 빠르게 루프를 증명하고, 제품은 A로 간다. 호스트 함수 계약(04)은 두 방식에서 같게 유지한다.

## 경계 규칙

- 스크립트는 호스트 함수로만 세계에 닿는다. 라이브러리 로더에는 os 모듈이 없고, c 모듈과 raw 포인터는 막는다 (05).
- frontend는 입출력과 승인 UI만 그린다. 정책 판단은 core에 둔다.
- provider는 모델별 차이를 흡수한다. core는 공통 메시지 형식만 본다.
- 컴파일러 일부 경로는 panic이 아니라 프로세스 abort를 낸다 (cyber 기록). 스크립트 실행은 별도 프로세스로 분리하는 안을 열어 둔다.

## 모듈 후보

~~~text
agentd/
  main.zig
  core/{loop,session,message}.zig
  provider/{anthropic,adapter}.zig
  runtime/{vm,loader,limits}.zig
  host/{fs,search,edit,shell,task,net}.zig
  host/prelude.cy        호스트 함수 선언과 사양 주석
  permission/{policy,store}.zig
  ui/{tui,headless}.zig
  log/session_log.zig
~~~
