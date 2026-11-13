import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

String fmtDate(int epochSeconds) {
  if (epochSeconds <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}.${two(d.month)}.${two(d.day)}';
}

void showNoticeSheet(BuildContext context, NoticeItem item) {
  final st = context.read<AppState>();
  showAppSheet(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(C.pad, 20, C.pad, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.accentWash, borderRadius: BorderRadius.circular(6)),
                child: Text(st.s.t('notice'),
                    style: T.tiny.copyWith(color: C.accent, fontSize: 9.5, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text(fmtDate(item.createdAt), style: T.tiny.copyWith(fontSize: 10.5)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, size: 19, color: C.faint),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(C.pad, 14, C.pad, 0),
          child: Text(item.title, style: T.h1.copyWith(fontSize: 21)),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: C.lineSoft, margin: const EdgeInsets.symmetric(horizontal: C.pad)),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(C.pad, 18, C.pad, 8),
            child: MarkdownLite(text: item.content.isEmpty ? item.title : item.content),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(C.pad, 10, C.pad, 26),
          child: GoldButton(label: st.s.t('ok'), onTap: () => Navigator.pop(context), height: 48),
        ),
      ],
    ),
  );
}
