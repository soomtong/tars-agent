# M0 스파이크 검토 02: cyber dev 빌드로 다시 돌리기 (2026-11-13)

첫 검토(2026-11-13-m0-spikes-review.md)에서 cyber에 보낸 결함 둘이 cyber master에 고쳐졌고, 컴파일 오류 문구가 보강됐다. 스파이크 1과 2를 그 dev 빌드로 다시 돌려 세 가지를 확인했다.

1. 결함 둘이 정말 고쳐졌는가. 우회(fork한 자식에서 검증, `Future[!int]` 손잡이와 `take`)를 걷어내고 돌려서 본다.
2. 보강된 오류 문구가 모델이 실제로 틀린 코드에 대해 원인을 말해 주는가.
3. CodeAct에서 모델이 Cyber를 얼마나, 어떻게 쓰는가. 특히 Cyber가 받지 않는 코드 패턴을 모았다(사용자 요청).

숫자는 모두 이 날 실제로 돌려서 얻은 것이다. 스파이크 코드처럼 이 재실행에 쓴 사본도 버린다.

## 1. 한 장 요약

| 질문 | 답 | 근거 |
|---|---|---|
| 요청서의 결함 둘이 고쳐졌나 | dev에서 고쳐졌다. 우회를 걷어 내고 s1 검사 31개, 죽던 재현 셋, s2 비교 실행 전부가 통과한다 | 3 |
| 보강된 오류 문구가 도움이 되나 | 문법 쪽(목록 리터럴, Map 초기화)은 고칠 방법을 말하고, 모델은 다음 스텝에 모두 고쳤다. 의미 쪽(없는 메서드, 캡처)은 그대로다 | 4, 6.5 |
| 모델은 Cyber를 얼마나 쓰나 | run 호출의 6~7할이 반복과 분기를 쓰는 18줄 안팎의 스크립트다. 쓰는 구문은 열 가지 남짓으로 좁다 | 5.1 |
| 무엇을 틀리나 | 없는 메서드(Python, JS 이름), `!T` 미처리, 대괄호 목록, 콜론 초기화, `:=` 없는 대입. 그리고 안내 문서가 만든 것: 표의 `\|` 이스케이프를 베낌 | 6 |
| 안내를 고치면 줄어드나 | 컴파일 오류가 과제당 deepseek 1.1 → 0.2, qwen3.8-flash 3.8 → 1.1. 대신 안내가 4할 커졌다 | 8 |

새로 찾은 것 가운데 무거운 셋:

1. `not`이 `and`, `or`보다 약하게 묶인다. `not a and b`는 `not (a and b)`다. 문서와 다르고 Python과 반대이며 오류 없이 값이 다르다. qwen3.8-flash 과제 하나가 이것으로 실패했다 (6.2, cyber 결함 후보).
2. `sort`에 Map 값으로 정렬하는 비교 함수를 줄 길이 없다. 캡처는 `^T`나 `&T`로 하라는 안내를 따라도 `sort`의 인자 모양에서 막힌다 (6.2).
3. 안내 문서의 결함 셋: Map 리터럴이 "없다", `max`, `min`이 "없다"(둘 다 0.4.9부터 있다), 표 안의 `\|` 이스케이프 (4.1, 6.4).

## 2. 무엇으로 돌렸나

| 항목 | 값 |
|---|---|
| cyber | soomtong/cyber master `dcedfc48`와 커밋되지 않은 작업 트리(F-121 범위식, F-122 목록과 Map 리터럴 문구). `cl_full_version`은 `Cyber 0.4.10-DEV build-0-local` |
| 비교 기준 | 첫 검토의 cyber 0.4.9 (`03d24f4e`), 로컬 CLI `/usr/local/bin/cyber` 0.4.9 |
| 호스트 | Zig 0.17.1, macOS |
| 모델 | deepseek-chat (ds-anth), qwen/qwen3.8-flash와 qwen/qwen3.8-max-0902 (or-oai) |

받는 방법: cyber 저장소는 다른 세션이 동시에 편집하므로 작업 트리를 스크래치 폴더에 스냅숏으로 떴다(`.git`, `.zig-cache`, `zig-out` 제외). 스파이크 s1과 s2도 사본을 떠서 build.zig.zon의 cyber 의존을 `.path = "../cyber-dev"`로 바꿨다. Zig 0.17.1의 `zig build`에는 `--fork`가 없다. 저장소의 spike/ 원본은 0.4.9 고정 그대로다.

사본에서 바꾼 것 (우회 걷어내기):

| 파일 | 0.4.9 우회 | 재실행 |
|---|---|---|
| s1, s2의 능력 | `read_async`, `exec_async`가 `Future[!int]` 손잡이를 돌려주고 래퍼가 `take(h)`로 문자열을 꺼냄 | `Future[!str]`을 돌려주고 래퍼는 `return read_async(path).await()` 한 줄. 호스트는 `cl_str_init(cl_vm_main_thread(vm), ...)`로 만든 문자열로 `cl_future_complete` |
| s2 vm.zig의 검증 | fork한 자식에서 `cl_vm_validate`, 자식이 죽으면 "compiler crash" | 세션 VM에서 바로 `cl_vm_validate`. 죽으면 s2 프로세스가 죽는다 |
| s2 compare.sh | fork 자식의 죽음을 셈 | s2의 종료 코드를 찍음 |

## 3. 결함 둘의 재확인

### 3.1 실패한 컴파일 뒤 다음 컴파일에서 죽던 것 (요청서 1, cyber F-120)

| 재현 | 0.4.9 | dev |
|---|---|---|
| `s1 replay crash-validate.txt`: 같은 VM에서 `names.sort(\|a, b\| counts[a] > counts[b])` 검증 실패 뒤 `Map[str, int]` 스크립트 검증 | `script 1: Segmentation fault at address 0x0` | `validate=SUCCESS eval=SUCCESS`, 끝까지 |
| `s1 crash 1` (호스트 모듈이 `Future[!str]`을 선언, persist_main 켬과 끔) 12회 | 모듈 컴파일 실패 뒤 죽음 | 짝수 회 PANIC, 홀수 회 SUCCESS, 죽지 않음. PANIC은 없는 파일 `x`를 읽어 `error.NotFound`를 `!`로 푼 것이라 맞는 동작이다 |
| `s1 crash 2` (모듈 본문에 선언 안 된 이름) 12회, persist_main 켬과 끔 | 죽음 | 짝수 회 COMPILE, 홀수 회 SUCCESS, 죽지 않음 |
| s2 비교 실행 전부, 같은 VM에서 검증 (5절) | fork로 우회 | 죽은 실행 0 |

replay 뒤에 Zig의 할당기가 새는 메모리를 둘 보고하지만 둘 다 스파이크 호스트 쪽(`g_out`, 읽은 파일)이다. cyber 쪽 누수가 아니다.

### 3.2 `!str` 값을 복사하지 못하던 것 (요청서 2, cyber F-119)

s1 사본의 검사 31개를 `Future[!str]` 모양으로 바꿔 돌렸다. 31개 모두 통과했다. 원본(손잡이 모양)도 dev 빌드로 31개 통과해 회귀는 없다.

- 2, 2b: `fs.read`가 완료된 `Future[!str]`로 값과 `error.NotFound`를 돌려준다
- 3c: `proc.exec`의 stdout이 승인 뒤 `Future[!str]`로 돌아온다
- 3f: 승인 흐름 뒤 살아 있는 객체 수가 그대로다. 문자열을 Future로 넘기는 경로에서 새는 것이 없다
- 첫 검토에서 qwen3.8-max가 맞은 `print(proc.exec('...'))`의 ``Expected type instance of `Result`, found `Ptr[!str]`. core:2918:49``는 이번 실행에서 한 번도 나오지 않았다

결론: 요청서의 결함 둘은 dev에서 우회 없이 통과한다. 본체의 선행 조건(feedback-fix-spike-defects-first.md)은 이것이 릴리스되고 고정 버전을 올린 뒤에 채워진다. 요청서 3(빌드 내보내기)과 4(spawn 차단)는 아직 cyber의 미릴리스 노트에 없다.

## 4. 오류 문구: 모델이 틀린 코드에 전후로 넣어 보기

첫 검토 5절의 "모델이 틀린 Cyber" 표를 그대로 0.4.9 CLI와 dev CLI에 넣었다.

| 모델이 쓴 것 | 0.4.9 | dev |
|---|---|---|
| `for ['a.py','b.py'] \|f\|:` | ParseError: Expected `]`. | ParseError: A list literal uses braces: `{a, b}` or `[]T{a, b}`. |
| `Map[str, int]{'app': 7}` | ParseError: Expected closing brace. | ParseError: Expected `=` between a key and a value. An initializer uses `key=value`, not `key: value`. |
| `names := {'a.py', 'b.py'}`, `for {1, 2, 3} \|n\|:` | CompileError: TODO: infer tuple type | 컴파일되고 돈다 (첫 원소 타입의 `[]T`) |
| `a[1..=2]` (a = 1, 2, 3, 4) | `{2}` (조용히 틀림) | `{2, 3}` |
| `for 'a','b','c' \|p\|:` | ParseError: Expected :. | 같다 |
| `names.sort(\|a, b\| counts[a] > counts[b])` | Can only capture variables declared with the reference types `^T` or `&T`. | 같다 |
| `'\n'.join(out)` | Can not find the symbol `join` in `str`. | 같다 |
| `out.pop()`, `names.find(x)`, `s.startswith(x)` | Can not find the symbol ... | 같다 |

읽는 법:

- 문법을 Python식으로 쓴 것(목록 리터럴, Map 리터럴)은 이제 고치는 방법까지 말해 준다. 5절에서 qwen3.8-flash가 `Count{name: f, n: c}`를 쓰고 이 문구를 받아 다음 스텝에 `name=f`로 고쳤다.
- 남은 넷은 문법이 아니라 의미(클로저 캡처, 메서드의 방향, 없는 메서드)다. "없다"는 맞게 말하지만 무엇을 대신 쓸지 말하지 않는다. `join`은 `str`이 아니라 `[]str`에 있다(`out.join('\n')`)는 것, `[]str`에 `find`가 없다면 무엇이 있는지를 알려 주면 한 스텝이 준다. cyber에 보낼 만한 다음 요청이다(7절).

### 4.1 안내 문서의 결함

`prompt/cyber-subset.en.md:53`은 `{"a": 1}`의 대응으로 "`Map[str, int]{}`, then `m['a'] = 1`. There is no literal"이라고 적는다. 0.4.9에서도 `Map[str, int]{app=7, db=2}`가 된다(확인함). 안내가 리터럴이 없다고 하니 모델은 Python의 `{'app': 7}`로 돌아간다. dev에서는 괄호 키(`{(k)=3}`)로 식 키도 된다. 이 줄과 52행("The element type is required", dev에서는 타입 없는 `{1, 2}`가 된다)은 8절에서 고쳤다.

## 5. CodeAct 재실행: 숫자

과제는 첫 검토와 같은 셋(T1 로그 집계, T2 TODO 세기, T3 설정 파일 고치기), codeact만 돌렸다. direct는 cyber와 무관하다. 첫 검토는 과제마다 1회였고 이번에는 deepseek과 qwen3.8-flash를 3회씩, qwen3.8-max를 1회 돌렸다. 그다음 6절의 패턴으로 안내 문서를 고치고(8절) 같은 빌드에서 안내만 바꿔 3회씩 다시 돌렸다.

| 모델 | cyber, 안내 | 과제 | 통과 | 스텝 평균 | 컴파일 오류 (과제당) | 과제당 시간 |
|---|---|---|---|---|---|---|
| deepseek-chat | 0.4.9, 옛 안내 (첫 검토) | 3 | 3 | 4.7 | 1.0 | 6초 |
| deepseek-chat | dev, 옛 안내 | 9 | 9 | 5.2 | 1.1 | 7초 |
| deepseek-chat | dev, 새 안내 | 9 | 8 | 3.9 | 0.2 | 6초 |
| qwen3.8-flash | 0.4.9, 옛 안내 (첫 검토) | 3 | 2 | 14.0 | 8.0 | 59초 |
| qwen3.8-flash | dev, 옛 안내 | 9 | 8 | 12.4 | 3.8 | 58초 |
| qwen3.8-flash | dev, 새 안내 | 9 | 8 | 8.6 | 1.1 | 45초 |
| qwen3.8-max | 0.4.9, 옛 안내 (첫 검토) | 3 | 3 | 9.3 | 1.3 | 134초 |
| qwen3.8-max | dev, 옛 안내 | 3 | 3 | 6.3 | 0.3 | 58초 |

- 죽은 실행은 없다. 세션 VM에서 바로 검증한 스크립트가 옛 안내 158개, 새 안내 95개다.
- 실패 넷 중 셋은 과제 해석이었다. qwen3.8-flash r1 T1은 보고서를 오름차순으로 쓰고 답에서는 내림차순이라고 말했다. deepseek 새 안내 n2 T2는 `#`로 시작하는 줄만 세어 줄 끝 주석(`pass  # TODO handle errors`)을 놓쳤다. 넷째인 qwen3.8-flash 새 안내 n2 T3는 Cyber 쪽이다: `not added and (...)`가 Python과 다르게 묶여(6.2의 `not`) `debug` 줄을 엉뚱한 곳에 넣었고, 되돌리다 스텝 한도(15)에 걸렸다.
- 표본이 작다. 과제 셋, 회차 셋이다. 방향을 보는 숫자이지 판정(ADR 0006)이 아니다.

### 5.1 모델은 Cyber를 얼마나 쓰는가

run 호출마다 스크립트를 셋으로 나눴다(scratchpad의 usage.py, 규칙은 단순한 정규식).

- 셸 위임: `proc.exec`와 `print`뿐. 셸 명령을 Cyber로 감싼 것
- 입출력만: `fs.read`, `fs.write`, `print`뿐
- 로직: 반복, 분기, 함수, Map, 문자열 메서드, 정렬 중 하나라도 쓴 것

| 모델 (dev, 옛 안내) | run 호출 | 셸 위임 | 입출력만 | 로직 | 컴파일 실패 | 스크립트 평균 줄 (로직만) |
|---|---|---|---|---|---|---|
| deepseek-chat | 38 | 9 (24%) | 7 (18%) | 22 (58%) | 10 (26%) | 11.4 (18.7) |
| qwen3.8-flash | 104 | 22 (21%) | 5 (5%) | 77 (74%) | 34 (33%) | 14.0 (18.3) |
| qwen3.8-max | 16 | 5 (31%) | 1 (6%) | 10 (63%) | 1 (6%) | 17.3 |

쓰는 구문의 비율 (run 호출 중 그 구문이 들어 있는 것):

| 구문 | deepseek-chat | qwen3.8-flash |
|---|---|---|
| `!`, `!else` (오류 처리) | 97% | 74% |
| `fs.read` | 74% | 53% |
| `for` | 58% | 44% |
| `'%{x}'` 보간 | 50% | 61% |
| `[]T` 목록 | 47% | 41% |
| 문자열 메서드 | 42% | 53% |
| `if` | 39% | 57% |
| `proc.exec` | 39% | 47% |
| `sort` | 16% | 19% |
| `Map` | 13% | 5% |
| `fn` (함수 선언) | 11% | 11% |

읽는 법:

- 모델은 Cyber를 셸 감싸개로만 쓰지 않는다. run 호출의 6~7할이 반복과 분기를 쓰는 18줄 안팎의 스크립트다. 첫 한두 스텝은 `proc.exec('ls ...')`로 둘러보고, 그다음 한 스크립트에 읽기, 세기, 정렬, 쓰기를 다 담는 흐름이 세 모델에 공통이다.
- Map은 적게 쓴다. 집계 과제(T1, T2)인데도 deepseek 13%, qwen3.8-flash 5%다. 안내가 "Map 리터럴이 없다"고 했고(4.1), Map 값으로 정렬하는 길이 막혀 있어서(6.2) 목록과 struct로 돌아간다.
- 함수 선언은 1할 남짓이다. 스크립트가 짧고 한 번 쓰고 버리는 모양이라 그렇다. persist_main으로 남은 함수를 다음 호출에서 다시 부른 경우는 158개 중 0이었다. 세션이 이어지는 이점을 모델은 쓰지 않는다.
- 쓰는 Cyber는 좁다. 위 표의 열한 가지와 struct 선언(16), 최상위 `try:` 블록(59)이 거의 전부다. `if x |v|:`는 5번, `?else`는 2번이고 `switch`, `^T`, 트레이트, 제너레이터는 한 번도 나오지 않았다. 안내 문서도 이 좁은 부분에 힘을 주는 편이 낫다.

## 6. 모델이 쓴 코드 중 Cyber가 받지 않은 패턴

dev, 옛 안내 실행의 컴파일 실패 45건을 오류 문구와 가리킨 줄로 나눴다(scratchpad의 categorize.py). 괄호 안은 건수와 모델. 끝 열은 이 패턴을 무엇이 막거나 고치는가다.

### 6.1 Python과 JS를 그대로 쓴 문법

| 모델이 쓴 것 | 건수 | 오류 첫 줄 | 대응 |
|---|---|---|---|
| `for ['app','db','web'] \|n\|:`, `lines[..k] + ["port = 9090"] + ...` | 5 (deepseek 2, flash 3) | A list literal uses braces: `{a, b}` or `[]T{a, b}`. | dev 문구가 고침을 말한다. 다음 스텝에 모두 고쳤다 |
| `Count{name: f, n: c}`, `Item{name: name, count: n}` | 3 (flash) | Expected `=` between a key and a value. ... | dev 문구. 다음 스텝에 고쳤다 |
| `for p in ['a','b','c']:`, `for p in []str{...}:` | 2 (deepseek, flash) | Expected :. | 문구가 원인을 말하지 않는다. 안내에 있다 |
| `b = "x\ny"` (`:=` 없이), `for p \|path\|:` (없는 이름) | 4 (deepseek 1, flash 3) | Undeclared variable `b`. | 안내 |
| `t := cts[j]; cts[j] = cts[j + 1]; ...` | 1 (deepseek) | Expected end of line or file. Got semicolon. | 안내 |
| `if counts[a] == counts[b]: a.less(b) else ...` (식 안의 if) | 1 (deepseek) | Expected `(`. | 안내 (`if (c) x else y`) |
| `global g_counts Map[str, int]{}` (`=` 없이) | 1 (deepseek) | `g_counts` does not have an initializer. | 문구가 충분하다 |
| `if s.startsWith('port') and '=' in_safe s:` | 1 (flash) | Expected colon after if condition. | 모델의 헛것 |

### 6.2 의미 규칙

| 모델이 쓴 것 | 건수 | 오류 첫 줄 | 대응 |
|---|---|---|---|
| `fs.write('report.txt', lines.join('\n') + '\n')` (결과를 처리하지 않음) | 5 (flash) | Expected to handle the error case for `!void`. | 새 안내에 규칙과 오류 줄을 넣었다 |
| `print("len=%{r.len()}")`, `print(out.ok!)` (`!str`을 풀지 않고 씀) | 2 (flash) | Can not find the symbol `len` in `!str`. / Field `ok` does not exist in `!str`. | 새 안내 |
| `names.sort(\|a, b\| counts[a] > counts[b])` | 1 (deepseek), 첫 검토에서도 deepseek 1 | Can only capture variables declared with the reference types `^T` or `&T`. | 안내를 따라 `^Map`이나 `&counts`로 바꿔도 안 된다(아래). 새 안내는 struct 목록 정렬로 돌린다. cyber 요청 |
| `if header_name(l) ?else '' == 'server':` | 1 (flash) | Expected type `str`, got `bool`. | `?else`가 `==`보다 약하게 묶인다. 새 안내 |
| `out.insert(idx, 'debug = true')` (돌려준 목록을 버림) | 1 (deepseek) | Expected assignment to a variable or placeholder for `[]str`. | 안내에 규칙이 있고 문구도 맞다 |
| `if section == 'server' and not added and (...)` | 새 안내 실행에서 1 (flash), 과제 실패 | 오류 없음, 값이 다르다 | `not`이 뒤의 식 전체에 걸린다. 아래. 새 안내, cyber 결함 후보 |

Map 값으로 정렬하기는 지금 Cyber로 쓸 길이 없다. 확인한 것:

~~~cy
counts := Map[str, int]{app=7, db=8, web=23}
names := counts.keys()
names.sort(|a, b| counts[a] > counts[b])        -- Can only capture variables ...
c := &counts
names.sort(|a, b| c[a] > c[b])                  -- Expected argument `&OpaqueFunc[...]`, found `OpaqueFunc[...]`
counts2 := ^Map[str, int]{app=7}
names.sort(&(|a, b| counts2[a] > counts2[b]))   -- Expected argument `&OpaqueFunc[...]`, found `&Func[...]`
~~~

`not`의 우선순위 (dev와 0.4.9 같음):

~~~cy
a := false
b := false
print(not a and b)      -- true. Python은 false
print((not a) and b)    -- false
x := true
print(not x or true)    -- false. not (x or true)
print(!a and b)         -- false. 접두 ! 는 단단히 묶인다
~~~

`not`은 뒤의 식 전체를 받는다. cyber 문서의 연산자 표(docs/docs.md "Operators")는 접두 연산자가 가장 높다고 하고 `!`(Logic not)를 올려 두지만 `not` 키워드는 표에 없다. 문서와 다르고 Python과 반대이며 컴파일 오류도 없이 다른 값을 낸다. 모델의 사고 기록에 "Cyber에 우선순위 문제가 있는 것 같다"는 추측이 나오고, 그 사이에 파일이 망가졌다.

`sort`는 `&OpaqueFunc[LessFn[T]]`를 받는데, 캡처하는 클로저는 `Func`이고 캡처 없는 람다만 그 모양이 된다. 그래서 안내의 "캡처는 `^T`나 `&T`로" 규칙을 따라도 정렬에서는 막힌다. 되는 길은 struct 목록을 필드로 정렬하는 것뿐이다(새 안내 예제 4).

### 6.3 없는 메서드

| 모델이 쓴 것 | 건수 | 있는 것 |
|---|---|---|
| `t.startsWith('[')`, `t.endsWith(']')` (camelCase, JS) | 5 (flash 4, max 1) | `starts_with`, `ends_with` |
| `line.find('TODO')`, `f.rfind('/')` | 5 (deepseek 1, flash 4) | `s.index(sub)`는 `?int`. `rfind`는 없다 |
| `s.startswith(p)` (Python) | 1 (flash) | `starts_with` |
| `s.split("=")[0].trim()` (인자 없이) | 1 (flash) | `trim`은 자를 문자를 받는다 |
| 첫 검토: `'\n'.join(out)`, `out.pop()`, `names.find(x)` | 3 (deepseek 1, max 2) | `out.join('\n')`, `last()`와 `remove(i)`, `index(x)` |

없는 메서드는 모두 Python이나 JS의 이름이다. 오류 문구("Can not find the symbol `find` in `str`")는 맞지만 무엇을 쓸지 말하지 않는다. 모델은 다음 스텝에 다른 이름을 찾아 고쳤다. 11건 중 셸(`proc.exec`)로 미룬 경우는 없었다.

### 6.4 형식과 오타

| 모델이 쓴 것 | 건수 | 원인 |
|---|---|---|
| `for files \|i, f\|:`, `for lines \|idx, ln\|:`, `for items \|it\|:` (역슬래시가 글자로 들어감) | 3 (flash) | 옛 안내의 표 칸에 마크다운 이스케이프 `\|`가 있다. 안내는 원문으로 들어가므로 모델은 `\|`를 문법으로 읽고 베꼈다. 새 안내는 `\|`가 든 표를 목록으로 바꿨다 |
| `fs.read('project/config.ini)!` (닫지 않은 문자열) | 2 (flash, 다른 회차에서 똑같이) | 모델의 오타 |

### 6.5 오류 뒤에 모델이 하는 일

실패 45건 뒤의 바로 다음 run 호출을 봤다(scratchpad의 followup.py).

- 같은 오류를 되풀이한 것: 0건
- 다음 호출이 성공: 29건
- 고쳤지만 다른 오류에 걸림: 16건

16건의 대부분은 한 스크립트에 틀린 곳이 여럿이었다. 컴파일러가 첫 오류에서 멈추니 모델은 한 스텝에 하나씩 벗겨낸다. qwen3.8-flash r3 T1은 `\|`, 대괄호 목록, 콜론 초기화, `!void` 처리를 네 스텝에 걸쳐 차례로 고쳤다. 오류 문구는 제 몫을 한다. 문제는 한 번에 하나라는 것이다(9절).

## 7. cyber에 보낼 다음 요청 (후보)

요청서는 사용자가 정하면 docs/requests/에 쓴다. 지금은 후보다.

0. (결함 후보) `not`이 `and`, `or`보다 약하게 묶인다(6.2). 문서의 연산자 표와 다르고 조용히 다른 값을 낸다. 의도라면 문서에 적고, 아니면 접두 연산자의 우선순위로. 스파이크에서 찾은 결함이니 고치고 진행하는 규칙(feedback-fix-spike-defects-first.md)에 든다고 본다. 확정은 사용자가.
1. `sort`가 캡처하는 클로저를 받게 하거나, 키를 뽑는 정렬(`xs.sort_by(|x| key)`처럼)을 둔다. 지금은 Map 값으로 정렬할 길이 없다(6.2). 집계 과제마다 나온다.
2. 없는 메서드 오류에 비슷한 이름을 붙인다: "Can not find the symbol `startsWith` in `str`. Did you mean `starts_with`?", `find`에는 `index`, `str.join`에는 "`[]str.join(sep)`". 실패 45건 중 11건이 이것이다.
3. `print(f())`에서 `f`가 `!T`를 돌려주면 값이 아니라 타입 이름(`!str`, `!int`)이 찍힌다. 0.4.9에서는 `!str`이면 core:2918 컴파일 오류였고 dev에서는 컴파일되어 `!str`을 찍는다. `!int`는 0.4.9에서도 `!int`를 찍었다. `?str`은 값을 찍는다. 성공 값이나 `error.Name`을 찍거나, 컴파일 오류로 "unwrap with `!` first"를 말해 주기를 바란다. deepseek이 이것을 한 스텝 썼다.
4. `for x in xs:`의 "Expected :."에 `for xs |x|:`를 알려 주는 문구. 목록 리터럴처럼 흔한 Python 습관이다.
5. "Expected `Vector` element type."의 `Vector`는 Cyber 문법에 없는 이름이다(`lines[..k] + ["port = 9090"]`에서). 사용자 쪽 이름으로.
6. (그대로 남은 것) 요청서 3 빌드 내보내기, 4 spawn 차단, 5의 메서드 목록을 기계가 읽는 형태로.

## 8. 안내 문서(prompt/cyber-subset)를 고친 것

사용자 요청으로 영문판과 한국어판을 같이 고쳤다. 기준 버전을 0.4.10-DEV(dcedfc48 이후)로 올렸다. 고친 것:

| 무엇 | 근거 |
|---|---|
| `\|`가 든 두 표(문법 차이, 자주 나는 오류)를 목록으로. 표 칸의 `\|` 이스케이프 제거 | 6.4. 안내는 원문으로 들어간다 |
| Map 리터럴 `Map[str, int]{a=1}`, 식 키 `{(k)=1}`. "리터럴 없음"을 지움 | 4.1. 0.4.9부터 됐다 |
| `max`, `min`을 "없는 것"에서 "같은 것"으로 | 0.4.9부터 있다(확인함). 안내의 결함 |
| 타입 없는 목록 `{1, 2}`, 빈 목록은 타입 필요, `s[1..=2]` | dev(F-121, F-122) |
| "있는 메서드" 절: str, []T, Map의 메서드 전부와 Python 이름 대응(`join`, `find`, `pop`, `startswith`, `strip`, `rfind`, `items`) | 6.3. 표준 라이브러리 core.cy에서 뽑아 하나씩 실행해 확인 |
| "정렬" 절과 예제 4(Map으로 세고 struct 목록을 개수로 정렬) | 6.2 |
| `!T`는 `!void`라도 처리, 풀고 나서 쓰기, `?else`의 우선순위 | 6.2 |
| struct 초기화 `P{name='a'}` (`P(name=...)`, `{name: ...}` 아님), snake_case 메서드 이름 | 6.1, 6.3 |
| 오류 목록에 dev의 새 문구와 위의 패턴 아홉 줄 | 6 |
| `not`은 뒤의 식 전체에 걸린다, `print(r())`는 `!str`을 찍는다 | 6.2, 7. 새 안내 실행이 끝난 뒤 더했으므로 5절의 새 안내 숫자에는 이 두 줄이 없다 |
| "없는 것"에 `sum`, `sorted`, `enumerate`, `zip`, `abs` | 확인함 |

예제 10개는 두 판 모두 dev CLI로 돌려 통과했다. 판끼리 예제 코드는 같다.

효과(5절 표의 "새 안내" 줄, 같은 dev 빌드에서 안내만 바꿈):

| 모델 | 컴파일 오류 (과제당) | 스텝 평균 | 과제당 시간 | 다음 호출에서 같은 오류 |
|---|---|---|---|---|
| deepseek-chat | 1.1 → 0.2 | 5.2 → 3.9 | 7초 → 6초 | 0 → 0 |
| qwen3.8-flash | 3.8 → 1.1 | 12.4 → 8.6 | 58초 → 45초 | 0 → 0 |

- 새 안내로 사라진 것: `\|` 베끼기, 콜론 초기화, `!void` 미처리, camelCase와 없는 메서드, 정렬 함수의 캡처. 모두 0건이 됐다.
- 남은 것 12건: qwen3.8-flash의 `:=` 없는 대입 4건(`t = ln.trim(...)`, `isHeader = ...`, camelCase 변수 이름과 함께 온다), `for x in xs:` 2건, 대괄호 목록 1건, 헛것 4건(`if h ?>= 0:`, `if h ?|idx|:`, `if rest[rest.index(?) ??] :`, `for p |{...}|:`), deepseek의 빈 블록 1건(Block requires an indented child statement).
- 사용 모양도 바뀌었다. 로직 스크립트의 비율은 deepseek 58% → 65%, qwen3.8-flash 74% → 68%로 비슷하고, 스크립트는 짧아졌다(평균 11.4 → 10.3줄, 14.0 → 11.2줄). Map을 쓴 호출이 0이 됐다. 예제 4와 "정렬" 절이 집계를 struct 목록으로 이끌었다. Map 값으로 정렬하는 길이 cyber에 생기면(7절 1) 안내를 되돌릴 일이다.
- 대가는 크기다. 안내가 12.9KB에서 18.1KB로 커져 시스템 프롬프트가 약 4,450토큰에서 약 6,000토큰이 됐다. TODO의 "4,000 토큰 이하" 목표를 넘는다. 캐시가 있는 제공자(DeepSeek, OpenRouter의 Qwen 모두 캐시가 붙었다)에서는 스텝이 준 몫이 더 크다: qwen3.8-flash의 과제당 입력이 80.6k에서 70.5k토큰으로 줄었다. 목표를 바꿀지, 안내를 줄일지(예: 오류 목록을 덜어 내고 문구가 충분한 줄은 뺀다)는 사용자가 정한다.

## 9. 본체에 주는 뜻 (추천, 확정은 본체를 만들 때 사용자가)

첫 검토 8절의 추천에 더하거나 고치는 것만 적는다.

1. 검증은 세션 VM에서 바로 한다. fork 검증은 본체에 넣지 않는다(이미 그렇게 정했고, 이번에 우회 없이 도는 것을 봤다). 능력은 `Future[!str]`을 돌려준다. 손잡이와 `take`는 넣지 않는다.
2. 검증에 `cl_vm_set_error_recovery(vm, true)`를 켜고 `cl_vm_compile_report`로 오류를 전부 돌려주는 것을 시험할 가치가 있다(0.4.10의 기능). 6.5의 "한 스텝에 하나씩"이 줄어든다. 구문 오류는 여전히 첫 것에서 멈춘다.
3. 도구 결과의 오류 문구 뒤에 호스트가 덧붙이는 힌트(없는 메서드면 안내의 "Python 이름" 줄)는 cyber 요청 2가 들어오면 필요 없다. cyber에서 고치는 쪽을 먼저 권한다.
4. 안내 문서는 시스템 프롬프트의 대부분이다. 원문으로 들어간다는 점을 잊지 않는다: 마크다운 이스케이프, 표의 정렬 같은 사람용 장식은 모델에게 잡음이거나 해가 된다.

## 10. 다시 돌리는 법

재실행에 쓴 것은 모두 세션 스크래치에 있고 세션이 끝나면 사라진다. 다시 하려면:

1. cyber 작업 트리를 `.git`, `.zig-cache`, `zig-out`을 빼고 한 폴더에 복사한다(`cyber-dev`).
2. spike/s1, spike/s2를 그 옆에 복사하고 build.zig.zon의 cyber를 `.path = "../cyber-dev"`로 바꾼다.
3. 2절의 표대로 우회를 걷어낸다: 능력의 `Future[!int]`를 `Future[!str]`로, 완료는 `cl_str_init(cl_vm_main_thread(vm), ...)`, 모듈 소스의 `take` 제거, s2 vm.zig의 `validateInChild`를 `cl_vm_validate` 한 줄로.
4. s1: `zig build && ./zig-out/bin/s1`, `./zig-out/bin/s1 replay <원본>/spike/s1/crash-validate.txt`, `./zig-out/bin/s1 crash 1`, `crash 2`, 끝에 `np`를 붙이면 persist_main을 끈다.
5. s2: compare.sh의 s2 호출에 `--guide <저장소>/prompt/cyber-subset.en.md`를 붙이고(사본 위치에서는 상대 경로가 깨진다), 회차마다 trace를 다른 폴더로 옮긴다. 모델이 쓴 명령은 그대로 jail.zig 안에서만 돈다.
