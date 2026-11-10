# 0002 호스트 구현 방식

상태: 확정 (방식 A). 2026-11-10, 초기 요구사항 대조(09 문서)

## 결정

agentd는 Zig 0.17 데몬이고 libcyber를 링크한다 (방식 A). 순수 Cyber CLI(방식 B)는 제품 후보에서 내리고 루프와 프롬프트를 빨리 보는 일회성 스파이크로만 쓴다.

## 근거

- 초기 요구사항이 Zig 호스트를 요구하고, 중단, 연료, 할당자, deny_raw_ptrs, validate 는 libcyber에만 있다.
- tars-linux 코드베이스와 같은 언어다.

## 이후 결정

- "데몬" 부분은 0004가 바꿨다: v1은 세션당 프로세스 하나이고 실행 파일 이름은 tars-agent다. Zig + libcyber는 그대로다.
- Zig 전용 API 표면 대 C ABI, 저장소 위치는 0005에서 닫았다. 방식 B 스파이크는 0009에서 뺐다.
- Zig 버전은 cyber의 minimum_zig_version을 따라 0.17.1이다.
