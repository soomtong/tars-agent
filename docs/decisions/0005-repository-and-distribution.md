# 0005 저장소, 런타임 링크, 배포

상태: 확정 (2026-11-10). M0 스파이크 1에서 링크 방법을 확인한다.

## 결정

- 코드는 이 저장소(tars-agent)에 둔다. tars-linux에 넣지 않는다.
- 런타임은 soomtong/cyber 한 곳이다. 두 번째 fork와 별도 런타임 이름은 만들지 않는다. 제품 이름은 tars-agent, 런타임 이름은 cyber 그대로다.
- cyber는 build.zig.zon 의존으로 태그와 해시를 고정해 소스에서 빌드하고 정적 링크한다 (-Dffi=false). libcyber를 따로 배포하지 않는다.
- API 표면은 cl_* C ABI를 runtime/cy.zig 한 파일로 감싸 쓴다. fork에 Zig 전용 표면을 만들지 않는다.
- 산출물은 x86_64-linux-gnu(glibc 동적 링크) 실행 파일 하나다. GitHub 릴리스에 sha256과 함께 올리고 tars-linux가 devlayer/manifest.toml로 들인다.

## 근거

- tars-linux의 규칙이 "도구는 sha256을 고정한 미리 빌드 바이너리로 들인다"이다. cyber, cci가 이미 이 길로 들어간다. 에이전트도 같은 길이면 tars-linux의 게이트와 릴리스 주기에 묶이지 않는다.
- 정적 링크면 런타임 버전 불일치가 없다. 시스템 프롬프트의 Cyber 안내와 링크된 런타임이 같은 커밋에서 테스트된다.
- C ABI는 이미 문서와 테스트가 있는 표면이다. 감싸는 비용은 파일 하나이고, Zig 전용 표면은 fork에 유지할 것을 하나 더 만든다.

## 주의

- cyber의 build.zig가 의존으로 쓸 아티팩트를 내보내지 않으면 fork에 내보내기를 더한다 (08 문서).
- 라이선스 조건은 FFI를 끈 빌드에서만 성립한다 (0003, docs/deps.md).
