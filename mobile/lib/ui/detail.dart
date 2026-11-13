import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'auth.dart';
import 'download_sheet.dart';
import 'player.dart';
import 'play_helper.dart';
import 'vip_sheet.dart';
import 'widgets.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.vod, this.site});
  final Vod vod;
  final String? site;

  static Route<void> route(Vod vod, {String? site}) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, a, _) => DetailPage(vod: vod, site: site),
        transitionsBuilder: (_, a, _, child) {
          final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      );

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Vod _vod = widget.vod;
  late final String _site = widget.site ?? context.read<AppState>().sourceCode;
  bool _loading = true;
  bool _authRequired = false;
  String? _error;
  int _srcIndex = 0;
  bool _expanded = false;
  List<Vod> _related = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
      _authRequired = false;
    });
    try {
      final full = await st.api.detail(_site, widget.vod.id);
      if (!mounted) return;
      setState(() {
        if (full != null) _vod = full;
        _loading = false;
      });
      unawaited(_loadRelated(st, _vod));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.isAuth) {
          _authRequired = true;
        } else {
          _error = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '网络连接失败';
      });
    }
  }

  Progress? get _progress => context.read<AppState>().progressOf(_site, _vod.id);

  /// 用当前影片的类型去片源里捞一批同类，补足详情页底部内容
  Future<void> _loadRelated(AppState st, Vod vod) async {
    if (vod.typeName.isEmpty) return;
    try {
      final bundle = await st.classes(_site);
      VodClass? match;
      for (final c in bundle.classes) {
        if (c.name == vod.typeName) {
          match = c;
          break;
        }
      }
      // 站点类目粒度比影片类型粗（只有「电影 / 剧集 / 动画」），匹配不到就退到第一个真实类目
      match ??= bundle.classes.where((c) => c.id != '0' && c.id.isNotEmpty).firstOrNull;
      if (match == null || match.id.isEmpty) return;
      final page = await st.api.list(_site, t: match.id, pg: 1);
      final items = page.items.where((v) => v.id != vod.id).take(12).toList();
      if (!mounted || items.isEmpty) return;
      setState(() => _related = items);
    } catch (_) {
      // 推荐属于增强内容，失败静默
    }
  }

  Future<void> _playAt(int epIndex) async {
    final st = context.read<AppState>();
    if (!st.canPlay(st.byCode(_site) ?? st.source)) {
      await showVipSheet(context);
      return;
    }
    final sources = _vod.sources;
    if (sources.isEmpty || sources[_srcIndex].episodes.isEmpty) return;
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(PlayerPage.route(
      vod: _vod,
      site: _site,
      sourceIndex: _srcIndex,
      episodeIndex: epIndex.clamp(0, sources[_srcIndex].episodes.length - 1),
    ));
    if (mounted) {
      // refresh user in case vip expired / progress updated
      st.refreshUser();
      setState(() {});
    }
  }

  /// 打开选集下载面板（复用 EpisodeDownloadSheet，逐集解析直链并提交）。
  void _openDownloadSheet() {
    final st = context.read<AppState>();
    final s = st.s;
    final episodes = _vod.sources.isEmpty ? const <Episode>[] : _vod.sources[_srcIndex.clamp(0, _vod.sources.length - 1)].episodes;
    if (episodes.isEmpty) {
      if (context.mounted) Toast.show(context, s.t('empty'));
      return;
    }
    showAppSheet(
      context,
      child: EpisodeDownloadSheet(
        vod: _vod,
        site: _site,
        episodes: episodes,
        preselect: {0},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    final episodes = _vod.sources.isEmpty ? const <Episode>[] : _vod.sources[_srcIndex.clamp(0, _vod.sources.length - 1)].episodes;
    final locked = !st.canPlay(st.byCode(_site) ?? st.source);
    final prog = _progress;

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            elevation: 0,
            backgroundColor: C.bg,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 60,
            leading: Padding(
              padding: const EdgeInsets.only(left: 14, top: 6, bottom: 6),
              child: IconPill(icon: Icons.arrow_back_rounded, size: 36, onTap: () => Navigator.pop(context)),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: IconPill(icon: Icons.refresh_rounded, size: 36, onTap: _load),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _Header(vod: _vod, site: _site, locked: locked),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(C.pad, 16, C.pad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_authRequired)
                    _LoginGate(onLogin: () => showAuthSheet(context), onRetry: _load)
                  else if (_error != null)
                    SizedBox(
                      height: 200,
                      child: ErrorView(message: _error!, onRetry: _load, retryLabel: s.t('retry')),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: GoldButton(
                            label: prog != null && episodes.length > 1 ? s.t('resume') : s.t('play'),
                            icon: Icons.play_arrow_rounded,
                            height: 50,
                            onTap: (episodes.isEmpty && !_loading)
                                ? null
                                : () => _playAt(prog?.epIndex ?? 0),
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 10),
                          GhostButton(
                            label: s.t('vipOpen'),
                            height: 50,
                            expanded: false,
                            icon: Icons.workspace_premium_rounded,
                            onTap: () => showVipSheet(context),
                          ),
                        ],
                      ],
                    ),
                    if (prog != null && episodes.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 3, height: 3,
                              decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${episodes[prog.epIndex.clamp(0, episodes.length - 1)].label} · ${_fmt(prog.position)}',
                              style: T.tiny.copyWith(fontSize: 11, color: C.faint),
                            ),
                          ],
                        ),
                      ),
                    if (st.dlEnabled && !locked)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: GhostButton(
                          label: s.t('dlSubmit'),
                          icon: Icons.cloud_download_outlined,
                          height: 46,
                          expanded: true,
                          onTap: () => _openDownloadSheet(),
                        ),
                      ),
                    if (_loading) ...[
                      const SizedBox(height: 22),
                      const Shimmer(height: 12, radius: 4),
                      const SizedBox(height: 8),
                      const Shimmer(height: 12, radius: 4, width: 210),
                    ],
                    if (_vod.content.trim().isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Text(s.t('intro'), style: T.h3.copyWith(fontSize: 14, letterSpacing: .2)),
                      const SizedBox(height: 9),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        alignment: Alignment.topCenter,
                        child: Text(
                          _vod.content.trim(),
                          maxLines: _expanded ? 40 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: T.bodySub.copyWith(fontSize: 13, height: 1.95),
                        ),
                      ),
                      if (_vod.content.trim().length > 90)
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Row(
                              children: [
                                Text(_expanded ? s.t('less') : s.t('more'),
                                    style: T.cap.copyWith(fontSize: 11.5, color: C.accent)),
                                Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                    size: 15, color: C.accent),
                              ],
                            ),
                          ),
                        ),
                    ],
                    if (_vod.sources.length > 1) ...[
                      const SizedBox(height: 24),
                      Text(s.t('source'), style: T.h3.copyWith(fontSize: 14)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < _vod.sources.length; i++)
                            SelectChip(
                              label: _vod.sources[i].name.isEmpty ? '${i + 1}' : _vod.sources[i].name,
                              selected: i == _srcIndex,
                              onTap: () => setState(() => _srcIndex = i),
                            ),
                        ],
                      ),
                    ],
                    if (episodes.length > 1) ...[
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Text(s.t('episodes'), style: T.h3.copyWith(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text('${episodes.length}', style: T.tiny.copyWith(fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _EpisodeGrid(
                        episodes: episodes,
                        current: prog?.epIndex,
                        onTap: _playAt,
                      ),
                    ],
                    if (_related.isNotEmpty) ...[
                      const SizedBox(height: 34),
                      Row(
                        children: [
                          Text(s.t('related'), style: T.h3.copyWith(fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(width: 3, height: 3,
                              decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _related.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 11),
                          itemBuilder: (context, i) {
                            final v = _related[i];
                            return PosterCard(
                              vod: v,
                              width: 114,
                              locked: locked,
                              onTap: () => openVod(context, v, site: _site),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 46),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int seconds) {
    if (seconds <= 0) return '';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vod, required this.site, required this.locked});
  final Vod vod;
  final String site;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    final metas = <String>[
      if (vod.year.isNotEmpty) vod.year,
      if (vod.area.isNotEmpty) vod.area,
      if (vod.typeName.isNotEmpty) vod.typeName,
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Transform.scale(scale: 1.3, child: NetImage(url: vod.pic)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB307070A), Color(0x5507070A), Color(0xFF07070A)],
              stops: [0, .45, 1],
            ),
          ),
        ),
        Positioned(
          left: C.pad,
          right: C.pad,
          bottom: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: C.line),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: NetImage(url: vod.pic, width: 96, height: 142, radius: 13),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (locked)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const VipPill(text: 'VIP'),
                            const SizedBox(width: 6),
                            Text(s.t('vipOnly'), style: T.tiny.copyWith(fontSize: 9.5, color: C.vip.withValues(alpha: .8))),
                          ],
                        ),
                      ),
                    Text(
                      vod.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: T.h1.copyWith(fontSize: 21, height: 1.4, shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 12)]),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        if (metas.isNotEmpty)
                          Flexible(
                            child: Text(
                              metas.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.cap.copyWith(fontSize: 11.5, color: C.sub),
                            ),
                          ),
                        if (metas.isNotEmpty) const SizedBox(width: 8),
                        ScorePill(score: vod.score),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EpisodeGrid extends StatelessWidget {
  const _EpisodeGrid({required this.episodes, required this.current, required this.onTap});
  final List<Episode> episodes;
  final int? current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 82,
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: 1.9,
      ),
      itemCount: episodes.length,
      itemBuilder: (context, i) {
        final active = current == i;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: active ? C.accentWash : C.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: active ? C.accent.withValues(alpha: .55) : C.line),
            ),
            child: Text(
              episodes[i].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: T.cap.copyWith(
                fontSize: 11.5,
                color: active ? C.accent : C.sub,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoginGate extends StatelessWidget {
  const _LoginGate({required this.onLogin, required this.onRetry});
  final VoidCallback onLogin;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle, border: Border.all(color: C.line)),
            child: const Icon(Icons.lock_outline_rounded, size: 22, color: C.sub),
          ),
          const SizedBox(height: 16),
          Text(s.t('needLogin'), style: T.h3.copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          Text(s.t('loginSub'), style: T.cap.copyWith(fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(width: 220, child: GoldButton(label: s.t('login'), onTap: onLogin, height: 46)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(s.t('retry'), style: T.cap.copyWith(color: C.faint, fontSize: 12))),
        ],
      ),
    );
  }
}
