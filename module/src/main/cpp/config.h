//
// Configuration file for custom library dumping
//

#ifndef ZYGISK_IL2CPPDUMPER_CONFIG_H
#define ZYGISK_IL2CPPDUMPER_CONFIG_H

#include <string>
#include <fstream>
#include <sstream>
#include <cstring>
#include "log.h"

struct Config {
    std::string packageName;
    std::string targetLibrary;
};

// Read config from /data/local/tmp/il2cpp_dumper_config.txt
// Format:
// PACKAGE_NAME=com.goo.lagme
// TARGET_LIBRARY=libMod.so
static Config ReadConfig() {
    Config config;
    // Default values
    config.packageName = "com.game.packagename";
    config.targetLibrary = "libil2cpp.so";
    
    const char *config_path = "/data/local/tmp/il2cpp_dumper_config.txt";
    std::ifstream config_file(config_path);
    
    if (!config_file.is_open()) {
        LOGI("Config file not found at %s, using defaults", config_path);
        return config;
    }
    
    std::string line;
    while (std::getline(config_file, line)) {
        // Skip empty lines and comments
        if (line.empty() || line[0] == '#') {
            continue;
        }
        
        size_t pos = line.find('=');
        if (pos == std::string::npos) {
            continue;
        }
        
        std::string key = line.substr(0, pos);
        std::string value = line.substr(pos + 1);
        
        // Remove whitespace
        key.erase(key.find_last_not_of(" \t") + 1);
        value.erase(0, value.find_first_not_of(" \t"));
        value.erase(value.find_last_not_of(" \t") + 1);
        
        if (key == "PACKAGE_NAME") {
            config.packageName = value;
            LOGI("Loaded package name: %s", config.packageName.c_str());
        } else if (key == "TARGET_LIBRARY") {
            config.targetLibrary = value;
            LOGI("Loaded target library: %s", config.targetLibrary.c_str());
        }
    }
    
    config_file.close();
    return config;
}

#endif //ZYGISK_IL2CPPDUMPER_CONFIG_H
