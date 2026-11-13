# Noqi · Windows 端（.NET 6 + Avalonia 11）

原生桌面客户端：Avalonia 在 Skia 上直接渲染，UI 全部用 C# 构建（无 XAML），
播放走 libVLC（HLS / AES-128 直连），不是 Electron、也不是 WebView 外壳。

## 构建

```powershell
dotnet restore
dotnet run                                    # 开发调试
powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1   # 出 zip 发行包
```

要求：.NET 6 SDK（或更高）、Windows 10 1809+ / 11 x64。
在 Linux / macOS 上交叉发布时加 `-p:EnableWindowsTargeting=true`。

## 结构

```
Program.cs        入口（Avalonia AppBuilder、Core.Initialize 初始化 libVLC）
App.cs            应用生命周期
MainWindow.cs     自绘窗口：40px 标题栏 + 216px 侧边导航 + 内容区
Page.cs           页面基类 + 复用控件（海报卡、区块标题）
Pages.cs          HomePage / LibraryPage / SearchPage
Detail.cs         DetailPage（详情 + 相关推荐）/ ProfilePage（账号 + 套餐）
Dialogs.cs        LoginDialog / SettingsDialog
PlayerWindow.cs   播放窗口：libVLC + VideoView + 进度条，快捷键 Esc/Space/←/→/F/F11/↑/↓
Api.cs            接口层与全部模型（与移动端一一对应）
Store.cs          状态与本地持久化（%APPDATA%\Noqi）
Theme.cs          设计令牌 + Segoe MDL2 图标 + 字体（内置 Noto Sans Arabic）
Assets/           应用图标、字体
packaging/        发行包内附的使用说明
```

## 平台约定

- 播放内核由 `libvlc\win-x64\` 提供，必须与 `Noqi.exe` 同级；发行版已剔除 win-x86 内核。
- 界面文案以中文为主，影片标题/简介按接口原样（维吾尔语）显示并使用内置 Arabic 字体。
- 数据目录：`%APPDATA%\Noqi`（服务器地址、片源、账号、观看进度）。
