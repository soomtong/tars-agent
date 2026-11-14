# cyber 요청: M0 스파이크에서 남은 것

보내는 곳: soomtong/cyber. 기준: 로컬 master 6a155275 (`Cyber 0.4.10-DEV build-0-6a155275`). 확인일 2026-11-14.

tars-agent는 libcyber를 정적 링크해 모델이 쓴 Cyber 스크립트를 세션 VM(persist_main, deny_raw_ptrs, deny_spawn, 검증 뒤 실행)에서 돌린다. 이 커밋으로 스파이크를 다시 돌렸고 남은 것은 아래 하나다. 이것이 tars-agent 본체 첫 단계의 선행 조건이다.

재현에 쓴 것: tars-agent의 spike/s1(`zig build && ./zig-out/bin/s1`. `s1 replay <파일>`은 `=====` 줄로 나눈 스크립트를 한 세션에서 검증 뒤 실행한다)과 이 커밋의 CLI(`zig build cli -Doptimize=ReleaseFast -Dcommit=6a155275`).

## 1. 커밋을 원격에 올린다

6a155275와 그 앞의 커밋들(118f0c62, 5de6c83a, bf5967db 등)이 soomtong/cyber 원격에 없다. tars-agent 스파이크는 지금 로컬 경로 의존(`.path = "../../../cyberscript"`)으로 받는다. 본체와 docs/deps.md는 URL과 해시로 고정한다.

요청: push한다. 릴리스(0.4.11 등)나 태그가 정해지면 tars-agent는 그것으로 고정한다.

## 확인을 마친 것

이 커밋에서 다음이 통과했다.

- s1 검사 40개 모두 통과. 새 검사 6m: 매개변수를 반환 슬롯보다 먼저 읽는 호스트 함수가 직접 호출, 함수 포인터 값, 함수 union 값, sort가 부르는 경로에서 모두 맞는 값이다. 버전 문자열의 커밋과 `#include "cyber.h"`의 구조체 크기(검사 0)도 통과했다.
- 오류 문구: 아래가 CLI와 세션(검증) 양쪽에서 회신에 적힌 그대로 나온다. `s.len`의 `len()` 제안, `{'a', 1}`과 `{1, true}`의 설명, 보간 안의 보간, `elif`(변수 이름 `elif`는 그대로 쓸 수 있다), 최상위와 반복 안의 `!else` 블록 끝, 최상위 `?else` 블록 끝, `trimStart`/`trim_end`/`lstrip`의 제안, `and`로 묶은 옵션 풀기, 보간 안의 백슬래시.
- 인자 없는 `trimLeft()`와 `trimRight()`는 공백, 탭, 줄바꿈을 자른다.
- `var b byte = 1` 뒤 `{b, 2}`, `{true, false}`, `{1.5, 2.5}`는 전처럼 된다.
- cyber.h의 `cl_vm_validate` 설명에 마지막 eval의 설정으로 검사한다는 것이 있다.
- 안내 문서의 코드 블록 11개와 오류 목록의 첫 줄 21개가 이 커밋의 CLI와 세션에서 맞다.
- macOS arm64(libcyber.a 2.53 MB, 공개 `cl_` 함수 135개)와 x86_64-linux-gnu 교차 빌드.
