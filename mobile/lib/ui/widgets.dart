import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';

/// ── brand mark ─────────────────────────────────────────────
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34, this.color = C.accent});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8D695), Color(0xFFD99A3F)],
        ),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * .42, size * .42),
          painter: _PlayMarkPainter(color: const Color(0xFF0A0A0C)),
        ),
      ),
    );
  }
}

class _PlayMarkPainter extends CustomPainter {
  _PlayMarkPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width * .18, size.height * .08)
      ..lineTo(size.width * .92, size.height * .5)
      ..lineTo(size.width * .18, size.height * .92)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _PlayMarkPainter old) => old.color != color;
}

class BrandRow extends StatelessWidget {
  const BrandRow({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(size: 30),
        const SizedBox(width: 11),
        Expanded(
          child: Text(title.toUpperCase(), style: T.brand.copyWith(fontSize: 15, letterSpacing: 3.4), maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        ?trailing,
      ],
    );
  }
}

/// ── image ──────────────────────────────────────────────────
class NetImage extends StatelessWidget {
  const NetImage({super.key, required this.url, this.fit = BoxFit.cover, this.alignment = Alignment.center, this.radius = 0, this.width, this.height, this.quality = FilterQuality.medium});
  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double radius;
  final double? width;
  final double? height;
  final FilterQuality quality;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (url.isEmpty) {
      child = const _ImgFallback();
    } else {
      child = Image.network(
        url,
        fit: fit,
        alignment: alignment,
        width: width ?? double.infinity,
        height: height,
        filterQuality: quality,
        gaplessPlayback: true,
        frameBuilder: (context, widget, frame, wasSync) {
          if (wasSync) return widget;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOut,
            child: widget,
          );
        },
        errorBuilder: (_, _, _) => const _ImgFallback(),
      );
    }
    if (radius <= 0) return child;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.surface,
      alignment: Alignment.center,
      child: const Icon(Icons.movie_outlined, size: 22, color: C.faint),
    );
  }
}

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.radius = 12, this.width, this.height});
  final double radius;
  final double? width;
  final double? height;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, -.4),
              end: Alignment(t * 2, .4),
              colors: const [Color(0xFF121216), Color(0xFF1B1B22), Color(0xFF121216)],
            ),
          ),
        );
      },
    );
  }
}

/// ── poster card ────────────────────────────────────────────
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.vod,
    required this.onTap,
    this.width = 122,
    this.showTitle = true,
    this.locked = false,
    this.badge,
  });

  final Vod vod;
  final VoidCallback onTap;
  final double width;
  final bool showTitle;
  final bool locked;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.48;
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), boxShadow: Sh.l1),
              child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: width,
                height: h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(url: vod.pic),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC000000)],
                          stops: [.45, 1],
                        ),
                      ),
                    ),
                    if (_score(vod.score) > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xA6000000),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_score(vod.score).toStringAsFixed(1),
                              style: T.num.copyWith(fontSize: 10.5, color: C.accent)),
                        ),
                      ),
                    if (locked)
                      Positioned(
                        top: 7,
                        left: 7,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: const Color(0xA6000000), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.lock_outline_rounded, size: 11, color: C.vip),
                        ),
                      ),
                    if ((badge ?? vod.remarks).isNotEmpty)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 7,
                        child: Text(
                          badge ?? vod.remarks,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Color(0xFFD8D8DE), height: 1.2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ),
            if (showTitle) ...[
              const SizedBox(height: 8),
              Text(vod.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.cap.copyWith(color: C.text, fontSize: 12.5, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }

  static double _score(String raw) {
    final v = double.tryParse(raw.split(' ').first);
    return v ?? 0;
  }
}

class GridPoster extends StatelessWidget {
  const GridPoster({super.key, required this.vod, required this.onTap, this.locked = false});
  final Vod vod;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return PosterCard(vod: vod, onTap: onTap, width: c.maxWidth, locked: locked);
    });
  }
}

/// ── section head ───────────────────────────────────────────
class SectionHead extends StatelessWidget {
  const SectionHead({super.key, required this.title, this.trailing, this.pad = C.pad});
  final String title;
  final Widget? trailing;
  final double pad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 26, pad, 13),
      child: Row(
        children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 9),
          Expanded(child: Text(title, style: T.h3.copyWith(fontSize: 15.5))),
          ?trailing,
        ],
      ),
    );
  }
}

/// ── chips ──────────────────────────────────────────────────
class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap, this.trailingIcon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8.5),
        decoration: BoxDecoration(
          color: selected ? C.text : C.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? Colors.transparent : C.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: T.cap.copyWith(
                  color: selected ? C.bg : C.sub,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
            if (trailingIcon != null) ...[
              const SizedBox(width: 5),
              Icon(trailingIcon, size: 13, color: selected ? C.bg : C.faint),
            ],
          ],
        ),
      ),
    );
  }
}

class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.items, required this.index, required this.onSelect, this.pad = C.pad, this.leading});
  final List<String> items;
  final int index;
  final ValueChanged<int> onSelect;
  final double pad;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: pad),
        itemCount: items.length + (leading != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (leading != null && i == 0) return leading!;
          final idx = i - (leading != null ? 1 : 0);
          return SelectChip(label: items[idx], selected: idx == index, onTap: () => onSelect(idx));
        },
      ),
    );
  }
}

/// ── buttons ────────────────────────────────────────────────
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, required this.onTap, this.icon, this.busy = false, this.expanded = true, this.height = 50});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final bool expanded;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final child = AnimatedOpacity(
      opacity: enabled ? 1 : .55,
      duration: const Duration(milliseconds: 180),
      child: Container(
        height: height,
        width: expanded ? double.infinity : null,
        padding: expanded ? null : const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: C.goldGrad,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: C.accent.withValues(alpha: .16), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF14100A)),
              )
            else if (icon != null)
              Icon(icon, size: 18, color: const Color(0xFF14100A)),
            if (busy || icon != null) const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF14100A), height: 1.2)),
          ],
        ),
      ),
    );
    return GestureDetector(onTap: enabled ? onTap : null, child: child);
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap, this.icon, this.height = 50, this.expanded = true});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: expanded ? double.infinity : null,
        padding: expanded ? null : const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 17, color: C.text), const SizedBox(width: 7)],
            Text(label, style: T.h3.copyWith(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class IconPill extends StatelessWidget {
  const IconPill({super.key, required this.icon, required this.onTap, this.size = 40, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final w = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle, border: Border.all(color: C.line)),
        child: Icon(icon, size: size * .46, color: C.text),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

/// ── states ─────────────────────────────────────────────────
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: C.accent)),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(label!, style: T.tiny.copyWith(letterSpacing: 1.2)),
          ],
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.text, this.icon = Icons.inbox_outlined, this.action});
  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: C.faint),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: T.bodySub),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry, this.retryLabel = '重试'});
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle, border: Border.all(color: C.line)),
              child: const Icon(Icons.wifi_off_rounded, size: 22, color: C.sub),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: T.bodySub),
            const SizedBox(height: 20),
            SizedBox(width: 150, child: GhostButton(label: retryLabel, onTap: onRetry, height: 44, icon: Icons.refresh_rounded)),
          ],
        ),
      ),
    );
  }
}

/// ── sheet scaffold ─────────────────────────────────────────
Future<R?> showAppSheet<R>(BuildContext context, {required Widget child, bool expand = false}) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xB3000000),
    builder: (_) => _SheetFrame(expand: expand, child: child),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child, this.expand = false});
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
        decoration: const BoxDecoration(
          color: C.bgSoft,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: C.line)),
        ),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: C.surfaceHi, borderRadius: BorderRadius.circular(3))),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class SheetTitle extends StatelessWidget {
  const SheetTitle({super.key, required this.title, this.subtitle, this.onClose});
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(C.pad, 16, C.pad, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.h2),
                if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: T.cap)],
              ],
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.only(top: 2, left: 8),
                child: Icon(Icons.close_rounded, size: 20, color: C.faint),
              ),
            ),
        ],
      ),
    );
  }
}

/// ── misc ───────────────────────────────────────────────────
class ScorePill extends StatelessWidget {
  const ScorePill({super.key, required this.score});
  final String score;

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(score.split(' ').first);
    if (v == null || v <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: C.accentWash,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: C.accent.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: C.accent),
          const SizedBox(width: 3),
          Text(v.toStringAsFixed(1), style: T.num.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class VipPill extends StatelessWidget {
  const VipPill({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(gradient: C.goldGrad, borderRadius: BorderRadius.circular(5)),
      child: Text(text,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF151007), letterSpacing: .6)),
    );
  }
}

class MetaDot extends StatelessWidget {
  const MetaDot({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Container(width: 2.5, height: 2.5, decoration: const BoxDecoration(color: C.faint, shape: BoxShape.circle)),
      );
}

class Toast {
  static void show(BuildContext context, String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(
      content: Text(msg, style: T.body.copyWith(fontSize: 13.5)),
      duration: const Duration(milliseconds: 2400),
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.surfaceHi,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.line)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
    ));
  }
}

/// ── tiny markdown for notices ──────────────────────────────
class MarkdownLite extends StatelessWidget {
  const MarkdownLite({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final children = <Widget>[];
    for (var raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('### ')) {
        children.add(Padding(padding: const EdgeInsets.only(top: 6, bottom: 4), child: Text(line.substring(4), style: T.h3)));
      } else if (line.startsWith('## ')) {
        children.add(Padding(padding: const EdgeInsets.only(top: 8, bottom: 5), child: Text(line.substring(3), style: T.h2)));
      } else if (line.startsWith('# ')) {
        children.add(Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: Text(line.substring(2), style: T.h1.copyWith(fontSize: 20))));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 7, left: 2, right: 8), child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle))),
              Expanded(child: _rich(line.substring(2), T.body)),
            ],
          ),
        ));
      } else if (line.startsWith('```')) {
        children.add(const SizedBox(height: 4));
      } else {
        children.add(Padding(padding: const EdgeInsets.only(bottom: 4), child: _rich(line, T.body)));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _rich(String line, TextStyle base) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\))');
    var idx = 0;
    for (final m in pattern.allMatches(line)) {
      if (m.start > idx) spans.add(TextSpan(text: line.substring(idx, m.start), style: base));
      final token = m.group(0)!;
      if (token.startsWith('**')) {
        spans.add(TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700, color: C.text)));
      } else {
        final label = token.substring(1, token.indexOf(']'));
        spans.add(TextSpan(text: label, style: base.copyWith(color: C.accent, decoration: TextDecoration.underline)));
      }
      idx = m.end;
    }
    if (idx < line.length) spans.add(TextSpan(text: line.substring(idx), style: base));
    return RichText(text: TextSpan(style: base, children: spans));
  }
}

/// subtle press-scale feedback wrapper
/// 入场动画：淡入 + 上滑，配合 delay 做 stagger
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: M.slow);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: M.curve);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .035), end: Offset.zero).animate(_a),
        child: widget.child,
      ),
    );
  }
}

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.scale = .97});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap!.call();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

double easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
