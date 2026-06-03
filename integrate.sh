#!/bin/bash

# Zygisk Il2CppDumper - Auto Integration Script
# This script automatically integrates the custom modifications

set -e

PROJECT_DIR="${1:-.}"
CPP_DIR="$PROJECT_DIR/module/src/main/cpp"

echo "================================"
echo "Zygisk Il2CppDumper Modifier"
echo "================================"
echo ""

# Check if project directory exists
if [ ! -d "$PROJECT_DIR/module/src/main/cpp" ]; then
    echo "❌ Error: Cannot find Zygisk project at $PROJECT_DIR"
    echo "Usage: ./integrate.sh /path/to/Zygisk-Il2CppDumper-master"
    exit 1
fi

echo "✓ Found project at: $PROJECT_DIR"
echo ""

# Backup original files
echo "📦 Creating backups..."
backup_date=$(date +%Y%m%d_%H%M%S)
backup_dir="$CPP_DIR/backup_$backup_date"

mkdir -p "$backup_dir"

cp "$CPP_DIR/main.cpp" "$backup_dir/main.cpp"
cp "$CPP_DIR/hack.cpp" "$backup_dir/hack.cpp"
cp "$CPP_DIR/hack.h" "$backup_dir/hack.h"

echo "✓ Backups created in: $backup_dir"
echo ""

# Function to add line to file (if not exists)
add_include() {
    local file=$1
    local include=$2
    if ! grep -q "$include" "$file"; then
        sed -i "1i$include" "$file"
        echo "  + Added: $include"
    fi
}

# Update hack.h
echo "📝 Updating hack.h..."
cat > "$CPP_DIR/hack.h" << 'EOF'
//
// Created by Perfare on 2020/7/4.
//
// Modified to support custom library dumping

#ifndef ZYGISK_IL2CPPDUMPER_HACK_H
#define ZYGISK_IL2CPPDUMPER_HACK_H

#include <stddef.h>

void hack_prepare(const char *game_data_dir, void *data, size_t length, const char *target_library);

#endif //ZYGISK_IL2CPPDUMPER_HACK_H
EOF
echo "✓ hack.h updated"
echo ""

# Update hack.cpp
echo "📝 Updating hack.cpp..."
cat > "$CPP_DIR/hack.cpp" << 'EOF'
//
// Created by Perfare on 2020/7/4.
//
// Modified to support custom library dumping

#include "hack.h"
#include "il2cpp_dump.h"
#include "log.h"
#include "xdl.h"
#include <cstring>
#include <cstdio>
#include <unistd.h>
#include <sys/system_properties.h>
#include <dlfcn.h>
#include <jni.h>
#include <thread>
#include <sys/mman.h>
#include <linux/unistd.h>
#include <array>

void hack_start(const char *game_data_dir, const char *target_library) {
    bool load = false;
    LOGI("Attempting to load library: %s", target_library);
    
    for (int i = 0; i < 10; i++) {
        void *handle = xdl_open(target_library, 0);
        if (handle) {
            load = true;
            LOGI("Successfully loaded %s", target_library);
            il2cpp_api_init(handle);
            il2cpp_dump(game_data_dir);
            break;
        } else {
            LOGI("Attempt %d: Failed to load %s, retrying...", i + 1, target_library);
            sleep(1);
        }
    }
    if (!load) {
        LOGE("Failed to load %s in thread %d after 10 attempts", target_library, gettid());
    }
}

std::string GetLibDir(JavaVM *vms) {
    JNIEnv *env = nullptr;
    vms->AttachCurrentThread(&env, nullptr);
    jclass activity_thread_clz = env->FindClass("android/app/ActivityThread");
    if (activity_thread_clz != nullptr) {
        jmethodID currentApplicationId = env->GetStaticMethodID(activity_thread_clz,
                                                                "currentApplication",
                                                                "()Landroid/app/Application;");
        if (currentApplicationId) {
            jobject application = env->CallStaticObjectMethod(activity_thread_clz,
                                                              currentApplicationId);
            jclass application_clazz = env->GetObjectClass(application);
            if (application_clazz) {
                jmethodID get_application_info = env->GetMethodID(application_clazz,
                                                                  "getApplicationInfo",
                                                                  "()Landroid/content/pm/ApplicationInfo;");
                if (get_application_info) {
                    jobject application_info = env->CallObjectMethod(application,
                                                                     get_application_info);
                    jfieldID native_library_dir_id = env->GetFieldID(
                            env->GetObjectClass(application_info), "nativeLibraryDir",
                            "Ljava/lang/String;");
                    if (native_library_dir_id) {
                        auto native_library_dir_jstring = (jstring) env->GetObjectField(
                                application_info, native_library_dir_id);
                        auto path = env->GetStringUTFChars(native_library_dir_jstring, nullptr);
                        LOGI("lib dir %s", path);
                        std::string lib_dir(path);
                        env->ReleaseStringUTFChars(native_library_dir_jstring, path);
                        return lib_dir;
                    } else {
                        LOGE("nativeLibraryDir not found");
                    }
                } else {
                    LOGE("getApplicationInfo not found");
                }
            } else {
                LOGE("application class not found");
            }
        } else {
            LOGE("currentApplication not found");
        }
    } else {
        LOGE("ActivityThread not found");
    }
    return {};
}

static std::string GetNativeBridgeLibrary() {
    auto value = std::array<char, PROP_VALUE_MAX>();
    __system_property_get("ro.dalvik.vm.native.bridge", value.data());
    return {value.data()};
}

struct NativeBridgeCallbacks {
    uint32_t version;
    void *initialize;
    void *(*loadLibrary)(const char *libpath, int flag);
    void *(*getTrampoline)(void *handle, const char *name, const char *shorty, uint32_t len);
    void *isSupported;
    void *getAppEnv;
    void *isCompatibleWith;
    void *getSignalHandler;
    void *unloadLibrary;
    void *getError;
    void *isPathSupported;
    void *initAnonymousNamespace;
    void *createNamespace;
    void *linkNamespaces;
    void *(*loadLibraryExt)(const char *libpath, int flag, void *ns);
};

bool NativeBridgeLoad(const char *game_data_dir, int api_level, void *data, size_t length, const char *target_library) {
    sleep(5);

    auto libart = dlopen("libart.so", RTLD_NOW);
    auto JNI_GetCreatedJavaVMs = (jint (*)(JavaVM **, jsize, jsize *)) dlsym(libart,
                                                                             "JNI_GetCreatedJavaVMs");
    LOGI("JNI_GetCreatedJavaVMs %p", JNI_GetCreatedJavaVMs);
    JavaVM *vms_buf[1];
    JavaVM *vms;
    jsize num_vms;
    jint status = JNI_GetCreatedJavaVMs(vms_buf, 1, &num_vms);
    if (status == JNI_OK && num_vms > 0) {
        vms = vms_buf[0];
    } else {
        LOGE("GetCreatedJavaVMs error");
        return false;
    }

    auto lib_dir = GetLibDir(vms);
    if (lib_dir.empty()) {
        LOGE("GetLibDir error");
        return false;
    }
    if (lib_dir.find("/lib/x86") != std::string::npos) {
        LOGI("no need NativeBridge");
        munmap(data, length);
        return false;
    }

    auto nb = dlopen("libhoudini.so", RTLD_NOW);
    if (!nb) {
        auto native_bridge = GetNativeBridgeLibrary();
        LOGI("native bridge: %s", native_bridge.data());
        nb = dlopen(native_bridge.data(), RTLD_NOW);
    }
    if (nb) {
        LOGI("nb %p", nb);
        auto callbacks = (NativeBridgeCallbacks *) dlsym(nb, "NativeBridgeItf");
        if (callbacks) {
            LOGI("NativeBridgeLoadLibrary %p", callbacks->loadLibrary);
            LOGI("NativeBridgeLoadLibraryExt %p", callbacks->loadLibraryExt);
            LOGI("NativeBridgeGetTrampoline %p", callbacks->getTrampoline);

            int fd = syscall(__NR_memfd_create, "anon", MFD_CLOEXEC);
            ftruncate(fd, (off_t) length);
            void *mem = mmap(nullptr, length, PROT_WRITE, MAP_SHARED, fd, 0);
            memcpy(mem, data, length);
            munmap(mem, length);
            munmap(data, length);
            char path[PATH_MAX];
            snprintf(path, PATH_MAX, "/proc/self/fd/%d", fd);
            LOGI("arm path %s", path);

            void *arm_handle;
            if (api_level >= 26) {
                arm_handle = callbacks->loadLibraryExt(path, RTLD_NOW, (void *) 3);
            } else {
                arm_handle = callbacks->loadLibrary(path, RTLD_NOW);
            }
            if (arm_handle) {
                LOGI("arm handle %p", arm_handle);
                auto init = (void (*)(JavaVM *, void *, const char *)) callbacks->getTrampoline(arm_handle,
                                                                                  "JNI_OnLoad",
                                                                                  nullptr, 0);
                LOGI("JNI_OnLoad %p", init);
                init(vms, (void *) game_data_dir, target_library);
                return true;
            }
            close(fd);
        }
    }
    return false;
}

void hack_prepare(const char *game_data_dir, void *data, size_t length, const char *target_library) {
    LOGI("hack thread: %d with target library: %s", gettid(), target_library);
    int api_level = android_get_device_api_level();
    LOGI("api level: %d", api_level);

#if defined(__i386__) || defined(__x86_64__)
    if (!NativeBridgeLoad(game_data_dir, api_level, data, length, target_library)) {
#endif
        hack_start(game_data_dir, target_library);
#if defined(__i386__) || defined(__x86_64__)
    }
#endif
}

#if defined(__arm__) || defined(__aarch64__)

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    auto game_data_dir = (const char *) reserved;
    const char *target_lib = "libil2cpp.so";
    std::thread hack_thread(hack_start, game_data_dir, target_lib);
    hack_thread.detach();
    return JNI_VERSION_1_6;
}

#endif
EOF
echo "✓ hack.cpp updated"
echo ""

# Add config.h if not exists
if [ ! -f "$CPP_DIR/config.h" ]; then
    echo "📝 Adding config.h..."
    cat > "$CPP_DIR/config.h" << 'EOF'
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
static Config ReadConfig() {
    Config config;
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
        if (line.empty() || line[0] == '#') {
            continue;
        }
        
        size_t pos = line.find('=');
        if (pos == std::string::npos) {
            continue;
        }
        
        std::string key = line.substr(0, pos);
        std::string value = line.substr(pos + 1);
        
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
EOF
    echo "✓ config.h created"
else
    echo "✓ config.h already exists"
fi
echo ""

# Update main.cpp
echo "📝 Updating main.cpp..."
cat > "$CPP_DIR/main.cpp" << 'EOF'
#include <cstring>
#include <thread>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <cinttypes>
#include "hack.h"
#include "zygisk.hpp"
#include "game.h"
#include "log.h"
#include "config.h"

using zygisk::Api;
using zygisk::AppSpecializeArgs;
using zygisk::ServerSpecializeArgs;

class MyModule : public zygisk::ModuleBase {
public:
    void onLoad(Api *api, JNIEnv *env) override {
        this->api = api;
        this->env = env;
        this->config = ReadConfig();
    }

    void preAppSpecialize(AppSpecializeArgs *args) override {
        auto package_name = env->GetStringUTFChars(args->nice_name, nullptr);
        auto app_data_dir = env->GetStringUTFChars(args->app_data_dir, nullptr);
        preSpecialize(package_name, app_data_dir);
        env->ReleaseStringUTFChars(args->nice_name, package_name);
        env->ReleaseStringUTFChars(args->app_data_dir, app_data_dir);
    }

    void postAppSpecialize(const AppSpecializeArgs *) override {
        if (enable_hack) {
            std::thread hack_thread(hack_prepare, game_data_dir, data, length, target_library);
            hack_thread.detach();
        }
    }

private:
    Api *api;
    JNIEnv *env;
    bool enable_hack;
    char *game_data_dir;
    char *target_library;
    void *data;
    size_t length;
    Config config;

    void preSpecialize(const char *package_name, const char *app_data_dir) {
        LOGI("Current package: %s, Target package: %s", package_name, config.packageName.c_str());
        
        if (strcmp(package_name, config.packageName.c_str()) == 0) {
            LOGI("detect game: %s", package_name);
            enable_hack = true;
            game_data_dir = new char[strlen(app_data_dir) + 1];
            strcpy(game_data_dir, app_data_dir);
            
            target_library = new char[config.targetLibrary.length() + 1];
            strcpy(target_library, config.targetLibrary.c_str());

#if defined(__i386__)
            auto path = "zygisk/armeabi-v7a.so";
#endif
#if defined(__x86_64__)
            auto path = "zygisk/arm64-v8a.so";
#endif
#if defined(__i386__) || defined(__x86_64__)
            int dirfd = api->getModuleDir();
            int fd = openat(dirfd, path, O_RDONLY);
            if (fd != -1) {
                struct stat sb{};
                fstat(fd, &sb);
                length = sb.st_size;
                data = mmap(nullptr, length, PROT_READ, MAP_PRIVATE, fd, 0);
                close(fd);
            } else {
                LOGW("Unable to open arm file");
            }
#endif
        } else {
            api->setOption(zygisk::Option::DLCLOSE_MODULE_LIBRARY);
        }
    }
};

REGISTER_ZYGISK_MODULE(MyModule)
EOF
echo "✓ main.cpp updated"
echo ""

# Summary
echo "================================"
echo "✅ Integration Complete!"
echo "================================"
echo ""
echo "Changes made:"
echo "  • config.h - Created (new config system)"
echo "  • hack.h - Updated (new parameter)"
echo "  • hack.cpp - Updated (dynamic library loading)"
echo "  • main.cpp - Updated (config reading)"
echo ""
echo "Backup location:"
echo "  $backup_dir"
echo ""
echo "Next steps:"
echo "  1. Build: ./gradlew :module:build"
echo "  2. Create config: adb shell echo 'PACKAGE_NAME=com.goo.lagme' > /data/local/tmp/il2cpp_dumper_config.txt"
echo "  3. Add: adb shell echo 'TARGET_LIBRARY=libMod.so' >> /data/local/tmp/il2cpp_dumper_config.txt"
echo "  4. Test: ./gradlew :app:installDebug"
echo ""
