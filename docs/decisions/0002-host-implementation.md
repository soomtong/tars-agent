# 0002 호스트 구현 방식

상태: 확정 (방식 A). 2026-11-10, 초기 요구사항 대조(09 문서)

## 결정

agentd는 Zig 0.17 데몬이고 libcyber를 링크한다 (방식 A). 순수 Cyber CLI(방식 B)는 제품 후보에서 내리고 루프와 프롬프트를 빨리 보는 일회성 스파이크로만 쓴다.

## 근거

- 초기 요구사항이 Zig 호스트를 요구하고, 중단, 연료, 할당자, deny_raw_ptrs, validate 는 libcyber에만 있다.
- tars-linux 코드베이스와 같은 언어다.

## 남은 열린 질문

Zig 전용 API 표면 vs C ABI 래핑, agentd 저장소 위치. 09 문서 참고.
