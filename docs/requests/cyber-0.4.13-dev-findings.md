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
