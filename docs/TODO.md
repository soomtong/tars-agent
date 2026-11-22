# TODO

표기: [ ] 미착수, [~] 진행 중, [x] 완료.

단계(M)마다 끝에 게이트가 있다. 게이트는 눈으로 확인할 수 있는 동작 하나다. 게이트를 통과한 뒤 다음 단계로 간다. 단계를 시작할 때 짧은 계획을 쓰고, 끝나면 배운 것을 docs/decisions에 남긴다.

## 끝난 것

- [x] tars-linux, cyber fork 현황 확인
- [x] 라이선스 BSD 3-Clause (ADR 0003)
- [x] 실행 모델 CodeAct + Cyber (ADR 0001), 호스트는 Zig + libcyber (ADR 0002)
- [x] 초기 요구사항 대조 (09 문서)
- [x] 명세 재검토와 열린 질문 결정 (ADR 0004~0009, 2026-11-10)
- [x] cyber 기준 빌드 반영: 0.4.17. 스파이크 의존은 가장 새 빌드를 따르고(ADR 0023), s1, 안내의 코드 블록과 오류 문구를 설치된 CLI와 세션에서 확인했다. CodeAct 비교의 최신 회차는 0.4.16이다(검토 문서 5.4). 스파이크의 호스트 로더는 허용 목록이다(ADR 0026) (2026-11-22)

## M0 증명

코드를 쓰기 전에 세 가지를 증명한다. 산출물은 버려도 되는 스파이크와 검토 결과다. CodeAct 판정은 본체의 헤드리스와 direct 모드가 선 뒤 E 단계에서 한다 (13, ADR 0031).

스파이크는 Claude가 혼자 검토, 구현하고 결정도 위임받았다 (ADR 0012의 덧붙임, 2026-11-13). 코드는 spike/에, 상세한 검토 결과는 docs/spikes/에 둔다. 사용자는 검토 결과로 아키텍처의 감을 잡고, 본체 구현은 페어로 한다.

- [x] 스파이크 1, 호스트 경계: build.zig.zon으로 cyber를 받아 Zig에서 링크. 능력 2개(fs.read, proc.exec), 호스트 로더(허용 목록), deny_raw_ptrs, 연료(fuel), 벽시계(wall-clock) interrupt, 스택과 메모리 상한, persist_main 반복 eval, validate, 능력 안에서 블록 후 반환
- [x] 스파이크 1의 확인 목록 (08 문서 "M0에서 확인한 것"). 검사 48개 모두 통과
- [x] 스파이크 1에서 동시 승인 확인 (ADR 0016): scope 블록으로 요청 둘을 걸고 번호 순으로 하나씩 완료, 중첩 블록, 하나를 거부하면 나머지가 버려지고 요청 표가 비는지
- [x] 스파이크 2, 제공자: 전송 형식 둘(Anthropic Messages, OpenAI Chat Completions)을 DeepSeek으로 확인 (ADR 0014). Zig std.http로 스트리밍 요청, SSE 해석, run 도구 한 번 왕복. TLS와 CA 묶음은 macOS에서 된다
- [x] 스파이크 검토 결과: docs/spikes/2026-11-14-m0-spikes-review.md, 발견과 추천은 ADR 0017. 스파이크 코드(spike/)는 사용자가 검토한 뒤 지운다
- [~] 스파이크 3, 교차 빌드: x86_64-linux-gnu 교차 빌드는 확인. tars 게스트(QEMU)에서의 실행은 기준 빌드로 확인할 것 (tars-linux 산출물 필요)
- [x] cyber 0.4.15로 옮기기 (2026-11-18): 두 스파이크의 의존을 태그 `0.4.15`(`93a9ca4f`)로 올렸다. s1 47개 통과(새 검사 7i: `cl_vm_symbol_hints`, 7a4: `use test`, 6n: 오류 복구), s2 빌드, x86_64 교차 빌드. 안내 두 판과 agent-guide.md의 코드 블록 34개가 CLI와 세션에서 모두 통과한다(`test`를 연 뒤, ADR 0028). 제자리 `Slice`의 문구(`xs = xs.append(3)`, `ys := xs.append(3)`, 전역 `g.append(g.len())`)를 CLI와 세션에서, `os` 옛 꼴의 문구를 CLI에서 탐침으로 확인했다(세션은 `os`를 싣지 않는다). 세션의 마지막 줄 `xs.append(4)`는 결과 없는 문장, `xs.appended(3)`은 eval 결과다. `cyber-lsp`를 stdio로 붙여 unused 경고, quick fix, inlay hint, `scope` 출구 알림, 문서 주석 hover를 확인했다. 검토 문서 3.5, 7, 8절, 9절 18
- [x] CodeAct 비교를 0.4.15로 다시 돌림 (2026-11-18): 0.4.12와 같은 표(회차 14개, 과제 42개). 41개 통과, 실패 하나는 과제 해석, 죽은 실행 없음, 컴파일 오류 51건에서 41건. 원자료 spike/s2/out/0.4.15/, 검토 문서 5.3
- [x] cyber 0.4.16으로 옮기기 (2026-11-21): 두 스파이크의 의존을 태그 `0.4.16`(`ca000225`)으로 올렸다. s1 48개 통과. 7f와 `s1 spawn`을 새 꼴 `spawn f(a)`로 고쳤다(옛 꼴은 ParseError라 deny_spawn을 보지 않게 된다). 새 검사 6o: `CLReport`의 고칠 편집을 적용하면 검증 통과, 오류 복구에서 한 본문의 오류 둘, `CL_HINT_PARAM_NAME`, 실패한 검증 뒤의 타입 힌트. s2 빌드, x86_64 교차 빌드(s1, s2). 안내 두 판과 agent-guide.md의 코드 블록 34개가 CLI와 세션에서 통과한다. 기본 로더의 모듈은 그대로 열셋, 공개 `cl_` 함수 142개, libcyber.a arm64 3,130,152바이트, x86_64 3,700,220바이트. CodeAct 비교는 다시 돌리지 않았다
- [x] CodeAct 비교를 0.4.16으로 다시 돌림 (2026-11-21): 같은 표(회차 14개, 과제 42개). 39개 통과(CodeAct 36개 중 35개). 실패 셋은 direct의 과제 해석과 셸 출력 형식, CodeAct의 스텝 상한(모델의 판정 실수)이다. 죽은 실행 없음, 컴파일 오류 41건에서 45건. 'Expected exclusive access'는 나오지 않았다. 문구 넷으로 요청서를 냈다(docs/requests/cyber-0.4.16-messages-from-codeact-round.md). 원자료 spike/s2/out/0.4.16/, 검토 문서 5.4
- [x] cyber 요청: 0.4.15 회차에서 고치는 법을 말하지 않은 문구 셋(`!T`가 아닌 함수의 `!`, `.!`, `^[]T`의 제자리 메서드). 0.4.16에서 셋 모두 고치는 법을 말한다. CLI와 세션에서 확인하고 요청서를 지웠다 (2026-11-21)
- [x] 0.4.16에서 안내 고치기 (2026-11-21): 두 판의 기준 버전 줄, 51행에 값을 바꾸는 메서드 `fn (&&P) m():`와 공유 빌림 두 문구('Cannot replace a managed value through a shared borrow.', 'Cannot borrow exclusively through a shared borrow.', 둘 다 `&&T`를 말하므로 오류 표가 아니라 정본 agent-guide.md 52행처럼 본문에), 105행은 `log.append(log.len())`가 된다로 줄였다(남은 오류 `g.append(g.span())`는 문구가 지역에 먼저 담으라고 말한다). `json.parse(s, &&diag)`, `spawn f(a)`, `os` 오류 이름은 안내에 없다
- [x] 다음 cyber 빌드로 올릴 때 안내 고치기 (0.4.17에서 함, 2026-11-22. 168행은 함수 안의 이동과 세션 최상위의 `move a`로 나눠 썼고, `int(z)`와 `int('Z')`가 다른 줄을 더했고, 오류 표의 'Expected assignment ...' 줄을 뺐고 'Cannot copy ...' 줄을 원소 읽기로 고쳤다. 요청서 넷은 CLI와 세션에서 확인하고 지웠다): prompt/cyber-subset.md · .en.md 168행(`Array[T]`는 `move a`로 넘긴다 → 변수에서 넘기거나 대입하면 `move` 없이 이동, 이동 뒤 사용은 'was moved at ...' 오류)과 347행('Cannot copy ...'는 원소 읽기 `x := a[0]`에서만, `&a[0]`로 빌린다). 오류 표의 'Expected assignment to a variable or placeholder ...' 줄은 문구가 `_ = xs.pop()`을 말하게 되어 뺄 수 있다. cyber 정본 agent-guide.md는 같이 고쳐졌다. 요청서 cyber-0.4.16-messages-from-codeact-round.md의 넷은 그 빌드에서 CLI와 세션으로 확인하고 닫는다 (cyber 회신 2026-11-21). 세션(`persist_main`)은 다르다(cyber 코드 리뷰 수정 2026-11-21): 최상위 변수는 `move` 없이 이동하지 않고 'Cannot copy `Array[str]`, a `NoCopy` type. The top level variable `a` of the REPL does not move without `move`: later inputs read it. ...' 오류다. `move a`를 적으면 다음 입력에서 `a`는 'Undeclared variable'이고, 최상위 변수의 멤버는 옮기지 못한다. 함수 본문의 지역은 CLI와 같이 이동한다. 168행을 고칠 때 세션의 최상위 변수는 `move a`나 `&a`를 적는다고 같이 적는다. 새 문구 둘도 그 빌드에서 확인한다: `if` 문 조건식의 이동은 되고 `and` · `or` · `if` 식 · `?else` 안은 'Cannot move `a` inside an `and` expression: ...', 값을 반환하는 `op=` 메서드는 'The `+=` method of `Acc` returns `int`, ...' 이동한 변수에 다시 대입도 된다(cyber 2026-11-21): `acc = step(acc)`는 반복 본문에서도 되고 `xs = xs.appended(v)`는 버퍼를 재사용한다. 세션의 최상위 변수는 옮긴 뒤 대입하지 못하고 'Cannot assign to the top level variable `g` of the REPL after it was moved. Declare it again with `g := ...`.' 오류다. `x := f() ?else: ...`는 `NoCopy` 값(`Array[T]`)도 푼다. 갈래 · 반복 본문의 이동도 늘었다(cyber 2026-11-21): `if opt |v|:` 갈래 · `switch` 문 case · `begin:` 블록이 바깥 변수를 옮기고, 반복 본문은 옮긴 뒤 `break` · `return`으로 떠나거나 다시 대입하면 된다. 다음 반복으로 넘어가면 'Cannot move `a` here: it is declared outside the loop, and the next iteration reads it. ...' 오류다(전의 'declared in an outer block' 문구를 대신한다). `if o |v|:` · `while it.next() |v|:`는 `NoCopy` payload를 꺼내고, 변수에서 읽은 옵션은 이동한다. 남은 자리도 열렸다(cyber 2026-11-22): `if` 식 · `switch` 식의 갈래와 `try` 문의 본문 · `else` 블록이 바깥 변수를 옮긴다(본문이 실패할 수 있는 `!` 전에 옮긴 변수는 `else` 블록에서 '`a` was moved at ...'), 반복문의 `break`들이 서로 다른 변수를 옮긴 뒤여도 되고('Cannot leave the loop here: ...' 오류는 없어짐), 변수에 담긴 `NoCopy` 옵션도 `o ?else default`로 푼다(`o`는 이동). 위 문구의 'inside an `if` expression'은 이제 나오지 않는다(`and` · `or`와 `?else` · `!else`의 기본값만). `self.xs = self.xs.appended(v)`도 버퍼를 재사용한다. 마지막 두 자리도 열렸다(cyber 2026-11-22): `and` · `or`의 왼쪽 피연산자(`ok := take(a) and ready`)와 `scope` 블록의 본문이 바깥 변수를 옮긴다. 'Cannot move `a` inside an `and` expression: ...'은 오른쪽 피연산자와 `?else` · `!else`의 기본값 · 블록에서만 나온다. `scope |s|:`의 `s`는 옮기지 못한다('Cannot move `s`: it is the scope of a `scope` block, ...'). 이 항목의 "다음 cyber 빌드"는 0.4.17이다(cyber 릴리스 2026-11-22, `build-1031-02c3c42`, 릴리스 노트 `docs/releases/0.4.17.md`). 컴파일러 소스의 `sema.zig` 분할은 동작을 바꾸지 않는다.
- [x] cyber 0.4.17로 옮기기 (2026-11-22): 두 스파이크의 의존을 태그 `0.4.17`(`02c3c425`)으로 올렸다. s1 48개 통과, s2 빌드, x86_64 교차 빌드(s1, s2). 안내 두 판과 agent-guide.md의 코드 블록 34개가 CLI와 세션에서 통과한다. 기본 로더의 모듈은 그대로 열셋, 공개 `cl_` 함수 142개, libcyber.a arm64 3,191,496바이트, x86_64 3,769,132바이트. CodeAct 비교는 다시 돌리지 않았다
- [ ] cyber 요청: 세션에서 `[]Array[T]`로 실패한 검증 뒤 다음 `cl_vm_validate`가 세그폴트(0.4.16부터, 2026-11-22에 찾음). 본체 첫 단계 전에 닫는다(ADR 0019). 같은 요청서에 질문 둘(`[]Array[T]`의 복사 오류와 core 안의 첫 위치, `&[]T`를 `for a |x|:`로 돌 때의 `&&[]T` 문구). 고친 빌드에서 s1에 검사를 더하고 요청서를 닫는다 (docs/requests/cyber-0.4.17-session-crash-after-slice-of-nocopy.md). cyber 회신(2026-11-22, master, 릴리스 전): 셋 다 고쳤다. 세그폴트는 앞에 성공한 eval이 있는 세션에서만 났고, 실패한 템플릿 본문을 본문 단위로 표시해 다음 컴파일로 넘기지 않는다(같은 잘못을 다시 적으면 원래 오류가 다시 나온다). `[]T`의 `NoCopy` 원소는 타입을 적은 사용자 줄에서 'A slice `[]Array[int]` copies its elements, so the element type `Array[int]` can not be `NoCopy`. Use `Array[Array[int]]`, which moves them.'로 거절한다(필드 · 매개변수 타입으로 적기만 해도 오류). `a &[]T`의 `for a |x|:`는 스스로 역참조해 돈다. 다음 빌드로 올릴 때 안내의 오류 표와 `Array` 문장을 이 문구로 확인한다. 같은 날 cyber가 0.4.17의 이동 분석 결함 여섯도 고쳤다(master, 릴리스 전, cyber `docs/releases/unreleased.md`): `while` 조건식과 `while o |v|:`의 옵션 식이 반복문 밖 변수를 옮기면 'Cannot move `x` in the condition of a `while` loop: it is declared outside the loop, and the condition is evaluated before every iteration. ...' 오류(0.4.17은 컴파일되고 이중 소멸), `for xs |x|:` 본문의 `move x`가 된다(0.4.17은 컴파일러가 죽음), `try:` 안의 `xs = xs.appended(f()!)`가 다시 컴파일된다(0.4.17의 회귀). 안내가 이 꼴들을 가르치면 다음 빌드에서 확인한다
- [ ] 'Expected exclusive access. There is another active borrow to `self`.'(순회 중 `&&self` 메서드 호출, 빌려 둔 관리형 값의 대입)는 고치는 법을 말하지 않는다. 다음 CodeAct 회차에서 나오면 오류 표(prompt/cyber-subset*.md)에 넣거나 cyber에 문구를 요청한다
- [ ] Cyber 부분집합 안내 (prompt/cyber-subset*.md, 예제 10개). 기준 빌드로 다시 썼고 예제와 조언을 CLI와 세션(persist_main) 양쪽에서 확인했다 (검토 문서 8절). 남은 것: 크기가 4,000토큰 목표를 넘는다(검토 문서 8절의 수치). 목표를 바꿀지 안내를 줄일지 사용자가 정한다

게이트: 스파이크 검토 결과를 사용자에게 보고하고, 교차 빌드가 tars 게스트(QEMU)에서 실행된다.

## C cyber 쪽 작업 줄기 (ADR 0010)

필요한 것은 cyber에 만든다. 작업 장소는 soomtong/cyber이고 그 저장소의 절차를 따른다. 목록과 필요의 증거는 08 문서 "cyber에서 만들 것"이 정본이다. M 단계와 나란히 간다.

- [x] C0 `use c` 없는 `#[extern]` 함수가 검증 중에 프로세스를 죽이던 것. cyber 0.4.14에서 컴파일 오류가 됐다. s1 검사 7h (2026-11-17)
- [~] C1 json 모듈 (parse, stringify, 값 트리). 기준 빌드에 있고 로더가 싣는다(ADR 0025). 남은 게이트: 안내 문서의 예제가 이 모듈을 써서 통과
- [~] C1 toon 모듈 (encode, decode). 기준 빌드에 있고 로더가 싣는다. 남은 게이트는 json과 같다
- [~] C2 regex 모듈 (역추적 없는 엔진), peg 모듈. 기준 빌드에 있고 로더가 싣는다. 남은 게이트는 json과 같다
- [x] C2 time 모듈. 기준 빌드에 있다. 허용하고 clock.now는 두지 않는다. 스파이크 로더에서 열었다 (ADR 0024, 2026-11-17)
- [x] 표준 모듈 API: 패키지에 `docs/api.json`이 들어 있고 `cyber doc --api <module>`이 찍는다. s1 검사 0b가 빌드 때 읽어 모듈로 거른다 (cyber 0.4.14, 2026-11-17)
- [x] `test` 모듈을 연다. 순수 Cyber 검사 함수이고 정본 안내가 가르친다. s1 검사 7a4 (ADR 0028, 사용자 결정, 2026-11-18)
- [x] `path` 모듈(0.4.14, join, base, dir, ext, stem, normalize, is_absolute). 파일 시스템을 보지 않는 문자열 함수라 연다. 스파이크 로더에서 열었다. s1 검사 7a3 (ADR 0027, 2026-11-17)
- [ ] C3 임베딩 옵션: `os`를 호스트 콜백으로 받기(ADR 0026의 방향 D). 모듈 허용 표는 호스트 로더로 되므로 올리지 않는다
- [ ] 수시: 프로세스를 죽이는 경로 수정
- [ ] cyber의 새 빌드를 받을 때마다 s1, 안내의 예제와 항목, 평가를 다시 돌린다. 문서는 새 빌드의 사실로 고쳐 쓴다 (ADR 0020)

게이트: 모듈마다 cyber의 테스트(누수 검사 포함)와 릴리스, 그리고 tars-agent 안내 문서의 예제가 그 모듈을 써서 통과한다.

## M1 최소 루프 (헤드리스, 읽기 전용)

- [ ] 14의 열린 것(모의 provider의 자리, 시계와 ID 주입, 시나리오의 모양, 골든 갱신, 녹화 SSE, CI 장소, Linux 러너, 경계 검사 구현, fuzz 실행)을 사용자가 정한다. 앞의 둘은 loop와 provider의 모양에 닿으므로 뼈대 전에 정한다
- [ ] 저장소 뼈대: build.zig, cyber 의존(가장 새 빌드, ADR 0023), macOS와 linux 빌드. zig build 단계 test, check, e2e, measure (14)
- [ ] CI (14 "CI"): 매 커밋에 aarch64 macOS(test, check, e2e, measure, x86_64-linux-gnu 교차 빌드)와 x86_64 Linux(test, e2e). 키 없음, Zig 배포본 sha256 대조, 제3자 action 없음. ci.build
- [ ] 정적 검사 (14): check.boundary(libcyber는 runtime/cy.zig 밖으로 새지 않고 caps/는 정문만, frontend와 core의 경계, 네트워크 import, ADR 0030의 8 B4), check.no-panic, check.link(tcc, mimalloc 없음, glibc 동적), check.deps
- [ ] 측정 (14 "비기능 예산을 재는 법"): measure.size, measure.startup, measure.memory를 CI 작업 요약에 기록한다(B6). 수치와 넘을 때의 처리는 아래 줄과 01 열린 것 4
- [ ] 비기능 예산: 첫 빌드에서 실행 파일 크기, 시작 시간, 유휴 메모리를 macOS arm64와 x86_64-linux-gnu로 잰다. 01 열린 것 4의 후보로 예산을 정하고, 릴리스 빌드의 최적화 모드와 strip을 함께 정한다
- [ ] runtime: cy.zig 래퍼, 로더, 상한, 결과 조립. 첫 검사: 구조체(`Future[!ExecResult]`, `!Stat`)와 `Future[![]str]`의 완료, 호스트 모듈 소스의 오버로드와 옵션 구조체(03). 안 되면 cyber에 요청한다 (ADR 0010, 0019)
- [ ] caps: 능력 표와 생성기 (Cyber 선언, 바인딩, 프롬프트 사양, JSON Schema), fs.read, fs.list, fs.glob, fs.stat, help. 표를 편집할 때 행마다 reads_only, irreversible 술어를 둘지 정한다 (ADR 0030의 7)
- [ ] provider: 스트림을 끊을 때 Zig 0.17.1의 HTTP 정리 멈춤을 피한다(deps.md). Messages API와 OpenAI Chat Completions 어댑터(개발 기본 제공자 DeepSeek, ADR 0014, 0015), 스트리밍, 적응형 사고, effort, 캐시 지점, stop_reason 분기(end_turn, tool_use, max_tokens, refusal, pause_turn), 재시도. refusal의 서버 쪽 fallbacks 옵션 적용 여부 결정
- [ ] prompt: 조립기, rules.md
- [ ] loop: validate, eval, 실패 분류, 한도. 벽시계는 VM 안의 시간만 잰다(바인딩 층이 능력 호출 동안 타이머를 멈춘다). 실패 결과에 능력 호출 목록 (ADR 0021)
- [ ] session: JSONL 쓰기 (07의 형식). 줄 머리와 crc, write 한 번에 줄 하나, 턴을 닫는 줄 뒤 fsync, 임시 이름 뒤 rename, 찢긴 꼬리 자르기, flock 잠금 (ADR 0030)
- [ ] headless: -p, text, json(06의 객체, ADR 0030), stream-json 출력. 터미널에 그리기 전 terminalSafe (ADR 0030의 8 B3)
- [ ] 테스트 도구 (14 "재료"): test/support에 모의 provider(07 리플레이의 줄), 각본 프런트엔드, localhost 가짜 HTTP 서버, 시계와 ID와 잠자기 주입, resize를 거부하는 allocator 감싸개(fx 검토 B2). 스파이크 1의 검사 목록(08 "M0에서 확인한 것")을 runtime 테스트로 다시 쓴다
- [ ] 테스트 (14): unit.runtime.*, esc.*(탈출 시도 열둘이 모두 결과로 끝나고 VM이 남는다), unit.caps.*의 M1 줄(누수), unit.caps.nonempty, oom.*
- [ ] 테스트 (14): scn.*의 M1 줄(잘린 응답, run 둘, 실패 결과의 능력 목록, reset 알림, 같은 오류 5회, 재시도, 기록 순서, 리플레이), sse.*, fake.stream-abort, fake.retry-http
- [ ] 테스트 (14): unit.session.*(찢긴 꼬리, crc 불일치, 더 새 v, fsync 지점), e2e.session-lock, e2e.killed-run(죽은 run을 세는 재료, 01 "죽는 비율을 재는 법"), gold.prompt.system, gold.caps, gold.request, gold.headless.*, e2e.headless-io, e2e.exit-codes
- [ ] 테스트 (14): guide.examples(예제를 링크된 libcyber로 실행해 깨지면 빌드 실패, 06), fuzz.*의 M1 줄(SSE, provider JSON, 세션 JSONL, run 인자, 명령행, terminalSafe, ADR 0030의 8 B5), unit.fe.terminal-safe(B3)
- [ ] live 탐침 (14, 손으로, 키 필요): live.formats, live.record(test/sse/의 원문을 녹화하고 가린다), live.probes(10 "확인하지 않은 것"), live.prompt-tokens(안내와 능력 사양의 토큰 수)

게이트: tars-agent -p "이 저장소의 빌드 방법을 설명해" 가 파일을 읽고 답한다. 탈출 시도 테스트가 모두 통과한다.

## M2 쓰기와 권한

- [ ] fs.search (ripgrep), fs.edit(정규화 일치, 줄바꿈 보존), fs.write, 파일 상태 추적, 쓰기 전 보관
- [ ] proc.exec, proc.sh, proc.start, proc.output, proc.kill, 환경 정리, 프로세스 그룹 종료
- [ ] 결과 상한과 넘침 파일: 스크립트 결과 20,000자, 능력 반환 1 MiB (ADR 0021)
- [ ] permission: 프로파일, 모드 다섯, 규칙 맞춤(경로 glob, 인자 앞부분, 도메인), 설정 파일 세 층, 보호 규칙
- [ ] 비밀: 자격 파일 권한 검사, 자식 환경에서 지우기, 기록 가리기
- [ ] 헤드리스 권한 옵션 (--permission-mode, --allow, --profile), json 출력, 종료 코드. 한도 --max-budget-usd와 세션 토큰 예산 (02)
- [ ] 테스트 (14): unit.perm.*(판정 순서, 규칙 맞춤 표, 모드 표, 보호 규칙, 기본 deny, 프로파일), unit.caps.*의 M2 줄(경로 정규화와 심볼릭 링크, 넘침, 파일 상태, fs.search, fs.edit, proc), unit.config.layers, unit.secret.*, fuzz.config, fuzz.rule, fuzz.edit-normalize, e2e.headless-readonly, e2e.headless-ask-deny, e2e.limits, e2e.bypass-cli
- [ ] 루프 상태 기계의 TLA+ 모델을 둘지 판단 (ADR 0030의 8 B7)

게이트: 헤드리스가 규칙 파일 아래에서 파일을 고치고 테스트 명령을 돌린다. 규칙 밖의 쓰기는 거부로 기록된다.

## E 평가와 판정 (M2 뒤, 13)

평가는 본체의 헤드리스 위에서 바깥 OS 샌드박스와 bypass 모드로 돈다 (13, ADR 0031).

- [ ] direct 모드: 같은 능력 표를 API 도구 여럿으로 (ADR 0006 결정 2). json에는 도구 호출 하나를 능력 호출 하나짜리 run으로 적는다 (06). 테스트: e2e.direct-mode (14)
- [ ] 평가는 json 모듈을 안내에 넣은 뒤 돌린다(json은 기준 빌드에 있다). 안내에 가르칠 모듈과 크기는 사용자가 정한다
- [ ] eval/: 과제 20개와 채점기. 과제마다 디렉터리(prompt, fixture, check), 파이썬 표준 라이브러리. 첫 과제 둘을 만든 뒤 사용자에게 보인다. 과제마다 3회
- [ ] 평가 실행: CodeAct 대 direct, 판정 모델 DeepSeek-V4.1-Flash와 OpenRouter의 Qwen 둘(시작하는 날 날짜가 붙은 ID로 고정). 기록은 13
- [ ] 평가 실행기가 신호로 끝난 회차(json 결과 없음)를 죽은 회차로 세고, 그 회차의 세션 파일에서 죽은 run을 검증 중과 실행 중으로 나눠 센다 (01 "죽는 비율을 재는 법"). 그 값으로 실행 분리를 정한다 (01 열린 것 1)
- [ ] 검증 뒤 `cl_vm_symbol_hints`의 쓰지 않는 함수 안 지역을 모델에게 넘길지, 오류 모아 받기를 켤지 (검토 문서 9절 13, 18, 세션의 최상위 지역은 거른다)
- [ ] 판정 (ADR 0006, 13): 첫 시도 validate 통과 70% 이상이고 과제 성공률이 direct보다 5%p 넘게 낮지 않으면 CodeAct를 기본으로 간다. 못 미치면 안내를 고쳐 한 번 더 재고, 그래도 못 미치면 direct를 기본으로 하고 CodeAct는 선택 모드로 둔다. 모델 사이의 차이가 판정을 가르면 모델마다 판정한다

게이트: 평가 표와 판정을 docs/decisions에 기록하고 사용자에게 보고한다.

## M3 대화형

- [ ] 줄 편집기 (raw 모드, 여러 줄, 히스토리, 한글)
- [ ] 스트리밍 표시, 코드 접기와 펼치기, 상태 줄
- [ ] 승인 프롬프트 (숫자 키, diff 표시, 승인 기억을 settings.local.json에). CL_AWAIT 경로로 루프 바닥에서 묻는다 (ADR 0011)
- [ ] 인터럽트 (Esc, Ctrl-C), 취소 플래그를 능력에 연결
- [ ] 실행 중 입력(steering): 코어의 큐, 스텝마다 하나씩, 턴 끝에 남은 입력은 다음 턴, 인터럽트 때 입력 줄로 돌려주기. 코어-프런트엔드 이벤트와 명령 타입은 사용자가 편집한다 (ADR 0021). 편집할 때 도구 카드의 수명과 결과 종류, 열린 카드 닫기, 승인 요청의 출처, 승인 요청과 나란한 ui.ask 질문 요청을 함께 정한다 (ADR 0030의 6, 03)
- [ ] 모드 전환 (Shift+Tab, /mode)과 system 메시지
- [ ] AGENTS.md 읽기, 프로젝트 설정 수락 절차
- [ ] 슬래시 명령: /help /clear /mode /model /cost /permissions /quit
- [ ] ! 셸 접두 (06): 사용자 권한 실행, 결과 상한, user 줄 기록
- [ ] ui.ask(승인과 같은 CL_AWAIT 경로, 03), ui.todo, memo
- [ ] os 대신 능력으로: fs.mkdir, fs.remove, fs.copy, fs.move, env.get 후보를 평가를 보고 정한다 (04, ADR 0026)
- [ ] net.fetch와 외부 입력 표시
- [ ] 테스트 (14): scn.*의 M3 줄(승인 대기, 동시 승인, ui.ask, 인터럽트, steering, 하네스 알림, todo, 시스템 프롬프트 고정), unit.perm.external-input(표시가 선 뒤의 권한 판정), unit.perm.approval-options, unit.config.trust, unit.prompt.agents-md, unit.caps.*의 M3 줄, unit.fe.*, fake.net-fetch, pty.*, Linux에서 linux.termios

게이트: macOS 터미널과 tars 패널(QEMU)에서 대화로 파일을 고친다. 승인, 거부, 인터럽트가 한글 입력 상태에서도 동작한다.

## M4 긴 세션

- [ ] 재개: --continue, --resume, /resume. VM 새 시작 알림, memo와 todo 복원
- [ ] 컴팩션: 자동 임계치와 /compact, 요약 요청 형식과 요약의 틀, 파일 목록 누적, 두 번째부터 요약 고치기 (02)
- [ ] 확인: 컴팩션에서 최근 구간을 원문으로 남길 때, 앞부분이 바뀐 대화에 남긴 사고 블록을 제공자가 받는지. 결과로 남길지 정한다 (ADR 0021 열어 둔 것)
- [ ] 캐시 점검: cache_read가 0으로 이어지면 경고
- [ ] 비용 계산과 tars-agent stats. 확인: 녹화한 세션으로 토큰과 비용, stats의 능력별 호출 수, 오류율, 결과 크기, 실패 종류별 비율을 맞춘다
- [ ] 지연 사양 (예산을 넘는 능력은 한 줄 요약과 help)
- [ ] 죽은 세션: crash/ 보관, 재개 때 crashed 결과 채우기, 재개 안내 (02)
- [ ] 테스트 (14): scn.compact, scn.context-overflow, scn.cache-warning, gold.compact, gold.stats(죽은 run의 셈 포함), unit.obs.cost, unit.session.crash-fill, e2e.crash-resume, e2e.resume
- [ ] 프로세스가 죽는 비율 재기: tars-agent stats가 세션 파일의 죽은 run(재개하지 않은 결과 없는 run 줄 포함)을 센다. E에서 실행 분리를 정하지 않았으면 이 값으로 정한다 (01 열린 것 1, ADR 0017 추천 10)

게이트: 컨텍스트 창을 넘기는 작업 하나를 컴팩션을 거쳐 끝낸다. 중간에 프로세스를 죽이고 이어서 끝낸다.

## M5 tars-linux 통합

- [ ] 릴리스: 태그를 밀면 CI가 x86_64-linux-gnu 산출물과 sha256을 올린다 (ci.release, 14)
- [ ] tars-linux devlayer/manifest.toml 등록 (tars-linux 쪽 작업, 그 저장소의 절차를 따른다)
- [ ] 커널 설정 CONFIG_SECURITY_LANDLOCK 확인과 추가 요청
- [ ] sandbox/landlock.zig: 쓰기 범위, TCP 제한, ABI 버전 확인, 없을 때의 내려가기
- [ ] auto 모드 (샌드박스가 있을 때만)
- [ ] 테스트 (14): linux.sandbox(범위 밖 쓰기와 TCP 연결이 막히는지, ABI 6의 신호 범위), unit.sandbox.fallback(Landlock이 없을 때 알리고 샌드박스 없이 도는지), unit.perm.sandbox-false(샌드박스 밖 실행은 승인을 묻는지). Linux 러너 커널에 Landlock이 없으면 linux.sandbox는 체인에서 돈다
- [ ] tars 게이트 체인 make check CHAIN=agent (chain.agent, 14): QEMU에서 헤드리스 stream-json으로 요청, 스크립트, 승인, 파일 생성을 로그로 판정하고 대화형은 픽셀로 본다. agent 체인은 tars-linux 쪽 작업이라 요청서(docs/requests/)를 먼저 쓴다. 산출물을 받는 길과 승인 단계를 로그로 판정할 길(이벤트 타입)을 요청서에서 정한다
- [ ] 사용자 문서: 설치, 키 설정, 권한 규칙, 모드
- [ ] tars.conf에 둘 키가 있는지 판단 (없으면 두지 않는다. 에이전트 설정은 settings.json에 있다)

게이트: tars ISO에서 tars-agent가 실행되고 체인이 통과한다. 0.1.0 릴리스.

## M6 확장 (06 문서의 순서)

- [ ] /rewind
- [ ] MCP 클라이언트 (stdio)
- [ ] 서브에이전트
- [ ] 스킬, 훅, 사용자 슬래시 명령, /init
- [ ] agentd와 tars 터미널 제어 채널, tars.* 능력: 자기 조작(명령 실행, 콘솔 입력). tars-linux 쪽 설계와 개선도 이 프로젝트의 일이다 (ADR 0013). 앞당길 자리는 능력 표 설계 때 정한다. agentd의 클라이언트 프로토콜은 AHP를 먼저 검토한다 (ADR 0029)
- [ ] MCP 서버 방향, MCP HTTP 전송
- [ ] ACP 어댑터: 헤드리스 프런트엔드 하나로 얹는다 (ADR 0029)
- [ ] 두 전송 형식(Messages, Chat Completions) 밖의 제공자 어댑터
- [ ] 안내를 cyber의 docs/agent-guide.md와 호스트 덧붙임으로 만든다 (ADR 0022). 기준 빌드의 패키지에 이 파일이 있다. 언제, 어떤 모양으로 모을지는 ADR 0022의 "열린 것"이고 사용자가 정한다
- [ ] fiber 안 Future.await의 양보(cyber에 있다): agentd에서 한 스레드에 여러 세션을 돌릴 때 쓸지 판단

## 뺀 것

이전 TODO에 있었으나 하지 않기로 한 것 (ADR 0009).

- 방식 B(순수 Cyber CLI) 스파이크
- docs/design.md, docs/fork-plan.md: 명세(spec/)와 08 문서가 그 역할을 한다
- 셸 명령 분류기
- tars.* 모의 구현
- OpenTelemetry
- 세션 재개 때 코드 재생으로 VM 복원
- JSON, 정규식을 호스트 능력으로 주기 (ADR 0010: cyber 표준 모듈로 만든다)
