import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/dl_client.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// 选集下载面板：多选剧集后，逐集解析直链并提交到第三方下载服务。
///
/// 供「详情页」与「播放器页」复用：详情页默认全选，播放器页默认选中当前集。
class EpisodeDownloadSheet extends StatefulWidget {
  const EpisodeDownloadSheet({
    super.key,
    required this.vod,
    required this.site,
    required this.episodes,
    this.preselect = const {},
  });

  final Vod vod;
  final String site;
  final List<Episode> episodes;
  final Set<int> preselect;

  @override
  State<EpisodeDownloadSheet> createState() => _EpisodeDownloadSheetState();
}

class _EpisodeDownloadSheetState extends State<EpisodeDownloadSheet> {
  late final Set<int> _sel = {...widget.preselect};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    final eps = widget.episodes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(title: s.t('dlSelectEp'), subtitle: '${s.t('dlSelectedCount')} ${_sel.length} / ${eps.length}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(C.pad, 2, C.pad, 8),
          child: Row(
            children: [
              TextButton(
                onPressed: _busy ? null : () => setState(() => _sel.addAll(List.generate(eps.length, (i) => i))),
                child: Text(s.t('dlSelectAll'), style: T.cap.copyWith(color: C.accent, fontSize: 12)),
              ),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _sel.clear()),
                child: Text(s.t('dlSelectNone'), style: T.cap.copyWith(color: C.faint, fontSize: 12)),
              ),
              const Spacer(),
              if (_sel.length != eps.length && _sel.isNotEmpty)
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _sel.addAll(List.generate(eps.length, (i) => i))),
                  child: Text(s.t('dlSelectAll'), style: T.cap.copyWith(color: C.accent, fontSize: 12)),
                ),
            ],
          ),
        ),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(C.pad, 0, C.pad, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 1.62,
            ),
            itemCount: eps.length,
            itemBuilder: (_, i) {
              final on = _sel.contains(i);
              return GestureDetector(
                onTap: _busy
                    ? null
                    : () => setState(() {
                          if (on) {
                            _sel.remove(i);
                          } else {
                            _sel.add(i);
                          }
                        }),
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
                    eps[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(
                      fontSize: 12.5,
                      color: on ? const Color(0xFF14100A) : C.sub,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(C.pad, 0, C.pad, 18),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: GoldButton(
              label: _busy ? s.t('dlSubmitting') : '${s.t('dlConfirmDownload')} (${_sel.length})',
              height: 48,
              onTap: _busy || _sel.isEmpty ? null : _submit,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final st = context.read<AppState>();
    final s = st.s;
    if (st.dlBase.isEmpty) {
      if (mounted) Toast.show(context, s.t('dlNotConfig'));
      return;
    }
    setState(() => _busy = true);
    final indexes = _sel.toList()..sort();
    var ok = 0;
    String? lastErr;
    try {
      final client = DlClient(st.dlBase, st.dlKey);
      for (final i in indexes) {
        final ep = widget.episodes[i];
        try {
          final info = await st.api.play(
            code: widget.site,
            play: ep.play,
            q: ep.q,
            token: st.user?.playToken,
          );
          await client.submit(url: info.url, title: '${widget.vod.name} ${ep.label}', headers: info.headers);
          ok++;
        } on ApiError catch (e) {
          lastErr ??= e.message;
        } on DlException catch (e) {
          lastErr = e.message;
          break; // 密钥 / 连接错误，整体停止
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
      if (ok > 0) {
        Toast.show(context, s.t('dlSubmittedCount').replaceAll('{n}', '$ok'));
      } else if (lastErr != null) {
        Toast.show(context, lastErr);
      }
    } catch (_) {
      if (!mounted) return;
      Toast.show(context, s.t('dlConnError'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
