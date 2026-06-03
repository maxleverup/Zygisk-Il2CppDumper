//
// Modified version to support custom library dumping
//

#ifndef ZYGISK_IL2CPPDUMPER_HACK_H
#define ZYGISK_IL2CPPDUMPER_HACK_H

#include <stddef.h>

void hack_prepare(const char *game_data_dir, void *data, size_t length, const char *target_library);

#endif //ZYGISK_IL2CPPDUMPER_HACK_H
