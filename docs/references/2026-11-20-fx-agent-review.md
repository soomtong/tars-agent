# fx 검토: 참고할 것, 배울 것, 차용할 것 (2026-11-20)

대상: vercel-labs/fx `5960bc93d` (로컬 사본 `~/Repository/_study/fx-agent`). Zig 0.17.1, Apache-2.0. 아래 경로는 그 저장소 기준이다.

이 문서는 검토 결과다. 결정이 아니다. 차용 후보는 사용자가 고른 뒤 ADR과 명세로 간다 (pi 검토가 ADR 0021로 간 것과 같은 길).

## 0. fx는 무엇인가

- "minimal"이라 부르지만 Zig 약 87만 줄이다(src/core 59만, src/ui 15만, gateway 3만, tools 2만, acp 2만, mcp 2만). 작은 것은 실행 파일(Apple silicon 상한 6.75~8.75 MiB)과 시작 시간(명령마다 2 ms)이다.
- 같은 코어를 CLI(TUI), `fx ask --json`, ACP 서버(`fx acp`), libfx(Node 네이티브 애드온과 WASM)가 쓴다.
- 도구는 JSON 도구 호출이다. CodeAct가 아니다. 그래서 루프, 세션, 권한, 프로토콜은 비교 대상이고 도구 표면은 우리와 다르다.
- 권한의 auto 모드는 샌드박스가 아니라 모델 검토자에 기댄다. 우리는 샌드박스(Landlock)와 능력 표에 기댄다.
- 규칙 문서(RULES.md)에 번호 붙은 규칙 약 50개가 있고, 많은 규칙이 CI 스크립트나 TLA+ 모델로 강제된다.

우리와 닮은 점: Zig 0.17.1, 한 실행 파일, 헤드리스 우선, ACP를 프런트엔드 자리에 둠, MCP 도구를 프롬프트 밖에 둠(캐시 안정), 덧붙이기만 하는 JSONL 세션.

## 1. 참고할 것 (그 부분을 설계할 때 열어 볼 곳)

| 우리 단계 | fx에서 볼 곳 | 무엇을 보나 |
|---|---|---|
| 코어-프런트엔드 이벤트 타입 (M3, 사용자 편집) | `src/core/shared/types.zig:242` `ToolLifecycleEvent`, `src/acp/prompt.zig:480,550,3706`, `src/acp/types.zig:63,191` | 도구 카드의 수명(provisional, authoritative_started, progress, terminal, turn_finished), 결과 enum, ACP 매핑, 턴 끝에 열린 카드 닫기 |
| 세션 파일 (M1, 07) | `src/core/session_manager/schema.zig`, `log.zig:164-214`, `session.zig:543,1105,1401` | 줄 머리, CRC, 찢긴 꼬리 자르기, fsync 지점, 잠금, 스냅숏 |
| 재시도와 복구 (M1 provider) | `src/core/recovery/recovery.zig`, `tests/tla/recovery/Recovery.tla:433-477`, `src/core/agent/runtime/resend_strategy.zig` | 순수 모듈 `step(state, event, now_ms) Plan` |
| 컴팩션 (M4) | `src/core/compactor/window.zig:23-27`, `ledger.zig`, `checkpoint.zig:80,631`, `lint.zig` | 원문 유지 범위, 기록 형식, 접힌 턴을 ID로 다시 열기 |
| 실행 중 입력 (M3) | `src/core/agent/worker_runtime.zig:86,118,1706-1724`, `execution_memory.zig:33-39` | steering 경계 셋(model, cancelled, finalizing)과 handoff |
| 서브에이전트 (06) | `src/core/subagent/authority.zig:29,619,771` | 자식의 권한이 부모를 넘지 않게 하는 검사 |
| auto 모드를 다시 볼 때 (05) | `src/core/permissions/auto_classifier.zig:30-37,279,717-830,1844-1887` | 모델 검토자: 입력 묶음, 출력 스키마, 인용 검증 |
| git 능력이 생길 때 | `src/core/shell_command/safe_git.zig:181-237` | 저장소 설정이 프로그램을 띄우지 못하게 하는 git 앞머리 |
| 시스템 프롬프트 | `src/builtins/system_prompt.md` | 실행 중 바뀐 맥락을 메시지 끝에 `<fx-context-update>`로 덧붙여 캐시 앞부분을 지킴 |
| 프런트엔드별 차이 | `src/core/agent/context_contract.zig:596-630` | 진입점(대화형, ask, acp)마다 다른 맥락, 도구, 권한을 데이터 표로 적음 |

## 2. 배울 것 (방법과 관행)

1. 판단은 순수 모듈로. recovery는 I/O, 시계, 할당이 없고 std만 import한다. 사건을 받아 계획(`Plan{save, send, status, finish}`)을 돌려주고, 상태는 32바이트 기록으로 세션에 저장된다. 그래서 백오프 대기 중에 죽어도 그 대기부터 이어 간다. 시계는 호출자가 넘기므로 재생이 결정적이다.
2. 상태 기계는 TLA+로, 버그를 심어서 확인한다. 모델 약 33개. 각 `.cfg`가 버그 하나를 심고 검사기가 잡아야 한다. 드라이버(`tests/tla/drivers/agent_runtime/driver.ts`)는 빌드한 실행 파일을 가짜 게이트웨이에 붙여 관찰열을 만들고, 그것을 명세의 동작으로 재생한다. 우리 07의 리플레이(모의 provider와 JSONL)가 같은 관찰원이 된다.
3. 바깥 바이트를 읽는 디코더마다 fuzz 대상 하나. `tests/fuzz/targets.json`에 96개(SSE, JSON-RPC, MCP, 세션 로그, CLI 인자, 명령 lexer). `zig build test`가 씨앗과 말뭉치를 재생한다. `--fuzz`가 찾은 실패도 종료 코드 0이라 출력을 읽어야 한다.
4. 모듈 경계는 스크립트로 강제. `scripts/check-*-boundary.sh`가 `git grep`으로 `@import`를 보고, 바깥에서는 정문 파일만, 안에서는 허용 목록만 import하게 한다. 한 단계 건너 import도 본다.
5. 멈춤을 세지 스텝을 세지 않는다. 기본 스텝 상한은 없음(0)이고, 형식이 깨진 도구 호출은 두 번 고치라고 알린 뒤 세 번째에 끝낸다. 빈 응답은 한 번 재촉한다. 우리의 "같은 오류 3회 경고, 5회 중단"과 같은 계열이다.
6. 실패 문구가 다음 시도를 이끈다. 편집이 맞지 않으면 들여쓰기를 무시하고 가장 가까운 창을 보여 주고, 여럿 맞으면 개수와 줄 번호, 조각 셋을 보여 준다(`src/tools/file_mutation.zig:1529-1610,1720`). cyber 요청서에서 우리가 요구해 온 "고치는 법을 말하는 문구"와 같은 생각이다.
7. 모델 평가는 헤드리스 JSON 위에. `tests/evals/eval-helpers.ts:174-296`이 임시 작업 폴더와 격리된 HOME에서 `fx ask --auto --json --no-save`를 돌리고 파일 상태와 쓴 도구로 채점한다. `run-matrix.ts`가 모델마다 다시 돌린다.
8. 크기와 시작 시간을 처음부터 잰다. 명령마다 2 ms, 실행 파일 상한, 51 KiB 넘게 커지면 경고. 우리는 libcyber를 정적 링크하므로 처음부터 재는 편이 싸다.
9. Zig 0.17.1의 지뢰(`.fx/skills/zig/references/toolchain.md:59-82,203-225`).
   - `http.Client.Request.deinit`이 남은 본문을 끝까지 읽는다. 서버가 여는 채로 두는 스트림(SSE)이면 멈춘다. `connection.closing = true`로 피한다. 우리 provider 스트리밍의 Esc 취소에 바로 걸린다.
   - Linux libc의 `tcgetattr`가 44바이트 termios에 60바이트를 써서 스택을 넘친다. `std.os.linux.tcgetattr`를 쓴다. tars-linux의 줄 편집기에 걸린다.
   - macOS에서 작업이 도는 중에 `Select`를 취소하면 다음 `connect`가 `EISCONN`으로 panic할 수 있다.
   - `@hasDecl`은 pub만 본다. 비공개를 찾는 탐침은 조용히 기능을 끈다. `containsAtLeastScalar`의 뒤 두 인자가 바뀌었고 옛 호출도 컴파일된다.
   - `FailingAllocator` 훑기는 resize가 성공하면 흔들린다. resize를 거부하는 감싸개(`src/core/shared/testing_allocator.zig`, 20줄)로 고정한다.

## 3. 차용 후보

표시: 작음(명세 몇 줄), 중간(명세 절 하나 또는 모듈 하나), 큼. "결정"은 구조에 관한 것이라 사용자가 정한다.

### 3.1 명세 보강

| # | 후보 | fx | 우리 지금 | 갈 곳 | 크기 |
|---|---|---|---|---|---|
| A1 | 큰 결과는 미리보기와 손잡이로 | 16 KiB를 넘으면 전문은 내용 주소 blob, 모델에는 4 KiB 미리보기와 `handle`. `read_tool_result`가 바이트 범위(기본 8 KiB, 최대 64 KiB)나 문자열로 다시 읽는다 | 스크립트 결과 20,000자, 넘침 파일 | 02, 07, ADR 0021의 6 | 작음 |
| A2 | 세션 줄 머리 | `{"v":1,"seq":N,"ts":…,"kind":…,…,"crc":"…"}`. 줄 4 MiB 상한. 더 새 `v`는 읽기 전용으로 연다 | 07의 JSONL, 버전과 CRC 없음 | 07, ADR 0008 | 작음 |
| A3 | 세션 쓰기의 내구성 | 쓰기로 열 때 찢긴 꼬리를 자름(뒤에 줄이 없으면 찢김, 있으면 손상). fsync는 턴 확정과 인터럽트에서만. 새 세션은 임시 폴더에서 만들어 rename | 정하지 않음 | 07, ADR 0008 | 작음 |
| A4 | 세션 하나에 쓰는 이 하나 | `{id}/lock`에 비차단 flock, 2초 재시도 뒤 Busy | 정하지 않음 | 07, ADR 0004 | 작음 |
| A5 | 크래시 뒤 이어 가기와 반복 크래시 | 결과 없는 호출에 "멈췄을 때 돌고 있었으니 효과를 확인하고 다시 돌려라"를 채움(우리 ADR 0021의 1과 같음). 다른 점은 둘: 스스로 이어 감(`<session_resumed>`), 보내는 중에 두 번 죽으면 사용자에게 한 번 묻는다 | 크래시 결과를 채우고 사용자에게 보여 줌 | 02, ADR 0021 | 작음, 결정 |
| A6 | 컴팩션의 원문 유지 | 접힌 구간에서도 user 메시지와 최종 답은 글자 그대로. 최근 턴 최대 4개를 원문으로. 사이의 일만 모델이 적는다 | 2,000자 자유 요약 틀. 최근 구간 원문은 열어 둠(TODO M4) | 06, ADR 0021 열린 것 | 중간, 결정 |
| A7 | 접힌 기록을 다시 열기 | 턴(M12), 도구 호출(T12)을 파일로 두고 ID나 검색(BM25)으로 연다 | 없음 | `history.search`, `history.open` 능력. 세션 JSONL 위에서 | 중간, 결정 |
| A8 | steering 경계 | 경계 셋: 모델 요청 앞, 취소, 턴을 끝내려는 순간. 턴을 끝내려는 순간에 들어온 입력은 턴을 잇는다. Esc를 쳤는데 대기 입력이 있으면 그 입력으로 턴을 잇는다. 턴에 들어갈 수 없는 입력은 handoff | 스텝마다 하나씩, 턴 끝에 남으면 다음 턴, 인터럽트 때 입력 줄로 돌려줌 | 02 실행 중 입력 | 작음, 결정 |
| A9 | 이벤트 타입의 도구 수명 | 임시(인자 스트리밍 중)와 확정의 구분, 결과 enum(completed, denied, cancelled, failed, deferred), 턴 끝에 열린 카드 모두 닫기, 승인 요청의 `origin`(본 세션, 서브에이전트), ACP와 맞춘 멈춤 이유 | ADR 0029의 "이벤트 타입을 정할 때 볼 것" | 이벤트 타입(사용자 편집) | 결정 |
| A10 | 능력 표의 두 열 | 모든 도구가 `reads_only`, `irreversible` 술어를 갖고, 권한 문이 컴파일 때 모양을 검사한다. 결정자가 없으면 "읽기 전용이고 되돌릴 수 있는 것만 통과" | 능력 표의 열은 미정 | caps/table.zig(사용자 편집), 05 | 결정 |
| A11 | 복구를 순수 모듈로 | 위 2절의 1. 백오프 1, 2, 4, 8, 16, 30초(80~100% 흔들기), Retry-After는 30초 상한, 같은 종류 3회면 다른 길, 문맥 초과는 한 번 압축 뒤 묻기 | 5회 백오프 재시도, 끊긴 스트림 다시 보내기, 초과 때 한 번 압축 | 02 또는 provider 절, 모듈 경계 | 중간, 결정 |
| A12 | 헤드리스 JSON 결과 | `{output, final_output, exit_code, model, session_id, steps, tool_calls[…], usage, error?, recovery?}`. 필드는 더하기만 한다. 승인이 필요하면 기다리지 않고 실패 | -p, stream-json, 종료 코드 3 | 01/07, eval/ | 작음 |
| A13 | 안전한 git | git을 PATH가 아닌 고정 경로에서, `core.fsmonitor`, `core.hooksPath`, filter, ext-diff, textconv를 끄고, `PATH=/usr/bin:/bin`, `GIT_TERMINAL_PROMPT=0` | git 전용 능력 없음(proc.exec) | 04, git 읽기 능력을 둘 때 | 작음 |

A8은 ADR 0021의 7(하나씩)과 다르다. fx는 경계에서 쌓인 입력을 모두 넣는다. 하나씩 넣는 근거(입력마다 응답할 기회)는 그대로이므로, 받을 것은 경계 둘(턴을 끝내려는 순간, 취소에 대기 입력)과 handoff다.

### 3.2 코드와 도구 (재구현)

| # | 후보 | 크기 | 언제 |
|---|---|---|---|
| B1 | Zig 0.17.1 지뢰를 기록으로(2절의 9) | 작음 | 지금. M1 provider 전에 |
| B2 | resize를 거부하는 테스트 allocator | 20줄 | M1 테스트 |
| B3 | `terminalSafe`: 제어 문자, DEL, 잘못된 UTF-8을 보이는 이스케이프로 바꾸는 할당 없는 formatter. 나뉜 UTF-8 조각을 이어 받는 증분판 | 약 150줄 | 도구 출력과 파일 이름을 터미널에 그리기 전(M1 헤드리스 text부터) |
| B4 | 모듈 경계 검사 스크립트: `runtime/cy.zig` 밖으로 libcyber가 새지 않게, `caps/`는 정문만 | 작음 | 저장소 뼈대(M1) |
| B5 | 디코더마다 fuzz와 목록 파일 | 중간 | SSE, provider JSON, 세션 JSONL을 만들 때 |
| B6 | 시작 시간과 실행 파일 크기 예산 | 작음 | CI를 세울 때 |
| B7 | 루프 상태 기계의 TLA+ 모델과 리플레이 관찰 | 큼 | M1 루프가 선 뒤. 루프 하나부터 |

## 4. 가져오지 않을 것

- 코어와 프런트엔드 사이를 콜백 구조체(`AgentRuntimeDeps`, `src/core/agent/runtime/deps.zig:198-319`)로 잇는 것: 묻는 것과 밀어 주는 것이 섞이고, TUI 쪽 변이 30개짜리 `WorkerEvent`를 ACP는 대부분 버린다. 우리는 01대로 이벤트 하나의 tagged union과 명령 타입을 따로 둔다. 그래야 stream-json, REPL, ACP 어댑터가 같은 것을 직렬화한다.
- auto 모드의 근거를 모델 검토자로: 우리 auto는 샌드박스와 능력 표에 기댄다(ADR 0007). 다만 검토자를 둔다면 볼 설계(범주 둘, 정확한 인용 필수, 인용의 출처 검사, 증명 못 한 경고는 통과로, 경고는 새 검토 한 번이 clear여야 풀림, 실패는 닫힘)는 1절 표에 남긴다. CodeAct에서는 스크립트 전체를 한 번 보고, 승인이 필요한 능력 호출에서 CL_AWAIT로 멈춰 그 호출의 실제 인자와 지금까지의 반환을 보는 모양이 된다(ADR 0011).
- 셸 명령 분류기와 셸 동등성 시험: ADR 0007에서 버렸다. fx는 좁게 만들고 sh, dash, bash, zsh에서 같게 도는지 시험으로 받쳤다. 되살린다면 이것이 기준이다.
- 로그인 셸 환경을 한 번 떠서 재생: tars-linux 안에서는 터미널이 따로 있다. v1 밖.
- 전송 오류의 무한 재시도(Esc만 끝냄): 헤드리스와 평가에서는 끝이 있어야 한다. 상한은 둔다.
- 전역 `io_mod.getIo()`: 호출 수천 곳의 편의다. 작은 코어는 `io`를 인자로 넘긴다. 테스트에서 `std.testing.io`로 바꾸는 생각만 받는다.
- 코드 크기 줄이기용 공유 JSON 파서와 정렬(`json_decode.zig`, `sort_utils.zig`): 크기가 문제가 될 때 다시 본다.
- 구독 로그인(ChatGPT, Grok OAuth)과 AI Gateway 전용 경로: 우리는 형식 둘의 어댑터와 데이터로서의 제공자(ADR 0015)로 간다. "제공자 차이는 게이트웨이 어댑터에 두고 제공자 검사를 늘리지 않는다"(RULES R1.3)는 ADR 0015와 같은 결론이다.

## 5. 라이선스

fx는 Apache-2.0, 우리는 BSD 3-Clause(ADR 0003). 생각, 모양, 시험 방법은 자유롭게 쓴다. 파일을 베끼면 그 파일은 Apache 조건(저작권 머리, 바꿨다는 표시, 라이선스 본문, 특허 조항)을 지고 들어온다. ADR 0003은 제삼자 코드를 들이는 경우를 다루지 않는다. 3절의 후보는 모두 재구현으로 잡았다.

## 6. 추천 순서

1. 지금: B1(지뢰 기록), A2~A4(세션 파일 형식과 내구성, 잠금), A12(헤드리스 JSON). 명세 몇 줄이고 M1 session과 headless에 바로 쓰인다.
2. 이벤트 타입과 능력 표를 편집할 때: A9, A10을 사용자 결정 거리로 올린다.
3. M1 provider: A11(복구 모듈)과 B1의 SSE `deinit` 회피, B3, B4.
4. M3: A8. M4: A6, A7.
5. M1 루프가 선 뒤: B5~B7.
