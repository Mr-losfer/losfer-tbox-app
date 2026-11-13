import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

Future<void> showServerSheet(BuildContext context) async {
  final st = context.read<AppState>();
  final ctrl = TextEditingController(text: st.base);
  await showAppSheet(
    context,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetTitle(title: st.s.t('server'), subtitle: 'https://x.noqi.pro', onClose: () => Navigator.pop(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(C.pad, 8, C.pad, 0),
            child: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              style: T.body,
              decoration: const InputDecoration(hintText: 'https://', prefixIcon: Icon(Icons.language_rounded, size: 18, color: C.faint)),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: C.pad),
            child: GoldButton(
              label: st.s.t('save'),
              onTap: () async {
                final v = Api.normalize(ctrl.text);
                Navigator.pop(context);
                if (v.isNotEmpty) await st.setBase(v);
              },
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    ),
  );
}
