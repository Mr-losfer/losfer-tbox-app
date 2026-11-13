import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fonts.dart';

/// ─────────────────────────────────────────────────────────────
///  Noqi design tokens — near-black canvas, one warm accent.
/// ─────────────────────────────────────────────────────────────
class C {
  static const bg = Color(0xFF07070A);
  static const bgSoft = Color(0xFF0B0B0F);
  static const surface = Color(0xFF131318);
  static const surfaceHi = Color(0xFF1C1C23);
  static const line = Color(0x1FFFFFFF);
  static const lineSoft = Color(0x0FFFFFFF);

  static const text = Color(0xFFF5F5F7);
  static const sub = Color(0xFF9B9BA6);
  static const faint = Color(0xFF5E5E69);

  static const accent = Color(0xFFEFBF6B);
  static const accentDeep = Color(0xFFD79A3F);
  static const accentWash = Color(0x1FEFBF6B);

  static const vip = Color(0xFFEFBF6B);
  static const danger = Color(0xFFFF5F5F);
  static const ok = Color(0xFF4CD493);

  static const radius = 20.0;
  static const radiusSm = 12.0;
  static const pad = 18.0;

  static const goldGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8D695), Color(0xFFE3A94F)],
  );

  static const veilGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x0007070A), Color(0x9907070A), Color(0xFF07070A)],
    stops: [0.0, 0.62, 1.0],
  );

  static List<BoxShadow> get glow => [
    BoxShadow(color: accent.withValues(alpha: .22), blurRadius: 30, offset: const Offset(0, 10)),
  ];
}

/// 动效 token：一条缓动曲线族 + 三档时长（impeccable：不用回弹/弹性）
class M {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);

  static const curve = Curves.easeOutQuart;      // 进场 / 展开
  static const curveIn = Curves.easeInQuart;     // 退场
  static const curveStd = Curves.easeOutCubic;   // 常规状态切换
}

/// 三级阴影：卡片 / 浮层 / 播放器控件
class Sh {
  static const l1 = [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3))];
  static const l2 = [BoxShadow(color: Color(0x59000000), blurRadius: 26, offset: Offset(0, 10))];
  static const l3 = [BoxShadow(color: Color(0x8A000000), blurRadius: 44, offset: Offset(0, 18))];
}

/// 间距网格（4 的倍数）
class G {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class T {
  static const brand = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: 5,
    color: C.text,
    height: 1.1,
  );
  static const h1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: C.text, height: 1.45);
  static const h2 = TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.text, height: 1.45);
  static const h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text, height: 1.45);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: C.text, height: 1.7);
  static const bodySub = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: C.sub, height: 1.7);
  static const cap = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: C.sub, height: 1.5);
  static const tiny = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: C.faint, height: 1.4);
  static const num = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.accent, height: 1.2);
}

ThemeData buildTheme({String fontFamily = kDefaultFont}) {
  final scheme = ColorScheme.fromSeed(seedColor: C.accent, brightness: Brightness.dark).copyWith(
    primary: C.accent,
    secondary: C.accent,
    surface: C.surface,
    onSurface: C.text,
    error: C.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: fontFamily,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: const [kFallbackFont]),
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: C.accent,
      secondary: C.accent,
      surface: C.surface,
      onSurface: C.text,
      error: C.danger,
    ),
    splashFactory: InkSparkle.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: C.accentWash,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.accent,
      selectionColor: C.accentWash,
      selectionHandleColor: C.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.surfaceHi,
      contentTextStyle: T.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.bgSoft,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(C.radius)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.accent, linearTrackColor: C.lineSoft),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      hintStyle: T.bodySub,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.accent, width: 1.2)),
    ),
  );
}
