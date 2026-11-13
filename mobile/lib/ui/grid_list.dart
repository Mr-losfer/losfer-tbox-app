import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'play_helper.dart';
import 'widgets.dart';

/// 分页影片网格：下拉刷新 + 触底加载 + 空/错状态
class VodFeed extends StatefulWidget {
  const VodFeed({
    super.key,
    required this.fetch,
    required this.emptyText,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(C.pad, 6, C.pad, 28),
    this.locked = false,
    this.columns = 3,
  });

  final Future<PageResult> Function(int page) fetch;
  final String emptyText;
  final Widget? header;
  final EdgeInsets padding;
  final bool locked;
  final int columns;

  @override
  State<VodFeed> createState() => _VodFeedState();
}

class _VodFeedState extends State<VodFeed> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final List<Vod> _items = [];
  int _page = 0;
  int _pageCount = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant VodFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fetch != widget.fetch) _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore) return;
    if (!reset && _page >= _pageCount) return;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await widget.fetch(reset ? 1 : _page + 1);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(res.items);
        _page = res.page;
        _pageCount = res.pageCount <= 0 ? 1 : res.pageCount;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset) _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset) _error = '网络连接失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final st = context.read<AppState>();
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      color: C.accent,
      backgroundColor: C.surface,
      edgeOffset: 8,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header!),
          if (_loading)
            SliverPadding(
              padding: widget.padding,
              sliver: SliverGrid(
                gridDelegate: _delegate(),
                delegate: SliverChildBuilderDelegate(
                  (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Shimmer(radius: 13)),
                      const SizedBox(height: 8),
                      Shimmer(height: 9, radius: 4, width: 60),
                    ],
                  ),
                  childCount: widget.columns * 3,
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(message: _error!, onRetry: () => _load(reset: true), retryLabel: st.s.t('retry')),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(text: widget.emptyText),
            )
          else ...[
            SliverPadding(
              padding: widget.padding,
              sliver: SliverGrid(
                gridDelegate: _delegate(),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final vod = _items[i];
                    return GridPoster(
                      vod: vod,
                      locked: widget.locked,
                      onTap: () => openVod(context, vod, site: st.sourceCode),
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30, top: 2),
                child: Center(
                  child: _loadingMore
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.6, color: C.faint))
                      : (_page >= _pageCount && _items.length > 6)
                          ? Text('—  ${_items.length}  —', style: T.tiny.copyWith(letterSpacing: 2))
                          : const SizedBox(height: 4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  SliverGridDelegate _delegate() => SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        mainAxisSpacing: 18,
        crossAxisSpacing: 12,
        childAspectRatio: 0.565,
      );
}
