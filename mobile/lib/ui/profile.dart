import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'auth.dart';
import 'feedback.dart';
import 'notice_sheet.dart';
import 'play_helper.dart';
import 'settings.dart';
import 'vip_sheet.dart';
import 'widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  bool _noticesLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = context.read<AppState>();
      if (st.isLoggedIn) st.refreshUser();
    });
  }

  Future<void> _openNotices() async {
    final st = context.read<AppState>();
    setState(() => _noticesLoading = true);
    try {
      final list = await st.api.notices();
      if (!mounted) return;
      setState(() => _noticesLoading = false);
      if (list.isEmpty) {
        Toast.show(context, st.s.t('empty'));
        return;
      }
      showNoticeSheet(context, list.first);
    } catch (_) {
      if (!mounted) return;
      setState(() => _noticesLoading = false);
      Toast.show(context, st.s.t('netError'));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final st = context.watch<AppState>();
    final s = st.s;
    final user = st.user;
    final history = st.history;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(C.pad, 12, C.pad, 30),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(s.t('me'), style: T.h1.copyWith(fontSize: 23)),
            const SizedBox(height: 18),
            // account card
            GestureDetector(
              onTap: user == null ? () => showAuthSheet(context) : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(C.radius),
                  border: Border.all(color: C.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: user != null && user.vipActive ? C.goldGrad : null,
                        color: user != null && user.vipActive ? null : C.surfaceHi,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.line),
                      ),
                      child: Text(
                        user == null ? 'N' : user.initial,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: user != null && user.vipActive ? const Color(0xFF17120A) : C.sub,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.displayName ?? s.t('guest'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.h3.copyWith(fontSize: 16)),
                          const SizedBox(height: 3),
                          Text(
                            user == null
                                ? s.t('loginSub')
                                : (user.email.isNotEmpty ? user.email : (user.joined.isNotEmpty ? user.joined : '—')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.cap.copyWith(fontSize: 11.5, color: C.faint),
                          ),
                        ],
                      ),
                    ),
                    if (user == null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(gradient: C.goldGrad, borderRadius: BorderRadius.circular(100)),
                        child: Text(s.t('login'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF14100A))),
                      )
                    else
                      Icon(Icons.chevron_right_rounded, size: 20, color: C.faint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // vip banner
            GestureDetector(
              onTap: () => showVipSheet(context),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(C.radius),
                  border: Border.all(color: C.accent.withValues(alpha: .22)),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [C.accent.withValues(alpha: .13), C.accent.withValues(alpha: .03)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(gradient: C.goldGrad, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.workspace_premium_rounded, size: 19, color: Color(0xFF17120A)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user != null && user.vipActive ? s.t('vipActive') : s.t('vipOpen'),
                            style: T.h3.copyWith(fontSize: 14, color: C.accent),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user != null && user.vipActive
                                ? '${user.daysLeft} ${s.t('daysLeft')}${user.vipUntil != null ? ' · ${user.vipUntil}' : ''}'
                                : s.t('vipTip'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.tiny.copyWith(fontSize: 10.5, color: C.sub),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 19, color: C.accent),
                  ],
                ),
              ),
            ),
            if (history.isNotEmpty) ...[
              SectionHead(title: s.t('history'), pad: 0, trailing: GestureDetector(
                onTap: () => st.clearHistory(),
                child: Text(s.t('clear'), style: T.tiny.copyWith(fontSize: 10.5)),
              )),
              SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _HistoryCard(progress: history[i]),
                ),
              ),
            ],
            SectionHead(title: s.t('account'), pad: 0),
            _MenuGroup(items: [
              _MenuItem(Icons.workspace_premium_rounded, s.t('vipPlans'), () => showVipSheet(context)),
              _MenuItem(Icons.campaign_outlined, s.t('notice'), _openNotices, busy: _noticesLoading),
              _MenuItem(Icons.chat_bubble_outline_rounded, s.t('feedback'), () {
                if (st.user == null) {
                  showAuthSheet(context);
                  return;
                }
                Navigator.of(context).push(FeedbackPage.route());
              }),
              _MenuItem(Icons.tune_rounded, s.t('settings'), () => Navigator.of(context).push(SettingsPage.route())),
            ]),
            if (user != null) ...[
              const SizedBox(height: 12),
              _MenuGroup(items: [
                _MenuItem(Icons.logout_rounded, s.t('logout'), () async {
                  final ok = await _confirm(context, s.t('logout'), s.t('quit'));
                  if (ok) {
                    await st.logout();
                    if (context.mounted) Toast.show(context, s.t('quit'));
                  }
                }, danger: true),
              ]),
            ],
            const SizedBox(height: 26),
            Center(
              child: Column(
                children: [
                  const BrandMark(size: 26),
                  const SizedBox(height: 10),
                  Text('Noqi 1.0.0', style: T.tiny.copyWith(fontSize: 10, letterSpacing: 1.6)),
                  const SizedBox(height: 3),
                  Text(s.t('aboutBody'), style: T.tiny.copyWith(fontSize: 10, color: C.faint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String ok) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: T.h3),
        content: Text(context.read<AppState>().s.t('ok'), style: T.bodySub.copyWith(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.read<AppState>().s.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok, style: const TextStyle(color: C.accent))),
        ],
      ),
    );
    return r ?? false;
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        openVod(
          context,
          Vod(id: progress.vodId, name: progress.name, pic: progress.pic),
          site: progress.site,
        );
      },
      child: SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 108,
                height: 148,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(url: progress.pic),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress.ratio,
                        minHeight: 2.5,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(C.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(progress.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.cap.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.onTap, {this.busy = false, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;
  final bool danger;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Padding(padding: const EdgeInsets.only(left: 46), child: Container(height: 1, color: C.lineSoft)),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                child: Row(
                  children: [
                    Icon(items[i].icon, size: 17, color: items[i].danger ? C.danger : C.sub),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(items[i].label,
                          style: T.body.copyWith(fontSize: 13.5, color: items[i].danger ? C.danger : C.text)),
                    ),
                    if (items[i].busy)
                      const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.5, color: C.faint))
                    else
                      const Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
