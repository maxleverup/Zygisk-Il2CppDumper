//
// Modified version to support custom library dumping
//

#ifndef ZYGISK_IL2CPPDUMPER_HACK_H
#define ZYGISK_IL2CPPDUMPER_HACK_H

#include <stddef.h>
#include <string>

void hack_prepare(const char *game_data_dir, void *data, size_t length, const char *target_library);
void SetTargetLibrary(const char *lib);

#endif //ZYGISK_IL2CPPDUMPER_HACK_H
