# Hướng dẫn tích hợp code sửa đổi (Step by Step)

## 📋 Danh sách file cần sửa

| File | Thay đổi | Mục đích |
|------|---------|---------|
| `main.cpp` | Sửa đổi toàn bộ | Thêm config loading |
| `hack.h` | Sửa đổi signature | Thêm tham số target_library |
| `hack.cpp` | Sửa đổi toàn bộ | Support dynamic library |
| `game.h` | Giữ nguyên (optional) | Có thể xóa |
| `il2cpp_dump.cpp` | Giữ nguyên | Không cần sửa |
| `config.h` | TẠO MỚI | Config file reader |

---

## 🔧 Cách tích hợp chi tiết

### Bước 1: Backup file gốc
```bash
cd Zygisk-Il2CppDumper-master

# Backup
cp module/src/main/cpp/main.cpp module/src/main/cpp/main.cpp.bak
cp module/src/main/cpp/hack.cpp module/src/main/cpp/hack.cpp.bak
cp module/src/main/cpp/hack.h module/src/main/cpp/hack.h.bak
```

### Bước 2: Thêm file config.h
```bash
# Copy file config mới vào project
cp config.h module/src/main/cpp/config.h
```

### Bước 3: Sửa hack.h
**File gốc:** `module/src/main/cpp/hack.h`

Thay thế nội dung:
```cpp
//
// Created by Perfare on 2020/7/4.
//

#ifndef ZYGISK_IL2CPPDUMPER_HACK_H
#define ZYGISK_IL2CPPDUMPER_HACK_H

#include <stddef.h>

// OLD: void hack_prepare(const char *game_data_dir, void *data, size_t length);
// NEW:
void hack_prepare(const char *game_data_dir, void *data, size_t length, const char *target_library);

#endif //ZYGISK_IL2CPPDUMPER_HACK_H
```

### Bước 4: Sửa hack.cpp

**Phần 1: Hàm hack_start() - Line 20-36**

```cpp
// OLD:
void hack_start(const char *game_data_dir) {
    bool load = false;
    for (int i = 0; i < 10; i++) {
        void *handle = xdl_open("libil2cpp.so", 0);  // ← HARDCODED
        if (handle) {
            load = true;
            il2cpp_api_init(handle);
            il2cpp_dump(game_data_dir);
            break;
        } else {
            sleep(1);
        }
    }
    if (!load) {
        LOGI("libil2cpp.so not found in thread %d", gettid());
    }
}

// NEW:
void hack_start(const char *game_data_dir, const char *target_library) {
    bool load = false;
    LOGI("Attempting to load library: %s", target_library);  // ← NEW
    
    for (int i = 0; i < 10; i++) {
        void *handle = xdl_open(target_library, 0);  // ← DYNAMIC
        if (handle) {
            load = true;
            LOGI("Successfully loaded %s", target_library);  // ← NEW
            il2cpp_api_init(handle);
            il2cpp_dump(game_data_dir);
            break;
        } else {
            LOGI("Attempt %d: Failed to load %s, retrying...", i + 1, target_library);  // ← NEW
            sleep(1);
        }
    }
    if (!load) {
        LOGE("Failed to load %s in thread %d after 10 attempts", target_library, gettid());  // ← UPDATED
    }
}
```

**Phần 2: Hàm NativeBridgeLoad() - Line 114**

Thay đổi signature:
```cpp
// OLD:
bool NativeBridgeLoad(const char *game_data_dir, int api_level, void *data, size_t length)

// NEW:
bool NativeBridgeLoad(const char *game_data_dir, int api_level, void *data, size_t length, const char *target_library)
```

Ở dòng 180 (trong JNI_OnLoad callback):
```cpp
// OLD:
init(vms, (void *) game_data_dir);

// NEW:
init(vms, (void *) game_data_dir, target_library);
```

**Phần 3: Hàm hack_prepare() - Line 189**

```cpp
// OLD:
void hack_prepare(const char *game_data_dir, void *data, size_t length) {
    LOGI("hack thread: %d", gettid());
    int api_level = android_get_device_api_level();
    LOGI("api level: %d", api_level);

#if defined(__i386__) || defined(__x86_64__)
    if (!NativeBridgeLoad(game_data_dir, api_level, data, length)) {
#endif
        hack_start(game_data_dir);
#if defined(__i386__) || defined(__x86_64__)
    }
#endif
}

// NEW:
void hack_prepare(const char *game_data_dir, void *data, size_t length, const char *target_library) {
    LOGI("hack thread: %d with target library: %s", gettid(), target_library);  // ← UPDATED
    int api_level = android_get_device_api_level();
    LOGI("api level: %d", api_level);

#if defined(__i386__) || defined(__x86_64__)
    if (!NativeBridgeLoad(game_data_dir, api_level, data, length, target_library)) {  // ← ADD PARAM
#endif
        hack_start(game_data_dir, target_library);  // ← ADD PARAM
#if defined(__i386__) || defined(__x86_64__)
    }
#endif
}
```

**Phần 4: JNI_OnLoad() - Line 205**

```cpp
// OLD:
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    auto game_data_dir = (const char *) reserved;
    std::thread hack_thread(hack_start, game_data_dir);
    hack_thread.detach();
    return JNI_VERSION_1_6;
}

// NEW:
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    auto game_data_dir = (const char *) reserved;
    const char *target_lib = "libil2cpp.so";  // ← DEFAULT FALLBACK
    std::thread hack_thread(hack_start, game_data_dir, target_lib);  // ← ADD PARAM
    hack_thread.detach();
    return JNI_VERSION_1_6;
}
```

### Bước 5: Sửa main.cpp

**Thêm include:**
```cpp
#include "config.h"  // ← ADD THIS
```

**Sửa class MyModule:**

```cpp
// OLD:
class MyModule : public zygisk::ModuleBase {
public:
    void onLoad(Api *api, JNIEnv *env) override {
        this->api = api;
        this->env = env;
    }

// NEW:
class MyModule : public zygisk::ModuleBase {
public:
    void onLoad(Api *api, JNIEnv *env) override {
        this->api = api;
        this->env = env;
        this->config = ReadConfig();  // ← ADD THIS
    }
```

**Sửa postAppSpecialize:**
```cpp
// OLD:
void postAppSpecialize(const AppSpecializeArgs *) override {
    if (enable_hack) {
        std::thread hack_thread(hack_prepare, game_data_dir, data, length);
        hack_thread.detach();
    }
}

// NEW:
void postAppSpecialize(const AppSpecializeArgs *) override {
    if (enable_hack) {
        std::thread hack_thread(hack_prepare, game_data_dir, data, length, target_library);  // ← ADD PARAM
        hack_thread.detach();
    }
}
```

**Sửa private members:**
```cpp
private:
    Api *api;
    JNIEnv *env;
    bool enable_hack;
    char *game_data_dir;
    char *target_library;  // ← ADD THIS
    void *data;
    size_t length;
    Config config;  // ← ADD THIS
```

**Sửa hàm preSpecialize:**
```cpp
void preSpecialize(const char *package_name, const char *app_data_dir) {
    // OLD:
    if (strcmp(package_name, GamePackageName) == 0) {  // ← HARDCODED
    
    // NEW:
    LOGI("Current package: %s, Target package: %s", package_name, config.packageName.c_str());
    if (strcmp(package_name, config.packageName.c_str()) == 0) {  // ← DYNAMIC
        LOGI("detect game: %s", package_name);
        enable_hack = true;
        game_data_dir = new char[strlen(app_data_dir) + 1];
        strcpy(game_data_dir, app_data_dir);
        
        // ← ADD THIS BLOCK
        target_library = new char[config.targetLibrary.length() + 1];
        strcpy(target_library, config.targetLibrary.c_str());
        
        // ... rest of code
    }
}
```

### Bước 6: Build

```bash
# Clean build
./gradlew clean

# Build module
./gradlew :module:build

# Check output
ls -la module/build/outputs/
```

---

## ✅ Kiểm tra sửa đổi

```bash
# Kiểm tra file có tồn tại
ls -la module/src/main/cpp/config.h

# Kiểm tra includes
grep -n "#include \"config.h\"" module/src/main/cpp/main.cpp

# Kiểm tra ReadConfig
grep -n "ReadConfig" module/src/main/cpp/main.cpp

# Kiểm tra hack_prepare signature
grep -n "hack_prepare" module/src/main/cpp/hack.h
grep -n "hack_prepare" module/src/main/cpp/hack.cpp
grep -n "hack_prepare" module/src/main/cpp/main.cpp
```

---

## 🚀 Deploy

```bash
# Build APK
./gradlew build

# Install
adb install app/build/outputs/apk/debug/app-debug.apk

# Tạo config file
adb shell mkdir -p /data/local/tmp

cat > /tmp/config.txt << 'EOF'
PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so
EOF

adb push /tmp/config.txt /data/local/tmp/il2cpp_dumper_config.txt

# Verify
adb shell cat /data/local/tmp/il2cpp_dumper_config.txt

# Trigger app
adb shell am start -n com.goo.lagme/.MainActivity

# Monitor logs
adb logcat | grep -E "hack|detect|load|dump"

# Retrieve dump
adb pull /data/data/com.goo.lagme/files/dump.cs
```

---

## 🔍 Common Mistakes

### ❌ Quên thêm #include "config.h"
```cpp
// Lỗi: "ReadConfig was not declared"
// Fix: Thêm #include "config.h" ở đầu main.cpp
```

### ❌ Quên update signature ở hack.h
```cpp
// hack.cpp sẽ compile fail vì signature không match
// Fix: Cập nhật hack.h
```

### ❌ Quên add parameter ở hack_prepare() calls
```cpp
// main.cpp sẽ compile fail: "too few arguments"
// Fix: Thêm target_library parameter
```

### ❌ Forget to allocate target_library
```cpp
// Runtime crash: strcpy null pointer
// Fix: Thêm: target_library = new char[config.targetLibrary.length() + 1];
```

---

## 📝 Verify Checklist

- [ ] config.h được copy vào project
- [ ] #include "config.h" được thêm vào main.cpp
- [ ] hack.h signature được update (thêm target_library parameter)
- [ ] hack_prepare() được update ở hack.cpp
- [ ] hack_start() được sửa để dùng target_library
- [ ] NativeBridgeLoad() được update
- [ ] MyModule::onLoad() gọi ReadConfig()
- [ ] target_library member variable được thêm
- [ ] preSpecialize() dùng config.packageName
- [ ] postAppSpecialize() pass target_library
- [ ] Build thành công (không có error)
- [ ] APK được tạo

---

## 📚 File mẫu hoàn chỉnh

Tất cả file đã sửa xong đều có sẵn trong:
- `main_modified.cpp` - Toàn bộ main.cpp sửa xong
- `hack_modified.cpp` - Toàn bộ hack.cpp sửa xong
- `hack_modified.h` - hack.h sửa xong
- `config.h` - File config mới

Bạn có thể copy trực tiếp hoặc merge theo hướng dẫn trên.
