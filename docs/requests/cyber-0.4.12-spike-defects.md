# cyber 요청: 0.4.12 스파이크의 결함 둘과 `cyber doc` 검토 둘

보내는 곳: soomtong/cyber. 기준: 릴리스 0.4.12 (`Cyber 0.4.12 build-919-67a2735`), (c)와 (d)는 0.4.13에 들어갈 `cyber doc`이 있는 HEAD `fa72869e`. 확인일 2026-11-16.

tars-agent는 libcyber를 정적 링크해 모델이 쓴 Cyber 스크립트를 세션 VM(persist_main, deny_raw_ptrs, deny_spawn, 검증 뒤 실행)에서 돌린다. 0.4.12로 스파이크를 다시 돌리다 결함 둘을 찾았다. 둘 다 tars-agent 본체 첫 단계의 선행 조건이다 (tars-agent ADR 0019). (a)가 무겁다. (a)와 (b)는 HEAD `fa72869e`에서도 그대로 재현된다.

그 뒤 0.4.13에 들어갈 `cyber doc`을 HEAD에서 빌드해 검토했다. agents.md의 코드 블록 12개가 CLI에서 통과하고, `use test`를 쓰는 블록 하나를 뺀 11개가 tars-agent 세션에서도 통과한다. 새 주장(`os.write_file`의 `!void` 처리, `os.args()`, `fn (&&P)`, 람다가 잡는 `&T` 빌림, `cyber fmt --check`)도 탐침에서 맞았다. 검토에서 나온 것이 (c)와 (d)다.

재현: 설치된 0.4.12 CLI(`cyber <파일>`)와 tars-agent의 `spike/s1`(`s1 replay <파일>`, 세션에서 실행). 표의 결과는 CLI다.

## (a) 크기를 바꾸는 `[]T` 메서드 뒤의 옛 목록이 해제된 원소를 본다

모델이 쓴 스크립트 하나가 CodeAct 회차에서 호스트 프로세스(s2)를 죽였다. 컴파일을 통과하는 보통의 코드다.

~~~cy
while out.len() > 0 and out.last().trim() == '':
    _ = out.remove(out.len() - 1)
~~~

`out`은 `fs.read(...)!.split('\n')`에서 채운 `[]str`이다. 모델은 Python의 `pop`처럼 `out`이 준다고 여겼다. 결과를 버렸으니 루프는 끝나지 않아야 하고, 그러면 tars-agent의 연료와 벽시계 상한이 멈춘다. 실제로는 0.1초 안에 세그폴트로 프로세스가 끝났다.

최소 재현:

| 코드 | 0.4.12 결과 |
|---|---|
| `out := []int{1, 2}` 뒤 `_ = out.remove(1)`, `print('%{out.len()} %{out[1]}')` | `2 2` (정수는 드러나지 않는다) |
| `out := []str{'a'.concat(''), 'b'.concat('')}` 뒤 `r := out.remove(1)`, `print(out[1])` | `b`가 아니라 다른 값(`2`) |
| 같은 목록, `_ = out.remove(1)`, `print(out[1])` | 쓰레기 바이트 뒤 rc=134 |
| 같은 목록, `_ = out.remove(1)` 두 번 | ``panic: index out of bounds: index 268435454, len 206`` |
| 같은 목록, `_ = out.clear()`, `print('%{out[0]} %{out[1]}')` | `2 2` (해제된 원소) |
| 같은 목록, `_ = out.insert(0, 'c'.concat(''))`, `print('%{out[0]} %{out[1]}')` | `c a` (옛 목록에 끼워 넣기가 보이고 `b`가 사라진다) |
| `ys := out` 뒤 `ys = ys.remove(1)`, `print(out[1])` | `b` (버퍼를 함께 쓰면 복사되어 맞다) |

Debug로 빌드한 libcyber에서는 `vm.c:925`(`COPY_STR`)의 `retain`이 `retain dangling ptr`로 멈춘다. ReleaseFast에서는 세그폴트나 버스 오류다. 0.4.11(097b831f)에서도 같다. 회귀가 아니다.

까닭으로 보이는 곳: `fn (&Slice[]) remove(idx int) -> Self`(src/builtins/core.cy)는 `clone_on_resize(0)`이 버퍼를 복사하지 않으면(다른 참조가 없으면) 같은 버퍼에서 원소를 `@destruct`하고 당긴 뒤 그것을 돌려준다. 받는 변수는 옛 길이로 같은 버퍼를 본다. `clear`, `insert`도 같은 꼴로 보인다.

요청: 스크립트 코드가 VM을 죽이지 않게 한다. 방법은 cyber가 정한다. 예를 들면 받는 변수를 함께 고치거나(`&&Slice`), 결과를 쓰지 않은 호출을 컴파일 오류로 하거나(``The result of `remove` is the new list. Write `out = out.remove(i)`.``), 옛 변수를 move된 것으로 다룬다. 모델에게는 컴파일 오류가 가장 낫다. `_ = out.remove(i)`는 고치는 법을 말하는 문구로 막히고, 고친 코드 `out = out.remove(i)`는 끝나는 루프가 된다.

## (b) 타입 선언 문구가 `let x = 1`에 틀린 고치는 법을 말한다

0.4.11 회차의 문구 여섯은 0.4.12의 CLI와 세션에서 요청한 꼴로 나온다. 그중 (b), (c)의 타입 선언 문구가 `단어 단어 = 값` 꼴을 모두 "이름 타입 = 값"으로 읽어, 다른 언어의 선언 키워드에 틀린 고치는 법을 말한다. 0.4.11에서는 ``Expected end of line or file. Got ident.``였고 tars-agent의 안내가 이것을 "`let`은 Cyber 문법이 아니다"로 설명했다. 지금은 문구가 고치는 법을 말하므로 모델이 그대로 따를 수 있다. 그때까지 tars-agent의 안내가 오류 목록의 한 줄로 우회한다.

| 입력 | 0.4.12 첫 줄 |
|---|---|
| `let x = 1` | ``ParseError: To declare a typed variable, write `var let x = 1` or `let := x(1)`.`` |
| `let x: int = 1` | ``ParseError: To declare a typed variable, write `var let x: int = 1` or `let := x: int(1)`.`` |
| `mut x = 1` | ``ParseError: To declare a typed variable, write `var mut x = 1` or `mut := x(1)`.`` |
| `val x = 1`, `auto x = 1` | 같은 꼴 |
| 함수 안의 `let x = 1` | 같은 꼴 |

문구를 따라 쓴 `var let x = 1`은 ``CompileError: Could not find the symbol `x`.``다.

요청: 첫 단어가 `let`, `mut`, `val`, `auto`처럼 다른 언어의 선언 키워드이면 ``Cyber has no `let`. Declare with `x := 1`, or `var x int = 1` for a type.``처럼 말한다. `let x: int = 1`은 같은 문구에 `var x int = 1`을 보이면 된다. 그 밖의 `이름 타입 = 값`(`x int = 1`, `name str = 'a'`)은 지금 문구가 맞다.

## (c) agents.md가 `os.write_file`만 보여 `os.read_file`로 텍스트를 읽게 둔다

agents.md는 `os` 모듈을 한 줄로 소개하고(148행) 함수로는 `os.write_file`만 보인다(166행). 모델은 짝으로 `os.read_file`을 짐작한다. 이것은 `![]byte`를 돌려주므로(src/std/os.cy:460) 텍스트로 쓰면 컴파일 오류 없이 틀린 값이 나온다.

| 코드 (`hi`가 든 파일) | HEAD 결과 |
|---|---|
| `print(os.read_file(p)!)` | `{0x68, 0x69}` |
| `print(os.read_file_str(p)!)` | `hi` |

텍스트를 읽는 함수는 `os.read_file_str`(os.cy:464)이다. 모듈 API는 `cyber doc`에 들어 있지 않아 에이전트가 오프라인에서 이 이름을 찾을 길이 없다.

요청: agents.md의 Modules 절에 한 줄을 더한다. 예: ``Read text with `os.read_file_str(p)!`. `os.read_file` returns `[]byte`.`` 모듈 API를 `cyber doc`에 넣을지는 cyber가 정한다.

## (d) 패키지의 `.paths`에 `docs`가 없다

build.zig.zon의 `.paths`는 `build.zig`, `build.zig.zon`, `src`, `lib`다. `zig fetch`로 받은 패키지에는 `docs/`가 빠진다. 그래서 의존 쪽에서 두 가지가 안 된다.

- tars-agent가 의존의 `docs/agents.md`를 빌드 때 읽어 시스템 프롬프트의 바탕으로 쓸 수 없다. 지금은 같은 안내를 두 저장소가 손으로 따로 고친다(tars-agent의 prompt/cyber-subset.en.md와 cyber의 docs/agents.md).
- `create_cli_module`이 `docs/docs.md`와 `docs/agents.md`를 anonymous import로 넣으므로(build.zig:664-665) 받은 패키지에서 cli 아티팩트를 빌드하면 파일이 없어 실패할 것으로 보인다. 라이브러리 아티팩트는 문서를 쓰지 않아 tars-agent의 지금 빌드는 문제없다.

요청: `.paths`에 `docs`를 넣는다. 크기가 걱정이면 `docs/agents.md`와 `docs/docs.md`만 넣어도 된다.

## 확인을 마친 것

0.4.12에서 다음이 통과했다.

- tars-agent spike/s1 검사 40개(검사 0이 버전 문자열 `Cyber 0.4.12 build-919-67a2735` 전체를 비교). 의존은 `git+https://github.com/soomtong/cyber?ref=0.4.12#67a2735c2535fafbc4ba8b4815592f2c37b1d5b5`, 해시 `cyber-0.4.12-AW3fkAqEngAhLopP1tr-x8mnWp10OqG14QiB9PLuNEUp`.
- 0.4.11 회차의 문구 여섯((a) `for ... in`, (b) `q: byte = 0`, (c) `in_s str = ''`, (d) 옵션 아닌 값과 `none`, (e) 옵션 아닌 값의 `?else`, (f) `str`과 `int`의 비교)이 CLI와 세션에서 요청한 꼴로 나온다.
- 안내 문서의 코드 블록 11개가 CLI와 세션에서 통과한다. 오류 목록의 나머지 첫 줄은 0.4.11과 같다.
- 세션의 기본 로더가 `json`, `toon`, `regex`, `peg`, `time`을 싣는다. tars-agent 스파이크는 안내가 이 모듈을 가르치지 않아 호스트 로더에서 막는다.
- macOS arm64(libcyber.a 3.01 MB, 공개 `cl_` 함수 140개)와 x86_64-linux-gnu 교차 빌드(libcyber.a 3.54 MB).

## cyber 회신 (2026-11-16, master, push 전)

네 건 모두 고쳤다. 커밋은 `85c95b1d`(c), `526146a9`(d), `4cf57841`(b), `40ae5b5a`(a)이고, 각각 13단계 검증 rc=0이다. 다음 릴리스에 들어간다. 바뀐 점은 cyber `docs/releases/unreleased.md`에 있다.

알릴 것: agents.md는 0.4.12 뒤 `5c894d06`에서 `docs/agent-guide.md`로 이름이 바뀌었다. 대소문자를 무시하는 파일 시스템에서 `AGENTS.md`로 읽히기 때문이다. 아래 경로는 새 이름이다.

### (a) 받는 변수는 그대로, 버린 결과는 컴파일 오류

- 런타임: 길이를 바꾸는 `Slice` 메서드가 받는 변수를 바꾸지 않는다. `r := out.remove(1)` 뒤에도 `out`은 `a b`이고 길이 2다.
  - `size_down`, `clear`, 끝 원소의 `remove`는 같은 버퍼에서 길이만 줄이고 원소를 해제하지 않는다.
  - 끝이 아닌 `remove`와 `insert`는 새 버퍼에 복사한다.
  - 요청서 표의 일곱 행이 모두 맞는 값을 낸다(테스트 `core/Slice_resize_receiver.cy`).
- 컴파일 오류: `_ = out.remove(i)`, 그리고 결과를 쓰지 않은 `out.clear()`는 다음 오류를 낸다.
  ``The result of `remove` is the new list, and `out` keeps the old one. Write `out = out.remove(out.len() - 1)`.``
  대상은 `append`, `insert`, `remove`, `clear`, `size_down`, `size_up`의 결과가 `Slice`일 때다. 문구의 호출은 원문을 그대로 쓴다.
- 비용: `out = out.remove(0)` 반복은 이제 매번 할당한다. 둘 다 원래 O(n)이다.

### (b) 다른 언어의 선언 키워드

| 입력 | 첫 줄 |
|---|---|
| `let x = 1` | ``ParseError: Cyber has no `let`. Declare with `x := 1`, or `var x int = 1` for a type.`` |
| `let x: int = 1`, `let x int = 1` | ``ParseError: Cyber has no `let`. Declare with `var x int = 1`.`` |
| `val name = 'a'` | ``... Declare with `name := 'a'`, or `var name str = 'a'` for a type.`` |
| `let mut x = 1`, `mut x = 1`, `auto x = 1.5` | 같은 꼴 (`auto`는 `float`) |
| `let x`, `auto x: float` | ``... Declare with `x := value`, ...`` / ``... `var x float = value`.`` |

예의 타입은 값이 리터럴이면 그 타입이고, 아니면 `T`다. `const`는 Cyber의 상수 선언이라 대상에서 뺐다. `x int = 1`처럼 키워드가 없는 꼴은 지금 문구 그대로다. 안내 문서의 오류 목록에서 이 줄을 지웠다.

### (c) 한 줄 추가가 아니라 API 정리로 고쳤다 (깨지는 변경)

| 함수 | 반환 / 인자 |
|---|---|
| `os.read_file(p)` | `!str`. UTF-8이 아니면 `error.Unicode` |
| `os.read_file_bytes(p)` | `![]byte` |
| `os.write_file(p, s)` | `str`만 받는다 |
| `os.write_file_bytes(p, b)` | `[]byte` |

- 모델이 짐작하는 `read_file`이 텍스트를 돌려준다.
- `os.read_file_str`은 없어졌다. 쓰면 ``Can not find the symbol `read_file_str` in `os`.``다.
- `write_file(p, bytes)`는 ``Expected argument `str`, found `[]byte` ...``다.
- tars-agent 프롬프트와 스크립트에 `read_file_str`이나 `str(os.read_file(..)!)`이 있으면 바꿔야 한다.
- 안내 문서 Modules 절에 네 함수를 한 줄로 적었다.
- 모듈 API를 `cyber doc`에 넣는 일은 하지 않았다. 결정 대기다.

### (d) `.paths`

`docs/docs.md`와 `docs/agent-guide.md` 두 파일만 넣었다. `.paths`에 든 파일만 복사한 디렉터리에서 cli와 lib 빌드, `cyber doc --for-agents`를 확인했다. 패키지 해시가 바뀌므로 다음 고정 때 해시를 갱신해야 한다.

## tars-agent 확인 (2026-11-16, cyber master `54e61f48`, push 전)

`git archive 54e61f48`을 스크래치에서 빌드한 CLI와, 그 소스에 경로로 연결한 `spike/s1`(세션)로 확인했다. 네 건 모두 회신대로다.

- s1 검사 40개 통과(버전 문자열의 커밋만 `54e61f4`로 바꿈).
- (a) 요청서 표의 일곱 행이 CLI와 세션에서 맞는 값을 낸다. 0.4.12 회차에서 s2를 죽인 모델 스크립트(`_ = out.remove(out.len() - 1)`)는 CLI와 세션 모두 컴파일 오류 ``The result of `remove` is the new list, and `out` keeps the old one. Write `out = out.remove(out.len() - 1)`.``이고, 문구대로 고친 스크립트는 맞는 결과로 끝난다. `out.clear()`만 쓴 줄도 같은 꼴의 오류다.
- (b) `let x = 1`, `let x: int = 1`, 함수 안의 `mut y = 2`가 회신의 문구다. `x int = 1`은 지금 문구 그대로다.
- (c) `os.read_file`이 `str`, `os.read_file_bytes`가 `[]byte`, `os.write_file`이 str을 쓴다. `os.read_file_str`은 ``Can not find the symbol `read_file_str` in `os`.``다. tars-agent의 프롬프트와 스파이크 코드는 `os`를 쓰지 않는다(세션 로더가 막는다).
- (d) `zig fetch`로 받은 패키지(`cyber-0.4.12-AW3fkAQQowCQOQU9RDn94mUcFKLXZWnDDlsS83bHvBhq`)에 `docs/agent-guide.md`와 `docs/docs.md`가 들어 있다.
- `docs/agent-guide.md`의 코드 블록 12개가 CLI에서 통과한다. 세션에서는 11개가 통과하고, `use test`를 쓰는 블록은 s1 로더가 `test`를 막아 `Failed to load module: test`다.

남은 일은 tars-agent 쪽이다. cyber가 push하고 릴리스하면 고정을 올리고 이 요청서를 지운다.
