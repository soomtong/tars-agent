# cyber에 보내는 요청: M0 스파이크 검토 03에서 나온 것 (2026-11-14)

tars-agent의 M0 스파이크를 cyber master `6ed1b6c4`와 그때의 작업 트리로 다시 돌렸다. 검토 02의 요청 후보는 대부분 반영된 것을 확인했다(tars-agent `docs/spikes/2026-11-14-m0-spikes-review-03.md` 4.1절). 이 요청서는 그 실행에서 새로 나온 것이다. 1은 호스트 프로세스를 죽이는 결함이고, 2는 오류 문구다.

## 1. `^[]str`에 `+=`하면 메모리가 깨진다 (결함, 먼저)

에이전트 실행에서 모델이 쓴 스크립트(`out := ^[]str{}` 뒤에 반복문 안에서 `out += '%{name} %{c}'`)가 tars-agent 호스트를 Segmentation fault로 죽였다. 세션 VM에서 검증은 통과했고 실행 중에 죽었다. 첫 줄은 `Segmentation fault at address 0xc4`이고, 그 아래 `_cl_mod_bind_core`, `_execBytecode`가 이어진다.

최소 재현 (CLI, master 6ed1b6c4 작업 트리와 0.4.9 build-833에서 같다):

~~~cy
out := ^[]str{}
out += 'x'
out += 'y'
print('done')
~~~

결과: `Segmentation fault at address 0xc4`.

~~~cy
out := ^[]str{}
out += 'x'
print(out.len())
~~~

결과: `0`. 오류 없이 붙지 않는다.

~~~cy
out := ^[]str{}
s := 'a'
out += '%{s} 1'
print(out.len())
~~~

결과: `4225619005488`처럼 실행마다 다른 큰 수. 메모리가 깨진다.

대조:

| 스크립트 | 결과 |
|---|---|
| `out := ^[]int{}` 뒤 `out += 1`, `print(out.len())` | `1` (맞다) |
| `out := ^[]str{}` 뒤 `out.* += 'x'`, `print(out.len())` | `1` (맞다) |
| `out := []str{}` 뒤 `out += 'x'` 두 번 | 맞다 |
| `out := ^[]str{}` 뒤 `out = out.append('x')` | 컴파일 오류 ``Expected type `^[]str`, got `[]str`.`` |

`^[]T`에 대한 `+=`가 요소가 관리되는 타입(`str`)일 때 잘못된 자리에 쓰는 것으로 보인다. 원인은 cyber 쪽에서 판단해 주기를 바란다. 기대하는 것은 둘 중 하나다: `out.* += x`와 같은 뜻으로 동작하거나, 컴파일 오류로 막는다.

tars-agent는 이것이 고쳐진 릴리스를 기다린다(스파이크의 결함은 고치고 진행한다는 규칙). 그때까지 안내 문서는 "목록에는 `^`를 붙이지 않는다"고 적어 둔다.

## 2. 오류 문구 (원인은 맞지만 고칠 방법을 말하지 않는 것)

모델이 실제로 틀린 코드다. 괄호 안은 검토 02와 03의 실행에서 나온 횟수다. 검토 02의 요청처럼, 문구 끝에 고칠 방법을 한 문장으로 붙여 주기를 바란다.

| 모델이 쓴 것 | 지금 문구 | 바라는 덧붙임 (예) |
|---|---|---|
| `report = lines.join('\n')` (`:=` 없이 처음 대입) (6) | Undeclared variable `report`. | Declare it with `report := ...`. (대입문의 왼쪽일 때만) |
| `if a: x() else if b: y()` (`else if`) (3) | Expected `(`. | Write `else b:`, not `else if b:`. |
| `lvl := if c parts[1] else ''`, `y := if x == 1: 2 else 3` (2) | Expected `(`. | An if expression is written `if (c) a else b`. |
| `fs.write(p, s)` (`!void`를 처리하지 않음) (5) | Expected to handle the error case for `!void`. | Add `!` (inside `try:`) or `!else`. |
| `r().len()`, `r().ok` (`!str`을 풀지 않음) (2) | Can not find the symbol `len` in `!str`. | Unwrap it with `!` first. (`Can not print` 문구와 같은 꼴) |
| `print(build()!)`에서 `build()`가 `str`, `s.index('=')!` (`?int`에 `!`) (4) | Expected type instance of `Result`, found `str`. | `!` unwraps a `!T`. This value is `str`. (`?int`이면 `?else`나 `.?`를 말해 준다) |
| `s.trim()` (1) | Expected `2` arguments, found `1`, when calling the function `fn trim(&str, str) -> str`. | `trim` takes the characters to cut: `s.trim(' ')`. |
| `f.rfind('/')` (1) | Can not find the symbol `rfind` in `str`. | 제안 표에 `rfind`가 없다. 대응 이름이 없으면 "There is no `rfind`." 정도라도 |
| `'ab'.length` (필드로) (0, 확인만) | Field `length` does not exist in `str`. | 메서드 호출 `length()`는 `len`을 제안한다. 필드 접근에도 같은 제안을 |
| `if h() ?else '' == 'server':`, `if i >= 0 and ... s.index('#') ?else 999` (2) | Expected type `str`, got `bool`. | `?else` binds weaker than `==`: `(h() ?else '') == 'server'`. (어렵다면 문서의 연산자 표에 `?else`와 `!else`를 올리는 것으로 충분하다) |

## 3. 확인된 것 (참고)

- 검토 02의 결함 둘(실패한 컴파일 뒤의 죽음, `!str` 복사)은 이 빌드에서도 우회 없이 통과한다. s1 검사 31개, 재현 다섯, s2 실행 전부.
- `not`의 우선순위, 풀지 않은 `!T`의 출력, `for` 문구, 없는 메서드 제안, `^T`나 `&T`를 캡처한 정렬은 모두 기대대로 동작한다.
- ``Cannot persist local `c` of borrow type `&Map[str, int]` across evals.``는 에이전트 세션에서 처음 만났지만 문구가 충분했다. 모델은 다음 스텝에 고쳤다.
- 지역을 캡처하는 정렬의 설계(`docs/decisions/project_sort_closures.md`)는 tars-agent 쪽에서는 급하지 않다. `^Map`으로 선언하는 길이 세션에서도 되고, 모델이 그 모양을 잘 따른다.
