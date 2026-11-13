
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'browse.dart';
import 'play_helper.dart';
import 'search.dart';
import 'source_sheet.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  List<VodClass> _classes = const [];
  List<Vod> _latest = const [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    final code = st.sourceCode;
    if (code.isEmpty) {
      setState(() {
        _loading = false;
        _error = st.bootError;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await st.classes(code, force: true);
      final page = await st.api.list(code, t: '', pg: 1);
      if (!mounted) return;
      setState(() {
        _classes = bundle.classes.where((c) => c.id != '0').toList();
        _latest = page.items;
        _loading = false;
      });
      if (st.hot.isEmpty) await st.refreshHot();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '网络连接失败';
      });
    }
  }

  void _open(Vod vod, {String? site}) {
    openVod(context, vod, site: site);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final st = context.watch<AppState>();
    final s = st.s;
    final hot = st.hot;
    final locked = !st.canPlay(st.source);
    final hero = hot.isNotEmpty ? hot.first : (_latest.isNotEmpty ? _latest.first.toHot() : null);

    return Scaffold(
      backgroundColor: C.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: C.accent,
        backgroundColor: C.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: C.bg,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 60,
              titleSpacing: C.pad,
              automaticallyImplyLeading: false,
              title: BrandRow(
                title: st.siteName,
                trailing: Row(
                  children: [
                    IconPill(icon: Icons.search_rounded, size: 36, onTap: () {
                      Navigator.of(context).push(SearchPage.route());
                    }),
                    const SizedBox(width: 8),
                    _SourceChip(label: st.source?.name ?? '—', vip: st.needsVip && (st.source?.isVip ?? false), onTap: () => showSourceSheet(context)),
                  ],
                ),
              ),
            ),
            if (_loading)
              SliverToBoxAdapter(child: const _Skeleton())
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(message: _error!, onRetry: _load, retryLabel: s.t('retry')),
              )
            else ...[
              if (hero != null)
                SliverToBoxAdapter(
                  child: _Hero(
                    item: hero,
                    locked: locked,
                    playLabel: s.t('play'),
                    onTap: () => _open(hero.toVod(), site: hero.siteCode.isEmpty ? null : hero.siteCode),
                  ),
                ),
              if (hot.length > 1) ...[
                SliverToBoxAdapter(child: SectionHead(title: s.t('hot'), trailing: _RankTag(count: hot.length))),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 206,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: C.pad),
                      itemCount: hot.length > 12 ? 12 : hot.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 11),
                      itemBuilder: (context, i) {
                        final item = hot[i];
                        return PosterCard(
                          vod: item.toVod(),
                          width: 116,
                          badge: item.plays > 0 ? '${item.plays}' : null,
                          locked: locked,
                          onTap: () => _open(item.toVod(), site: item.siteCode.isEmpty ? null : item.siteCode),
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (_classes.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionHead(title: s.t('type'))),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: C.pad),
                      itemCount: _classes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => SelectChip(
                        label: _classes[i].name,
                        selected: false,
                        onTap: () => Navigator.of(context).push(CategoryPage.route(
                          title: _classes[i].name,
                          classId: _classes[i].id,
                          classes: _classes,
                        )),
                      ),
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SectionHead(
                  title: s.t('latest'),
                  trailing: GestureDetector(
                    onTap: () => Navigator.of(context).push(CategoryPage.route(
                      title: s.t('all'),
                      classId: '',
                      classes: _classes,
                    )),
                    child: Row(
                      children: [
                        Text(s.t('all'), style: T.cap.copyWith(color: C.accent, fontSize: 12)),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 15, color: C.accent),
                      ],
                    ),
                  ),
                ),
              ),
              if (_latest.isEmpty)
                SliverToBoxAdapter(child: SizedBox(height: 180, child: EmptyView(text: s.t('empty'))))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(C.pad, 0, C.pad, 0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.565,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => GridPoster(vod: _latest[i], locked: locked, onTap: () => _open(_latest[i])),
                      childCount: _latest.length > 12 ? 12 : _latest.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28, bottom: 34),
                  child: Column(
                    children: [
                      Text('NOQI · 1.0.2', style: T.tiny.copyWith(letterSpacing: 2.4, color: C.faint.withValues(alpha: .7))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, required this.onTap, this.vip = false});
  final String label;
  final VoidCallback onTap;
  final bool vip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: C.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vip) ...[const Icon(Icons.workspace_premium_rounded, size: 13, color: C.vip), const SizedBox(width: 4)],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 88),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.cap.copyWith(fontSize: 11.5, color: C.text, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: C.faint),
          ],
        ),
      ),
    );
  }
}

class _RankTag extends StatelessWidget {
  const _RankTag({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Text('TOP $count', style: T.tiny.copyWith(letterSpacing: 1.6, color: C.faint));
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.item, required this.locked, required this.playLabel, required this.onTap});
  final HotItem item;
  final bool locked;
  final String playLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(C.pad, 2, C.pad, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 392,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: C.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 主图保持清晰：海报本身 1024×1536，压暗靠渐变而不是虚化。
                // 略微上移并裁掉海报自带的下方文字，避免和片名打架。
                ClipRect(
                  child: Transform.scale(
                    scale: 1.14,
                    alignment: Alignment.topCenter,
                    child: NetImage(
                      url: item.pic,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      quality: FilterQuality.medium,
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x5907070A), Color(0x0007070A), Color(0xB307070A), Color(0xFF07070A)],
                      stops: [0, .26, .70, 1],
                    ),
                  ),
                ),
                // 左侧压暗，保证标题在浅色海报上也读得清
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0x8C07070A), Color(0x1A07070A), Color(0x0007070A)],
                      stops: [0, .55, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  top: 18,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x66000000),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: C.accent.withValues(alpha: .3)),
                        ),
                        child: Text('${item.plays}',
                            style: T.num.copyWith(fontSize: 10.5, color: C.accent)),
                      ),
                      const Spacer(),
                      if (locked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0x88000000), borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 10, color: C.vip),
                              SizedBox(width: 4),
                              Text('VIP', style: TextStyle(fontSize: 9, color: C.vip, fontWeight: FontWeight.w700, letterSpacing: 1)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: T.h1.copyWith(fontSize: 22, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              gradient: C.goldGrad,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: C.accent.withValues(alpha: .2), blurRadius: 20, offset: const Offset(0, 8))],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.play_arrow_rounded, size: 20, color: Color(0xFF14100A)),
                                const SizedBox(width: 4),
                                Text(playLabel,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF14100A))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(C.pad, 2, C.pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Shimmer(height: 392, radius: 22),
          const SizedBox(height: 26),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 11),
                  child: Column(
                    children: [
                      const Shimmer(height: 172, radius: 13),
                      const SizedBox(height: 8),
                      Shimmer(height: 9, radius: 4, width: 60),
                    ],
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

extension on Vod {
  HotItem toHot() => HotItem(siteCode: '', id: id, name: name, pic: pic, plays: 0);
}
