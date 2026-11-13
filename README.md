# Noqi · 三端影视客户端 (losfer-tbox-app)

简洁极致的影视客户端，覆盖 **Android / Web（Flutter）** 与 **Windows（Avalonia .NET）** 三端。

> 本项目仓库：`Mr-losfer/losfer-tbox-app`

## 功能特性

- **三端统一观影**：Android / Web（Flutter）+ Windows（Avalonia），共享同一套后端接口。
- **维吾尔语优先**：内置 10 款维吾尔语字体，设置中心一键切换，立即全局生效。
- **大厂级播放器**：手势操作（双击快进/快退、长按 2× 倍速、横向拖动 seek、竖向调节亮度/音量）、锁屏、自动连播、选集、多线路、画面比例。
- **投屏（DLNA）**：纯 Dart 实现，无需第三方 SDK，手机一键投到电视。
- **内置更新**：设置页从 GitHub Releases 检测新版本，**优先走 `gh-proxy.com` 代理，失败自动回退直连**。
- **第三方下载服务**：设置中心可配置自定义下载接口（Base URL + API Key，兼容 Media Super 风格 REST API），支持提交下载、下载列表、进度查看、**完成后直接播放**。
- **安全加固**：防截屏/录屏、代理/VPN 检测与提醒。
- **跳过详情页**：关闭后点击影片列表直接进入播放。

## 目录结构

```
losfer-tbox-app/
├── mobile/        # Flutter 工程（Android / Web / iOS）
├── windows/       # Avalonia (.NET 6) Windows 工程
└── .github/       # CI：Android / iOS / Windows 自动构建
```

## 后端接口

客户端默认连接：`http://test3.noqi.pro:8090`（可在设置中心修改）。

## 构建

### Android / Web

```bash
cd mobile
flutter pub get
flutter build apk --release          # APK
flutter build appbundle --release    # AAB
flutter build web --release          # Web
```

### Windows

```bash
cd windows
dotnet publish -c Release -r win-x64 --self-contained true -o dist/Noqi
```

## 内置更新说明

客户端在「设置 → 检查更新」中请求：

```
https://api.github.com/repos/Mr-losfer/losfer-tbox-app/releases/latest
```

- 检测与下载地址**优先 `https://gh-proxy.com/` 代理**，代理不可用时自动回退直连。
- 比对语义化版本号，发现新版本后跳转到代理加速的 APK 下载地址。

## 许可证

仅供学习与交流使用。
