# Cyber 런타임 사실과 제약

출처: soomtong/cyber docs/decisions (project_tars_agent_runtime_review, project_embedding_agent_loop, project_direction), 2026-11 기준 0.4.4. 구현 시작 전에 최신 상태를 다시 확인한다.

## 확인된 사실

- fork 용도: Python, Perl, Shell 대용 스크립트 CLI와 tars 에이전트 루프의 실행 언어 후보. 기본 백엔드는 바이트코드 VM이고 JIT, LLVM 백엔드는 제거했다.
- 언어 0.4: 정적 타입 + 값 소유권(move, &T 빌림, ^T ARC). 에러는 !T 와 error.Name 값. 보간은 %{}. 파이버는 없고 #[generator]와 spawn Thread + Future가 있다.
- 임베딩: libcyber 정적 라이브러리 2.1 MB (ReleaseFast, FFI 끔). cl_vm_init 0.2 ms, 첫 eval 2.8 ms, 같은 VM 두 번째 eval 0.01 ms. VM당 RSS 증가 약 2 MB, 첫 VM만 약 7 MB.
- 상태 유지: persist_main 으로 함수, 타입, use, main 지역 변수가 eval 사이에 이어진다. panic이면 지역 변수는 버려진다. 빌림 타입 지역은 이월되지 않는다.
- 제어: cl_vm_interrupt(다른 스레드에서 호출 가능), cl_vm_set_fuel, cl_vm_validate(실행 없이 컴파일만), cl_vm_set_printer, cl_vm_initx(할당자).
- 호스트 함수: #[bind] 선언 + cl_mod_add_func. 값 매개변수는 호스트가 소유하고 해제해야 한다.
- 라이브러리 기본 로더는 core, meta, math, cy, c, io, test 일곱 모듈만 제공한다. os, libc, cli는 CLI 전용이다.
- 없는 것: JSON, 정규식, 날짜 라이브러리. 호스트 함수 중간에 멈췄다 재개하는 수단. 메모리 상한 내장 기능. musl 정적 타깃에서 self dlopen(기본 ffi 꺼짐).
- tars에 이미 배포된 것은 CLI 번들(cyber-linux-x64.tar.gz). 실행 파일 옆에 src/ 가 있어야 한다. libcyber는 별도로 빌드해야 한다.

## 위험과 대응

- 스크립트 중 컴파일러 abort 가능성: 실행 프로세스 분리 평가
- 비-main await 등 Zig @panic("TODO") 경로: 해당 기능을 막는다 (spawn 금지 초기)
- 호스트 함수 안 블록은 못 끊음: 함수별 시간 제한
- 모델이 Cyber를 틀림: 부분집합 교육, validate 후 오류 되돌림, 측정으로 확인 (P0 평가)
- 언어/런타임 변경: fork라 변경 권한이 있지만 같은 변경을 두 번 유지하지 않도록 런타임은 soomtong/cyber 한 곳에 둔다. agentd는 tars-linux 쪽 또는 이 저장소.

## 외부 의존

- tars는 도구를 sha256 고정 미리 빌드 바이너리로 들인다. agentd와 libcyber도 이 방식(릴리스 산출물 + 해시)에 맞춘다.
- 프로토타입이 쓰는 외부 바이너리(curl, rg, fd, git)는 시작 시 존재 여부를 점검한다.
