# 📊 Visual Guide - Cách hoạt động chi tiết

## 1️⃣ Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│          Android Device (Rooted)                    │
├─────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────┐   │
│  │  Magisk + Zygisk                            │   │
│  └──────────────────────────────────────────────┘   │
│                       ↓                              │
│  ┌──────────────────────────────────────────────┐   │
│  │  Zygisk Il2CppDumper Module (Modified)      │   │
│  │  ├─ config.h (read config)                  │   │
│  │  ├─ main.cpp (load config on startup)       │   │
│  │  ├─ hack.cpp (dynamic library loading)      │   │
│  │  └─ il2cpp_dump.cpp (extract metadata)      │   │
│  └──────────────────────────────────────────────┘   │
│                       ↓                              │
│  ┌──────────────────────────────────────────────┐   │
│  │  Target App (e.g., com.goo.lagme)           │   │
│  │  ├─ libMod.so  ← Dump this!                 │   │
│  │  ├─ libUnity.so                             │   │
│  │  └─ libil2cpp.so                            │   │
│  └──────────────────────────────────────────────┘   │
│                       ↓                              │
│  ┌──────────────────────────────────────────────┐   │
│  │  Output: /data/data/com.goo.lagme/files/    │   │
│  │  └─ dump.cs (extracted metadata)            │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## 2️⃣ Data Flow Diagram

```
┌─────────────────┐
│  App Startup    │
└────────┬────────┘
         │
         ↓
┌──────────────────────────────┐
│  Check Package Name          │
│  "com.goo.lagme"             │
└────────┬─────────────────────┘
         │
         ├─── Match?
         │
    YES │                NO
         │                ├───→ Unload Module
         ↓
┌──────────────────────────────┐
│  Load Config File            │
│  /data/local/tmp/config.txt  │
└────────┬─────────────────────┘
         │
         ├─ PACKAGE_NAME=com.goo.lagme
         ├─ TARGET_LIBRARY=libMod.so
         │
         ↓
┌──────────────────────────────┐
│  Activate Hack Module        │
└────────┬─────────────────────┘
         │
         ↓
┌──────────────────────────────┐
│  Wait for Library to Load    │
│  xdl_open("libMod.so")       │
│  (retry 10 times, 1s each)   │
└────────┬─────────────────────┘
         │
    Load? ├─ Yes ─┐
         │        │
    No   │        ↓
         │   ┌────────────────┐
         │   │  Init il2cpp   │
         │   │  API functions │
         │   └────────┬───────┘
         │            │
         ↓            ↓
    ┌────────────┐ ┌──────────────────────┐
    │  Log Error │ │  Dump Metadata       │
    │  Not found │ │  ├─ Assemblies       │
    └────────────┘ │  ├─ Classes          │
                   │  ├─ Methods          │
                   │  └─ Fields           │
                   └────────────┬─────────┘
                                │
                                ↓
                   ┌─────────────────────────┐
                   │  Save to dump.cs        │
                   │  /data/data/            │
                   │  com.goo.lagme/         │
                   │  files/dump.cs          │
                   └─────────────────────────┘
```

---

## 3️⃣ Config File Format Examples

### Example 1: Dump libMod.so
```
/data/local/tmp/il2cpp_dumper_config.txt
═════════════════════════════════════════
PACKAGE_NAME=com.goo.lagme
TARGET_LIBRARY=libMod.so
```

### Example 2: Dump libUnity.so
```
/data/local/tmp/il2cpp_dumper_config.txt
═════════════════════════════════════════
PACKAGE_NAME=com.example.game
TARGET_LIBRARY=libUnity.so
```

### Example 3: Dump libil2cpp.so (default)
```
/data/local/tmp/il2cpp_dumper_config.txt
═════════════════════════════════════════
PACKAGE_NAME=com.unity.game
TARGET_LIBRARY=libil2cpp.so
```

---

## 4️⃣ File Structure Changes

### BEFORE (Old version)
```
main.cpp
├─ GamePackageName = "com.game.packagename" [HARDCODED]
└─ hack_prepare(game_data_dir, data, length)
   └─ hack_start(game_data_dir)
      └─ xdl_open("libil2cpp.so", 0) [HARDCODED]
         └─ il2cpp_dump(game_data_dir)
```

### AFTER (New version)
```
config.h [NEW]
├─ ReadConfig()
└─ Config {
   ├─ packageName (from file)
   └─ targetLibrary (from file)
   }

main.cpp [MODIFIED]
├─ config = ReadConfig()
└─ hack_prepare(game_data_dir, data, length, target_library)

hack.cpp [MODIFIED]
└─ hack_start(game_data_dir, target_library)
   └─ xdl_open(target_library, 0) [DYNAMIC]
      └─ il2cpp_dump(game_data_dir)
```

---

## 5️⃣ Parameter Passing Flow

```
┌──────────────────────┐
│ main.cpp             │
│ MyModule::onLoad()   │
│ config=ReadConfig()  │
└────────────┬─────────┘
             │
             ├─ config.packageName = "com.goo.lagme"
             └─ config.targetLibrary = "libMod.so"
                     │
                     ↓
        ┌──────────────────────────┐
        │ preSpecialize()          │
        │ if (strcmp(package_name, │
        │     config.packageName)) │
        └────────┬─────────────────┘
                 │
                 ├─ target_library = "libMod.so"
                 │
                 ↓
        ┌──────────────────────────┐
        │ postAppSpecialize()      │
        │ hack_thread(hack_prepare,│
        │   game_data_dir,         │
        │   data,                  │
        │   length,                │
        │   target_library) ← PASS │
        └────────┬─────────────────┘
                 │
                 ↓
        ┌──────────────────────────┐
        │ hack_prepare()           │
        │   target_library ← USE   │
        │   hack_start(             │
        │     game_data_dir,        │
        │     target_library)       │
        └────────┬─────────────────┘
                 │
                 ↓
        ┌──────────────────────────┐
        │ hack_start()             │
        │   xdl_open(              │
        │     target_library, 0) ← │
        │   Dump libMod.so!        │
        └──────────────────────────┘
```

---

## 6️⃣ Sequence Diagram

```
Time  Device          App              Module           File
│
├──→  [Boot]
│
├──→  [Startup]
│     │
│     ├──→ App Launch: com.goo.lagme
│                      │
│                      ├────────────→ MyModule::onLoad()
│                      │             ReadConfig() [returns Config]
│                      │
│                      ├────────────→ preAppSpecialize()
│                      │             Check package name ✓
│                      │             Copy target_library
│                      │
│                      ├────────────→ postAppSpecialize()
│                      │             Launch hack_thread
│                      │
│                      ├────────────→ hack_prepare()
│                      │             hack_start("libMod.so")
│                      │
│                      ├────────────→ xdl_open("libMod.so")
│                      │             ├─ Retry 1... ✗
│                      │             ├─ Retry 2... ✗
│                      │             ├─ Retry 3... ✗
│                      │             ├─ Retry 4... ✓
│                      │
│                      ├────────────→ il2cpp_api_init(handle)
│                      │
│                      ├────────────→ il2cpp_dump()
│                      │             Extract metadata
│                      │             Write to file ────→ dump.cs
│                      │             "dump done!"
```

---

## 7️⃣ Key Differences (Old vs New)

| Aspect | Old | New |
|--------|-----|-----|
| **Package Name** | `#define GamePackageName` | `config.packageName` (from file) |
| **Target Library** | `"libil2cpp.so"` (hardcoded) | `config.targetLibrary` (from file) |
| **Config Method** | Edit code + rebuild | Edit text file |
| **Multiple Targets** | Rebuild each time | Create new config |
| **Flexibility** | Low (code change needed) | High (file-based) |
| **User Experience** | Developer | End-user friendly |

---

## 8️⃣ Example Workflow

### Scenario: Dump libMod.so from com.goo.lagme

```
┌─────────────────────────────────────────────────────┐
│ STEP 1: Create config file                          │
├─────────────────────────────────────────────────────┤
│ $ adb shell                                         │
│ # cat > /data/local/tmp/il2cpp_dumper_config.txt   │
│ PACKAGE_NAME=com.goo.lagme                         │
│ TARGET_LIBRARY=libMod.so                           │
│ ^D                                                  │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ STEP 2: Install module                              │
├─────────────────────────────────────────────────────┤
│ $ adb install app-debug.apk                         │
│ $ adb reboot                                        │
│ [Wait for reboot]                                   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ STEP 3: Trigger app                                 │
├─────────────────────────────────────────────────────┤
│ $ adb shell am start -n com.goo.lagme/.MainActivity│
│ [App launches]                                      │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ STEP 4: Monitor logs                                │
├─────────────────────────────────────────────────────┤
│ $ adb logcat | grep "detect game\|loaded\|dump"    │
│                                                     │
│ detect game: com.goo.lagme                         │
│ Attempting to load library: libMod.so              │
│ Successfully loaded libMod.so                      │
│ ... [dumping process] ...                          │
│ dump done!                                          │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ STEP 5: Retrieve dump file                          │
├─────────────────────────────────────────────────────┤
│ $ adb pull /data/data/com.goo.lagme/files/dump.cs  │
│ $ file dump.cs                                      │
│ dump.cs: ASCII text, with very long lines          │
│ $ wc -l dump.cs                                     │
│ 5000+ lines of C# code                             │
└─────────────────────────────────────────────────────┘
                        ✅ SUCCESS!
```

---

## 9️⃣ Common Patterns

### Pattern 1: Single Library
```
Config → One package + one library → Dump once
```

### Pattern 2: Multiple Sequential
```
Config 1 → Dump lib1 → Save → 
Config 2 → Dump lib2 → Save
```

### Pattern 3: Bulk Dump
```
For each library:
  Create config
  Trigger app
  Wait for completion
  Save result
```

---

## 🔟 Debugging Flowchart

```
┌─────────────────┐
│ Dump Not Working │
└────────┬────────┘
         │
         ├─→ "detect game" in logs?
         │   ├─ NO: Package name mismatch
         │   │     └─ Fix: Check config + app name
         │   └─ YES:
         │       │
         │       ├─→ "loaded library" in logs?
         │       │   ├─ NO: Library not found
         │       │   │     └─ Fix: Increase retry time
         │       │   │          or check library name
         │       │   └─ YES:
         │       │       │
         │       │       ├─→ "dump done!" in logs?
         │       │       │   ├─ NO: Dump failed
         │       │       │   │     └─ Fix: Check il2cpp format
         │       │       │   └─ YES:
         │       │       │       │
         │       │       │       └─→ File exists?
         │       │       │           ├─ NO: Permission issue
         │       │       │           │     └─ Fix: Check /data/data/
         │       │       │           │           permissions
         │       │       │           └─ YES: ✅ Success!
```

---

**Color Legend:**
- 🟢 GREEN = Success path
- 🔴 RED = Error path
- 🟡 YELLOW = Check point
