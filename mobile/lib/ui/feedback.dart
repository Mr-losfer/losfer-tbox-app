import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'notice_sheet.dart';
import 'widgets.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, a, _) => const FeedbackPage(),
        transitionsBuilder: (_, a, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, .04), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
        ),
      );

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  Future<List<FeedItem>>? _history;

  @override
  void initState() {
    super.initState();
    _history = context.read<AppState>().api.myFeedback();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final st = context.read<AppState>();
    final s = st.s;
    final txt = _ctrl.text.trim();
    if (txt.length < 4) {
      Toast.show(context, s.t('fbHint'));
      return;
    }
    setState(() => _busy = true);
    try {
      await st.api.sendFeedback(txt);
      if (!mounted) return;
      _ctrl.clear();
      setState(() {
        _busy = false;
        _history = st.api.myFeedback();
      });
      FocusScope.of(context).unfocus();
      Toast.show(context, s.t('fbSent'));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      Toast.show(context, e.message);
    }
  }

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
                Text(s.t('feedback'), style: T.h2),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.line),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: TextField(
                controller: _ctrl,
                minLines: 4,
                maxLines: 8,
                maxLength: 500,
                style: T.body.copyWith(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: s.t('fbHint'),
                  hintStyle: T.cap.copyWith(color: C.faint, fontSize: 12.5),
                  counterStyle: T.tiny.copyWith(fontSize: 9.5),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 14),
            GoldButton(label: s.t('send'), busy: _busy, onTap: _submit, height: 48),
            const SizedBox(height: 26),
            Text(s.t('myFeedback'), style: T.h3.copyWith(fontSize: 14)),
            const SizedBox(height: 12),
            FutureBuilder<List<FeedItem>>(
              future: _history,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 26), child: Center(child: LoadingView()));
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: ErrorView(
                      message: snap.error is ApiError ? (snap.error as ApiError).message : '加载失败',
                      onRetry: () => setState(() => _history = st.api.myFeedback()),
                      retryLabel: s.t('retry'),
                    ),
                  );
                }
                final list = snap.data ?? const <FeedItem>[];
                if (list.isEmpty) {
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 22), child: EmptyView(text: s.t('empty')));
                }
                return Column(
                  children: [for (final f in list) _FeedbackTile(item: f)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>().s;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(fmtDate(item.createdAt), style: T.tiny.copyWith(fontSize: 9.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: item.replied ? C.accentWash : C.surfaceHi,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(item.replied ? s.t('replied') : s.t('pending'),
                    style: T.tiny.copyWith(fontSize: 9, color: item.replied ? C.accent : C.faint)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.content, style: T.body.copyWith(fontSize: 13)),
          if (item.reply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: C.bgSoft, borderRadius: BorderRadius.circular(9)),
              child: Text(item.reply, style: T.cap.copyWith(fontSize: 12, color: C.sub, height: 1.75)),
            ),
          ],
        ],
      ),
    );
  }
}
