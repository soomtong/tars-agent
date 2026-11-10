# TODO

표기: [ ] 미착수, [~] 진행 중, [x] 완료. 코드 작성은 P0 결과 이후.

## P0 조사와 스파이크 (결정 전 필수)

- [x] tars-linux, cyber fork 현황 확인 (00, 08 문서에 반영)
- [x] 라이선스: BSD 3-Clause
- [x] ADR 0002: 호스트 방식 A(Zig + libcyber) 확정
- [x] 초기 요구사항 대조 (09 문서)
- [ ] 스파이크 1 (선택, 일회성, 방식 B): cyber CLI만으로 모델 호출 -> 코드 실행 -> 결과 반환 루프 (curl 위임 허용). 루프와 프롬프트 형태 검증
- [ ] 스파이크 2 (방식 A): Zig에서 libcyber 링크, 호스트 함수 2개(read, shell), 연료와 interrupt, 승인 대기 블록 동작 증명 (cyber 검토 문서의 5.3 2단계)
- [ ] libcyber를 tars-linux x86_64 glibc 환경에서 빌드, 배포하는 경로 확인 (devlayer 묶음 방식)
- [ ] 모델의 Cyber 코드 작성 정확도 측정: 부분집합 프롬프트로 대표 작업 20개, 첫 시도 성공률과 오류-수정 왕복 수
- [ ] 스크립트 실행 프로세스 분리 필요성 평가 (컴파일러 abort 경로)
- [ ] 모델 제공자 범위 결정 (Anthropic 단독 시작 여부)
- [ ] 저장소 위치 결정: agentd를 이 저장소에 둘지 tars-linux에 넣을지

## P0 산출 문서 (요구사항 5절)

- [ ] docs/design.md: 구성요소 책임, 데이터 흐름, 정책 파일 포맷, 감사 로그 포맷, MCP 매핑 규칙 (이 저장소의 spec/ 을 통합)
- [ ] docs/fork-plan.md: 에이전트 프로파일의 빌드 옵션과 로더 구성, 필요한 fork 변경(비-main await 차단, c 모듈 필터 옵션 등)
- [ ] docs/deps.md: 의존 목록, 이유, 라이선스 (GPL 계열 금지)
- [ ] 정책 파일 포맷 확정, 감사 로그 JSONL 필드 확정

## P1 코어 뼈대

- [ ] 메시지 형식, 세션 구조 확정 (02)
- [ ] provider 어댑터: Anthropic Messages API, 스트리밍
- [ ] 루프: run 도구, validate -> eval -> 결과 조립, 한도 (턴, 연료, 벽시계)
- [ ] 실패 분류 문구: 컴파일 오류, panic, 중단, 거부, reset 알림
- [ ] 세션 로그 JSONL과 리플레이 (07)
- [ ] agentd 데몬: session manager, runtime pool(VM당 스레드), capability broker
- [ ] 컨텍스트 예산: 능력 결과는 스크립트 안에서 소비, return 상한

## P2 호스트 함수

- [ ] prelude.cy 선언과 사양 주석 형식, 사양을 시스템 프롬프트로 조립
- [ ] 호스트 함수 작성 규칙 검사 (소유권 해제, 오류 값 반환, 절단)
- [ ] 파일: read, glob, search
- [ ] 파일: edit, write
- [ ] 셸: shell, shell_start, task_output, task_kill
- [ ] json, regex, now
- [ ] note, recall (panic에도 남는 상태)
- [ ] help (지연 로딩)

## P3 권한과 샌드박스

- [ ] 런타임 구성: ffi 끔, c 모듈 필터, deny_raw_ptrs, 할당자 상한
- [ ] 정책 엔진: allow/ask/deny, 모드
- [ ] shell 명령 분류기와 테스트 표
- [ ] 승인 기억 저장소
- [ ] 보호 규칙 (시스템 경로, 하네스 외 프로세스), 비밀 마스킹

## P4 프런트엔드

- [ ] 헤드리스 CLI (단발 프롬프트, 정책 파일)
- [ ] tars terminal 안의 대화형 TUI (입력, 스트리밍, 승인, 인터럽트)

## P5 컨텍스트와 확장

- [ ] 컴팩션 (출력 요약, 정의된 이름 목록 유지)
- [ ] 세션 재개 (VM 상태는 히스토리 코드를 재생해 복원하는 안 검토)
- [ ] MCP stdio 클라이언트와 선언 생성
- [ ] MCP 서버 방향: tars 능력을 외부에 노출 (같은 정책 지점)
- [ ] MCP HTTP 전송(SSE 또는 streamable)
- [ ] 프롬프트 캐싱 최적화

## P6 후속

- [ ] 서브에이전트
- [ ] tars 특화 함수 (service_status, journal)
- [ ] API 수준 JSON 도구 폴백 모드
- [ ] 스택형 Fiber 필요성 판단 (승인 대기 한계가 실제 문제일 때)
- [ ] 다른 provider 어댑터

## tars-linux 통합

- [ ] devlayer 묶음 등록 (sha256 고정 릴리스 산출물)
- [ ] init 서비스 감독 하에 실행할지 사용자 명령으로만 실행할지 결정 (부팅은 막지 않는다)
- [ ] tars 게이트 체인 make check CHAIN=agent: 자연어 요청 -> 스크립트 -> 승인 프롬프트 -> y -> 파일 생성을 픽셀과 로그로 판정
- [ ] tars 패널 API 확인, 없으면 인터페이스만 정의하고 모의 구현
- [ ] 승인 키 바인딩이 copy mode, 한/영 전환 키와 충돌하지 않는지 확인
- [ ] tars.conf 설정 키 정의
- [ ] 규율: 서브프로젝트마다 design doc과 milestone plan, 끝나면 기록

## 언어 문서와 평가

- [ ] 런타임 CLI: new(AGENTS.md + 최소 프로젝트), spec --for-agents(버전 일치 규칙, 능력 시그니처, 에러 코드), 4,000 토큰 이하, 예제 10개를 테스트로 실행
- [ ] 사람용 스펙과 에이전트용 문서를 한 소스에서 생성
- [ ] eval/: 과제 20개와 채점 스크립트, 첫 시도 성공률과 실패 유형 기록
- [ ] 측정 결과에 따른 문법 또는 스펙 문서 수정

## 테스트 계획

- [ ] 호스트 함수별 단위: 정상, 오류, 절단, 타임아웃, 빈 결과, 누수 검사 allocator
- [ ] 루프: 모의 provider로 코드 블록 시나리오 재생
- [ ] 샌드박스: raw 포인터, c 모듈, 무한 루프(연료), 시간 초과 시도가 모두 결과 오류로 끝나는지
- [ ] 권한 분류기 케이스 표
- [ ] 헤드리스 종단 테스트

## 문서

- [ ] 사용자 가이드 (설치, 정책 파일)
- [ ] 호스트 함수 작성 가이드
- [ ] 시스템 프롬프트의 Cyber 부분집합 가이드
