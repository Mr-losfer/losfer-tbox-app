# Noqi · 移动端（Flutter）

Android + iOS 一套 Dart 代码，原生渲染（非 WebView）。影视资源浏览 / 搜索 / 播放客户端，
接口见交付包根目录的 `APP_API.md`（LOSFER / Noqi 站点 API）。

## 结构

```
lib/
├─ main.dart            入口：Edge-to-edge、主题、RTL 方向、全局 state
├─ core/
│  ├─ api.dart          Dio 封装：统一 {code,msg} 解包、错误码中文映射
│  ├─ models.dart       Vod / Episode / Progress 等模型（全部 safe-get，缺字段不崩）
│  ├─ store.dart        AppState：配置、片源、账号、历史、类目缓存
│  ├─ i18n.dart         维吾尔语（RTL）+ 中文两套文案
│  └─ theme.dart        设计令牌（色彩 / 字号 / 圆角 / 动效曲线）
└─ ui/                  splash shell home grid_list browse search detail player profile …
```

## 开发

```bash
flutter pub get
flutter test                       # 12 项模型 / 错误码 / 进度 / 文案测试
flutter analyze                    # 应零告警
flutter run                        # 连接真机或模拟器
```

## 打包

```bash
bash scripts/build_android.sh      # arm64 / universal APK + AAB，产物在 dist/android
bash scripts/build_ipa.sh          # 仅 macOS：pod install + build ipa，产物在 build/ios/ipa
```

- applicationId / Bundle ID：`pro.noqi.app`
- 签名：`android/keystore/noqi-release.jks`（alias `noqi`，演示证书，正式发版请替换）
- 默认服务器：`https://x.noqi.pro`，App 内「设置」可改，无需重新打包

## 设计约定

- 只用一种强调色（香槟金 `#EFBF6B`），其余黑白灰；层级靠 1px 细线与 `#131318 / #1C1C23` 两级表面区分。
- 所有页面 `Directionality` 随语言切换，维吾尔语下整体镜像（不是右对齐）。
- 动效统一 `easeOutCubic`，页面 240–340ms，按压缩放 0.97；播放器 4 秒无操作隐藏控件。
