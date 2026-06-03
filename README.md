# 🎯 Zygisk Il2CppDumper - Custom Library Dumper
## Version 2.0 - Multi-Library Support

### 📌 Tóm tắt thay đổi

**Vấn đề gốc:**
- ❌ Chỉ dump được `libil2cpp.so` (hardcoded)
- ❌ Package name cố định (phải sửa code)
- ❌ Không thể dump các library khác

**Giải pháp:**
- ✅ Dump **bất kỳ library nào** (libMod.so, libUnity.so, v.v.)
- ✅ Package name **động từ file config**
- ✅ Cấu hình **không cần sửa code**

---

## 🚀 Bắt đầu nhanh (5 phút)

### Cách 1: Dùng script tự động (Khuyên dùng)

```bash
# 1. Copy script vào project
cp integrate.sh Zygisk-Il2CppDumper-master/

# 2. Chạy script
cd Zygisk-Il2CppDumper-master
chmod +x integrate.sh
./integrate.sh .

# 3. Build
./gradlew :module:build

# 4. Config
adb shell mkdir -p /data/local/tmp
adb shell "cat > /data/local/tmp/il2cpp_dumper_config.txt << 'EOF'
PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so
EOF"

# 5. Test
adb shell am start -n com.goo.lagme/.MainActivity
adb logcat | grep "hack\|load\|dump"
```

### Cách 2: Merge thủ công

Xem file `INTEGRATION_GUIDE.md` để hướng dẫn chi tiết từng bước.

---

## 📋 Tệp tin bao gồm

```
├── config.h                    # File cấu hình mới [TẠO MỚI]
├── main_modified.cpp           # main.cpp sửa đổi
├── hack_modified.cpp           # hack.cpp sửa đổi
├── hack_modified.h             # hack.h sửa đổi
├── integrate.sh                # Script tự động hóa
├── USAGE_GUIDE_VI.md          # Hướng dẫn sử dụng chi tiết
├── INTEGRATION_GUIDE.md       # Hướng dẫn tích hợp (merge thủ công)
├── QUICK_START.md             # Bắt đầu nhanh
└── README.md                   # File này
```

---

## 🔧 Cách hoạt động

### Flow Diagram
```
App Launch
    ↓
Package Name Check
    ├─ Match → Load Config
    │   ├─ Read PACKAGE_NAME from config.txt
    │   ├─ Read TARGET_LIBRARY from config.txt
    │   └─ Activate Dump Module
    └─ No Match → Disable Module

Dump Module Active
    ↓
Wait for Target Library to Load
    ├─ Retry 10 times (with 1s interval)
    ├─ xdl_open(TARGET_LIBRARY)
    └─ Success → Start dumping
    
Dumping
    ↓
Extract all IL2CPP metadata
    ├─ Iterate assemblies
    ├─ Dump classes, methods, fields
    └─ Save to /data/data/PACKAGE_NAME/files/dump.cs
```

### File Config Format
```
# /data/local/tmp/il2cpp_dumper_config.txt

# Package name of target app
PACKAGE_NAME=com.goo.lagme

# Library to dump (relative name in lib directory)
TARGET_LIBRARY=libMod.so

# Optional: increase retry attempts
# RETRY_ATTEMPTS=15

# Lines starting with # are comments
```

---

## 💻 Ví dụ sử dụng

### Ví dụ 1: Dump libMod.so từ com.goo.lagme

```bash
# Tạo config
adb shell mkdir -p /data/local/tmp
adb shell "cat > /data/local/tmp/il2cpp_dumper_config.txt << 'EOF'
PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so
EOF"

# Verify
adb shell cat /data/local/tmp/il2cpp_dumper_config.txt

# Trigger app (phải có module Zygisk installed)
adb shell am start -n com.goo.lagme/.MainActivity

# Check logs (một vài giây)
adb logcat | grep -E "detect game|Successfully loaded|dump done"

# Get dump file
adb pull /data/data/com.goo.lagme/files/dump.cs ~/Desktop/
```

### Ví dụ 2: Dump nhiều libraries lần lượt

```bash
# Lần 1: libMod.so
echo "PACKAGE_NAME=com.goo.lagme" > /tmp/config1.txt
echo "TARGET_LIBRARY=libMod.so" >> /tmp/config1.txt
adb push /tmp/config1.txt /data/local/tmp/il2cpp_dumper_config.txt
adb shell am start -n com.goo.lagme/.MainActivity
sleep 10
adb pull /data/data/com.goo.lagme/files/dump.cs ~/Desktop/dump_mod.cs

# Lần 2: libUnity.so
echo "PACKAGE_NAME=com.goo.lagme" > /tmp/config2.txt
echo "TARGET_LIBRARY=libUnity.so" >> /tmp/config2.txt
adb push /tmp/config2.txt /data/local/tmp/il2cpp_dumper_config.txt
adb shell am start -n com.goo.lagme/.MainActivity
sleep 10
adb pull /data/data/com.goo.lagme/files/dump.cs ~/Desktop/dump_unity.cs
```

---

## 🛠️ Sửa đổi Core Changes

### 1. config.h (NEW)
```cpp
// Đọc file cấu hình từ /data/local/tmp/il2cpp_dumper_config.txt
// Parse KEY=VALUE pairs
// Default: com.game.packagename / libil2cpp.so

struct Config {
    std::string packageName;
    std::string targetLibrary;
};
```

### 2. hack.h (MODIFIED)
```cpp
// OLD: void hack_prepare(const char *game_data_dir, void *data, size_t length);
// NEW: 
void hack_prepare(const char *game_data_dir, void *data, size_t length, 
                  const char *target_library);
```

### 3. hack.cpp (MODIFIED)
```cpp
// hack_start() - nhận target_library làm tham số
void hack_start(const char *game_data_dir, const char *target_library) {
    // void *handle = xdl_open(target_library, 0);  // ← DYNAMIC
}

// NativeBridgeLoad() - pass target_library through
// hack_prepare() - receive and pass target_library
```

### 4. main.cpp (MODIFIED)
```cpp
// onLoad() - gọi ReadConfig()
Config config = ReadConfig();

// preSpecialize() - dùng config.packageName instead of GamePackageName
if (strcmp(package_name, config.packageName.c_str()) == 0)

// postAppSpecialize() - pass target_library
hack_thread(hack_prepare, game_data_dir, data, length, target_library);
```

---

## ✅ Kiểm tra danh sách

### Build
- [ ] Clone/download Zygisk project
- [ ] Copy tất cả file sửa đổi
- [ ] Chạy `./gradlew clean build`
- [ ] Không có compile errors

### Deploy
- [ ] `adb install app/build/outputs/apk/debug/app-debug.apk`
- [ ] Restart/reboot phone
- [ ] Module được load (check Magisk)

### Configuration
- [ ] Create `/data/local/tmp/il2cpp_dumper_config.txt`
- [ ] PACKAGE_NAME chính xác
- [ ] TARGET_LIBRARY tồn tại trong app

### Testing
- [ ] Khởi động app
- [ ] Check logs: "detect game: com.goo.lagme"
- [ ] Check logs: "Successfully loaded libMod.so"
- [ ] Check logs: "dump done!"
- [ ] Verify file: `/data/data/com.goo.lagme/files/dump.cs`

---

## 🐛 Troubleshooting

### Problem: "libMod.so not found"

**Nguyên nhân:** Library chưa load khi hack_start() chạy

**Giải pháp:**
```cpp
// Tăng retry time
for (int i = 0; i < 20; i++) {      // 10 -> 20
    sleep(2);                        // 1s -> 2s
}
```

### Problem: Config file không đọc được

**Kiểm tra:**
```bash
# 1. File tồn tại?
adb shell ls -la /data/local/tmp/il2cpp_dumper_config.txt

# 2. Format đúng?
adb shell cat /data/local/tmp/il2cpp_dumper_config.txt
# Không được có space quanh =: PACKAGE_NAME=com.goo.lagme (✓)
# Không: PACKAGE_NAME = com.goo.lagme (✗)

# 3. Check logs
adb logcat | grep "Config\|Loaded"
```

### Problem: Dump file không tạo

**Kiểm tra log sequence:**
```bash
adb logcat | grep -E "detect game|Successfully loaded|dump done"
```

Cần thấy tất cả 3 message.

---

## 📊 Biến số tuỳ chỉnh

| Biến | File | Dòng | Mục đích |
|------|------|------|---------|
| Config path | config.h | 21 | Đường dẫn file config |
| Default package | config.h | 27 | Package mặc định |
| Default library | config.h | 28 | Library mặc định |
| Retry attempts | hack.cpp | 23 | Số lần thử load |
| Sleep duration | hack.cpp | 31 | Thời gian chờ |
| Output format | il2cpp_dump.cpp | 420 | Tên/format file output |

---

## 📚 Tài liệu chi tiết

| File | Nội dung |
|------|---------|
| **INTEGRATION_GUIDE.md** | Hướng dẫn merge thủ công từng file |
| **USAGE_GUIDE_VI.md** | Hướng dẫn sử dụng chi tiết |
| **QUICK_START.md** | Bắt đầu nhanh chóng |
| **config.h** | Source code file config |
| **main_modified.cpp** | Source code main.cpp hoàn chỉnh |
| **hack_modified.cpp** | Source code hack.cpp hoàn chỉnh |

---

## 🎯 Kế tiếp có thể?

### Tính năng có thể thêm:
1. **Dump multiple libraries cùng lúc**
   - Parse `TARGET_LIBRARY=lib1.so;lib2.so;lib3.so`
   - Loop qua từng library

2. **Custom output directory**
   - Add `OUTPUT_DIR=/path/to/output`
   - Flexible saving location

3. **Auto-apply patches**
   - Auto-patch library sau khi dump
   - Immediate hooking

4. **Config via Android app UI**
   - Thay vì file text
   - GUI input fields

---

## ⚠️ Cảnh báo quan trọng

1. **Cần Root** - Module Zygisk yêu cầu root
2. **Cần Magisk** - Module phải cài qua Magisk
3. **Package name phải đúng** - Là case-sensitive
4. **Library phải được load** - Không thể dump library chưa load
5. **File path cố định** - `/data/local/tmp/il2cpp_dumper_config.txt`

---

## 📞 Support

### Lỗi compile?
- Kiểm tra includes: `#include "config.h"`
- Verify C++ version (phải C++17+)
- Check NDK version

### Lỗi runtime?
- Check logcat: `adb logcat | grep il2cpp`
- Verify config format
- Restart app/device

### Lỗi dump?
- Verify package name chính xác
- Verify library tồn tại
- Check permissions: `/data/data/PACKAGE_NAME/files/` có write không?

---

## 📄 License

Dựa trên [Zygisk-Il2CppDumper](https://github.com/Perfare/Zygisk-Il2CppDumper) gốc

---

**Last Updated:** June 2025  
**Version:** 2.0  
**Status:** Tested and Working ✅
