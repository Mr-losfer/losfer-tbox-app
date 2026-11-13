import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

Future<void> showAuthSheet(BuildContext context, {bool register = false}) async {
  await showAppSheet(context, child: _AuthSheet(startWithRegister: register));
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({this.startWithRegister = false});
  final bool startWithRegister;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  late bool _register = widget.startWithRegister;
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _notice;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    super.dispose();
  }

  static const _oauthLabels = {
    'qq': 'QQ',
    'wx': '微信',
    'wechat': '微信',
    'alipay': '支付宝',
    'sina': '微博',
    'baidu': '百度',
    'douyin': '抖音',
    'huawei': '华为',
    'xiaomi': '小米',
    'dingtalk': '钉钉',
    'gitee': 'Gitee',
    'github': 'GitHub',
    'feishu': '飞书',
    'facebook': 'Facebook',
  };

  Future<void> _submit() async {
    final st = context.read<AppState>();
    final email = _email.text.trim();
    final pwd = _pwd.text;
    setState(() {
      _error = null;
      _notice = null;
    });
    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请填写完整信息');
      return;
    }
    if (pwd.length < 6) {
      setState(() => _error = '密码至少 6 位');
      return;
    }
    if (_register && !email.contains('@')) {
      setState(() => _error = '邮箱格式不正确');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = _register ? await st.register(email, pwd) : await st.login(email, pwd);
      if (!mounted) return;
      if (res.verifyRequired) {
        setState(() {
          _busy = false;
          _notice = st.s.t('verifySent');
        });
        return;
      }
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      Toast.show(context, '${st.s.t('login')} · ${st.user?.displayName ?? ''}');
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '网络连接失败';
      });
    }
  }

  Future<void> _oauth(String type) async {
    final st = context.read<AppState>();
    final uri = Uri.parse('${st.base}/oauth/start/$type');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() => _notice = '已打开浏览器授权，完成后请返回 App 用邮箱密码登录');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '无法打开浏览器');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    final types = (st.config?.oauthTypes ?? const []).where((e) => _oauthLabels.containsKey(e)).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(C.pad, 8, C.pad, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const BrandMark(size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_register ? s.t('registerTitle') : st.siteName, style: T.h2),
                      const SizedBox(height: 2),
                      Text(_register ? s.t('registerTitle') : s.t('loginSub'), style: T.cap.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, size: 20, color: C.faint),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Field(
              controller: _email,
              hint: s.t('email'),
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _pwd,
              hint: s.t('pwdHint'),
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              trailing: GestureDetector(
                onTap: () => setState(() => _obscure = !_obscure),
                child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17, color: C.faint),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: C.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error!, style: T.cap.copyWith(fontSize: 12, color: C.danger))),
                ],
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined, size: 14, color: C.ok),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_notice!, style: T.cap.copyWith(fontSize: 12, color: C.ok))),
                ],
              ),
            ],
            const SizedBox(height: 18),
            GoldButton(
              label: _register ? s.t('register') : s.t('login'),
              busy: _busy,
              onTap: _submit,
              height: 50,
            ),
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: () {
                  if (_register && !(st.config?.registerOpen ?? true)) {
                    setState(() => _error = s.t('registerClosed'));
                    return;
                  }
                  setState(() {
                    _register = !_register;
                    _error = null;
                    _notice = null;
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: T.cap.copyWith(fontSize: 12),
                    children: [
                      TextSpan(text: _register ? s.t('hasAccount') : s.t('noAccount')),
                      TextSpan(
                        text: _register ? s.t('login') : s.t('register'),
                        style: const TextStyle(color: C.accent, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (types.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: C.lineSoft)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(s.t('otherLogin'), style: T.tiny.copyWith(fontSize: 10.5)),
                  ),
                  Expanded(child: Container(height: 1, color: C.lineSoft)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in types)
                    GestureDetector(
                      onTap: () => _oauth(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        decoration: BoxDecoration(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: C.line),
                        ),
                        child: Text(_oauthLabels[t] ?? t,
                            style: T.cap.copyWith(fontSize: 11.5, color: C.text, fontWeight: FontWeight.w500)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, size: 17, color: C.faint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              onSubmitted: onSubmitted,
              textInputAction: onSubmitted != null ? TextInputAction.done : TextInputAction.next,
              style: T.body.copyWith(fontSize: 14),
              cursorHeight: 16,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                hintText: hint,
                hintStyle: T.cap.copyWith(color: C.faint, fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          if (trailing != null) Padding(padding: const EdgeInsets.only(right: 14), child: trailing!),
          if (trailing == null) const SizedBox(width: 14),
        ],
      ),
    );
  }
}
