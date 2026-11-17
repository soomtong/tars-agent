# 요청: agent-guide.md에 임베딩 호스트에 관한 줄 (cyber latest, 23ac9045)

상태: 열림 (2026-11-17). 결함이 아니라 문서 요청이다. tars-agent의 본체 일정과 묶이지 않는다.

## 배경

tars-agent는 모델에게 주는 Cyber 안내의 정본을 cyber의 `docs/agent-guide.md`로 정했다(tars-agent ADR 0022). 시스템 프롬프트는 가이드를 그대로 싣고, 그 뒤에 호스트 덧붙임을 붙인다. 덧붙임에는 이 호스트에서만 참인 것(능력 모듈, 막힌 모듈, 세션 규칙, 코드를 돌리는 법)을 적는다.

가이드는 지금 독자가 `cyber` 실행 파일을 쓴다고 본다. 그래서 임베딩 호스트에서는 가이드와 덧붙임이 서로 다른 말을 하는 곳이 생긴다. 모델은 어느 쪽을 따를지 스스로 정해야 한다.

## 가이드와 임베딩 호스트가 다른 곳 (latest 패키지의 agent-guide.md)

| 가이드의 자리 | 가이드의 말 | tars-agent 세션에서 |
|---|---|---|
| `## Running and checking code` | `cyber main.cy`, `cyber fmt`, `cyber doc <id>`로 돌리고 확인한다 | `cyber` 명령이 없다. 코드는 호스트의 run 도구로 돌린다 |
| 같은 절, 예제 11 | 테스트는 `use test` | 호스트 로더가 `test`를 싣지 않는다. `CompileError: Failed to load module: test` |
| `## Modules` | `core`는 늘 실리고 나머지는 `use name`으로 가져온다. `os`, `cli`, `io`, `cy`, `libc` 목록 | 호스트가 정한 모듈만 실린다. `os`, `libc`, `cli`는 라이브러리의 기본 로더에 없다. 바깥(파일, 프로세스)에는 호스트의 모듈(`fs`, `proc`)로 닿는다 |
| `## Errors and Option` | `os.write_file(p, s)!`를 예로 든다 | 같은 규칙이 호스트 모듈의 `!T`에도 맞는다. 예의 모듈만 이 세션에 없다 |

가이드에는 이미 임베딩 호스트를 말하는 줄이 하나 있다(`## Values, references, borrows`의 "In the REPL and in hosts that keep top-level variables between runs ..."). 같은 결로 한두 줄을 더해 달라는 요청이다.

## 요청

1. 머리말에 한 줄. 위치는 "If the guide and the compiler disagree, the compiler is right." 다음을 제안한다.

~~~
When Cyber runs inside another program (an embedding host), the host can load fewer modules, add its own modules, and run code without the `cyber` command. If the host's instructions differ from this guide about running code or about modules, follow the host.
~~~

2. `## Modules`에 한 줄. 막힌 모듈의 오류 문구를 모델이 알아보게 한다.

~~~
An embedding host can refuse a module. Then `use name` fails with `Failed to load module: name`. Do not retry it; use what the host provides.
~~~

문구와 위치는 cyber가 정한다. 바라는 것은 두 가지다.
- 호스트의 지시가 실행 방법과 모듈에 대해 가이드보다 앞선다는 것.
- 거부된 모듈의 오류 문구가 무엇이고 그때 어떻게 하는지.

## 바라지 않는 것

- tars-agent나 특정 호스트의 이름, 능력 모듈(`fs`, `proc`)을 가이드에 적는 것. 그것은 호스트 덧붙임의 일이다.
- CLI를 기준으로 쓴 기존 절(`## Running and checking code`, 예제 11, `os` 예)을 바꾸는 것. CLI 사용자에게는 그대로가 맞다.

## 확인 방법

tars-agent 쪽에서 새 빌드를 받으면 시스템 프롬프트(가이드 + 덧붙임)를 다시 만들고, 덧붙임에서 "가이드의 이 절은 이 세션에 맞지 않는다"는 줄을 뺄 수 있는지 본다. 안내 코드 블록 34개(가이드 12개 포함)를 세션에서 다시 돌린다.
