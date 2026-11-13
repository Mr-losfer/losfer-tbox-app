import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dio/dio.dart';

import '../core/api.dart';
import '../core/fonts.dart';
import '../core/security.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/update.dart';
import 'dl_sheet.dart';
import 'downloads.dart';
import 'font_sheet.dart';
import 'server_sheet.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, a, _) => const SettingsPage(),
        transitionsBuilder: (_, a, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, .04), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(C.pad, 8, C.pad, 30),
          children: [
            Row(
              children: [
                IconPill(icon: Icons.arrow_back_rounded, size: 36, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Text(s.t('settings'), style: T.h2),
              ],
            ),
            const SizedBox(height: 24),
            _Label(s.t('server')),
            _Group(children: [
              _Row(
                icon: Icons.dns_outlined,
                title: s.t('server'),
                value: st.base.replaceFirst(RegExp(r'^https?://'), ''),
                onTap: () => showServerSheet(context),
              ),
            ]),
            const SizedBox(height: 20),
            _Label(s.t('language')),
            _Group(children: [
              _Row(
                icon: Icons.translate_rounded,
                title: s.t('language'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final code in ['ug', 'zh'])
                      GestureDetector(
                        onTap: () => st.setLang(code),
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: st.lang == code ? C.accentWash : C.surfaceHi,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: st.lang == code ? C.accent.withValues(alpha: .45) : C.line),
                          ),
                          child: Text(code == 'ug' ? 'ئۇيغۇرچە' : '中文',
                              style: T.tiny.copyWith(
                                fontSize: 10.5,
                                color: st.lang == code ? C.accent : C.sub,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
            if (st.user != null) ...[
              const SizedBox(height: 20),
              _Label(s.t('account')),
              _Group(children: [
                _Row(
                  icon: Icons.password_rounded,
                  title: s.t('changePwd'),
                  onTap: () => _changePassword(context),
                ),
                _Row(
                  icon: Icons.key_rounded,
                  title: s.t('resetKey'),
                  onTap: () => _reset(context, key: true),
                ),
                _Row(
                  icon: Icons.pin_outlined,
                  title: s.t('resetToken'),
                  onTap: () => _reset(context, key: false),
                ),
              ]),
            ],
            const SizedBox(height: 20),
            _Label(s.t('appearance')),
            _Group(children: [
              _Row(
                icon: Icons.font_download_outlined,
                title: s.t('font'),
                value: fontLabelOf(st.font),
                onTap: () => showFontSheet(context),
              ),
            ]),
            const SizedBox(height: 20),
            _Label(s.t('player')),
            _Group(children: [
              _SwitchRow(
                icon: Icons.skip_next_rounded,
                title: s.t('skipDetail'),
                sub: s.t('skipDetailSub'),
                value: st.skipDetail,
                onChanged: (v) => st.setSkipDetail(v),
              ),
            ]),
            const SizedBox(height: 20),
            _Label(s.t('dlService')),
            _Group(children: [
              _SwitchRow(
                icon: Icons.cloud_download_outlined,
                title: s.t('dlEnable'),
                sub: s.t('dlEnableSub'),
                value: st.dlEnabled,
                onChanged: (v) async {
                  await st.setDlEnabled(v);
                  if (v) await showDlSheet(context);
                },
              ),
              if (st.dlEnabled)
                _Row(
                  icon: Icons.tune_rounded,
                  title: s.t('dlConfig'),
                  value: st.dlBase.isEmpty ? s.t('dlNotConfig') : st.dlBase.replaceFirst(RegExp(r'^https?://'), ''),
                  onTap: () => showDlSheet(context),
                ),
              if (st.dlEnabled)
                _Row(
                  icon: Icons.download_rounded,
                  title: s.t('downloadList'),
                  onTap: () => Navigator.of(context).push(DownloadsPage.route()),
                ),
            ]),
            const SizedBox(height: 20),
            _Label(s.t('updates')),
            _Group(children: [
              _Row(
                icon: Icons.system_update_alt_rounded,
                title: s.t('checkUpdate'),
                value: 'v${AppState.versionName}',
                onTap: () => _checkUpdate(context),
              ),
            ]),
            const SizedBox(height: 20),
            _Label(s.t('security')),
            _Group(children: [
              _SwitchRow(
                icon: Icons.shield_outlined,
                title: s.t('proxyBlock'),
                sub: s.t('proxyBlockSub'),
                value: st.blockProxy,
                onChanged: (v) => st.setBlockProxy(v),
              ),
              _SwitchRow(
                icon: Icons.screenshot_monitor_outlined,
                title: s.t('secureScreen'),
                sub: s.t('secureScreenSub'),
                value: st.secureScreen,
                onChanged: (v) {
                  st.setSecureScreen(v);
                  Security.setSecureScreen(v);
                },
              ),
            ]),
            const SizedBox(height: 20),
            _Label(s.t('history')),
            _Group(children: [
              _Row(
                icon: Icons.delete_sweep_outlined,
                title: s.t('clear'),
                onTap: () async {
                  await st.clearHistory();
                  if (context.mounted) Toast.show(context, s.t('resetDone'));
                },
              ),
            ]),
            const SizedBox(height: 26),
            Center(
              child: Column(
                children: [
                  const BrandMark(size: 26),
                  const SizedBox(height: 10),
                  Text('Noqi ${AppState.versionName} (${AppState.versionCode})', style: T.tiny.copyWith(fontSize: 10, letterSpacing: 1.4)),
                  const SizedBox(height: 3),
                  Text(st.base, style: T.tiny.copyWith(fontSize: 9.5, color: C.faint.withValues(alpha: .8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reset(BuildContext context, {required bool key}) async {
    final st = context.read<AppState>();
    final s = st.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(key ? s.t('resetKey') : s.t('resetToken'), style: T.h3),
        content: Text(s.t('vipTip'), style: T.bodySub.copyWith(fontSize: 12.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('ok'), style: const TextStyle(color: C.accent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (key) {
        await st.api.resetKey();
      } else {
        await st.api.resetPlayToken();
      }
      await st.refreshUser();
      if (context.mounted) Toast.show(context, s.t('resetDone'));
    } on ApiError catch (e) {
      if (context.mounted) Toast.show(context, e.message);
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final st = context.read<AppState>();
    final s = st.s;
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    await showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetTitle(title: s.t('changePwd'), onClose: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(C.pad, 6, C.pad, 0),
              child: Column(
                children: [
                  TextField(controller: oldCtrl, obscureText: true, style: T.body, decoration: InputDecoration(hintText: s.t('oldPwd'))),
                  const SizedBox(height: 10),
                  TextField(controller: newCtrl, obscureText: true, style: T.body, decoration: InputDecoration(hintText: s.t('newPwd'))),
                  const SizedBox(height: 18),
                  GoldButton(
                    label: s.t('save'),
                    onTap: () async {
                      if (newCtrl.text.length < 6) {
                        Toast.show(context, s.t('pwdHint'));
                        return;
                      }
                      try {
                        await st.api.changePassword(oldCtrl.text, newCtrl.text);
                        if (context.mounted) {
                          Navigator.pop(context);
                          Toast.show(context, s.t('resetDone'));
                        }
                      } on ApiError catch (e) {
                        if (context.mounted) Toast.show(context, e.message);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
    oldCtrl.dispose();
    newCtrl.dispose();
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final st = context.read<AppState>();
    final s = st.s;
    Toast.show(context, s.t('checkUpdate'));
    late UpdateInfo info;
    try {
      info = await Updater.fetchLatest();
    } on DioException catch (_) {
      if (context.mounted) Toast.show(context, s.t('dlConnError'));
      return;
    } catch (_) {
      if (context.mounted) Toast.show(context, s.t('dlConnError'));
      return;
    }
    if (!context.mounted) return;
    final newer = Updater.isNewer(info.version);
    if (!newer) {
      if (context.mounted) Toast.show(context, s.t('upToDate'));
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.system_update_alt_rounded, size: 20, color: C.accent),
            const SizedBox(width: 10),
            Expanded(child: Text('${s.t('newVersion')} v${info.version}', style: T.h3.copyWith(fontSize: 15))),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            info.notes.trim().isEmpty ? 'v${info.version}' : info.notes,
            style: T.bodySub.copyWith(fontSize: 12.5, height: 1.7),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel'), style: T.cap.copyWith(fontSize: 12, color: C.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('updateNow'), style: T.cap.copyWith(fontSize: 12, color: C.accent)),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final url = info.apkUrl;
    if (url == null || url.isEmpty) {
      // 没有 apk 资源时，跳到 Release 页面
      final releaseUrl = 'https://github.com/${AppState.updateRepo}/releases/tag/${info.tag}';
      final uri = Uri.parse(Updater.proxiedUrl(releaseUrl));
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final uri = Uri.parse(Updater.proxiedUrl(url));
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
        child: Text(text, style: T.tiny.copyWith(fontSize: 10.5, letterSpacing: 1.2, color: C.faint)),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.line),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Padding(padding: const EdgeInsets.only(left: 48), child: Container(height: 1, color: C.lineSoft)),
              children[i],
            ],
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.value, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 17, color: C.sub),
            const SizedBox(width: 13),
            Text(title, style: T.body.copyWith(fontSize: 13.5)),
            const Spacer(),
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: T.cap.copyWith(fontSize: 11.5, color: C.faint)),
              ),
            ?trailing,
            if (onTap != null) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right_rounded, size: 18, color: C.faint)),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
        child: Row(
          children: [
            Icon(icon, size: 17, color: C.sub),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.body.copyWith(fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(sub, style: T.tiny.copyWith(fontSize: 10.5, color: C.faint, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF14100A),
              activeTrackColor: C.accent,
              inactiveTrackColor: C.surfaceHi,
              inactiveThumbColor: C.faint,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
