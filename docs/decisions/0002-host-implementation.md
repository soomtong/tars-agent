# 0002 호스트 구현 방식

상태: 제안 (P0 스파이크 후 확정)

## 선택지

- A: Zig 호스트 + libcyber. 중단, 연료, 할당자, deny_raw_ptrs, validate 전부 사용. tars-linux와 같은 언어.
- B: 순수 Cyber CLI. 설치 불필요(cyber 0.4.4가 이미 devlayer에 있음). JSON, SSE, 중단/연료, 샌드박스 제어 없음.

## 제안

프로토타입은 B로 루프와 프롬프트를 빠르게 검증하고, 제품은 A로 간다. 호스트 함수 계약(04)은 두 방식에서 같게 한다.

## 확정 조건

스파이크 1, 2 결과(TODO P0)와 libcyber의 tars 배포 경로.
