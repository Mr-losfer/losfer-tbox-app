import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/security.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'ui/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final prefs = await SharedPreferences.getInstance();
  // 防截屏 / 录屏（默认开），必须在首帧前下发，避免启动页被截
  await Security.setSecureScreen(prefs.getBool('secure_screen') ?? true);
  runApp(ChangeNotifierProvider(create: (_) => AppState(prefs), child: const NoqiApp()));
}

class NoqiApp extends StatelessWidget {
  const NoqiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return MaterialApp(
      title: 'Noqi',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(fontFamily: st.font),
      locale: Locale(st.lang),
      builder: (context, child) {
        return Directionality(
          textDirection: st.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2, child: child ?? const SizedBox.shrink()),
        );
      },
      home: const SplashPage(),
    );
  }
}
