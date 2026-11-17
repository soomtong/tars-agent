# 요청: 표준 모듈 API를 의존 패키지와 `cyber doc`에서 (cyber latest, 23ac9045)

상태: 열림 (2026-11-17). 결함이 아니라 문서와 패키지에 관한 요청이다. tars-agent 본체의 첫 단계를 막지 않는다.

0.4.12 요청서의 (c) 회신에 "모듈 API를 `cyber doc`에 넣는 일은 하지 않았다. 결정 대기다"라는 줄이 있었다. 이 요청은 그 줄을 이어 받는다.

## 배경

tars-agent는 스크립트에 표준 모듈 json, toon, regex, peg, time을 연다(tars-agent ADR 0024, 0025). 모델이 이 모듈을 쓰려면 함수 이름과 시그니처를 알아야 한다. 지금 모델이 받는 것은 agent-guide.md의 `## Modules` 절뿐이고, 모듈마다 한 줄 소개다.

가이드는 API를 이렇게 안내한다.

~~~
The API of every module is on the docs site (`api.html`) and in `api.json` of each release.
~~~

임베딩된 세션의 모델은 두 곳 모두에 닿지 못한다. 네트워크가 없거나 막혀 있고, 있더라도 릴리스 자산을 받는 것은 모델의 일이 아니다.

## 지금 있는 것 (latest, 23ac9045)

| 출처 | 패키지에 있나 | 내용 |
|---|---|---|
| `docs/agent-guide.md` (`cyber doc --for-agents`) | 있다 | 모듈마다 한 줄 |
| `docs/docs.md` (`cyber doc <topic>`) | 있다 | `builtin-modules` 아래 네 절. json-and-toon 6.0 KB, regular-expressions 5.1 KB, parsing-expression-grammars 6.8 KB, dates-and-times 11.6 KB. 설명과 예제이고 전체 함수 목록은 아니다 |
| `api.json` (`docs/gen-api-json.cy`) | 없다 | CI(latest-build.yml, gen-docs.yml)가 만들어 릴리스 자산으로 올린다. 함수 265개, 타입 237개, 시그니처와 한 줄 doc |
| `api.html` | 없다 | 문서 사이트와 릴리스 자산 |

`api.json`에서 다섯 모듈만 골라 시그니처를 한 줄씩 적으면 228줄, 약 6.8 KB다. 함수 67개, 타입 24개, 메서드 137개다. core와 math를 더하면 약 12.4 KB가 늘어난다. 시스템 프롬프트에 늘 싣기에는 크고, 필요할 때 한 모듈씩 꺼내기에는 알맞다.

## 요청

1. 의존 패키지에 모듈 API를 넣는다.
   - tars-agent는 agent-guide.md처럼 빌드 시점에 의존 패키지에서 파일을 읽는다(ADR 0022). 이렇게 하면 릴리스 자산을 따로 받지 않고, 받은 빌드와 API가 늘 같다.
   - 형식은 지금의 `api.json` 그대로면 충분하다. 모듈별로 걸러 쓸 수 있도록 `module` 필드가 있어야 한다.
   - 소스에서 만드는 방법은 cyber가 정한다. 예를 들면 생성 결과를 커밋하고 `.paths`에 넣거나, `zig build` 단계에서 만들거나.
2. `cyber doc`에서 모듈 API를 볼 수 있게 한다.
   - 예: `cyber doc --api json`이 json 모듈의 함수와 타입 메서드를 시그니처와 한 줄 doc으로 찍는다.
   - CLI를 쓰는 에이전트도 오프라인에서 이름을 찾을 수 있다. 1과 같은 소스에서 나와야 한다.
3. 가이드의 안내 줄이 1과 2를 가리키게 한다.
   - 예: "`cyber doc --api <module>` prints the API of a module. An embedding host may give it to you in another way."
   - 문구는 cyber가 정한다. 임베딩 호스트 요청(cyber-agent-guide-embedding-host.md)에서 들어간 머리말 줄과 이어진다.

## 바라지 않는 것

- 가이드에 모듈 API 전체를 싣는 것. 가이드는 시스템 프롬프트에 늘 실리므로 짧게 둔다.
- tars-agent 전용 형식. 출력 모양은 `api.json`이나 `api.html`과 같은 소스, 같은 결이면 된다.

## tars-agent 쪽에서 쓰는 방법 (참고)

허용 목록의 모듈(json, toon, regex, peg, time, 그리고 필요하면 core와 math)만 걸러서 모델에게 준다. 시스템 프롬프트에 둘지, `help(name)` 능력으로 필요할 때 꺼내게 할지는 본체의 능력 설계 단계에서 정한다. 어느 쪽이든 원천은 받은 cyber 패키지 하나다.

## 확인 방법

- `zig fetch`로 받은 패키지에 API 파일이 있고, 다섯 모듈의 항목이 `api.json` 릴리스 자산과 같다.
- `cyber doc --api <module>`(또는 cyber가 정한 모양)이 같은 내용을 찍는다.
- tars-agent 스파이크에서 이 파일을 읽어 모듈별로 거르는 시험을 한다.
