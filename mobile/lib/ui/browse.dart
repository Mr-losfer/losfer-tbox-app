import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'grid_list.dart';
import 'search.dart';
import 'source_sheet.dart';
import 'widgets.dart';

/// 片库 tab
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> with AutomaticKeepAliveClientMixin {
  List<VodClass> _classes = const [];
  String _classId = '';
  String _source = '';
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    if (st.sourceCode.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final bundle = await st.classes(st.sourceCode);
      if (!mounted) return;
      setState(() {
        _classes = bundle.classes;
        _source = st.sourceCode;
        _classId = bundle.classes.isEmpty ? '' : bundle.classes.first.id;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final st = context.watch<AppState>();
    final s = st.s;
    if (!_loading && _source != st.sourceCode && st.sourceCode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(C.pad, 10, C.pad, 14),
              child: Row(
                children: [
                  Expanded(child: Text(s.t('browse'), style: T.h1.copyWith(fontSize: 23))),
                  IconPill(icon: Icons.search_rounded, size: 36, onTap: () => Navigator.of(context).push(SearchPage.route())),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => showSourceSheet(context),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: C.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 82),
                            child: Text(st.source?.name ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.cap.copyWith(fontSize: 11.5, color: C.text, fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: C.faint),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_classes.isNotEmpty)
              ChipRow(
                items: _classes.map((e) => e.name).toList(),
                index: _classes.indexWhere((e) => e.id == _classId).clamp(0, _classes.length - 1),
                onSelect: (i) => setState(() => _classId = _classes[i].id),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: LoadingView())
                  : VodFeed(
                      key: ValueKey('$_source:$_classId'),
                      locked: !st.canPlay(st.source),
                      emptyText: s.t('empty'),
                      fetch: (pg) => st.api.list(_source, t: _classId, pg: pg),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类列表页（带分类切换）
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key, required this.title, required this.classId, required this.classes});
  final String title;
  final String classId;
  final List<VodClass> classes;

  static Route<void> route({required String title, required String classId, required List<VodClass> classes}) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, a, _) => CategoryPage(title: title, classId: classId, classes: classes),
      transitionsBuilder: (_, a, _, child) {
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late String _classId = widget.classId.isEmpty && widget.classes.isNotEmpty ? widget.classes.first.id : widget.classId;

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(C.pad, 8, C.pad, 10),
              child: Row(
                children: [
                  IconPill(icon: Icons.arrow_back_rounded, size: 36, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(widget.title, style: T.h2)),
                ],
              ),
            ),
            if (widget.classes.isNotEmpty)
              ChipRow(
                items: widget.classes.map((e) => e.name).toList(),
                index: widget.classes.indexWhere((e) => e.id == _classId).clamp(0, widget.classes.length - 1),
                onSelect: (i) => setState(() => _classId = widget.classes[i].id),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: VodFeed(
                key: ValueKey('cat:$_classId'),
                locked: !st.canPlay(st.source),
                emptyText: s.t('empty'),
                fetch: (pg) => st.api.list(st.sourceCode, t: _classId, pg: pg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
