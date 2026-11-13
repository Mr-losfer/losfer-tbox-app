import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/security.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'browse.dart';
import 'downloads.dart';
import 'home.dart';
import 'notice_sheet.dart';
import 'play_helper.dart';
import 'profile.dart';
import 'search.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _i = 0;
  static bool _noticeChecked = false;
  static bool _securityChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _securityGate();
      _maybeNotice();
    });
  }

  /// 代理 / VPN 检测：命中就提示，用户可以选择退出或继续（选择只在本进程内记住）
  Future<void> _securityGate() async {
    if (_securityChecked) return;
    _securityChecked = true;
    final st = context.read<AppState>();
    if (!st.blockProxy) return;
    final report = await Security.inspect();
    if (!report.risky || !mounted) return;
    final s = st.s;
    final goOn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, size: 20, color: C.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(s.t('secWarnTitle'), style: T.h3.copyWith(fontSize: 15))),
          ],
        ),
        content: Text(s.t('secWarnBody'), style: T.bodySub.copyWith(fontSize: 13, height: 1.7)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('quit'), style: T.cap.copyWith(fontSize: 12, color: C.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('secContinue'), style: T.cap.copyWith(fontSize: 12, color: C.accent)),
          ),
        ],
      ),
    );
    if (goOn != true && mounted) {
      await SystemNavigator.pop();
    }
  }

  Future<void> _maybeNotice() async {
    if (_noticeChecked) return;
    _noticeChecked = true;
    final st = context.read<AppState>();
    try {
      final list = await st.api.notices();
      if (!mounted || list.isEmpty) return;
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      showNoticeSheet(context, list.first);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    final items = [
      (Icons.play_circle_outline_rounded, Icons.play_circle_fill_rounded, s.t('home')),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, s.t('browse')),
      (Icons.search_rounded, Icons.search_rounded, s.t('search')),
      (Icons.download_outlined, Icons.download_rounded, s.t('downloadList')),
      (Icons.person_outline_rounded, Icons.person_rounded, s.t('me')),
    ];
    return Scaffold(
      backgroundColor: C.bg,
      body: IndexedStack(
        index: _i,
        children: const [HomePage(), BrowsePage(), SearchPage(), DownloadsPage(), ProfilePage()],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
        decoration: const BoxDecoration(
          color: Color(0xD907070A),
          border: Border(top: BorderSide(color: C.lineSoft)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // 切到「下载」Tab 时通知常驻列表立即刷新
                        if (i == 3) DownloadsPage.refreshTick.value++;
                        setState(() => _i = i);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: M.base,
                            curve: M.curveStd,
                            height: 2,
                            width: _i == i ? 18 : 0,
                            margin: const EdgeInsets.only(bottom: 7),
                            decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(2)),
                          ),
                          AnimatedScale(
                            scale: _i == i ? 1.08 : 1,
                            duration: M.base,
                            curve: M.curve,
                            child: Icon(
                              _i == i ? items[i].$2 : items[i].$1,
                              size: 21,
                              color: _i == i ? C.accent : C.faint,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            items[i].$3,
                            style: T.tiny.copyWith(
                              fontSize: 10,
                              color: _i == i ? C.accent : C.faint,
                              fontWeight: _i == i ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ),
        ),
      ),
    );
  }
}

/// 打开详情页 / 直接播放（供各 tab 复用，遵循「跳过详情页」开关）
void openDetail(BuildContext context, Vod vod, {String? site}) {
  openVod(context, vod, site: site);
}
