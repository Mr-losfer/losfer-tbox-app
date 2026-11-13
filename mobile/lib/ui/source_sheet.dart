import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

Future<void> showSourceSheet(BuildContext context) async {
  final st = context.read<AppState>();
  await showAppSheet(
    context,
    child: StatefulBuilder(
      builder: (context, setLocal) {
        final s = st.s;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetTitle(
              title: s.t('chooseSource'),
              subtitle: st.needsVip ? '${st.sources.length} · ${s.t('vipOnly')} = ${st.sources.where((e) => e.isVip).length}' : '${st.sources.length}',
              onClose: () => Navigator.pop(context),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(C.pad, 6, C.pad, 26),
                itemCount: st.sources.length,
                itemBuilder: (context, i) {
                  final src = st.sources[i];
                  final active = st.sourceCode == src.code;
                  final locked = !st.canPlay(src);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await st.selectSource(src.code);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: active ? C.accentWash : C.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: active ? C.accent.withValues(alpha: .45) : C.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(src.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.h3.copyWith(fontSize: 14, color: active ? C.accent : C.text)),
                                ),
                                const SizedBox(width: 8),
                                if (src.isVip && st.needsVip) const VipPill(text: 'VIP'),
                                if (!src.isVip && st.needsVip) ...[
                                  const SizedBox(width: 6),
                                  Text(s.t('free'),
                                      style: T.tiny.copyWith(color: C.ok.withValues(alpha: .85), fontSize: 9.5, letterSpacing: .6)),
                                ],
                              ],
                            ),
                          ),
                          if (locked)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.lock_outline_rounded, size: 15, color: C.faint),
                            ),
                          if (active)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.check_rounded, size: 17, color: C.accent),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
