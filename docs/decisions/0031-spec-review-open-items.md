# 0031 스펙 검토의 열린 것

상태: 확정 (2026-11-20). 전체 스펙 검토가 spec 03, 05, 10, 11, 13에 열린 것과 추천안을 적었고, 사용자가 "모든 추천안에 동의, 나머지는 Claude에게 맡김"으로 받았다. 추천안 밖의 세부는 Claude가 정했다. 상세는 각 문서 본문이다.

## 결정

제공자 (spec 10)

1. 블록은 text, thinking, tool_call, tool_result 넷이다. 불투명 원문 칸은 thinking에만 두고 출처 형식과 원문 바이트를 담는다.
2. 사고는 같은 형식으로 보낼 때 늘 되돌린다(Anthropic은 signature와 함께, OpenAI는 reasoning_content). 다른 형식의 thinking 블록은 요청에 싣지 않는다.
3. 어댑터는 Format enum에 대한 switch로 고른다. vtable과 comptime 매개변수는 쓰지 않는다.
4. 제공자 항목은 내장 기본 넷(ds-anth, ds-oai, or-anth, or-oai)에 settings.json의 providers가 더하거나 같은 name이면 통째로 덮는다. url은 전체 주소다. 기본 항목은 ds-anth다. max_tokens 기본 4096, effort는 기본으로 보내지 않는다. 키는 환경 변수, 없으면 credentials 파일(`KEY_ENV=값` 줄)이다.
5. 끝난 이유는 end_turn, tool_use, max_tokens, refusal, pause_turn, other다. other는 턴을 끝내고 원값을 보인다.
6. 하네스 알림은 다음 user 메시지의 text 블록이고 `<harness-notice>`로 감싼다. 두 형식이 같은 모양이고 세션 파일에는 notice 줄로 쓴다. 시스템 프롬프트가 그 뜻을 알린다.
7. 맞춘 사용량의 입력은 캐시 몫을 포함한 전체다. null인 캐시 필드는 "모름"이다.

권한 (spec 05)

8. read 등급은 작업 디렉터리 안이면 모든 모드에서 allow, 밖이면 ask(bypass는 allow)다. 현재 세션의 곁 디렉터리는 안으로 본다. ui 등급은 모든 모드에서 allow이고 readonly 프로파일에 든다. net은 bypass 말고 모두 ask다.
9. 게이트 판정 순서는 프로파일, deny 규칙, 모드의 deny, 보호 규칙, ask 규칙, allow 규칙, 모드 표, 외부 입력 표시, 헤드리스의 ask→deny다. deny 규칙은 bypass에서도 걸린다.
10. 규칙 문법: fs 규칙은 fs.read, fs.write 둘이고 같은 등급의 fs 능력 모두에 걸린다. `*`는 경로 한 마디, `**`는 0개 이상의 마디다. proc.exec는 `*`가 없으면 정확히 같을 때, 끝의 `*`는 남은 인자 0개 이상, 중간의 `*`는 인자 하나다. proc.sh는 정확한 문자열이나 `*` 하나다. `domain:`은 정확한 호스트이고 하위 도메인은 `domain:*.x`로 쓴다. 리다이렉트는 hop마다 판정한다.
11. 승인 선택지 2의 패턴은 능력마다 뽑고 프롬프트에 보인다. 3은 같은 규칙을 settings.local.json에 더한다. 둘은 그 규칙이 실제로 allow를 낼 때만 보인다. 2의 규칙은 재개 뒤에 남지 않는다.
12. 샌드박스는 bypass일 때만 네트워크를 연다. 샌드박스 밖 실행은 proc 능력의 sandbox = false로 요청하고 bypass가 아니면 늘 ask다. Landlock 신호 범위 제한(ABI 6)으로 샌드박스 밖 프로세스에 신호를 막는다.
13. 외부 입력 표시는 네트워크가 열린 proc 실행에도 서고, 재개와 컴팩션 뒤에도 이어진다.
14. 헤드리스는 프로파일이 정해지지 않으면 readonly다. ask를 deny로 바꾼 호출이 나오면 그 스크립트 뒤 턴을 끝내고 종료 코드 3이다.

설정과 명령행 (spec 11, 06)

15. 설정 키로 여는 한도는 limits.max_steps, step_wall_seconds, session_tokens, max_budget_usd이고 시작 모드는 permissions.default_mode다(bypass는 받지 않는다). 나머지 상한은 상수다.
16. 명령행이 모든 설정 층보다 앞선다. --allow는 합친 allow 목록에 더한다. --output-format 기본 text, --help, --version, --provider, --tool-mode codeact|direct를 둔다.
17. <프로젝트>는 작업 디렉터리에서 저장소 루트까지 올라가며 처음 만나는 .tars-agent/다. credentials와 AGENTS.md도 XDG_CONFIG_HOME을 따른다. 세션 임시 디렉터리는 `$TMPDIR/tars-agent-<세션 ID>`(0700, 끝나면 지운다)다. 프로젝트 설정 수락은 `$XDG_STATE_HOME/tars-agent/trust.json`에 해시로 기억한다. 수락 대상에 providers와 default_mode를 넣는다.
18. 해석할 수 없는 설정은 시작을 거부한다. 모르는 키는 경고 한 줄이다. 시작 전의 실패는 종료 코드 1이다.
19. 헤드리스 json에 provider, ms, tool_mode를 더한다. outcome capability_error는 처리하지 않은 능력 오류가 main 밖으로 나간 run이다. 처리한 오류는 ok이고 caps에 error가 남는다.
20. 대화형 입력의 ! 접두는 사용자 권한의 셸 실행이고 게이트를 지나지 않는다. 출력은 결과 상한을 따라 user 메시지에 들어간다.

능력 (spec 03, 04)

21. 생략할 인자가 하나면 인자 수가 다른 래퍼 둘, 둘 이상이면 필수 인자만 받는 꼴과 옵션 구조체를 받는 꼴이다. 래퍼는 호스트 로더가 돌려주는 모듈 소스에 있다.
22. 구조체와 목록을 담는 Future는 runtime 단계의 첫 검사로 확인하고, 안 되면 cyber에 요청한다. 문자열로 우회하지 않는다.
23. ui.ask는 승인과 같은 CL_AWAIT 경로다 (ADR 0011).

평가 (spec 13)

24. 평가는 본체 헤드리스 위에서, 바깥 OS 샌드박스 안의 bypass로 돈다. 단계는 M2 뒤의 E다.
25. 판정 모델은 DeepSeek이고 OpenRouter Qwen 둘을 같은 표에 기록한다. 모델 ID는 평가를 시작하는 날 날짜가 붙은 것으로 고정한다 (ADR 0006).
26. 첫 시도 validate 통과율의 분모는 직전 run이 compile_error가 아닌 run이다.
27. 과제는 디렉터리 하나에 prompt, fixture, check를 두고 파이썬 표준 라이브러리만 쓴다.

## 근거

- 각 항목의 선택지와 추천 근거는 검토 때 해당 문서의 열린 것 절에 있었다. 이제 근거는 본문의 설명이 맡는다.
- 8: ADR 0017 추천 6을 받았다. 작업 디렉터리 밖 읽기는 유출의 앞 단계다.
- 19: 처리한 오류까지 capability_error로 세면 평가의 실패 유형이 부풀려진다.
- 20: 사용자가 친 명령은 신뢰 경계 안이다 (05 위협 모델).

## 정하지 않은 것

- 코어-프런트엔드 이벤트 타입과 능력 표의 모양. 사용자가 편집한다 (ADR 0012). 요구는 spec 12의 체크리스트에 있다.
- 안내의 4,000토큰 목표 (HANDOFF의 사용자 결정 목록).
