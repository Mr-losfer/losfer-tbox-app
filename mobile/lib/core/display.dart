import 'package:flutter/services.dart';

/// 屏幕亮度：Android / iOS 走原生通道；Web / 桌面没有对应能力时
/// 退化为「遮罩模拟」，播放器会盖一层黑色降低观感亮度。
class Display {
  static const _ch = MethodChannel('pro.noqi/display');

  static double _value = .6;
  static bool _native = true;
  static bool _loaded = false;

  static double get brightness => _value;

  /// false 时播放器用遮罩模拟亮度（Web / 桌面）
  static bool get native => _native;

  static Future<double> load() async {
    if (_loaded) return _value;
    _loaded = true;
    try {
      final v = await _ch.invokeMethod<double>('getBrightness');
      if (v != null && v >= 0 && v <= 1) _value = v;
    } on MissingPluginException {
      _native = false;
    } on PlatformException {
      _native = false;
    }
    return _value;
  }

  static Future<void> setBrightness(double v) async {
    _value = v.clamp(0.02, 1.0);
    if (!_native) return;
    try {
      await _ch.invokeMethod<void>('setBrightness', {'value': _value});
    } on MissingPluginException {
      _native = false;
    } on PlatformException {
      _native = false;
    }
  }
}
