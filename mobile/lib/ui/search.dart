import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/store.dart';
import '../core/theme.dart';
import 'grid_list.dart';
import 'widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.standalone = false});
  final bool standalone;

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, a, _) => const SearchPage(standalone: true),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
      );

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.standalone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
      context.read<AppState>().pushRecent(v);
    });
  }

  void _submit(String v) {
    final q = v.trim();
    if (q.isEmpty) return;
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() => _query = q);
    context.read<AppState>().pushRecent(q);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final st = context.watch<AppState>();
    final s = st.s;
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(C.pad, 10, C.pad, 12),
              child: Row(
                children: [
                  if (widget.standalone) ...[
                    IconPill(icon: Icons.arrow_back_rounded, size: 36, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                  ],
                  if (!widget.standalone) ...[
                    Text(s.t('search'), style: T.h1.copyWith(fontSize: 23)),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: C.line),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 13),
                          const Icon(Icons.search_rounded, size: 18, color: C.faint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              onChanged: _onChanged,
                              onSubmitted: _submit,
                              textInputAction: TextInputAction.search,
                              style: T.body.copyWith(fontSize: 13.5),
                              cursorHeight: 16,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                hintText: s.t('searchHint'),
                                hintStyle: T.cap.copyWith(color: C.faint, fontSize: 13),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          ValueListenableBuilder(
                            valueListenable: _ctrl,
                            builder: (context, v, _) {
                              if (v.text.isEmpty) return const SizedBox(width: 12);
                              return GestureDetector(
                                onTap: () {
                                  _ctrl.clear();
                                  setState(() => _query = '');
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(Icons.close_rounded, size: 16, color: C.faint),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _RecentView(onPick: (v) {
                      _ctrl.text = v;
                      _ctrl.selection = TextSelection.collapsed(offset: v.length);
                      _submit(v);
                    })
                  : VodFeed(
                      key: ValueKey('search:${st.sourceCode}:$_query'),
                      locked: !st.canPlay(st.source),
                      emptyText: s.t('noResult'),
                      fetch: (pg) => st.api.search(st.sourceCode, _query, pg: pg),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentView extends StatelessWidget {
  const _RecentView({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    final recent = st.recent;
    if (recent.isEmpty) {
      return EmptyView(text: s.t('searchHint'), icon: Icons.search_rounded);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(C.pad, 8, C.pad, 30),
      children: [
        Row(
          children: [
            Expanded(child: Text(s.t('recent'), style: T.cap.copyWith(fontSize: 12, color: C.faint, letterSpacing: .4))),
            GestureDetector(
              onTap: () => st.clearRecent(),
              child: Text(s.t('clear'), style: T.cap.copyWith(fontSize: 12, color: C.faint)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final w in recent)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPick(w),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 15, color: C.faint),
                  const SizedBox(width: 11),
                  Expanded(child: Text(w, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontSize: 14))),
                  const Icon(Icons.north_west_rounded, size: 13, color: C.faint),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
