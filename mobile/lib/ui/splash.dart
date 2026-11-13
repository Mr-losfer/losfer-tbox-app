import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/store.dart';
import '../core/theme.dart';
import 'server_sheet.dart';
import 'shell.dart';
import 'widgets.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final st = context.read<AppState>();
    final watch = Stopwatch()..start();
    var timedOut = false;
    try {
      // 看门狗：网络再差也不让启动页无限转圈
      await st.boot().timeout(const Duration(seconds: 11));
    } on TimeoutException {
      timedOut = true;
    }
    if (watch.elapsedMilliseconds < 1100) {
      await Future.delayed(Duration(milliseconds: 1100 - watch.elapsedMilliseconds));
    }
    if (!mounted) return;
    if (timedOut && st.bootError == null) {
      st.bootError = '连接超时，请检查网络或换个服务器地址';
    }
    if (st.bootError != null) {
      setState(() => _failed = true);
      return;
    }
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: const ShellPage()),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    ));
  }

  Future<void> _retry() async {
    setState(() => _failed = false);
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          // ambient glow
          Positioned(
            top: -140,
            left: 0,
            right: 0,
            child: Container(
              height: 460,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [C.accent.withValues(alpha: .07), Colors.transparent],
                  radius: .6,
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_c.value.clamp(0.0, 1.0));
                    return Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: .82 + .18 * t,
                        child: Column(
                          children: [
                            const BrandMark(size: 74),
                            const SizedBox(height: 26),
                            Text(st.siteName.toUpperCase(),
                                style: T.brand.copyWith(fontSize: 22, letterSpacing: 9, height: 1.1)),
                            const SizedBox(height: 12),
                            Container(width: 28, height: 1, color: C.accent.withValues(alpha: .5)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                        const SizedBox(height: 54),
                        if (_failed)
                          _FailPanel(
                            message: st.bootError ?? '',
                            onRetry: _retry,
                            onServer: () => showServerSheet(context),
                            retryLabel: s.t('retry'),
                            serverLabel: s.t('server'),
                          )
                        else
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 116,
                                height: 2,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: const LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: C.surfaceHi,
                                    valueColor: AlwaysStoppedAnimation<Color>(C.accent),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                st.base.replaceFirst(RegExp(r'^https?://'), ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: T.tiny.copyWith(fontSize: 10.5, letterSpacing: 1.1, color: C.faint),
                              ),
                            ],
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailPanel extends StatelessWidget {
  const _FailPanel({
    required this.message,
    required this.onRetry,
    required this.onServer,
    required this.retryLabel,
    required this.serverLabel,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onServer;
  final String retryLabel;
  final String serverLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 26, color: C.faint),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: T.bodySub.copyWith(fontSize: 13, height: 1.7)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: GhostButton(label: serverLabel, onTap: onServer, height: 46, icon: Icons.dns_outlined)),
              const SizedBox(width: 10),
              Expanded(child: GoldButton(label: retryLabel, onTap: onRetry, height: 46)),
            ],
          ),
        ],
      ),
    );
  }
}
