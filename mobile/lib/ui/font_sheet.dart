import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/fonts.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// 字体选择面板：每款字体用自身字形渲染预览，点一下即时生效并持久化。
Future<void> showFontSheet(BuildContext context) {
  return showAppSheet(
    context,
    child: Consumer<AppState>(
      builder: (context, st, _) {
        final s = st.s;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetTitle(title: s.t('font'), subtitle: s.t('fontTip')),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(C.pad, 4, C.pad, 22),
                itemCount: kFonts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final f = kFonts[i];
                  final on = st.font == f.id;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await st.setFont(f.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                      decoration: BoxDecoration(
                        color: on ? C.accentWash : C.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: on ? C.accent.withValues(alpha: .45) : C.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: f.id,
                                    fontSize: 15,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: on ? C.accent : C.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  f.note,
                                  style: T.tiny.copyWith(fontSize: 10.5, color: on ? C.accent.withValues(alpha: .75) : C.faint),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'تەنھا ئوغرى · Noqi 2026 · 4K',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: f.id,
                                    fontSize: 13.5,
                                    height: 1.9,
                                    color: C.sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 160),
                            opacity: on ? 1 : 0,
                            child: const Icon(Icons.check_circle_rounded, size: 20, color: C.accent),
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
