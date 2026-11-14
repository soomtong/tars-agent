// cyber 아티팩트의 include 경로로 cyber.h를 받는지 확인한다. 크기를 translate-c 쪽과 비교한다.
#include "cyber.h"

size_t inc_eval_config_size(void) { return sizeof(CLEvalConfig); }
size_t inc_compile_config_size(void) { return sizeof(CLCompileConfig); }
