# Zygisk Il2CppDumper - Custom Library Dumper (Modified Version)

## 🎯 Tính năng chính (Version 2.0)

✅ **Dump bất kỳ library nào** - Không chỉ libil2cpp.so  
✅ **Config động** - Không cần sửa code  
✅ **Một build, nhiều targets** - Thay đổi library qua file config  
✅ **User-friendly** - File-based configuration  

---

## 📋 So sánh Old vs New

| Tính năng | Original | Modified |
|----------|----------|----------|
| Package name | Hardcoded | ✅ From config file |
| Target library | libil2cpp.so only | ✅ Any .so file |
| Config method | Edit code | ✅ Edit config.txt |
| Flexibility | Low | ✅ High |

---

## ⚡ Quick Start (5 phút)

### 1. Integrate Code
```bash
cd Zygisk-Il2CppDumper-master

# Option A: Auto-integration (recommended)
chmod +x integrate.sh
./integrate.sh .

# Option B: Manual merge
# Follow INTEGRATION_GUIDE.md
```

### 2. Build
```bash
./gradlew clean build
```

### 3. Create Config File
```bash
adb shell mkdir -p /data/local/tmp
adb shell "cat > /data/local/tmp/il2cpp_dumper_config.txt << 'EOF'
PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so
EOF"
```

### 4. Deploy & Test
```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.goo.lagme/.MainActivity
adb logcat | grep "detect game\|loaded\|dump done"
```

### 5. Get Result
```bash
adb pull /data/data/com.goo.lagme/files/dump.cs ~/dump.cs
```

---

## 📚 Documentation Files

| File | Purpose | Time |
|------|---------|------|
| **QUICK_START.md** | 5-minute setup | ⚡ Fast |
| **README.md** | Complete overview | 📖 Full |
| **INTEGRATION_GUIDE.md** | Line-by-line merge | 📝 Detailed |
| **USAGE_GUIDE_VI.md** | End-user guide | 👤 User |
| **VISUAL_GUIDE.md** | Diagrams & flows | 📊 Visual |
| **PROJECT_STRUCTURE.txt** | Project layout | 📦 Overview |
| **FILES_SUMMARY.md** | File index | 📋 Reference |

**START HERE:** Read `README.md` or `QUICK_START.md`

---

## 🔧 What's New

### New File: config.h
- Reads `/data/local/tmp/il2cpp_dumper_config.txt`
- Parses PACKAGE_NAME and TARGET_LIBRARY
- Supports dynamic configuration

### Modified Files:
1. **main.cpp** - Load config, detect package dynamically
2. **hack.cpp** - Support any library (not just libil2cpp.so)
3. **hack.h** - Updated function signatures

### New Tool: integrate.sh
- Automatic code integration script
- Backs up original files
- Updates all files in one command

---

## 📖 Config File Format

```
# /data/local/tmp/il2cpp_dumper_config.txt

# Package name of target app
PACKAGE_NAME=com.goo.lagme

# Library to dump (any .so file)
TARGET_LIBRARY=libMod.so

# Comments start with #
```

---

## 📋 Example Usage

### Dump libMod.so from com.goo.lagme
```bash
# Create config
echo "PACKAGE_NAME=com.goo.lagme" > /tmp/config.txt
echo "TARGET_LIBRARY=libMod.so" >> /tmp/config.txt
adb push /tmp/config.txt /data/local/tmp/il2cpp_dumper_config.txt

# Trigger app
adb shell am start -n com.goo.lagme/.MainActivity

# Check logs
adb logcat | grep "hack\|load\|dump"

# Get result
adb pull /data/data/com.goo.lagme/files/dump.cs
```

---

## ✅ Requirements

- ✓ Android device (rooted)
- ✓ Magisk installed
- ✓ Zygisk enabled
- ✓ ADB access
- ✓ Target app with IL2CPP backend
- ✓ Zygisk-Il2CppDumper source

---

## 🐛 Troubleshooting

### "libMod.so not found"
```cpp
// Increase retry attempts in hack.cpp line 23
for (int i = 0; i < 20; i++) {  // was 10
    sleep(2);                    // was 1
}
```

### Config file not read
```bash
# Verify file exists and format is correct
adb shell cat /data/local/tmp/il2cpp_dumper_config.txt
# Should show: PACKAGE_NAME=com.goo.lagme
```

### No output file created
```bash
# Check permissions and location
adb shell ls -la /data/data/com.goo.lagme/files/
```

---

## 📊 Supported Libraries

✓ libil2cpp.so (default)  
✓ libMod.so (custom)  
✓ libUnity.so (Unity native)  
✓ Any native .so file in the app  

---

## 🔄 How It Works

```
1. App Launch
   ↓
2. Read Config File (/data/local/tmp/il2cpp_dumper_config.txt)
   ├─ PACKAGE_NAME=com.goo.lagme
   └─ TARGET_LIBRARY=libMod.so
   ↓
3. Check Package Name Match
   ├─ Match → Activate dumping
   └─ No match → Unload module
   ↓
4. Wait for Target Library Load
   └─ xdl_open(TARGET_LIBRARY)
   ↓
5. Extract IL2CPP Metadata
   ↓
6. Save to /data/data/com.goo.lagme/files/dump.cs
```

---

## 📝 File Changes Summary

```
NEW:
  + config.h (config file reader)
  + integrate.sh (auto-integration script)
  + Documentation (README, guides, etc.)

MODIFIED:
  ~ main.cpp (load config, detect package)
  ~ hack.cpp (dynamic library loading)
  ~ hack.h (function signatures)

UNCHANGED:
  - All other files remain the same
  - il2cpp_dump.cpp untouched
  - xdl files untouched
```

---

## 🚀 Next Steps

1. Read `README.md` or `QUICK_START.md`
2. Run `./integrate.sh .` or manual merge
3. Build: `./gradlew clean build`
4. Create config file
5. Deploy and test
6. Retrieve dump.cs

---

## 💡 Advanced Usage

### Dump Multiple Libraries
```bash
# First: config with libMod.so
echo "PACKAGE_NAME=com.goo.lagme" > /tmp/config1.txt
echo "TARGET_LIBRARY=libMod.so" >> /tmp/config1.txt
adb push /tmp/config1.txt /data/local/tmp/il2cpp_dumper_config.txt
adb shell am start -n com.goo.lagme/.MainActivity
sleep 10
adb pull /data/data/com.goo.lagme/files/dump.cs ~/dump_mod.cs

# Second: config with libUnity.so
echo "PACKAGE_NAME=com.goo.lagme" > /tmp/config2.txt
echo "TARGET_LIBRARY=libUnity.so" >> /tmp/config2.txt
adb push /tmp/config2.txt /data/local/tmp/il2cpp_dumper_config.txt
adb shell am start -n com.goo.lagme/.MainActivity
sleep 10
adb pull /data/data/com.goo.lagme/files/dump.cs ~/dump_unity.cs
```

### Customize Retry Attempts
Edit `module/src/main/cpp/hack.cpp`:
```cpp
// Line 23: Change loop count
for (int i = 0; i < 20; i++) {  // Increase from 10
    sleep(2);                    // Increase from 1
}
```

---

## 📄 License

Based on original [Zygisk-Il2CppDumper](https://github.com/Perfare/Zygisk-Il2CppDumper)

Modified version with dynamic configuration support.

---

## 🎯 Key Improvements

1. **No Hardcoding** - Config from file, not code
2. **Multiple Targets** - Same build, different libraries
3. **User Friendly** - No coding knowledge needed
4. **Flexible** - Easy to modify and extend
5. **Documented** - Complete guides and examples

---

**Version:** 2.0 (Modified)  
**Status:** Ready to Use ✅  
**Last Updated:** June 2025

Start with `QUICK_START.md` or `README.md`!
