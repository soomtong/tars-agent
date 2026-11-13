#!/bin/sh
# 스파이크 2a: 같은 질문과 같은 도구 하나를 두 전송 형식으로 보내고 원문 응답을 저장한다. 버리는 코드다.
# 사용: ./run.sh  (DEEPSEEK_API_KEY, OPENROUTER_API_KEY 필요)
set -u
cd "$(dirname "$0")"
SYS='You are a coding agent. Use the sh tool to act. Be brief.'
Q='How many lines does /etc/hosts have? Use the tool.'

anth() { # $1=name $2=url $3=auth header $4=model $5=extra json
  cat > out/$1.req.json <<J
{"model":"$4","max_tokens":1024,"stream":true,$5
 "system":"$SYS",
 "tools":[{"name":"sh","description":"Run a shell command and return its output","input_schema":{"type":"object","properties":{"cmd":{"type":"string"}},"required":["cmd"]}}],
 "messages":[{"role":"user","content":"$Q"}]}
J
  curl -sS -m 120 "$2" -H "$3" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" -d @out/$1.req.json > out/$1.sse
}
oai() { # $1=name $2=url $3=auth header $4=model $5=extra json
  cat > out/$1.req.json <<J
{"model":"$4","max_tokens":1024,"stream":true,"stream_options":{"include_usage":true},$5
 "tools":[{"type":"function","function":{"name":"sh","description":"Run a shell command and return its output","parameters":{"type":"object","properties":{"cmd":{"type":"string"}},"required":["cmd"]}}}],
 "messages":[{"role":"system","content":"$SYS"},{"role":"user","content":"$Q"}]}
J
  curl -sS -m 120 "$2" -H "$3" -H "content-type: application/json" -d @out/$1.req.json > out/$1.sse
}

anth ds-anth        https://api.deepseek.com/anthropic/v1/messages "x-api-key: $DEEPSEEK_API_KEY" deepseek-chat ''
oai  ds-oai         https://api.deepseek.com/chat/completions "Authorization: Bearer $DEEPSEEK_API_KEY" deepseek-chat ''
anth ds-anth-think  https://api.deepseek.com/anthropic/v1/messages "x-api-key: $DEEPSEEK_API_KEY" deepseek-reasoner '"thinking":{"type":"enabled","budget_tokens":1024},'
oai  ds-oai-think   https://api.deepseek.com/chat/completions "Authorization: Bearer $DEEPSEEK_API_KEY" deepseek-reasoner ''
anth or-anth-qwen   https://openrouter.ai/api/v1/messages "Authorization: Bearer $OPENROUTER_API_KEY" qwen/qwen3.8-flash ''
oai  or-oai-qwen    https://openrouter.ai/api/v1/chat/completions "Authorization: Bearer $OPENROUTER_API_KEY" qwen/qwen3.8-flash ''
wc -c out/*.sse
