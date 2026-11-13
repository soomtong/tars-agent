# M0 스파이크 검토 03: 요청 후보를 반영한 cyber dev로 다시 돌리기 (2026-11-14)

검토 02(2026-11-13-m0-spikes-review-02.md)의 7절 요청 후보를 cyber가 master에 반영했다. 같은 스파이크와 같은 과제를 그 빌드로 다시 돌려 세 가지를 봤다.

1. 회귀가 없는가. 검토 02에서 확인한 결함 둘의 수정이 그대로인가.
2. 요청 후보가 실제로 고쳐졌는가. 모델이 틀렸던 코드를 그대로 넣어 전후를 비교한다.
3. 안내 문서를 새 빌드에 맞춘 뒤 CodeAct의 컴파일 오류와 스텝이 어떻게 되는가.

숫자는 모두 이 날 실제로 돌려서 얻은 것이다.

## 1. 한 장 요약

| 질문 | 답 | 근거 |
|---|---|---|
| 회귀가 있나 | 없다. 검토 02의 결함 둘은 우회 없이 계속 통과한다 | 3 |
| 요청 후보가 고쳐졌나 | 검토 02 7절의 0~5가 모두 반영됐다. `not`은 Python처럼 묶이고, 풀지 않은 `!T`의 출력은 컴파일 오류이고, 없는 메서드에는 Cyber 이름을 제안하고, `^Map`이나 `&T`를 캡처해 정렬할 수 있다 | 4.1 |
| CodeAct가 나아졌나 | 컴파일 오류의 수는 검토 02의 새 안내 때와 비슷하다(오류로 세는 기준이 하나 늘었다). 달라진 것은 모양이다: Map을 다시 쓴다(0% → 11~15%) | 6 |
| 새 문제 | `^[]str`에 `+=`하면 메모리가 깨지고 프로세스가 죽는다. 0.4.9부터 있던 결함이고, 모델이 `^Map` 권장을 목록에까지 넓혀 쓰면서 드러났다. cyber에 요청서를 썼다 | 7 |
| 안내 | 정렬, 문자열 비교, `xs.sort()`를 새 빌드에 맞췄다. 처음 넣은 "최상위에서 빌려서 정렬" 조언은 세션에서 오류여서 `^Map` 선언으로 바꿨다 | 5 |

새로 찾은 것 가운데 무거운 둘:

1. `^[]str`에 대한 `+=`가 메모리를 깨뜨린다. 두 번 붙이면 Segmentation fault, 한 번이면 오류 없이 붙지 않거나 길이가 쓰레기 값이다. 에이전트 호스트가 실제로 죽었다 (7절, docs/requests/cyber-m0-spike-review-03.md).
2. 안내의 조언은 CLI가 아니라 세션(persist_main)에서 확인해야 한다. CLI로만 확인한 "`c := &counts`로 빌려서 정렬"이 에이전트에서는 ``Cannot persist local ... of borrow type``으로 세 번 막혔다 (5절).

## 2. 무엇으로 돌렸나

| 항목 | 값 |
|---|---|
| cyber | master `6ed1b6c4`(0.4.10 뒤 8커밋)와 커밋되지 않은 작업 트리(정렬, `str`의 비교 연산자, 캡처 오류 문구). 스냅숏으로 고정했다. `cl_full_version`은 `Cyber 0.4.10-DEV build-0-local` |
| 비교 기준 | 검토 02의 dev 스냅숏(`dcedfc48`과 그때의 작업 트리) |
| 스파이크 | 검토 02에서 우회를 걷어 낸 사본(s1, s2)을 다시 복사해 새 스냅숏에 링크 |
| 안내 | prompt/cyber-subset*.md. 검토 02 뒤 커밋되지 않은 부분 갱신(b6c7f713 기준: `not` 줄 삭제, `print(r())` 오류, `for` 오류 문구)이 이미 있었고, 그 위에 이번 빌드의 정렬과 문자열 비교를 더했다(5절) |

검토 02 뒤 `m1`~`m3`라는 회차가 같은 스크래치에서 돌았다. 그 사이 첫 스냅숏이 b6c7f713 무렵의 트리로 다시 동기화되었던 것으로 보이며, 빌드와 안내를 확정할 수 없어 이 검토에는 쓰지 않는다.

cyber 쪽 변경(커밋 순):

| 커밋 | 내용 | 검토 02의 어디에서 |
|---|---|---|
| 64ac86bc | 타입 없는 목록 리터럴, Map 식 키, 포함 범위 (검토 02 때 작업 트리였던 것) | 4절 |
| b6c7f713 | `not`을 Python처럼 묶는다. 풀지 않은 `!T`의 출력은 컴파일 오류 | 7절 0, 3 |
| 78b23f89 | `for x in xs:`와 `for 'a', 'b'`의 문구, 오류 문구의 `Vector` 같은 내부 이름을 쓰는 표기로 | 7절 4, 5 |
| d91b0d35 | 없는 메서드 오류에 Cyber 이름을 제안 | 7절 2 |
| 6ed1b6c4 | 지역을 캡처하는 정렬 클로저의 설계 검토 문서 (결정은 cyber 쪽 사용자) | 7절 1 |
| 작업 트리 | `^T`, `&T`를 캡처한 클로저를 `sort`에 넘길 수 있다. 일반 지역 캡처 오류가 빌리는 법을 말한다. `str`의 `<` 등, 인자 없는 `xs.sort()` | 7절 1 |

## 3. 회귀

| 확인 | 결과 |
|---|---|
| s1 검사 31개 (`Future[!str]` 모양, 우회 없음) | 31 통과 |
| `s1 replay crash-validate.txt` (0.4.9에서 Segmentation fault) | 끝까지 간다 |
| `s1 crash 1`, `crash 2`, persist_main 켬과 끔 | 넷 모두 12회 eval 뒤 죽지 않음 |
| s2 비교 실행 전부, 세션 VM에서 바로 검증 (6절) | 검증 쪽의 죽음은 없다. 실행 중 한 번 죽었다: 오래된 다른 결함(7절)이다 |

## 4. 요청 후보: 모델이 틀린 코드를 전후로 넣어 보기

검토 02 6절의 실패 패턴을 최소 스크립트로 만들어 검토 02의 dev CLI와 새 dev CLI에 넣었다.

### 4.1 고쳐진 것

| 모델이 쓴 것 | 검토 02의 dev | 새 dev |
|---|---|---|
| `not a and b` (a, b 모두 false) | `true` (`not (a and b)`) | `false` (`(not a) and b`, Python과 같다). `not x == 2`는 여전히 `not (x == 2)` |
| `print(r())`, `'%{r()}'` (`r`이 `!T`) | `!str`, `n=!int`를 찍음 | Can not print `!str`. Unwrap it with `!` first, or handle the error with `!else` or `try`. |
| `names.sort(\|a, b\| counts[a] > counts[b])` | Can only capture variables declared with the reference types `^T` or `&T`. | 같은 오류 뒤에 "Declare it with `^T`, or borrow it before the lambda (`b := &counts`) and use `b` in the lambda." |
| `c := &counts` 뒤 `names.sort(\|a, b\| c[a] > c[b])` | Expected argument `&OpaqueFunc[...]`, found `OpaqueFunc[...]` | 된다 (`web,db,app`) |
| `counts := ^Map[...]` 뒤 같은 정렬 | Expected argument `&OpaqueFunc[...]`, found `Func[...]` | 된다 |
| `for p in {'a', 'b'}:` | Expected :. | Expected `:` or `\|x\|:`. A `for` loop is written `for xs \|x\|:` or `for 0..n \|i\|:`, not `for x in xs:`. |
| `for 'a','b','c' \|p\|:` | Expected :. | Expected `:` or `\|x\|:`. To loop over values, put them in a list literal: `for {a, b} \|x\|:`. |
| `t.startsWith('[')`, `s.startswith(p)` | Can not find the symbol ... | ... Did you mean `starts_with`? |
| `s.find('b')` | Can not find the symbol `find` in `str`. | ... Did you mean `index`? |
| `s.strip()` | 같은 꼴 | ... Did you mean `trim`? |
| `xs.push(2)` | 같은 꼴 | ... Did you mean `append`? |
| `'\n'.join(out)` | Can not find the symbol `join` in `str`. | ... `join` is a method of a list: `xs.join(sep)`. |
| `out.pop()` | Can not find the symbol `pop` in `[]str`. | ... Use `last()` and `remove(i)`. |
| `for m.items() \|e\|:` | Can not find the symbol `items` in `Map[str, int]`. | ... Iterate the map with `for m \|e\|:` and use `e.key` and `e.value`. |
| `lines[..k] + ['x'] + lines[k..]` | Expected `Vector` element type. ... | Expected the element type of `[n]T`. ... |
| `'a' < 'b'` | Can not find the symbol `<` in `str`. | `true` (바이트 순) |
| `xs.sort()` (인자 없이) | Expected `2` arguments, found `1` ... | 오름차순 정렬 (`int`, `float`, `str`) |

### 4.2 그대로인 것

원인은 맞게 말하지만 고칠 방법을 말하지 않는다.

| 모델이 쓴 것 | 오류 첫 줄 (전후 같음) | 검토 02의 건수 |
|---|---|---|
| `b = 1` (`:=` 없이) | Undeclared variable `b`. | 없는 이름까지 세면 옛 안내 4, 새 안내 4 (새 안내에서 qwen3.8-flash의 가장 큰 패턴). 대입문만 세면 검토 02와 03 합쳐 6 |
| `fs.write(p, s)` (`!void`를 처리하지 않음) | Expected to handle the error case for `!void`. | 5 |
| `r().len()` (`!str`을 풀지 않음) | Can not find the symbol `len` in `!str`. | 2 |
| `s.trim()` (인자 없이) | Expected `2` arguments, found `1`, when calling the function `fn trim(&str, str) -> str`. | 1 |
| `f.rfind('/')` | Can not find the symbol `rfind` in `str`. (제안 없음) | 1 |
| `'ab'.length` (필드로) | Field `length` does not exist in `str`. (메서드 호출 `length()`만 제안 대상) | 0 |
| `if h() ?else '' == 'server':` | Expected type `str`, got `bool`. | 1 |
| `y := if x == 1: 2 else 3` | Expected `(`. | 1 |
| `t := 1; u := 2` | Expected end of line or file. Got semicolon. | 1 |
| `xs.insert(0, 2)` (돌려준 값을 버림) | Expected assignment to a variable or placeholder for `[]int`. | 1 |

## 5. 안내 문서를 고친 것

검토 02 뒤 커밋되지 않은 부분 갱신(누가 했는지는 기록이 없다. b6c7f713에 맞춘 세 곳)이 있었고, 그 위에 이번 빌드에 맞춰 두 번 고쳤다.

1차 (d 회차에 쓴 것):

- 기준 버전을 `6ed1b6c4와 그 뒤의 변경`으로
- 문자열은 `<`, `<=`, `>`, `>=`로 비교한다("`<` 없음, `a.less(b)`"를 바꿈)
- 인자 없는 `xs.sort()`(오름차순), `sorted(xs)`와 `reverse=True`의 대응
- "정렬" 절: `c := &counts`로 빌린 뒤 정렬. 예제 3을 `names.sort()`로, 예제 4를 struct 목록 대신 Map 키 정렬로
- 원칙에 "새 변수는 처음에 `:=`" (검토 02 새 안내에서 qwen3.8-flash의 가장 큰 남은 패턴)
- 오류 목록에서 `&OpaqueFunc` 줄을 지우고 캡처 줄을 새 문구에 맞춤

1차는 CLI(`cyber 파일`)로만 확인했다. 에이전트 세션은 persist_main이고, 최상위 빌림은 다음 eval로 넘길 수 없어 컴파일 오류다. d 회차에서 이것이 세 번 나왔다(deepseek 2, qwen3.8-flash 1).

2차 (e 회차에 쓴 것):

- "정렬" 절과 예제 4: 정렬에 쓸 Map은 `counts := ^Map[str, int]{}`로 선언한다. 람다가 바로 캡처하고 다음 run에도 남는다. 최상위에서 빌리지 않는다
- 값, 참조 절에 "최상위 빌림은 다음 run으로 이어질 수 없다", 오류 목록에 `Cannot persist local ...` 줄
- 원칙에 "`!T`는 출력하거나 쓰기 전에 `!`: `print(f()!)`"

e 회차 뒤 (숫자에는 없다):

- "`^`는 Map에만, 목록은 `[]T` 그대로, `^[]str`로 쓰지 않는다" (7절의 결함)

확인 방법을 바꿨다. 예제 10개는 CLI로 한 번, 그리고 s1의 `replay`(같은 VM, persist_main)로 한 번 돌린다. 예제 4는 다음 eval에서 `counts`를 다시 쓰는 것까지 확인했다. 두 판의 예제 코드는 같다. 안내는 18.7KB(검토 02 끝 18.1KB)다.

## 6. CodeAct 재실행: 숫자

과제와 채점은 검토 02와 같다. d 회차는 1차 안내, e 회차는 2차 안내다. 둘 다 이번 스냅숏. d 회차의 qwen3.8-max는 안내를 고치는 도중에 돌아 버렸다. e 회차는 다른 실행과 겹치지 않게 한 작업으로 차례로 돌렸다.

| 모델 | cyber, 안내 | 과제 | 통과 | 스텝 평균 | 컴파일 오류 (과제당) | 그중 풀지 않은 `!T` 출력 | 과제당 시간 |
|---|---|---|---|---|---|---|---|
| deepseek-chat | 검토 02 dev, 검토 02 새 안내 | 9 | 8 | 3.9 | 0.2 | (오류로 세지 않음) | 6초 |
| deepseek-chat | 새 dev, 1차 | 9 | 7 | 6.2 | 1.6 | 1 | 10초 |
| deepseek-chat | 새 dev, 2차 | 9 | 8 | 5.3 | 0.4 | 1 | 8초 |
| qwen3.8-flash | 검토 02 dev, 검토 02 새 안내 | 9 | 8 | 8.6 | 1.1 | (오류로 세지 않음) | 45초 |
| qwen3.8-flash | 새 dev, 1차 | 9 | 9 | 6.9 | 2.1 | 7 | 23초 |
| qwen3.8-flash | 새 dev, 2차 | 9 | 8 | 7.6 | 1.7 | 4 | 41초 |
| qwen3.8-max | 검토 02 dev, 옛 안내 | 3 | 3 | 6.3 | 0.3 | | 58초 |
| qwen3.8-max | 새 dev, 2차 | 3 | 3 | 4.0 | 0.3 | 0 | 28초 |

- 실패: deepseek 1차 둘(보고서 끝에 `total: 38` 줄을 더함, 줄 끝 TODO를 놓침), deepseek 2차 하나(파일 이름에서 `.log`를 뺌)는 과제 해석이다. qwen3.8-flash 2차의 하나는 프로세스가 죽은 것이다(7절).
- 풀지 않은 `!T` 출력: 모델이 첫 둘러보기로 `print(proc.exec('ls ...'))`를 쓰는 습관이다. 검토 02의 dev에서는 `!str`이라는 글자를 찍고 성공으로 끝났고 모델은 다음 스텝에 `!`를 붙였다. 지금은 같은 한 스텝이 컴파일 오류로 세어진다. 쓰는 스텝은 같다. 이것을 빼면 2차의 과제당 컴파일 오류는 deepseek 0.3, qwen3.8-flash 1.2로 검토 02의 새 안내 때(0.2, 1.1)와 비슷하다.
- 표본이 작다(과제 셋, 회차 셋). 판정(ADR 0006)이 아니라 방향이다. 스텝과 시간은 회차마다 크게 흔들린다.

### 6.1 쓰는 모양

run 호출 중 그 구문이 들어 있는 것의 비율:

| 구문 | deepseek 검토 02 새 안내 | deepseek 2차 | qwen3.8-flash 검토 02 새 안내 | qwen3.8-flash 2차 |
|---|---|---|---|---|
| `Map[` | 0% | 15% (모두 `^Map`) | 0% | 11% (모두 `^Map`) |
| `sort` | 12% | 18% | 11% | 14% |
| `for` | 54% | 40% | 37% | 29% |
| `if` | 42% | 42% | 49% | 32% |
| 문자열 메서드 | 54% | 35% | 44% | 32% |
| `try:` | 4% | 18% | 25% | 6% |

검토 02의 새 안내는 Map 값 정렬 대신 struct 목록 정렬을 가르쳤고 Map 사용이 0이 됐다. 이번 빌드에서 `^Map` 캡처가 되자 안내를 되돌렸고, 모델은 집계에 다시 Map을 쓴다. 쓰는 모양은 안내의 예제를 거의 그대로 따른다.

### 6.2 남은 실패 패턴 (2차, 16건)

| 패턴 | 건수 | 예 |
|---|---|---|
| 풀지 않은 `!T` 출력 | 5 | `print(proc.exec('ls -la logs/ ...'))` |
| `for x in xs:` | 2 (deepseek) | `for f in {'app','db','web'}:`. 문구가 고칠 방법을 말하고 다음 스텝에 고쳤다 |
| `:=` 없는 대입, 없는 이름 | 2 | `report = lines.join('\n') + '\n'` |
| `?int`에 `!` | 1 | `eq := stripped.index('=')!` |
| 식 안의 if | 1 | `lvl := if parts.len() > 1 parts[1] else '<short>'` |
| 대괄호 목록 | 1 | `xs := ['a', 'b', 'c', 'd']` |
| 헛것 | 2 | `if h ?none:`, `for project/src/a.py project/src/b.py ... \|f\|:` |
| 죽은 실행 안에서 (집계 밖) | 2 | |

없는 메서드, camelCase, 캡처, `else if`는 2차에서 0건이다.

## 7. 새 결함: `^[]str`에 대한 `+=`

qwen3.8-flash 2차 T2에서 s2가 죽었다(종료 코드 134, stderr 첫 줄 `Segmentation fault at address 0xc4`, `_cl_mod_bind_core`, `_execBytecode`). 그 스텝의 스크립트는 검증을 통과했고, `proc.exec` 승인 뒤 실행 중에 죽었다. 모델이 쓴 것:

~~~cy
out := ^[]str{}
...
for paths |p|:
    ...
    if c > 0:
        parts := p.split('/')
        out += '%{parts.last()} %{c}'
out.sort()
fs.write('todo.txt', out.join('\n') + '\n')!
~~~

줄여서 CLI로 재현했다. 0.4.9 build-833과 이번 스냅숏이 같다.

| 스크립트 | 결과 |
|---|---|
| `out := ^[]str{}`, `out += 'x'`, `out += 'y'` | Segmentation fault at address 0xc4 |
| `out := ^[]str{}`, `out += 'x'`, `print(out.len())` | `0` (붙지 않음, 오류 없음) |
| `out := ^[]str{}`, `out += '%{s} 1'`, `print(out.len())` | `4225619005488` 같은 쓰레기 값 |
| `^[]int`에 `+= 1` | 맞다 |
| `^[]str`에 `out.* += 'x'` | 맞다 |

새 회귀가 아니다. 모델이 안내의 `^Map` 권장을 목록에까지 넓혀 쓰면서 처음 드러났다. 에이전트 입장에서는 모델의 스크립트 한 줄이 호스트 프로세스를 죽이는 길이라 가장 무겁다. TODO의 "프로세스를 죽이는 경로 수정"에 해당하고, 스파이크 결함은 고치고 진행한다는 규칙에 든다. 요청서 docs/requests/cyber-m0-spike-review-03.md 1절에 재현과 함께 적었다. 그때까지 안내는 목록에 `^`를 붙이지 말라고 적는다(5절의 마지막 줄).

이 일로 본체에 대한 뜻도 하나 더 생긴다: 스크립트 실행이 호스트를 죽일 수 있는 한, 본체가 VM을 별도 프로세스로 둘지 다시 볼 이유가 된다. 검토 02까지는 검증 쪽 죽음만 있었고 그것이 고쳐졌기 때문에 같은 프로세스 안에서 돌리는 쪽으로 기울었다. 이번 죽음은 실행 쪽이다. 결정은 본체의 runtime 경계 단계에서 사용자가 한다.

## 8. 오류 문구: 다음 요청

요청서 2절에 표로 적었다. 요점: 원인은 맞게 말하지만 고칠 방법을 말하지 않는 문구가 열 개 남았다. 가장 많은 것은 `:=` 없는 대입(검토 02와 03 합쳐 6), `!void` 미처리(5), `!`를 `str`이나 `?int`에 붙인 것(4), `else if`(3)다.

## 9. 본체에 주는 뜻 (추천, 확정은 본체를 만들 때 사용자가)

검토 02 9절에 더하는 것만 적는다.

1. 안내 문서의 예제와 조언은 에이전트와 같은 조건(세션 VM, persist_main, 검증 뒤 실행)에서 확인한다. 본체에 안내 검사 도구를 둔다면 CLI가 아니라 runtime 경계 위에서 돈다.
2. 스크립트 실행이 호스트를 죽이는 길이 아직 있다(7절). runtime 경계를 같은 프로세스로 둘지, 실행만 별도 프로세스로 둘지 정할 때 이 기록을 쓴다.
3. 모델은 안내의 예제를 거의 그대로 따른다(6.1). 안내에 넣는 예제 하나가 쓰는 모양 전체를 바꾼다. 예제를 고를 때 "모델이 그대로 넓혀 써도 안전한가"를 함께 본다(`^Map` 권장이 `^[]str`로 넓혀진 것처럼).

## 10. 다시 돌리는 법

검토 02 10절과 같다. 다른 것: 이번 스냅숏 폴더는 `cyber-dev2`, 스파이크 사본은 `s1b`, `s2b`. 회차는 한 작업 안에서 차례로 돌린다(같은 작업 폴더 `/tmp/tars-agent-s2`를 쓰므로 겹치면 결과가 섞인다). 안내 문서는 실행 중에 고치지 않는다.
