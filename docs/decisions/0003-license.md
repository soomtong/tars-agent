# 0003 라이선스

상태: 확정 (2026-11-10, 사용자 지시 "License prefer BSD")

## 결정

BSD 3-Clause.

## 근거와 주의

- 사용자 선호가 BSD다. 2조항과 3조항 중 이름 사용 금지 조항이 있는 3조항을 골랐다. 2조항을 원하면 바꾼다.
- cyber(MIT), mimalloc(MIT), linenoise(BSD)는 호환된다. tcc는 LGPL이라 -Dffi=false 빌드에서만 링크되지 않는다. 에이전트 빌드는 항상 ffi를 끈다.
