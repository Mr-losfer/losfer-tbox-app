import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

/// ─────────────────────────────────────────────────────────────
///  播放器皮肤层（Player skin）
///  与 video_player 完全解耦：只吃状态、只吐回调。
///  这样既能单独预览（lib/ui/player_preview.dart），也能被单测覆盖。
///
///  交互参照主流影视播放器：
///  · 顶部：返回 / 片名 / 集数 · 投屏 · 更多
///  · 底部：播放暂停 · 时间 · 可拖动进度条（含缓冲） · 倍速 · 选集 · 锁定 · 旋转
///  · 手势：左右侧双击快进快退、长按 2× 、竖向滑亮度 / 音量、横向滑 seek
/// ─────────────────────────────────────────────────────────────

String fmtDuration(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// 顶部渐变 —— 保证任何画面下文字都读得清（不靠模糊）
class TopVeil extends StatelessWidget {
  const TopVeil({super.key, this.height = 108});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Color(0x66000000), Color(0x00000000)],
            stops: [0, .55, 1],
          ),
        ),
      ),
    );
  }
}

class BottomVeil extends StatelessWidget {
  const BottomVeil({super.key, this.height = 168});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xE6000000), Color(0x8A000000), Color(0x00000000)],
            stops: [0, .55, 1],
          ),
        ),
      ),
    );
  }
}

/// 顶部栏：返回 + 标题（片名 / 第 N 集）+ 右侧动作
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?bottom,
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 10, 6),
          child: Row(
            children: [
              SkinIconButton(icon: Icons.arrow_back_rounded, onTap: onBack, size: 22),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: .62), height: 1.2),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ],
      ),
    );
  }
}

/// 播放器上的图标按钮：44px 触控区、半透明底、按下有缩放反馈
class SkinIconButton extends StatelessWidget {
  const SkinIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 21,
    this.color = Colors.white,
    this.active = false,
    this.tooltip,
    this.padding = 4,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final bool active;
  final String? tooltip;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: M.fast,
      curve: M.curveStd,
      margin: EdgeInsets.all(padding),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: active ? C.accent.withValues(alpha: .18) : Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? C.accent.withValues(alpha: .5) : Colors.white.withValues(alpha: .10)),
      ),
      child: Icon(icon, size: size, color: active ? C.accent : color.withValues(alpha: .94)),
    );
    final btn = _TapScale(onTap: onTap, child: child);
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, preferBelow: false, child: btn);
  }
}

class _TapScale extends StatefulWidget {
  const _TapScale({required this.onTap, required this.child, this.scale = .9});

  final VoidCallback onTap;
  final Widget child;
  final double scale;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: M.fast,
        curve: M.curveStd,
        child: widget.child,
      ),
    );
  }
}

/// 文字动作按钮（倍速 / 选集 / 画面）
class SkinTextButton extends StatelessWidget {
  const SkinTextButton({super.key, required this.label, required this.onTap, this.active = false});

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: M.fast,
        curve: M.curveStd,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? C.accent.withValues(alpha: .16) : Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? C.accent.withValues(alpha: .45) : Colors.white.withValues(alpha: .09)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? C.accent : Colors.white.withValues(alpha: .88),
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// 进度条：缓冲 + 进度 + 可拖动手柄 + 拖动时间气泡
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onChanged,
    this.onDragStart,
    this.onDragEnd,
    this.compact = false,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration> onChanged;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final bool compact;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _drag;

  double get _total => widget.duration.inMilliseconds.toDouble();

  double get _ratio {
    if (_total <= 0) return 0;
    final r = widget.position.inMilliseconds / _total;
    return r.clamp(0.0, 1.0);
  }

  double get _bufRatio {
    if (_total <= 0) return 0;
    return (widget.buffered.inMilliseconds / _total).clamp(0.0, 1.0);
  }

  double get _shown => _drag ?? _ratio;

  void _update(Offset local, double width) {
    if (width <= 0) return;
    final next = (local.dx / width).clamp(0.0, 1.0);
    if (_drag == null) widget.onDragStart?.call();
    setState(() => _drag = next);
  }

  void _commit() {
    final v = _drag;
    setState(() => _drag = null);
    widget.onDragEnd?.call();
    if (v != null && _total > 0) {
      widget.onChanged(Duration(milliseconds: (v * _total).round()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dragging = _drag != null;
    final trackH = dragging ? 5.0 : 3.0;
    final thumbR = dragging ? 8.0 : 5.5;

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            if (_total <= 0) return;
            widget.onChanged(Duration(milliseconds: ((d.localPosition.dx / width).clamp(0.0, 1.0) * _total).round()));
          },
          onHorizontalDragStart: (d) => _update(d.localPosition, width),
          onHorizontalDragUpdate: (d) => _update(d.localPosition, width),
          onHorizontalDragEnd: (_) => _commit(),
          onHorizontalDragCancel: () => setState(() => _drag = null),
          child: SizedBox(
            height: widget.compact ? 26 : 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 气泡
                if (dragging)
                  Positioned(
                    bottom: 22,
                    left: (_shown * width - 30).clamp(0.0, (width - 60).clamp(0.0, double.infinity)),
                    child: Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xE616161B),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white.withValues(alpha: .10)),
                      ),
                      child: Text(
                        fmtDuration(Duration(milliseconds: (_shown * _total).round())),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                // 轨道
                Positioned.fill(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: trackH,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Container(color: Colors.white.withValues(alpha: .20)),
                            FractionallySizedBox(
                              widthFactor: _bufRatio,
                              child: Container(color: Colors.white.withValues(alpha: .34)),
                            ),
                            FractionallySizedBox(
                              widthFactor: _shown,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: [C.accentDeep, C.accent]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 手柄
                Positioned(
                  left: (_shown * width - thumbR).clamp(0.0, double.infinity),
                  child: AnimatedContainer(
                    duration: M.fast,
                    curve: M.curveStd,
                    width: thumbR * 2,
                    height: thumbR * 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: C.accent.withValues(alpha: .5), blurRadius: dragging ? 14 : 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 底部控制条
class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({
    super.key,
    required this.s,
    required this.playing,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onToggle,
    required this.onSeek,
    required this.speedLabel,
    required this.onSpeed,
    required this.onFit,
    required this.onEpisodes,
    required this.onLock,
    required this.onRotate,
    required this.episodeLabel,
    this.onDragStart,
    this.onDragEnd,
    this.landscape = true,
  });

  final S s;
  final bool playing;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;
  final String speedLabel;
  final VoidCallback onSpeed;
  final VoidCallback onFit;
  final VoidCallback onEpisodes;
  final VoidCallback onLock;
  final VoidCallback onRotate;
  final String episodeLabel;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.fromLTRB(landscape ? 14 : 10, 0, landscape ? 14 : 10, landscape ? 10 : 14);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
      padding: pad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SeekBar(
            position: position,
            duration: duration,
            buffered: buffered,
            onChanged: onSeek,
            onDragStart: onDragStart,
            onDragEnd: onDragEnd,
            compact: !landscape,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _TapScale(
                scale: .88,
                onTap: onToggle,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: AnimatedSwitcher(
                    duration: M.fast,
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      key: ValueKey(playing),
                      size: 31,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                fmtDuration(position),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text('/', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .35))),
              ),
              Text(
                fmtDuration(duration),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: .55),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              SkinIconButton(icon: Icons.aspect_ratio_rounded, onTap: onFit, size: 18),
              const SizedBox(width: 6),
              SkinTextButton(label: speedLabel, onTap: onSpeed, active: speedLabel != '1.0x'),
              const SizedBox(width: 7),
              SkinTextButton(label: episodeLabel, onTap: onEpisodes),
              const SizedBox(width: 4),
              SkinIconButton(icon: Icons.lock_outline_rounded, onTap: onLock, size: 19, tooltip: s.t('lockTip')),
              SkinIconButton(
                icon: landscape ? Icons.stay_current_portrait_rounded : Icons.stay_current_landscape_rounded,
                onTap: onRotate,
                size: 19,
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

/// 手势 HUD：亮度 / 音量 —— 竖向胶囊条
class SliderHud extends StatelessWidget {
  const SliderHud({super.key, required this.icon, required this.value, required this.label});

  final IconData icon;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xE60E0E12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: .92)),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            width: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(color: Colors.white.withValues(alpha: .16)),
                  FractionallySizedBox(
                    heightFactor: v,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [C.accentDeep, C.accent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${(v * 100).round()}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: .5))),
        ],
      ),
    );
  }
}

/// 快进 / 快退 HUD —— 仿 YouTube 的中间大提示
class SeekHud extends StatelessWidget {
  const SeekHud({super.key, required this.forward, this.seconds, required this.position, required this.duration});

  final bool forward;

  /// 为空时只显示时间（拖动进度条的场景）
  final int? seconds;
  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final sec = seconds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC0E0E12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sec != null) ...[
            Icon(forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded, size: 17, color: C.accent),
            const SizedBox(width: 9),
            Text(
              '${sec > 0 ? '+' : ''}$sec s',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 14, color: Colors.white.withValues(alpha: .18)),
            const SizedBox(width: 12),
          ],
          Text(
            '${fmtDuration(position)} / ${fmtDuration(duration)}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .78),
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// 2× 长按加速提示
class SpeedBadge extends StatelessWidget {
  const SpeedBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC0E0E12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: C.accent.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed_rounded, size: 15, color: C.accent),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.accent)),
        ],
      ),
    );
  }
}

/// 锁定态：只剩一个锁
class LockChip extends StatelessWidget {
  const LockChip({super.key, required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SkinIconButton(icon: Icons.lock_rounded, onTap: onUnlock, size: 21, active: true),
    );
  }
}

/// 播放结束的「下一集」卡片
class NextUpCard extends StatelessWidget {
  const NextUpCard({super.key, required this.s, required this.title, required this.countdown, required this.onPlay, required this.onCancel});

  final S s;
  final String title;
  final int countdown;
  final VoidCallback onPlay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEE14141A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
        boxShadow: Sh.l3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.skip_next_rounded, size: 16, color: C.accent),
              const SizedBox(width: 7),
              Text(s.t('nextEp'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.accent)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4)),
          const SizedBox(height: 5),
          Text('$countdown ${s.t('nextEpIn')}',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .55))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: C.accent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onPlay,
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 34,
                      child: Center(
                        child: Text(s.t('playNow'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF14100A))),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 38,
                    height: 34,
                    child: Icon(Icons.close_rounded, size: 17, color: Colors.white.withValues(alpha: .7)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 中央缓冲圈
class BufferingDot extends StatelessWidget {
  const BufferingDot({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2, color: C.accent),
    );
  }
}
