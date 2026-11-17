# 0023 cyber 의존은 가장 새 빌드를 따른다

상태: 사용자 지시 (2026-11-16). "아직 커밋은 고정하는게 큰 의미가 없어. 그냥 latest 정도면 충분해."

## 결정

스파이크(그리고 본체가 생기면 본체)의 cyber 의존은 soomtong/cyber의 가장 새 빌드를 따른다. 특정 커밋을 기준으로 고정하지 않는다. 릴리스 태그와 `latest` 프리릴리스 태그 가운데 앞선 것을 받는다. 지금은 릴리스 `0.4.14`다(`latest` 프리릴리스보다 뒤에 나왔다). 릴리스면 사용자가 설치한 `/usr/local/bin/cyber`와 같다.

- build.zig.zon: `zig fetch --save=cyber "git+https://github.com/soomtong/cyber#<태그>"`. zig가 `?ref=<태그>#<받은 커밋>`과 해시를 적는다. 해시는 zig가 요구해서 남을 뿐, 기준을 고정하는 뜻은 없다.
- build.zig: 의존 인자는 `dev`만 넘긴다(릴리스면 false, 프리릴리스면 true). `build`, `commit`은 넘기지 않는다. 버전 문자열은 `Cyber 0.4.14-DEV build-0-local`(dev = true) 또는 `Cyber 0.4.14 build-0-local`(dev = false) 꼴이다.
- s1 검사 0은 버전 문자열을 비교하지 않고 `Cyber `로 시작하는지만 본다.
- 문구를 CLI로 볼 때는 받은 빌드와 같은 CLI를 쓴다. 릴리스면 설치된 `/usr/local/bin/cyber`, 프리릴리스면 `gh release download latest -R soomtong/cyber`.

## 근거

탐색 단계라 cyber가 tars-agent의 요청을 빠르게 받아 고친다. 커밋을 고정하면 고친 것을 받으려 매번 URL, 해시, 의존 인자, 검사 0, 문서의 버전 줄을 함께 올려야 한다. 그 비용에 비해 고정이 지키는 것(재현성)은 지금 쓸모가 적다.

`latest` 태그만 따르지 않는 것은, 릴리스 빌드만 돌고 `latest` 프리릴리스는 갱신되지 않는 때가 있어서다(0.4.13 릴리스 때 `latest`는 그 앞의 커밋에 남았다).

## 적용

- 새 릴리스(또는 릴리스보다 앞선 `latest`)가 나오면 두 스파이크에서 `zig fetch --save=cyber`를 다시 돌리고 s1, 안내의 코드 블록, 열린 요청의 재현을 돌린다.
- 아직 어느 태그에도 없는 cyber 수정은 `zig build --fork=<cyber 저장소>`로 본다.
- 문서의 기준 줄은 커밋 대신 버전(`cyber 0.4.14`)으로 적는다.
- 본체의 릴리스나 재현이 필요해지면 다시 정한다.

## 버린 대안

- 커밋 URL과 해시로 고정(이전 방식): 위 근거.
- `latest` 태그만 따르기: 위 근거.
- 로컬 cyber 저장소를 `.path`로: 로컬 상태에 따라 빌드가 바뀌고, 다른 기계와 tars 게스트에서 같은 것을 받지 못한다.
