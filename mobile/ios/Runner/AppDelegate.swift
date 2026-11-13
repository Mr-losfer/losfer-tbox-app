import CFNetwork
import Flutter
import Foundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecurityBridge") {
      SecurityBridge.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NoqiDisplay") {
      let display = FlutterMethodChannel(
        name: "pro.noqi/display", binaryMessenger: registrar.messenger())
      display.setMethodCallHandler { call, result in
        switch call.method {
        case "getBrightness":
          result(Double(UIScreen.main.brightness))
        case "setBrightness":
          if let args = call.arguments as? [String: Any], let v = args["value"] as? Double {
            UIScreen.main.brightness = CGFloat(min(max(v, 0.02), 1.0))
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

/// iOS 侧的同类安全能力（与 Android 的 SecurityBridge 对齐）。
///  · inspect —— 系统代理 / VPN / 越狱 探测
///  · secure  —— iOS 没有 FLAG_SECURE，录屏遮挡由 Flutter 层处理，这里只做占位
///  · wipe    —— 清空剪贴板
final class SecurityBridge: NSObject {
  static let channelName = "pro.noqi/security"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "inspect":
        result(inspect())
      case "secure":
        // 录屏 / 截屏遮挡交给 Dart 侧（UIScreen.isCaptured 监听），此处无需动作
        result(nil)
      case "wipe":
        UIPasteboard.general.items = []
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func inspect() -> [String: Any] {
    var proxy = false
    var vpn = false

    if let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] {
      if let httpProxy = settings["HTTPProxy"] as? String, !httpProxy.isEmpty { proxy = true }
      if let httpsProxy = settings["HTTPSProxy"] as? String, !httpsProxy.isEmpty { proxy = true }
      // VPN 会出现在 __SCOPED__ 里，接口名通常是 tap / tun / ipsec / ppp
      if let scoped = settings["__SCOPED__"] as? [String: Any] {
        for key in scoped.keys {
          let k = key.lowercased()
          if k.contains("tap") || k.contains("tun") || k.contains("ipsec") || k.contains("ppp") {
            vpn = true
          }
        }
      }
    }

    let jailbrokenPaths = [
      "/Applications/Cydia.app",
      "/Library/MobileSubstrate/MobileSubstrate.dylib",
      "/bin/bash",
      "/usr/sbin/sshd",
      "/etc/apt",
      "/private/var/lib/apt/",
    ]
    let rooted = jailbrokenPaths.contains { FileManager.default.fileExists(atPath: $0) }
      || canOpenCydia()

    return [
      "proxy": proxy,
      "vpn": vpn,
      "rooted": rooted,
      "debuggable": isDebugBuild(),
    ]
  }

  private static func canOpenCydia() -> Bool {
    guard let url = URL(string: "cydia://package/com.example.package") else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  private static func isDebugBuild() -> Bool {
    #if DEBUG
      return true
    #else
      return false
    #endif
  }
}
