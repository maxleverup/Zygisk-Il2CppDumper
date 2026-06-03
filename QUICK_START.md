# ⚡ Quick Start (5 phút)

## 🎯 Mục tiêu
Dump `libMod.so` từ app `com.goo.lagme`

## ✅ Yêu cầu
- ✓ Android phone rooted với Magisk
- ✓ Zygisk enabled
- ✓ ADB connected
- ✓ Zygisk-Il2CppDumper project

## 🚀 Các bước

### 1️⃣ Integrate Code (2 phút)

```bash
# Copy file sửa đổi vào project
cd Zygisk-Il2CppDumper-master

# Option A: Dùng script tự động (dễ)
chmod +x integrate.sh
./integrate.sh .

# Option B: Merge thủ công (xem INTEGRATION_GUIDE.md)
```

### 2️⃣ Build Module (1 phút)

```bash
./gradlew clean build

# Lấy output
ls -la app/build/outputs/apk/debug/
```

### 3️⃣ Setup Config (30 giây)

```bash
# Tạo file config
adb shell mkdir -p /data/local/tmp
adb shell "cat > /data/local/tmp/il2cpp_dumper_config.txt << 'EOF'
PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so
EOF"

# Verify
adb shell cat /data/local/tmp/il2cpp_dumper_config.txt
```

### 4️⃣ Install Module (1 phút)

```bash
# Install APK
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Reboot (hoặc dùng Magisk Manager để install module)
adb reboot
```

### 5️⃣ Test (30 giây)

```bash
# Trigger app
adb shell am start -n com.goo.lagme/.MainActivity

# Monitor logs (chờ 5-10 giây)
adb logcat | grep -E "detect game|loaded|dump done"
```

### 6️⃣ Get Result (10 giây)

```bash
# Pull file dump
adb pull /data/data/com.goo.lagme/files/dump.cs ~/dump.cs

# Verify (phải > 1KB)
ls -lh ~/dump.cs
```

---

## ✨ Kết quả mong đợi

**Logs:**
```
detect game: com.goo.lagme
Attempting to load library: libMod.so
Successfully loaded libMod.so
[... dumping process ...]
dump done!
```

**File:** `~/dump.cs` (100KB - 10MB)

---

## ❌ Nếu không hoạt động?

1. **"detect game" không xuất hiện**
   - Package name sai hoặc app chưa khởi động
   - Fix: Check `adb shell cat /data/local/tmp/il2cpp_dumper_config.txt`

2. **"libMod.so not found"**
   - Library chưa được load hoặc tên sai
   - Fix: Kiểm tra library trong app (`adb shell find /data/data/com.goo.lagme -name "*.so"`)

3. **"dump done!" nhưng không có file**
   - Permission issue hoặc path sai
   - Fix: `adb shell ls -la /data/data/com.goo.lagme/files/`

---

## 📚 Thêm thông tin

- **Sửa đổi chi tiết**: Xem `INTEGRATION_GUIDE.md`
- **Sử dụng nâng cao**: Xem `USAGE_GUIDE_VI.md`
- **Toàn bộ**: Xem `README.md`

---

**⏱️ Thời gian:** ~5 phút  
**🎯 Kết quả:** Dump thành công  
**✅ Status:** Ready to go!
