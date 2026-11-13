import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cast.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// 投屏设备选择面板：打开即扫描，点设备返回；返回 null 表示取消。
Future<CastDevice?> showCastSheet(BuildContext context) {
  return showAppSheet<CastDevice>(context, child: const _CastSheet());
}

class _CastSheet extends StatefulWidget {
  const _CastSheet();

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<_CastSheet> {
  List<CastDevice> _devices = const [];
  bool _scanning = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final list = await Dlna.discover();
    if (!mounted) return;
    setState(() {
      _devices = list;
      _scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>().s;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(
          title: s.t('cast'),
          subtitle: _scanning ? s.t('castScan') : s.t('castHint'),
          onClose: () => Navigator.pop(context),
        ),
        const SizedBox(height: 6),
        if (_scanning)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 46),
            child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2, color: C.accent)),
          )
        else if (_devices.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(C.pad, 24, C.pad, 10),
            child: Column(
              children: [
                const Icon(Icons.cast_rounded, size: 34, color: C.faint),
                const SizedBox(height: 14),
                Text(s.t('castEmpty'), style: T.bodySub.copyWith(fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(s.t('castHint'), style: T.tiny.copyWith(fontSize: 10.5), textAlign: TextAlign.center),
                const SizedBox(height: 18),
                SizedBox(width: 150, child: GhostButton(label: s.t('retry'), onTap: _scan, height: 42, icon: Icons.refresh_rounded)),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(C.pad, 4, C.pad, 18),
              itemCount: _devices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = _devices[i];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context, d),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    decoration: BoxDecoration(
                      color: C.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tv_rounded, size: 19, color: C.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text(d.host, style: T.tiny.copyWith(fontSize: 10, color: C.faint)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (!_scanning && _devices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton(
              onPressed: _scan,
              child: Text(s.t('refresh'), style: T.tiny.copyWith(fontSize: 11, color: C.sub)),
            ),
          ),
      ],
    );
  }
}
