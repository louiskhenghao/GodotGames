# 环境与平台构建

所有命令在 monorepo 根目录运行。先安装 Godot **4.5.1 标准版**、同版本 export templates、Python 3.9+。设置 `GODOT_BIN` 或把 `godot` 加到 PATH，然后 `python3 tools/workspace.py sync`。应用标识符与签名按游戏单独配置；密钥留在本机或 CI secrets。

## 网页与 Mac 试玩

```sh
python3 tools/workspace.py build RingRush
```

模板未安装到默认目录时：

```sh
python3 tools/workspace.py --godot /path/to/Godot build RingRush --templates /path/to/templates
```

该目录应包含 `web_nothreads_release.zip` 和 `macos.zip`。脚本恢复临时模板路径，打包说明与许可证，并生成 `builds/RingRush/SHA256SUMS.txt`。结果为 `builds/RingRush/mac/RingRush.zip` 及 `builds/RingRush/RingRush-Web-Playtest.zip`。

Mac 预设使用 Universal 2（Intel/Apple Silicon）和 ad-hoc 签名，适合目前的试玩，但未 notarize。公开分发前在独立正式预设中配置 Developer ID、notarization，确认通过后再分发。[Godot macOS 导出说明](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_macos.html)。

## Android：先 APK 试玩，再 AAB 上架

1. 安装 OpenJDK 17 和 Android SDK。在 Godot Editor Settings → Export → Android 配置 Java SDK Path 与 Android SDK Path。
2. Godot 4.5 文档列出 Platform/Build Tools 35、platform-tools、CMake 3.10.2.4988404、NDK 28.1.13356709；按该版本文档安装匹配依赖。提交商店前另行核对当时的 target SDK 要求。[官方环境步骤](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html)。
3. 打开 `games/RingRush/project.godot`，Project → Install Android Build Template。
4. Export 中将现有 `Android` 预设复制为 **Android APK**，把 Gradle Build → Export Format 设为 APK，输出设为 `../../builds/RingRush/android/ring-rush.apk`。原 `Android` 保持 AAB。
5. 替换 `com.example.ringrush`。APK 开发测试使用 debug 签名；发布 AAB 配置自己的 release keystore。不要提交密码或签名文件。

```sh
mkdir -p builds/RingRush/android
godot --headless --path games/RingRush --export-debug 'Android APK' ../../builds/RingRush/android/ring-rush.apk
adb install -r builds/RingRush/android/ring-rush.apk
# release signing 配置完成后：
godot --headless --path games/RingRush --export-release Android ../../builds/RingRush/android/ring-rush.aab
```

`Android APK` 是上述步骤中自行复制配置的预设。教程不会假装它已存在。先在实体机测试触控、暂停恢复、密集战斗帧时间及音频中断，再上传 AAB。

## iOS

使用 macOS、Xcode 和匹配 Godot 模板。填写 iOS 预设的 bundle identifier 与自己的 Apple Team ID，导出 Xcode 项目，在 Xcode 选择开发团队、设备并运行；分发时 Archive 后上传 TestFlight。Godot 4.5 需要实体设备验证该项目。[官方 iOS 步骤](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_ios.html)。

```sh
mkdir -p builds/RingRush/ios
godot --headless --path games/RingRush --export-release iOS ../../builds/RingRush/ios/RingRush.zip
```

签名、SDK 和原生插件需要本机先配置；本仓库提供预设与教程，目前没有已验证的 APK/IPA 或正式商店版本。正式预设应移除 `playtest` feature，并接入真实 commerce provider；默认未配置时交易返回不可用。
