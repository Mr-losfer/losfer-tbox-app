import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dl_client.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// 配置第三方下载服务（Base URL + API Key），并可测试连接。
Future<void> showDlSheet(BuildContext context) async {
  final st = context.read<AppState>();
  final s = st.s;
  final baseCtrl = TextEditingController(text: st.dlBase);
  final keyCtrl = TextEditingController(text: st.dlKey);
  var enabled = st.dlEnabled;
  var testing = false;
  var testMsg = '';

  await showAppSheet(
    context,
    expand: true,
    child: StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetTitle(title: s.t('dlConfig'), subtitle: s.t('dlEnableSub'), onClose: () => Navigator.pop(ctx)),
            Padding(
              padding: const EdgeInsets.fromLTRB(C.pad, 6, C.pad, 0),
              child: Row(
                children: [
                  Expanded(child: Text(s.t('dlEnable'), style: T.body.copyWith(fontSize: 13.5))),
                  Switch.adaptive(
                    value: enabled,
                    onChanged: (v) => setState(() => enabled = v),
                    activeThumbColor: const Color(0xFF14100A),
                    activeTrackColor: C.accent,
                    inactiveTrackColor: C.surfaceHi,
                    inactiveThumbColor: C.faint,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Field(controller: baseCtrl, hint: s.t('dlBaseHint'), icon: Icons.dns_outlined),
            const SizedBox(height: 12),
            _Field(controller: keyCtrl, hint: s.t('dlKeyHint'), icon: Icons.key_rounded, obscure: true),
            const SizedBox(height: 12),
            if (testMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(testMsg, style: T.cap.copyWith(fontSize: 11.5, color: testMsg.contains('成功') ? C.accent : C.vip)),
              ),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: s.t('dlConnecting'),
                    icon: Icons.link_outlined,
                    height: 46,
                    onTap: testing
                        ? null
                        : () async {
                            final base = baseCtrl.text.trim();
                            if (base.isEmpty) {
                              setState(() => testMsg = '请先填写服务地址');
                              return;
                            }
                            setState(() {
                              testing = true;
                              testMsg = s.t('dlConnecting');
                            });
                            try {
                              final client = DlClient(base, keyCtrl.text.trim());
                              await client.health();
                              if (ctx.mounted) setState(() => testMsg = '连接成功');
                            } on DlException catch (e) {
                              if (ctx.mounted) setState(() => testMsg = e.message);
                            } catch (_) {
                              if (ctx.mounted) setState(() => testMsg = s.t('dlConnError'));
                            } finally {
                              if (ctx.mounted) setState(() => testing = false);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GoldButton(
                    label: s.t('save'),
                    height: 46,
                    onTap: () async {
                      await st.setDlEnabled(enabled);
                      await st.setDlBase(baseCtrl.text.trim());
                      await st.setDlKey(keyCtrl.text.trim());
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        Toast.show(context, s.t('resetDone'));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, required this.icon, this.obscure = false});
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: C.line)),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          children: [
            Icon(icon, size: 16, color: C.sub),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                style: T.body.copyWith(fontSize: 13),
                decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: T.cap.copyWith(fontSize: 11.5)),
              ),
            ),
          ],
        ),
      );
}
