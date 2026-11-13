import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/api.dart';
import '../core/cast.dart';
import '../core/display.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'auth.dart';
import 'cast_sheet.dart';
import 'player_skin.dart';
import 'vip_sheet.dart';
import 'widgets.dart';

/// ─────────────────────────────────────────────────────────────
///  Noqi 播放器
///
///  手势（参照主流影视播放器）
///  · 单击              显示 / 隐藏控制条
///  · 双击左 / 右 1/3   快退 / 快进 10 秒
///  · 双击中间          播放 / 暂停
///  · 长按              2 倍速（松手恢复）
///  · 横向拖动          seek，中间实时显示目标时间
///  · 竖向拖动 左半屏   亮度；右半屏 音量
///  · 锁定              以上全部禁用，只留一个锁
///
///  其它：自动连播倒计时、倍速、选集、画面比例、投屏、切线路、进度续播
/// ─────────────────────────────────────────────────────────────
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.vod,
    required this.site,
    required this.sourceIndex,
    required this.episodeIndex,
    this.directUrl,
    this.directHeaders = const {},
  });

  final Vod vod;
  final String site;
  final int sourceIndex;
  final int episodeIndex;

  /// 直接播放一个外链（如下载服务转码后的视频流），跳过片源解析。
  final String? directUrl;
  final Map<String, String> directHeaders;

  static Route<void> route({
    required Vod vod,
    required String site,
    required int sourceIndex,
    required int episodeIndex,
    String? directUrl,
    Map<String, String> directHeaders = const {},
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => PlayerPage(
        vod: vod,
        site: site,
        sourceIndex: sourceIndex,
        episodeIndex: episodeIndex,
        directUrl: directUrl,
        directHeaders: directHeaders,
      ),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    );
  }

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _ctrl;
  late int _ep;
  late int _src = widget.sourceIndex;

  bool _loading = true;
  String? _error;
  bool _isVipError = false;
  bool _isAuthError = false;

  // ── 控制层 / 锁定 / 方向 ──
  bool _controls = true;
  bool _locked = false;
  bool _landscape = true;

  // ── 播放参数 ──
  double _speed = 1;
  double _volume = 1;
  double _brightness = .6;
  BoxFit _fit = BoxFit.contain;

  // ── 手势瞬时状态 ──
  double? _brightnessHud;
  double? _volumeHud;
  Duration? _seekPreview;
  int? _seekDelta;
  bool _boosting = false;
  bool _guideVisible = false;

  // ── 连播 ──
  bool _ended = false;
  int _countdown = 0;

  int _lastSaveSecond = -10;
  String? _url;
  CastSession? _cast;
  bool _castBusy = false;

  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _hudTimer;
  Timer? _nextTimer;
  Timer? _guideTimer;

  static bool _guideShownOnce = false;

  List<Episode> get _episodes => widget.vod.sources.isEmpty
      ? const []
      : widget.vod.sources[_src.clamp(0, widget.vod.sources.length - 1)].episodes;

  String get _srcName {
    if (widget.vod.sources.isEmpty) return '';
    return widget.vod.sources[_src.clamp(0, widget.vod.sources.length - 1)].name;
  }

  @override
  void initState() {
    super.initState();
    _ep = widget.episodeIndex;
    _applyOrientation();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initEnv();
    _boot();
    _saveTimer = Timer.periodic(const Duration(seconds: 8), (_) => _save());
  }

  Future<void> _initEnv() async {
    final v = await Display.load();
    if (!mounted) return;
    setState(() => _brightness = v);
  }

  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(_landscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _hudTimer?.cancel();
    _nextTimer?.cancel();
    _guideTimer?.cancel();
    _save();
    _cast?.stop();
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    _restoreChrome();
    super.dispose();
  }

  // ───────────────────────── 播放生命周期 ─────────────────────────

  Future<void> _boot() async {
    final st = context.read<AppState>();

    // ── 直接外链播放（下载服务转码流等） ──
    final direct = widget.directUrl;
    if (direct != null && direct.isNotEmpty) {
      setState(() {
        _loading = true;
        _error = null;
        _ended = false;
        _countdown = 0;
        _isVipError = false;
        _isAuthError = false;
      });
      _nextTimer?.cancel();
      try {
        final headers = <String, String>{'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'};
        widget.directHeaders.forEach((k, v) {
          headers[k.toLowerCase() == 'user-agent' ? 'User-Agent' : k] = v;
        });
        _url = direct;
        final ctrl = VideoPlayerController.networkUrl(Uri.parse(direct), httpHeaders: headers);
        await ctrl.initialize();
        await ctrl.setPlaybackSpeed(_speed);
        await ctrl.setVolume(_volume);
        if (!mounted) {
          ctrl.dispose();
          return;
        }
        _ctrl?.removeListener(_onTick);
        _ctrl?.dispose();
        setState(() {
          _ctrl = ctrl;
          _loading = false;
        });
        ctrl.addListener(_onTick);
        await ctrl.play();
        _startHideTimer();
        _maybeGuide();
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
          _error = '播放失败，请稍后重试';
        });
      }
      return;
    }

    final eps = _episodes;
    if (eps.isEmpty) {
      setState(() {
        _loading = false;
        _error = '没有可播放的内容';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _ended = false;
      _countdown = 0;
      _isVipError = false;
      _isAuthError = false;
    });
    _nextTimer?.cancel();
    try {
      final ep = eps[_ep.clamp(0, eps.length - 1)];
      final info = await st.api.play(
        code: widget.site,
        play: ep.play,
        q: ep.q,
        token: st.user?.playToken,
      );
      _url = info.url;
      final headers = <String, String>{'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'};
      info.headers.forEach((k, v) {
        headers[k.toLowerCase() == 'user-agent' ? 'User-Agent' : k] = v;
      });
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(info.url), httpHeaders: headers);
      await ctrl.initialize();
      await ctrl.setPlaybackSpeed(_speed);
      await ctrl.setVolume(_volume);
      final saved = st.progressOf(widget.site, widget.vod.id);
      if (saved != null && saved.epIndex == _ep && saved.position > 5) {
        await ctrl.seekTo(Duration(seconds: saved.position));
      }
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      _ctrl?.removeListener(_onTick);
      _ctrl?.dispose();
      setState(() {
        _ctrl = ctrl;
        _loading = false;
      });
      ctrl.addListener(_onTick);
      await ctrl.play();
      _startHideTimer();
      _maybeGuide();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _isVipError = e.isVip;
        _isAuthError = e.isAuth;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '播放失败，请稍后重试';
      });
    }
  }

  void _onTick() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    final v = c.value;
    if (v.hasError) {
      setState(() {
        _error = '播放中断：请切换片源重试';
        _loading = false;
      });
      return;
    }
    final sec = v.position.inSeconds;
    if (v.isPlaying && (sec - _lastSaveSecond).abs() >= 10) {
      _lastSaveSecond = sec;
      _save();
    }
    if (!_ended &&
        v.duration.inMilliseconds > 0 &&
        v.position >= v.duration - const Duration(milliseconds: 350)) {
      _onEnded();
    }
    if (mounted) setState(() {});
  }

  void _onEnded() {
    _ended = true;
    final eps = _episodes;
    if (_ep + 1 >= eps.length) {
      setState(() => _countdown = 0);
      return;
    }
    setState(() => _countdown = 5);
    _nextTimer?.cancel();
    _nextTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_countdown <= 1) {
        _nextTimer?.cancel();
        _playEpisode(_ep + 1);
      } else {
        setState(() => _countdown -= 1);
      }
    });
  }

  void _save() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    final v = c.value;
    if (v.position.inSeconds < 3 || v.duration.inSeconds <= 0) return;
    context.read<AppState>().saveProgress(Progress(
      vodId: widget.vod.id,
      site: widget.site,
      name: widget.vod.name,
      pic: widget.vod.pic,
      epIndex: _ep,
      position: v.position.inSeconds,
      duration: v.duration.inSeconds,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> _playEpisode(int index) async {
    final eps = _episodes;
    if (index < 0 || index >= eps.length) return;
    _nextTimer?.cancel();
    setState(() {
      _ep = index;
      _ended = false;
      _countdown = 0;
    });
    await _boot();
  }

  Future<void> _togglePlay() async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
      _hideTimer?.cancel();
      if (mounted) setState(() => _controls = true);
    } else {
      await c.play();
      _startHideTimer();
    }
    HapticFeedback.selectionClick();
    if (mounted) setState(() {});
  }

  Future<void> _seek(Duration target) async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    await c.seekTo(target);
    _startHideTimer();
    if (mounted) setState(() {});
  }

  Future<void> _seekBy(int seconds) async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    final d = c.value.duration;
    var target = c.value.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > d) target = d;
    _flashSeek(seconds);
    await c.seekTo(target);
    _startHideTimer();
  }

  void _flashSeek(int seconds) {
    setState(() => _seekDelta = seconds);
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _seekDelta = null);
    });
  }

  // ───────────────────────── 手势 ─────────────────────────

  double get _stageW => MediaQuery.sizeOf(context).width;
  double get _stageH => _landscape ? MediaQuery.sizeOf(context).height : MediaQuery.sizeOf(context).height * .32;

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_locked) setState(() => _controls = false);
    });
  }

  void _onDoubleTapDown(TapDownDetails d) {
    final w = _stageW;
    final x = d.globalPosition.dx;
    if (x < w / 3) {
      _seekBy(-10);
    } else if (x > w * 2 / 3) {
      _seekBy(10);
    } else {
      _togglePlay();
    }
  }

  void _beginBoost() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || !c.value.isPlaying) return;
    setState(() => _boosting = true);
    unawaited(c.setPlaybackSpeed(2));
    HapticFeedback.mediumImpact();
  }

  void _endBoost() {
    if (!_boosting) return;
    setState(() => _boosting = false);
    unawaited(_ctrl?.setPlaybackSpeed(_speed));
  }

  bool _vRight = false;
  double _vBase = 0;
  double _vStartY = 0;

  void _vStart(DragStartDetails d) {
    _vRight = d.globalPosition.dx > _stageW / 2;
    _vBase = _vRight ? _volume : _brightness;
    _vStartY = d.globalPosition.dy;
  }

  void _vUpdate(DragUpdateDetails d) {
    final h = _stageH <= 0 ? 1.0 : _stageH;
    final delta = (_vStartY - d.globalPosition.dy) / (h * .62);
    final v = (_vBase + delta).clamp(0.0, 1.0);
    if (_vRight) {
      _volume = v;
      unawaited(_ctrl?.setVolume(v));
      setState(() => _volumeHud = v);
    } else {
      _brightness = v;
      unawaited(Display.setBrightness(v));
      setState(() => _brightnessHud = v);
    }
  }

  void _vEnd() => setState(() {
        _volumeHud = null;
        _brightnessHud = null;
      });

  Duration _hBase = Duration.zero;
  double _hStartX = 0;

  void _hStart(DragStartDetails d) {
    _hBase = _ctrl?.value.position ?? Duration.zero;
    _hStartX = d.globalPosition.dx;
  }

  void _hUpdate(DragUpdateDetails d) {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    final total = c.value.duration.inMilliseconds.toDouble();
    if (total <= 0) return;
    final w = _stageW <= 0 ? 1.0 : _stageW;
    final ms = (_hBase.inMilliseconds + (d.globalPosition.dx - _hStartX) / w * .85 * total).clamp(0.0, total);
    setState(() => _seekPreview = Duration(milliseconds: ms.round()));
  }

  void _hEnd() {
    final target = _seekPreview;
    setState(() => _seekPreview = null);
    if (target != null) unawaited(_seek(target));
  }

  void _maybeGuide() {
    if (_guideShownOnce) return;
    _guideShownOnce = true;
    setState(() => _guideVisible = true);
    _guideTimer?.cancel();
    _guideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _guideVisible = false);
    });
  }

  // ───────────────────────── 面板 ─────────────────────────

  Future<void> _pickSpeed() async {
    const list = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
    final st = context.read<AppState>();
    final picked = await showAppSheet<double>(
      context,
      child: _OptionSheet<double>(
        title: st.s.t('speed'),
        subtitle: '倍速播放',
        values: list,
        current: _speed,
        labelOf: (v) => '${v == v.roundToDouble() ? v.toInt() : v}x',
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _speed = picked);
    await _ctrl?.setPlaybackSpeed(picked);
    _startHideTimer();
  }

  Future<void> _pickEpisode() async {
    final st = context.read<AppState>();
    final eps = _episodes;
    final picked = await showAppSheet<int>(
      context,
      child: _EpisodeSheet(
        s: st.s,
        episodes: eps,
        current: _ep,
        title: st.s.t('episodes'),
        subtitle: '共 ${eps.length} 集',
      ),
    );
    if (picked == null || !mounted) return;
    await _playEpisode(picked);
  }

  Future<void> _pickFit() async {
    final st = context.read<AppState>();
    final values = <BoxFit>[BoxFit.contain, BoxFit.cover, BoxFit.fill];
    final labels = <String>[st.s.t('fitContain'), st.s.t('fitCover'), st.s.t('fitFill')];
    final picked = await showAppSheet<BoxFit>(
      context,
      child: _OptionSheet<BoxFit>(
        title: st.s.t('fit'),
        subtitle: '画面比例',
        values: values,
        current: _fit,
        labelOf: (v) => labels[values.indexOf(v)],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _fit = picked);
    _startHideTimer();
  }

  Future<void> _switchSource() async {
    final sources = widget.vod.sources;
    if (sources.length <= 1) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final st = context.read<AppState>();
    final values = List<int>.generate(sources.length, (i) => i);
    final picked = await showAppSheet<int>(
      context,
      child: _OptionSheet<int>(
        title: st.s.t('switchSource'),
        subtitle: '共 ${sources.length} 条线路',
        values: values,
        current: _src,
        labelOf: (i) => sources[i].name.isEmpty
            ? '线路 ${i + 1}'
            : '${sources[i].name} · ${sources[i].episodes.length} 集',
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _src = picked;
      _ep = 0;
    });
    await _boot();
  }

  Future<void> _openCast() async {
    if (_cast != null) {
      await _stopCast();
      return;
    }
    final url = _url;
    if (url == null || url.isEmpty) {
      _showToast('视频还没准备好，稍后再投屏');
      return;
    }
    final device = await showCastSheet(context);
    if (device == null || !mounted) return;
    setState(() => _castBusy = true);
    final session = CastSession(device);
    try {
      final mime = url.contains('.m3u8') ? 'application/vnd.apple.mpegurl' : 'video/mp4';
      await session.open(url, title: widget.vod.name, mime: mime);
      await _ctrl?.pause();
      if (!mounted) return;
      setState(() {
        _cast = session;
        _castBusy = false;
      });
      _showToast('${context.read<AppState>().s.t('castTo')} ${device.name}');
    } on DlnaException catch (e) {
      if (!mounted) return;
      setState(() => _castBusy = false);
      _showToast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _castBusy = false);
      _showToast('投屏失败，请确认电视与手机在同一网络');
    }
  }

  Future<void> _stopCast() async {
    final session = _cast;
    setState(() => _cast = null);
    try {
      await session?.stop();
    } catch (_) {}
  }

  void _showToast(String msg) {
    if (!mounted) return;
    Toast.show(context, msg);
  }

  Future<void> _openVip() => showVipSheet(context);

  Future<void> _openLogin() => showAuthSheet(context);

  // ───────────────────────── 界面 ─────────────────────────

  /// 退出播放页时，必须把横屏 + 沉浸式状态彻底还原，否则返回后
  /// 整个首页 / 详情页会被「卡」在横屏全屏。这里在路由真正退栈前先还原。
  void _restoreChrome() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: C.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    return PopScope(
      // 在页面退栈前先把横屏 / 沉浸式还原，避免「返回后整页仍是全屏」的卡顿
      onPopInvokedWithResult: (_, _) => _restoreChrome(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _landscape
            ? SizedBox.expand(child: _buildStage(s))
            : Column(
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: _buildStage(s)),
                  Expanded(child: _buildPortraitPanel(s)),
                ],
              ),
      ),
    );
  }

  Widget _buildStage(S s) {
    final c = _ctrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _buildSurface()),

        // 无原生亮度能力时（Web / 桌面）用遮罩模拟
        if (!Display.native && _brightness < .99)
          IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: (1 - _brightness) * .78))),

        if (_cast != null) _buildCastLayer(s),

        if (_brightnessHud != null)
          Center(child: SliderHud(icon: Icons.brightness_6_rounded, value: _brightnessHud!, label: s.t('brightness'))),
        if (_volumeHud != null)
          Center(child: SliderHud(icon: Icons.volume_up_rounded, value: _volumeHud!, label: s.t('volume'))),
        if (_seekDelta != null && c != null && c.value.isInitialized)
          Center(
            child: SeekHud(
              forward: _seekDelta! > 0,
              seconds: _seekDelta,
              position: c.value.position,
              duration: c.value.duration,
            ),
          ),
        if (_seekPreview != null && c != null && c.value.isInitialized)
          Center(child: SeekHud(forward: true, position: _seekPreview!, duration: c.value.duration)),

        _buildControls(s),

        if (_loading && _error == null) const Center(child: BufferingDot(size: 32)),
        if (_error != null) Center(child: _buildError(s)),

        if (_ended && _countdown > 0)
          Positioned(
            right: 22,
            bottom: 74,
            child: NextUpCard(
              s: s,
              title: _nextEpTitle(),
              countdown: _countdown,
              onPlay: () => _playEpisode(_ep + 1),
              onCancel: () {
                _nextTimer?.cancel();
                setState(() {
                  _countdown = 0;
                  _controls = true;
                });
              },
            ),
          ),

        if (_guideVisible) _buildGuide(s),

        if (_boosting)
          const Positioned(top: 62, left: 0, right: 0, child: Center(child: SpeedBadge(label: '2× 播放中'))),
      ],
    );
  }

  String _nextEpTitle() {
    final eps = _episodes;
    final i = _ep + 1;
    if (i >= eps.length) return '';
    return eps[i].name.isEmpty ? '第 ${i + 1} 集' : eps[i].name;
  }

  Widget _buildSurface() {
    final c = _ctrl;
    final ready = c != null && c.value.isInitialized;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _locked ? null : _toggleControls,
      onDoubleTapDown: _locked ? null : _onDoubleTapDown,
      onLongPressStart: _locked ? null : (_) => _beginBoost(),
      onLongPressEnd: _locked ? null : (_) => _endBoost,
      onLongPressCancel: _locked ? null : _endBoost,
      onVerticalDragStart: _locked ? null : _vStart,
      onVerticalDragUpdate: _locked ? null : _vUpdate,
      onVerticalDragEnd: _locked ? null : (_) => _vEnd(),
      onVerticalDragCancel: _locked ? null : _vEnd,
      onHorizontalDragStart: _locked ? null : _hStart,
      onHorizontalDragUpdate: _locked ? null : _hUpdate,
      onHorizontalDragEnd: _locked ? null : (_) => _hEnd(),
      onHorizontalDragCancel: _locked ? null : _hEnd,
      child: ColoredBox(
        color: Colors.black,
        child: ready
            ? FittedBox(
                fit: _fit,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }

  Widget _buildCastLayer(S s) {
    return ColoredBox(
      color: const Color(0xF007070A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cast_connected_rounded, size: 32, color: C.accent),
            const SizedBox(height: 14),
            Text('${s.t('castTo')}  ${_cast!.device.name}',
                textAlign: TextAlign.center, style: T.bodySub.copyWith(fontSize: 13.5, color: C.text)),
            const SizedBox(height: 18),
            SizedBox(
              width: 132,
              child: GhostButton(label: s.t('castStop'), onTap: _stopCast, height: 40, icon: Icons.stop_circle_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(S s) {
    if (_locked) {
      return Positioned(
        left: 14,
        top: 14,
        child: SafeArea(
          child: LockChip(onUnlock: () => setState(() {
                _locked = false;
                _controls = true;
                _startHideTimer();
              })),
        ),
      );
    }
    final c = _ctrl;
    final ready = c != null && c.value.isInitialized;
    final show = _controls && ready && _error == null && !_loading;
    final pos = ready ? c.value.position : Duration.zero;
    final dur = ready ? c.value.duration : Duration.zero;
    final buffered = ready && c.value.buffered.isNotEmpty ? c.value.buffered.last.end : Duration.zero;

    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: M.base,
        curve: show ? M.curve : M.curveIn,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(top: 0, left: 0, right: 0, child: TopVeil()),
              const Positioned(bottom: 0, left: 0, right: 0, child: BottomVeil()),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: PlayerTopBar(
                  title: widget.vod.name,
                  subtitle: _subtitle(),
                  onBack: () => Navigator.pop(context),
                  actions: [
                    SkinIconButton(
                      icon: _cast == null ? Icons.cast_rounded : Icons.cast_connected_rounded,
                      active: _cast != null,
                      onTap: _castBusy ? () {} : _openCast,
                      tooltip: s.t('cast'),
                    ),
                    SkinIconButton(icon: Icons.more_vert_rounded, onTap: _switchSource, tooltip: s.t('switchSource')),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: PlayerBottomBar(
                  s: s,
                  playing: ready && c.value.isPlaying,
                  position: pos,
                  duration: dur,
                  buffered: buffered,
                  onToggle: _togglePlay,
                  onSeek: _seek,
                  speedLabel: _speed == _speed.roundToDouble() ? '${_speed.toInt()}x' : '${_speed}x',
                  onSpeed: _pickSpeed,
                  onFit: _pickFit,
                  onEpisodes: _pickEpisode,
                  onLock: () => setState(() {
                    _locked = true;
                    _controls = false;
                  }),
                  onRotate: () {
                    setState(() => _landscape = !_landscape);
                    _applyOrientation();
                  },
                  episodeLabel: s.t('episodes'),
                  onDragStart: () => _hideTimer?.cancel(),
                  onDragEnd: _startHideTimer,
                  landscape: _landscape,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final eps = _episodes;
    final epName = eps.isEmpty
        ? ''
        : (eps[_ep.clamp(0, eps.length - 1)].name.isEmpty ? '第 ${_ep + 1} 集' : eps[_ep.clamp(0, eps.length - 1)].name);
    final buf = StringBuffer(epName);
    if (_srcName.isNotEmpty) {
      buf.write('  ·  ');
      buf.write(_srcName);
    }
    return buf.toString();
  }

  Widget _buildGuide(S s) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 96,
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _guideVisible = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xCC0E0E12),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.white.withValues(alpha: .10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gesture_rounded, size: 15, color: C.accent),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(s.t('gestureTip'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: .82))),
                ),
                const SizedBox(width: 10),
                Text(s.t('gotIt'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(S s) {
    return _ErrorPanel(
      message: _error ?? '',
      onRetry: _boot,
      retryLabel: s.t('retry'),
      vipLabel: s.t('vipOpen'),
      loginLabel: s.t('login'),
      backLabel: s.t('back'),
      switchLabel: s.t('switchSource'),
      onVip: _isVipError ? _openVip : null,
      onLogin: _isAuthError ? _openLogin : null,
      onSwitch: _switchSource,
      back: () => Navigator.pop(context),
    );
  }

  Widget _buildPortraitPanel(S s) {
    final eps = _episodes;
    return ColoredBox(
      color: C.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(C.pad, 16, C.pad, 24),
        children: [
          Text(widget.vod.name, style: T.h3),
          const SizedBox(height: 4),
          Text(_subtitle(), style: T.tiny.copyWith(fontSize: 11.5)),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(s.t('episodes'), style: T.h3.copyWith(fontSize: 14)),
              const SizedBox(width: 8),
              Text('${eps.length}', style: T.tiny.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: List.generate(eps.length, (i) {
              final on = i == _ep;
              return GestureDetector(
                onTap: () => _playEpisode(i),
                child: AnimatedContainer(
                  duration: M.fast,
                  curve: M.curveStd,
                  width: 62,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? C.accentWash : C.surface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: on ? C.accent.withValues(alpha: .5) : C.line),
                  ),
                  child: Text(
                    eps[i].name.isEmpty ? '${i + 1}' : eps[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(fontSize: 12.5, color: on ? C.accent : C.sub),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 面板组件 ─────────────────────────

class _OptionSheet<V> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.current,
    required this.labelOf,
  });

  final String title;
  final String subtitle;
  final List<V> values;
  final V current;
  final String Function(V) labelOf;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(title: title, subtitle: subtitle),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(C.pad, 4, C.pad, 20),
            itemCount: values.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = values[i];
              final on = v == current;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context, v),
                child: AnimatedContainer(
                  duration: M.fast,
                  curve: M.curveStd,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  decoration: BoxDecoration(
                    color: on ? C.accentWash : C.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: on ? C.accent.withValues(alpha: .5) : C.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(labelOf(v), style: T.body.copyWith(fontSize: 13.5, color: on ? C.accent : C.text)),
                      ),
                      if (on) const Icon(Icons.check_rounded, size: 16, color: C.accent),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EpisodeSheet extends StatelessWidget {
  const _EpisodeSheet({
    required this.s,
    required this.episodes,
    required this.current,
    required this.title,
    required this.subtitle,
  });

  final S s;
  final List<Episode> episodes;
  final int current;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(title: title, subtitle: subtitle),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(C.pad, 4, C.pad, 22),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 1.62,
            ),
            itemCount: episodes.length,
            itemBuilder: (context, i) {
              final on = i == current;
              return GestureDetector(
                onTap: () => Navigator.pop(context, i),
                child: AnimatedContainer(
                  duration: M.fast,
                  curve: M.curveStd,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? C.accent : C.surface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: on ? C.accent : C.line),
                  ),
                  child: Text(
                    episodes[i].name.isEmpty ? '${i + 1}' : episodes[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(fontSize: 12.5, color: on ? const Color(0xFF14100A) : C.sub),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
    required this.vipLabel,
    required this.loginLabel,
    required this.back,
    required this.backLabel,
    required this.switchLabel,
    this.onVip,
    this.onLogin,
    this.onSwitch,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final String vipLabel;
  final String loginLabel;
  final VoidCallback back;
  final String backLabel;
  final String switchLabel;
  final VoidCallback? onVip;
  final VoidCallback? onLogin;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final primary = onVip ?? onLogin ?? onRetry;
    final primaryLabel = onVip != null ? vipLabel : (onLogin != null ? loginLabel : retryLabel);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(onVip != null ? Icons.workspace_premium_rounded : Icons.error_outline_rounded,
              size: 30, color: onVip != null ? C.vip : C.sub),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: T.bodySub.copyWith(fontSize: 13)),
          const SizedBox(height: 22),
          SizedBox(width: 176, child: GoldButton(label: primaryLabel, onTap: primary, height: 44)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onSwitch != null && onVip == null) ...[
                TextButton(
                    onPressed: onSwitch, child: Text(switchLabel, style: T.tiny.copyWith(fontSize: 11.5, color: C.sub))),
                Container(width: 3, height: 3, decoration: const BoxDecoration(color: C.faint, shape: BoxShape.circle)),
              ],
              TextButton(onPressed: back, child: Text(backLabel, style: T.tiny.copyWith(fontSize: 11.5, color: C.faint))),
            ],
          ),
        ],
      ),
    );
  }
}
