# 0023 cyber 의존은 latest 태그를 따른다

상태: 사용자 지시 (2026-11-16). "아직 커밋은 고정하는게 큰 의미가 없어. 그냥 latest 정도면 충분해."

## 결정

스파이크(그리고 본체가 생기면 본체)의 cyber 의존은 soomtong/cyber의 `latest` 태그(dev 프리릴리스)를 따른다. 특정 커밋이나 버전 태그에 묶지 않는다.

- build.zig.zon: `zig fetch --save=cyber "git+https://github.com/soomtong/cyber#latest"`. zig가 `?ref=latest#<받은 커밋>`과 해시를 적는다. 해시는 zig가 요구해서 남을 뿐, 기준을 고정하는 뜻은 없다.
- build.zig: 의존 인자에 `build`, `commit`을 넘기지 않는다. 버전 문자열은 `Cyber <버전>-DEV build-0-local`이다.
- s1 검사 0은 버전 문자열을 비교하지 않고 `Cyber `로 시작하는지만 본다.
- 문구를 CLI로 볼 때는 latest 프리릴리스의 CLI(`gh release download latest -R soomtong/cyber`)를 쓴다.

## 근거

탐색 단계라 cyber가 tars-agent의 요청을 빠르게 받아 고친다. 커밋을 고정하면 고친 것을 받으려 매번 URL, 해시, 의존 인자, 검사 0, 문서의 버전 줄을 함께 올려야 한다. 그 비용에 비해 고정이 지키는 것(재현성)은 지금 쓸모가 적다.

## 적용

- cyber가 고친 것을 받을 때는 `latest`가 그 커밋으로 옮겨졌는지 보고(`gh release view latest -R soomtong/cyber`), 두 스파이크에서 `zig fetch --save=cyber` 를 다시 돌린 뒤 s1을 돌린다.
- 문서의 기준 줄은 커밋 대신 "latest dev 0.4.x-DEV"로 적는다.
- 본체의 릴리스나 재현이 필요해지면 다시 정한다.

## 버린 대안

- 커밋 URL과 해시로 고정(이전 방식): 위 근거.
- 로컬 cyber 저장소를 `.path`로: 로컬 상태에 따라 빌드가 바뀌고, 다른 기계와 tars 게스트에서 같은 것을 받지 못한다. 확인용으로는 `zig build --fork=<cyber 저장소>`로 충분하다.
