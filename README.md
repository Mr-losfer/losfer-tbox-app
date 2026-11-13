# Noqi · 影视客户端 (losfer-tbox-app)

简洁极致的影视客户端，当前版本**仅面向 Android（arm64-v8a）** 发布。

> 本项目仓库：`Mr-losfer/losfer-tbox-app`
>
> 说明：PC / Windows 端已停止开发与发布；仓库内 `windows/` 为历史源码，仅供参考。

## 功能特性

- **Android arm64-v8a**：专注于 arm64 设备的轻量安装包。
- **维吾尔语优先**：内置 10 款维吾尔语字体，设置中心一键切换，立即全局生效。
- **大厂级播放器**：手势操作（双击快进/快退、长按 2× 倍速、横向拖动 seek、竖向调节亮度/音量）、锁屏、自动连播、选集、多线路、画面比例。
- **投屏（DLNA）**：纯 Dart 实现，无需第三方 SDK，手机一键投到电视。
- **内置更新**：设置页从 GitHub Releases 检测新版本，**优先走 `gh-proxy.com` 代理，失败自动回退直连**。
- **第三方下载服务**：设置中心可配置自定义下载接口（Base URL + API Key，兼容 Media Super 风格 REST API）；详情页与播放器页均可**选集下载**，下载列表实时显示进度，完成后可在 App 内直接播放。
- **安全加固**：防截屏/录屏、代理/VPN 检测与提醒。
- **跳过详情页**：关闭后点击影片列表直接进入播放。

## 目录结构

```
losfer-tbox-app/
├── mobile/        # Flutter 工程（Android）
├── windows/       # 历史 Windows 工程（已停止开发）
└── .github/       # CI：仅构建 Android arm64-v8a
```

## 后端接口

客户端默认连接：`http://test3.noqi.pro:8090`（可在设置中心修改）。

## 构建（Android arm64-v8a）

```bash
cd mobile
flutter pub get
flutter build apk --release --target-platform android-arm64
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

## 内置更新说明

客户端在「设置 → 检查更新」中请求：

```
https://api.github.com/repos/Mr-losfer/losfer-tbox-app/releases/latest
```

- 检测与下载地址**优先 `https://gh-proxy.com/` 代理**，代理不可用时自动回退直连。
- 比对语义化版本号，发现新版本后跳转到代理加速的 APK 下载地址。

## 许可证

仅供学习与交流使用。
