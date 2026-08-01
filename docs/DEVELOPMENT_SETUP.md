# Development Environment

## Pinned tools

- Godot `4.6.2.stable`:
  `C:\Users\eMich\source\Godot\Godot_v4.6.2-stable_win64.exe`
- Eclipse Temurin OpenJDK `17.0.20`.
- Android SDK: `C:\Users\eMich\AppData\Local\Android\Sdk`.
- Android Platform 35, Build Tools 35.0.1, Platform Tools 37.0.1.
- NDK 28.1.13356709 and CMake 3.10.2.4988404.
- Godot Android debug and release templates for 4.6.2.

Persistent user variables are `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, with Java,
platform-tools, and command-line tools on user `PATH`. Restart terminals after changing them.

Verify without modifying the project:

```powershell
powershell -ExecutionPolicy Bypass -File tools/check-environment.ps1
```

Run/import/test:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-tests.ps1
```

No Android emulator is required. Physical device testing uses Developer Options, USB debugging,
and `adb devices`; authorize the computer prompt on the device before installation.
