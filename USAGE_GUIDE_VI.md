# Hướng dẫn sử dụng Zygisk Il2CppDumper Custom

## Tổng quan
Đây là phiên bản sửa đổi của Zygisk Il2CppDumper cho phép:
- Dump **bất kỳ library nào** (không chỉ libil2cpp.so)
- Nhập **package name động** (không cần hardcode)
- Cấu hình qua **file config**

---

## Cách sửa đổi code

### Bước 1: Thay thế các file
Sao chép các file sửa đổi vào project của bạn:

```bash
# Thay thế file chính
cp main_modified.cpp module/src/main/cpp/main.cpp
cp hack_modified.cpp module/src/main/cpp/hack.cpp
cp hack_modified.h module/src/main/cpp/hack.h

# Thêm file config mới
cp config.h module/src/main/cpp/config.h
```

### Bước 2: Cập nhật CMakeLists.txt
Đảm bảo `config.h` được include trong CMakeLists.txt nếu cần.

---

## Cách sử dụng

### Phương pháp 1: Tạo file cấu hình (KHUYẾN NGHỊ)

**Trên thiết bị Android (cần root + terminal app):**

```bash
# Tạo file cấu hình
cat > /data/local/tmp/il2cpp_dumper_config.txt << 'EOF'
PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so
EOF

# Xem lại file
cat /data/local/tmp/il2cpp_dumper_config.txt
```

### Phương pháp 2: Dùng adb (từ máy tính)

```bash
# Tạo file cấu hình
cat > /tmp/config.txt << 'EOF'
PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so
EOF

# Gửi vào thiết bị
adb push /tmp/config.txt /data/local/tmp/il2cpp_dumper_config.txt

# Kiểm tra
adb shell cat /data/local/tmp/il2cpp_dumper_config.txt
```

---

## Ví dụ sử dụng

### Ví dụ 1: Dump libMod.so từ com.goo.lagme

**File config `/data/local/tmp/il2cpp_dumper_config.txt`:**
```
PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so
```

**Quy trình:**
1. Tạo file config như trên
2. Cài đặt module Zygisk
3. Khởi động lại điện thoại (hoặc khởi động lại ứng dụng)
4. Ứng dụng `com.goo.lagme` sẽ khởi động
5. Module sẽ tự động phát hiện app
6. Tìm và load `libMod.so`
7. Dump dữ liệu vào `/data/data/com.goo.lagme/files/dump.cs`

---

### Ví dụ 2: Dump libUnity.so

**File config:**
```
PACKAGE_NAME=com.example.game
TARGET_LIBRARY=libUnity.so
```

---

### Ví dụ 3: Dump multiple libraries

**Cách 1: Chạy lần lượt**
- Lần 1: Config với `libMod.so`, dump, lấy file
- Lần 2: Sửa config với `libUnity.so`, dump lại

**Cách 2: Sửa code để chạy cùng lúc**
- Tạo nhiều module với package name khác nhau

---

## Cấu trúc file output

Sau khi dump thành công, tìm file tại:
```
/data/data/PACKAGE_NAME/files/dump.cs
```

Ví dụ:
```
/data/data/com.goo.lagme/files/dump.cs
```

**Lấy file về máy tính:**
```bash
adb pull /data/data/com.goo.lagme/files/dump.cs
```

---

## Cách hoạt động chi tiết

### 1. **Config Loading** (config.h)
```cpp
- Đọc file: /data/local/tmp/il2cpp_dumper_config.txt
- Parse cặp KEY=VALUE
- Lấy PACKAGE_NAME và TARGET_LIBRARY
- Nếu không có file, dùng default (com.game.packagename / libil2cpp.so)
```

### 2. **Package Detection** (main.cpp)
```cpp
- Khi app khởi động, kiểm tra package name
- So sánh với PACKAGE_NAME từ config
- Nếu match, kích hoạt hack
```

### 3. **Library Loading** (hack.cpp)
```cpp
- Tìm kiếm TARGET_LIBRARY trong memory
- Load library qua xdl_open()
- Gọi il2cpp_api_init(handle)
- Thực hiện dump
```

### 4. **Data Dumping** (il2cpp_dump.cpp)
```cpp
- Iterate qua tất cả assemblies
- Dump class info, methods, fields
- Lưu vào /data/data/PACKAGE_NAME/files/dump.cs
```

---

## Troubleshooting

### Vấn đề 1: "libMod.so not found"

**Nguyên nhân:** Library chưa được load khi hack_start() được gọi

**Giải pháp:**
```cpp
// Sửa thời gian delay trong hack.cpp
// Tăng từ 10 giây lên 15 hoặc 20 giây
for (int i = 0; i < 20; i++) {  // Từ 10 -> 20
    void *handle = xdl_open(target_library, 0);
    if (handle) {
        ...
    }
    sleep(1);  // Hoặc tăng sleep lên 2 giây
}
```

### Vấn đề 2: File config không được đọc

**Kiểm tra:**
```bash
# 1. File có tồn tại không
adb shell ls -la /data/local/tmp/il2cpp_dumper_config.txt

# 2. Format có đúng không (không có spaces quanh =)
adb shell cat /data/local/tmp/il2cpp_dumper_config.txt

# 3. Check logs
adb logcat | grep "il2cpp_dumper"
```

### Vấn đề 3: Dump không thành công

**Kiểm tra log:**
```bash
adb logcat | grep -E "LOGI|LOGE|hack_start"
```

**Các thông báo cần xem:**
- "detect game: com.goo.lagme" - Package được phát hiện ✓
- "Attempting to load library: libMod.so" - Bắt đầu load
- "Successfully loaded libMod.so" - Load thành công ✓
- "dump done!" - Hoàn tất ✓

---

## Sửa đổi nâng cao

### 1. Tăng retry attempts
File `hack_modified.cpp`, hàm `hack_start()`:
```cpp
for (int i = 0; i < 20; i++) {  // Tăng từ 10
    ...
    LOGI("Attempt %d: Failed to load %s", i + 1, target_library);
    sleep(2);  // Tăng từ 1
}
```

### 2. Dump nhiều libraries cùng lúc
Sửa `config.h`:
```cpp
struct Config {
    std::string packageName;
    std::vector<std::string> targetLibraries;  // Multiple libraries
};
```

Sau đó loop qua từng library:
```cpp
for (const auto& lib : config.targetLibraries) {
    hack_start(game_data_dir, lib.c_str());
}
```

### 3. Dump tự động khi app khởi động
Code hiện tại đã hỗ trợ (postAppSpecialize)

---

## Lệnh build và test

```bash
# Build module
cd Zygisk-Il2CppDumper-master
./gradlew :module:build

# Lấy APK
adb install app-debug.apk

# Tạo config
adb shell "echo 'PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so' > /data/local/tmp/il2cpp_dumper_config.txt"

# Khởi động app
adb shell am start -n com.goo.lagme/.MainActivity

# Check logs
adb logcat | grep "hack\|detect\|load"

# Lấy file dump
adb pull /data/data/com.goo.lagme/files/dump.cs dump.cs
```

---

## Các biến có thể tùy chỉnh

| Biến | Vị trí | Mục đích |
|------|--------|---------|
| PACKAGE_NAME | config.txt | Tên package cần hook |
| TARGET_LIBRARY | config.txt | Library cần dump |
| Retry attempts | hack.cpp:23 | Số lần thử load |
| Sleep duration | hack.cpp:31 | Thời gian chờ giữa lần thử |
| Config path | config.h:21 | Đường dẫn file cấu hình |
| Output path | il2cpp_dump.cpp:420 | Nơi lưu file dump |

---

## Ghi chú quan trọng

1. **File config không bắt buộc** - Nếu không có, dùng giá trị mặc định
2. **Package name phải đúng** - So sánh chính xác (case-sensitive)
3. **Library phải tồn tại** - Không thể dump library không được load
4. **Cần root access** - Module Zygisk yêu cầu root
5. **Log là bạn** - Luôn check logcat để debug

---

## License
Dựa trên Zygisk-Il2CppDumper gốc
