import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'fonts.dart';
import 'i18n.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    // 旧版本默认域名自动跟随到新域名（用户手动改过的不动）
    final savedBase = _prefs.getString('base');
    _base = (savedBase == null || savedBase.isEmpty || savedBase == 'https://x.noqi.pro')
        ? defaultBase
        : savedBase;
    _lang = _prefs.getString('lang') ?? 'ug';
    _font = _prefs.getString('font') ?? kDefaultFont;
    _blockProxy = _prefs.getBool('block_proxy') ?? true;
    _secureScreen = _prefs.getBool('secure_screen') ?? true;
    _skipDetail = _prefs.getBool('skip_detail') ?? false;
    _dlEnabled = _prefs.getBool('dl_enabled') ?? false;
    _dlBase = _prefs.getString('dl_base') ?? '';
    _dlKey = _prefs.getString('dl_key') ?? '';
    _sourceCode = _prefs.getString('source') ?? '';
    final rawUser = _prefs.getString('user');
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        user = User.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      } catch (_) {}
    }
    final rawHistory = _prefs.getString('history');
    if (rawHistory != null && rawHistory.isNotEmpty) {
      try {
        final list = (jsonDecode(rawHistory) as List).whereType<Map>();
        for (final m in list) {
          final p = Progress.fromJson(m.cast<String, dynamic>());
          if (p.vodId.isNotEmpty) _progress['${p.site}:${p.vodId}'] = p;
        }
      } catch (_) {}
    }
    _recent = (_prefs.getStringList('recent') ?? []).toList();
  }

  static const defaultBase = 'http://test3.noqi.pro:8090';

  /// 当前 App 版本（用于内置更新比对）。与 pubspec.yaml 保持一致。
  static const String versionName = '1.0.3';
  static const int versionCode = 4;

  /// GitHub 仓库（内置更新从这里拉 Releases）
  static const String updateRepo = 'losfer-tbox-app';

  /// 下载加速代理：优先走它，失败自动回退直连
  static const String ghProxy = 'https://gh-proxy.com/';

  final SharedPreferences _prefs;

  late String _base;
  late String _lang;
  late String _font;
  bool _blockProxy = true;
  bool _secureScreen = true;
  bool _skipDetail = false;
  bool _dlEnabled = false;
  String _dlBase = '';
  String _dlKey = '';
  late String _sourceCode;
  late List<String> _recent;

  final Map<String, Progress> _progress = {};
  final Map<String, _CachedClasses> _classCache = {};

  SiteConfig? config;
  List<SourceSite> sources = const [];
  List<HotItem> hot = const [];
  User? user;

  bool booting = true;
  String? bootError;

  Api? _api;
  Api get api => _api ??= Api(_base, apikey: user?.apikey);

  String get base => _base;
  String get lang => _lang;
  String get font => _font;
  bool get blockProxy => _blockProxy;
  bool get secureScreen => _secureScreen;
  bool get skipDetail => _skipDetail;
  bool get dlEnabled => _dlEnabled;
  String get dlBase => _dlBase;
  String get dlKey => _dlKey;
  S get s => S(_lang);
  bool get isRtl => _lang != 'zh';
  bool get isLoggedIn => user != null;

  SourceSite? get source {
    if (sources.isEmpty) return null;
    for (final x in sources) {
      if (x.code == _sourceCode) return x;
    }
    for (final x in sources) {
      if (x.isDefault) return x;
    }
    return sources.first;
  }

  SourceSite? byCode(String code) {
    for (final x in sources) {
      if (x.code == code) return x;
    }
    return null;
  }

  String get sourceCode => source?.code ?? '';
  String get siteName => config?.siteName ?? 'Noqi';

  List<String> get recent => List.unmodifiable(_recent);
  List<Progress> get history {
    final list = _progress.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  bool canPlay(SourceSite? site) {
    if (site == null) return false;
    if (config == null || !config!.siteVip) return true;
    if (!site.isVip) return true;
    return user?.vipActive == true;
  }

  bool get needsVip => config?.siteVip == true;

  // ── bootstrap ────────────────────────────────────────────
  Future<void> boot() async {
    booting = true;
    bootError = null;
    notifyListeners();
    try {
      final cfg = await api.config();
      final srcs = await api.sources();
      config = cfg;
      sources = srcs;
      if (_sourceCode.isEmpty || !srcs.any((x) => x.code == _sourceCode)) {
        _sourceCode = srcs.isEmpty ? '' : srcs.firstWhere((x) => x.isDefault, orElse: () => srcs.first).code;
        _prefs.setString('source', _sourceCode);
      }
      if (user != null) {
        try {
          final fresh = await api.me();
          user = fresh;
          _prefs.setString('user', jsonEncode(fresh.toJson()));
          _api = null;
        } on ApiError catch (e) {
          if (e.isAuth) {
            user = null;
            _prefs.remove('user');
            _api = null;
          }
        }
      }
      unawaited(_prefetch());
    } on ApiError catch (e) {
      bootError = e.message;
    } catch (_) {
      bootError = '网络连接失败，请检查网络后重试';
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> _prefetch() async {
    try {
      hot = await api.hot(limit: 12);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshHot() async {
    try {
      hot = await api.hot(limit: 12);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBase(String raw) async {
    final v = Api.normalize(raw);
    if (v.isEmpty || v == _base) return;
    _base = v;
    _api = null;
    _classCache.clear();
    await _prefs.setString('base', v);
    notifyListeners();
    await boot();
  }

  Future<void> setLang(String code) async {
    if (code == _lang) return;
    _lang = code;
    await _prefs.setString('lang', code);
    notifyListeners();
  }

  Future<void> setFont(String id) async {
    if (id == _font) return;
    _font = id;
    await _prefs.setString('font', id);
    notifyListeners();
  }

  Future<void> setBlockProxy(bool v) async {
    _blockProxy = v;
    await _prefs.setBool('block_proxy', v);
    notifyListeners();
  }

  Future<void> setSecureScreen(bool v) async {
    _secureScreen = v;
    await _prefs.setBool('secure_screen', v);
    notifyListeners();
  }

  Future<void> setSkipDetail(bool v) async {
    _skipDetail = v;
    await _prefs.setBool('skip_detail', v);
    notifyListeners();
  }

  Future<void> setDlEnabled(bool v) async {
    _dlEnabled = v;
    await _prefs.setBool('dl_enabled', v);
    notifyListeners();
  }

  Future<void> setDlBase(String v) async {
    _dlBase = v.trim();
    await _prefs.setString('dl_base', _dlBase);
    notifyListeners();
  }

  Future<void> setDlKey(String v) async {
    _dlKey = v.trim();
    await _prefs.setString('dl_key', v.trim());
    notifyListeners();
  }

  Future<void> selectSource(String code) async {
    if (code == _sourceCode) return;
    _sourceCode = code;
    await _prefs.setString('source', code);
    notifyListeners();
  }

  // ── account ──────────────────────────────────────────────
  Future<AuthResult> login(String username, String password) async {
    final res = await api.login(username, password);
    if (res.user != null) await _storeUser(res.user!);
    return res;
  }

  Future<AuthResult> register(String email, String password) async {
    final res = await api.register(email, password);
    if (res.user != null) await _storeUser(res.user!);
    return res;
  }

  Future<void> _storeUser(User u) async {
    user = u;
    _api = null;
    await _prefs.setString('user', jsonEncode(u.toJson()));
    notifyListeners();
    try {
      final fresh = await api.me();
      user = fresh;
      await _prefs.setString('user', jsonEncode(fresh.toJson()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshUser() async {
    if (user == null) return;
    try {
      final fresh = await api.me();
      user = fresh;
      await _prefs.setString('user', jsonEncode(fresh.toJson()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {}
    user = null;
    _api = null;
    await _prefs.remove('user');
    notifyListeners();
  }

  // ── content ──────────────────────────────────────────────
  Future<ClassBundle> classes(String code, {bool force = false}) async {
    final cached = _classCache[code];
    if (!force && cached != null && DateTime.now().difference(cached.at).inMinutes < 30) {
      return cached.bundle;
    }
    final bundle = await api.siteHome(code);
    _classCache[code] = _CachedClasses(bundle, DateTime.now());
    return bundle;
  }

  List<VodClass> cachedClasses(String code) => _classCache[code]?.bundle.classes ?? const [];

  // ── progress ─────────────────────────────────────────────
  Progress? progressOf(String site, String vodId) => _progress['$site:$vodId'];

  Future<void> saveProgress(Progress p) async {
    _progress['${p.site}:${p.vodId}'] = p;
    final list = history.take(40).map((e) => e.toJson()).toList();
    await _prefs.setString('history', jsonEncode(list));
    notifyListeners();
  }

  Future<void> removeProgress(String site, String vodId) async {
    _progress.remove('$site:$vodId');
    await _prefs.setString('history', jsonEncode(history.take(40).map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _progress.clear();
    await _prefs.remove('history');
    notifyListeners();
  }

  // ── recent search ────────────────────────────────────────
  Future<void> pushRecent(String wd) async {
    final v = wd.trim();
    if (v.isEmpty) return;
    _recent.removeWhere((e) => e == v);
    _recent.insert(0, v);
    if (_recent.length > 10) _recent = _recent.take(10).toList();
    await _prefs.setStringList('recent', _recent);
    notifyListeners();
  }

  Future<void> clearRecent() async {
    _recent = [];
    await _prefs.remove('recent');
    notifyListeners();
  }
}

class _CachedClasses {
  _CachedClasses(this.bundle, this.at);
  final ClassBundle bundle;
  final DateTime at;
}
