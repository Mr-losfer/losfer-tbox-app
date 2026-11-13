// QA 专用入口：只用于截图核对设置页 / 字体面板，不参与正式构建。
//   flutter build web -t lib/qa_main.dart --dart-define=QA=font
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/store.dart';
import 'core/theme.dart';
import 'ui/font_sheet.dart';
import 'ui/player_preview.dart';
import 'ui/settings.dart';

const _qa = String.fromEnvironment('QA', defaultValue: 'settings');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ChangeNotifierProvider(
    create: (_) => AppState(prefs)..boot(),
    child: const _QaApp(),
  ));
}

class _QaApp extends StatelessWidget {
  const _QaApp();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(fontFamily: st.font),
      builder: (context, child) => Directionality(
        textDirection: st.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _QaHome(),
    );
  }
}

class _QaHome extends StatelessWidget {
  const _QaHome();

  @override
  Widget build(BuildContext context) {
    if (_qa == 'font') {
      WidgetsBinding.instance.addPostFrameCallback((_) => showFontSheet(context));
    }
    if (_qa.startsWith('player')) return PlayerSkinPreview(mode: _qa);
    return const SettingsPage();
  }
}

