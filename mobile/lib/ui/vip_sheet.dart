import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'auth.dart';
import 'widgets.dart';

Future<void> showVipSheet(BuildContext context, {String? reason}) async {
  final st = context.read<AppState>();
  await showAppSheet(
    context,
    child: _VipSheet(reason: reason),
  );
  // ignore: use_build_context_synchronously
  st.refreshUser();
}

class _VipSheet extends StatefulWidget {
  const _VipSheet({this.reason});
  final String? reason;

  @override
  State<_VipSheet> createState() => _VipSheetState();
}

class _VipSheetState extends State<_VipSheet> {
  late Future<List<Plan>> _future = context.read<AppState>().api.plans();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    final user = st.user;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(C.pad, 18, C.pad, 0),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(gradient: C.goldGrad, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.workspace_premium_rounded, size: 21, color: Color(0xFF17120A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('vipPlans'), style: T.h2),
                    const SizedBox(height: 3),
                    Text(
                      user != null && user.vipActive
                          ? '${s.t('vipActive')} · ${user.daysLeft} ${s.t('daysLeft')}'
                          : (widget.reason ?? s.t('vipTip')),
                      style: T.cap.copyWith(fontSize: 11.5, color: user != null && user.vipActive ? C.accent : C.sub),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, size: 20, color: C.faint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: FutureBuilder<List<Plan>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: LoadingView()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 34),
                  child: ErrorView(
                    message: snap.error is ApiError ? (snap.error as ApiError).message : '加载失败',
                    onRetry: () => setState(() => _future = context.read<AppState>().api.plans()),
                    retryLabel: s.t('retry'),
                  ),
                );
              }
              final plans = snap.data ?? const <Plan>[];
              if (plans.isEmpty) {
                return Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: EmptyView(text: s.t('empty')));
              }
              final best = plans.reduce((a, b) => (a.days / (double.tryParse(a.price) ?? 1)) >
                      (b.days / (double.tryParse(b.price) ?? 1))
                  ? a
                  : b);
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(C.pad, 0, C.pad, 24),
                children: [
                  for (final p in plans)
                    _PlanTile(
                      plan: p,
                      highlight: p.id == best.id,
                      unit: s.t('daysLeft').replaceAll(' ', ''),
                      onTap: () => _openContact(context, p),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    widget.reason ?? s.t('vipTip'),
                    style: T.tiny.copyWith(height: 1.8, color: C.faint),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _openContact(BuildContext context, Plan plan) {
    final st = context.read<AppState>();
    final url = st.config?.subscriptionUrl ?? '';
    if (url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    if (st.user == null) {
      Navigator.pop(context);
      showAuthSheet(context);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plan.title, style: T.h3),
        content: Text(
          '${plan.days} ${st.s.t('daysLeft')}  ·  ¥${plan.price}\n\n${st.s.t('contact')}:  ${st.siteName}',
          style: T.bodySub.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: plan.title));
              Navigator.pop(ctx);
            },
            child: Text(st.s.t('ok')),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.highlight, required this.unit, required this.onTap});
  final Plan plan;
  final bool highlight;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: highlight ? C.accentWash : C.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: highlight ? C.accent.withValues(alpha: .5) : C.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.title, style: T.h3.copyWith(fontSize: 14.5, color: highlight ? C.accent : C.text)),
                  const SizedBox(height: 3),
                  Text('${plan.days} $unit', style: T.tiny.copyWith(fontSize: 11)),
                ],
              ),
            ),
            Text('¥', style: T.cap.copyWith(color: C.accent, fontSize: 12)),
            const SizedBox(width: 1),
            Text(plan.price,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.accent, height: 1.1, fontFamily: 'NotoSansArabic')),
          ],
        ),
      ),
    );
  }
}
