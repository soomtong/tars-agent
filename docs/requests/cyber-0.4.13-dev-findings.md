# cyber 요청: 0.4.13-DEV에서 찾은 것 둘

보내는 곳: soomtong/cyber. 기준: latest dev 프리릴리스 `Cyber 0.4.13-DEV build-941-8a89231` (커밋 8a892310, 태그 0.4.13과 같은 커밋). 확인일 2026-11-16.

tars-agent는 libcyber를 정적 링크해 모델이 쓴 Cyber 스크립트를 세션 VM(persist_main, deny_raw_ptrs, deny_spawn, 검증 뒤 실행)에서 돌린다. 재현은 dev CLI(`cyber <파일>`)와 tars-agent의 `spike/s1`(`s1 replay <파일>`, 세션에서 실행. 파일 안의 `=====` 줄이 run을 나눈다)로 했다.

## (a) `let x := 1`에 틀린 고치는 법

다른 언어의 선언 키워드 뒤에 `:=`가 오면 문구가 `:=`를 값의 일부로 읽는다.

| 입력 | 첫 줄 |
|---|---|
| `let x := 1` | ``ParseError: Cyber has no `let`. Declare with `var x := 1 = value`.`` |
| `let name := 'a'` | ``... Declare with `var name := 'a' = value`.`` |
| `mut x := 1`, `let mut x := 1` | 같은 꼴 |

문구대로 쓴 `var x := 1`은 ``ParseError: Expected variable type.``다. 모델은 `let`을 지우려다 `:=`를 남기는 일이 흔하다.

요청: 키워드 뒤가 `이름 :=`이면 ``Cyber has no `let`. Declare with `x := 1`.``처럼 키워드만 뺀 꼴을 말한다.

## (b) 세션에서 스크립트 마지막 줄의 버린 `Slice` 결과

`_ = out.remove(i)`, 결과를 쓰지 않은 `out.clear()`는 CLI와 세션 모두 ``The result of `remove` is the new list, and `out` keeps the old one. ...`` 컴파일 오류다. 그런데 세션에서 그 호출이 스크립트의 마지막 줄이면 마지막 표현식 값으로 받아들여져 오류가 없다.

~~~cy
out := []int{1, 2}
out.remove(1)
=====
print(out.len())
~~~

| 실행 | 결과 |
|---|---|
| CLI (`=====` 없이 앞 두 줄) | ``CompileError: The result of `remove` is the new list, and `out` keeps the old one. Write `out = out.remove(1)`.`` |
| 세션 run 1 | 검증, eval 모두 SUCCESS, 출력 없음 |
| 세션 run 2 | `2` (out은 그대로) |

모델은 run 1에서 목록이 줄었다고 여긴다. 같은 run 안의 마지막 줄이 아닌 곳에서는 오류가 나므로, 줄의 자리에 따라 같은 코드의 뜻이 다르다.

요청: 마지막 표현식 값의 예외를 `Slice`의 크기를 바꾸는 메서드(`append`, `insert`, `remove`, `clear`, `size_down`, `size_up`)에는 적용하지 않는다. 방법은 cyber가 정한다.

## 확인을 마친 것

- tars-agent spike/s1 검사 40개(검사 0이 `Cyber 0.4.13-DEV build-941-8a89231` 전체를 비교). 의존은 `git+https://github.com/soomtong/cyber#8a892310554bba26061a5613784a20e930971275`, 해시 `cyber-0.4.13-AW3fkAQQowDHsJ54gaXZmRQLy97LTg3pDL1NKWoRadp0`.
- 0.4.12 요청서의 네 건((a) `Slice` 크기 바꾸기 뒤의 받는 변수, (b) `let`·`mut`·`val`·`auto` 문구, (c) `os.read_file`이 str, (d) 패키지의 `docs/agent-guide.md`)이 CLI와 세션에서 회신대로다. 0.4.12 회차에서 s2를 죽인 모델 스크립트는 고치는 법을 말하는 컴파일 오류로 멈춘다.
- tars-agent 안내(prompt/cyber-subset*.md)의 코드 블록 22개(두 판 11개씩)와 오류 목록의 첫 줄.
- `docs/agent-guide.md`의 코드 블록 12개가 CLI에서 통과한다. 세션에서는 `use test` 블록을 뺀 11개가 통과한다(s1 로더가 `test`를 막는다).

## cyber 회신 (2026-11-16, master `3acc0797`, push 전)

두 건 모두 고쳤다. 태그 `0.4.13`(`8a892310`)에는 들어 있지 않다. 0.4.13 릴리스는 아직 만들지 않았다(macOS arm64 러너 미배정). 릴리스할 때 태그를 다시 찍을지 정한다.

### (a) `let x := 1`

| 입력 | 첫 줄 |
|---|---|
| `let x := 1` | ``ParseError: Cyber has no `let`. Declare with `x := 1`.`` |
| `let name := 'a'` | ``ParseError: Cyber has no `let`. Declare with `name := 'a'`.`` |
| `mut x := 1`, `let mut x := 1` | 같은 꼴 (`mut`는 ``Cyber has no `mut`.``) |
| `let x :=` | ``... Declare with `x := value`.`` |

`=`를 쓴 꼴(`let x = 1`)의 문구는 그대로다.

### (b) 세션의 마지막 줄

세션(`persist_main`)의 마지막 표현식이 크기를 바꾸는 `Slice` 메서드의 결과이면, 마지막 줄이 아닌 자리와 같은 컴파일 오류가 난다. 대상 메서드는 `append`, `insert`, `remove`, `clear`, `size_down`, `size_up`이다. 그 밖의 값(`out.len()`, `out`)은 그대로 eval 결과다. 테스트는 `lib_test/session.zig`의 "a dropped Slice resize result on the last line"이다.

REPL에서 `xs.append(4)`로 결과를 미리 보던 쓰임도 이제 오류다. 같은 값을 보려면 `ys := xs.append(4)` 뒤 `ys`를 쓴다.

## 회신 확인 (2026-11-16, cyber master `fd9aed7e`)

로컬 cyber(`3acc0797`를 담은 master)로 확인했다. CLI는 `zig build cli`의 Debug 빌드, 세션은 s1을 `zig build --fork=<cyber 저장소>`로 빌드해 `s1 replay`로 돌렸다. `build.zig.zon`은 그대로다.

| 경우 | CLI | 세션 |
|---|---|---|
| `let x := 1` | ``Cyber has no `let`. Declare with `x := 1`.`` | 같음 |
| `let name := 'a'`, `mut x := 1`, `let mut x := 1`, `let x :=` | 회신 표와 같음 | 확인 안 함 |
| `let x = 1` | ``... Declare with `x := 1`, or `var x int = 1` for a type.`` (그대로) | 확인 안 함 |
| 위 (b) 예제 | `remove` 컴파일 오류 | run 1이 같은 컴파일 오류(run 2는 `out`이 없어 ``Undeclared variable `out`.``) |
| 마지막 줄 `_ = out.clear()` | | `clear` 컴파일 오류 |
| 마지막 줄 `xs.append(4)` | | `append` 컴파일 오류 |
| 마지막 줄 `out.len()`, `out` | | 검증, eval 모두 SUCCESS |

s1 검사 40개가 이 빌드에서 모두 통과한다. 검사 0의 버전 문자열은 s1 build.zig가 넘기는 인자라 `build-941-8a89231` 그대로다.

두 건은 고쳐졌다. 스파이크가 따르는 `latest` 태그(지금 `8a892310`)에는 아직 없다. `latest`가 이 수정을 담으면 다시 받아 확인하고 닫는다(ADR 0023).
