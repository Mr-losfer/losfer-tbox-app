import 'dart:io';

import 'package:flutter/services.dart';

/// 客户端安全能力：防抓包（代理 / VPN 探测）、防截屏录屏、TLS 校验。
///
/// 代理与 VPN 的判定放在原生侧（Android 读系统代理 + NetworkCapabilities，
/// iOS 读 CFNetworkCopySystemProxySettings），Dart 侧只做策略与提示。
class Security {
  static const _ch = MethodChannel('pro.noqi/security');

  /// 标记当前进程是否运行在越狱 / Root 设备上（原生侧计算，失败即 false）
  static Future<SecurityReport> inspect() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('inspect');
      if (m == null) return const SecurityReport();
      return SecurityReport(
        proxy: m['proxy'] == true,
        vpn: m['vpn'] == true,
        rooted: m['rooted'] == true,
        debuggable: m['debuggable'] == true,
      );
    } on MissingPluginException {
      return const SecurityReport();
    } catch (_) {
      return const SecurityReport();
    }
  }

  /// 防截屏 / 录屏：Android 走 FLAG_SECURE，iOS 走截屏遮罩
  static Future<void> setSecureScreen(bool on) async {
    try {
      await _ch.invokeMethod('secure', on);
    } catch (_) {
      // 平台不支持（桌面 / Web）时静默忽略
    }
  }

  /// 清空剪贴板里可能残留的播放直链（投屏后调用）
  static Future<void> wipeClipboard() async {
    try {
      await _ch.invokeMethod('wipe');
    } catch (_) {}
  }

  /// 地址是否为明文 HTTP（用于 UI 提示，不做拦截，因为测试站就是明文）
  static bool isCleartext(String base) => base.trim().toLowerCase().startsWith('http://');

  /// 本机是否设置了 http_proxy 环境变量（桌面端抓包常见手法）
  static bool get envProxy {
    final env = Platform.environment;
    final p = env['http_proxy'] ?? env['HTTP_PROXY'] ?? env['https_proxy'] ?? env['HTTPS_PROXY'] ?? '';
    return p.trim().isNotEmpty;
  }
}

class SecurityReport {
  const SecurityReport({this.proxy = false, this.vpn = false, this.rooted = false, this.debuggable = false});

  final bool proxy;
  final bool vpn;
  final bool rooted;
  final bool debuggable;

  bool get risky => proxy || vpn;
  bool get tampered => rooted || debuggable;

  SecurityReport merge(SecurityReport o) => SecurityReport(
        proxy: proxy || o.proxy,
        vpn: vpn || o.vpn,
        rooted: rooted || o.rooted,
        debuggable: debuggable || o.debuggable,
      );
}
