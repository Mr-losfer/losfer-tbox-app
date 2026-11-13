import 'package:dio/dio.dart';

import 'models.dart';

class ApiError implements Exception {
  ApiError(this.code, this.message, {this.raw});

  final int code;
  final String message;
  final Map<String, dynamic>? raw;

  bool get isAuth => code == 401;
  bool get isVip => code == 402;
  bool get isBlocked => code == 403;
  bool get isRate => code == 429;
  bool get isUpstream => code == 502;

  @override
  String toString() => message;
}

class ClassBundle {
  const ClassBundle({required this.classes, required this.page});
  final List<VodClass> classes;
  final PageResult page;
}

class AuthResult {
  const AuthResult({this.user, this.verifyRequired = false});
  final User? user;
  final bool verifyRequired;
}

class Api {
  Api(this.base, {this.apikey}) {
    _dio = Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 14),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        if (apikey != null && apikey!.isNotEmpty) 'Authorization': 'Bearer $apikey',
      },
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ));
  }

  final String base;
  final String? apikey;
  late final Dio _dio;

  static String normalize(String raw) {
    var v = raw.trim();
    if (v.isEmpty) return v;
    if (!v.startsWith('http://') && !v.startsWith('https://')) v = 'https://$v';
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  Map<String, dynamic> _unwrap(Response r) {
    final data = r.data;
    if (data is Map) {
      final m = data.map((k, v) => MapEntry(k.toString(), v));
      final code = i(m['code']);
      if (code != 0) {
        throw ApiError(code == 0 ? r.statusCode ?? -1 : code, _msg(code, s(m['msg'])), raw: m);
      }
      return m;
    }
    if (r.statusCode != null && r.statusCode! >= 400) {
      throw ApiError(r.statusCode!, _hint(r.statusCode!));
    }
    throw ApiError(-1, 'Invalid response');
  }

  /// 上游偶尔直接回 `player_err` 这类机器码，别把它当人话丢给用户。
  static const Map<String, String> _tokens = {
    'player_err': '该片源暂时无法播放，换一个片源试试',
    'upstream_error': '片源服务器异常，请稍后重试',
    'no_source': '没有可用的播放源',
    'not_found': '资源不存在或已下架',
    'vod_not_found': '资源不存在或已下架',
    'invalid_token': '登录已失效，请重新登录',
    'token_expired': '登录已失效，请重新登录',
    'rate_limited': '请求过于频繁，请稍后再试',
    'vip_required': '该片源仅限会员',
    'banned': '账号受限，请联系管理员',
  };

  static String _msg(int code, String raw) {
    final m = raw.trim();
    if (m.isEmpty) return _hint(code);
    final hit = _tokens[m.toLowerCase()];
    if (hit != null) return hit;
    // 纯 ASCII 的机器码（player_err / upstream_error 之类）不直接展示
    if (RegExp(r'^[a-zA-Z0-9_.:-]{2,48}$').hasMatch(m)) return _hint(code);
    return m;
  }

  static String _hint(int code) {
    switch (code) {
      case 400:
        return '请求参数有误';
      case 401:
        return '请先登录';
      case 402:
        return '该片源仅限会员';
      case 403:
        return '账号受限或权限不足';
      case 404:
        return '资源不存在';
      case 429:
        return '请求过于频繁，请稍后再试';
      case 502:
        return '片源异常，请切换片源重试';
      default:
        return '网络异常 ($code)';
    }
  }

  Never _throwDio(DioException e) {
    final r = e.response;
    if (r != null) {
      final data = r.data;
      if (data is Map) {
        final m = data.map((k, v) => MapEntry(k.toString(), v));
        final code = i(m['code'], r.statusCode ?? -1);
        throw ApiError(code == 0 ? (r.statusCode ?? -1) : code, _msg(code, s(m['msg'])), raw: m);
      }
      throw ApiError(r.statusCode ?? -1, _hint(r.statusCode ?? -1));
    }
    throw ApiError(-1, '网络连接失败，请检查网络后重试');
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.get(path, queryParameters: query);
      return _unwrap(r);
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<Map<String, dynamic>> _post(String path, {Object? body}) async {
    try {
      final r = await _dio.post(path, data: body);
      return _unwrap(r);
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // ── public ────────────────────────────────────────────────
  Future<SiteConfig> config() async => SiteConfig.fromJson(await _get('/api/portal/config'));

  Future<List<SourceSite>> sources() async {
    final m = await _get('/api/portal/sources');
    final list = m['list'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => SourceSite.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<List<NoticeItem>> notices() async {
    final m = await _get('/api/portal/notices');
    final list = m['list'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => NoticeItem.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<List<Plan>> plans() async {
    final m = await _get('/api/portal/plans');
    final list = m['list'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => Plan.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<List<HotItem>> hot({int limit = 12}) async {
    final m = await _get('/api/portal/hot', query: {'limit': limit});
    final list = m['list'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => HotItem.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<ClassBundle> siteHome(String code) async {
    final m = await _get('/api/portal/site/$code/classes');
    final classes = (m['class'] is List)
        ? (m['class'] as List).whereType<Map>().map((e) => VodClass.fromJson(e.cast<String, dynamic>())).toList()
        : <VodClass>[];
    final items = _vods(m['list']);
    return ClassBundle(
      classes: classes,
      page: PageResult(items: items, page: 1, pageCount: 1, total: items.length),
    );
  }

  Future<PageResult> list(String code, {String t = '', int pg = 1}) async {
    final m = await _get('/api/portal/site/$code/list', query: {'t': t, 'pg': pg});
    return PageResult(
      items: _vods(m['list']),
      page: i(m['page'], pg),
      pageCount: i(m['pagecount'], 1),
      total: i(m['total']),
    );
  }

  Future<PageResult> search(String code, String wd, {int pg = 1}) async {
    final m = await _get('/api/portal/site/$code/search', query: {'wd': wd, 'pg': pg});
    return PageResult(
      items: _vods(m['list']),
      page: i(m['page'], pg),
      pageCount: i(m['pagecount'], 1),
      total: i(m['total']),
    );
  }

  Future<Vod?> detail(String code, String vid) async {
    final m = await _get('/api/portal/site/$code/detail', query: {'vid': vid});
    final list = _vods(m['list']);
    return list.isEmpty ? null : list.first;
  }

  Future<PlayInfo> play({required String code, required String play, required int q, String? token}) async {
    try {
      final r = await _dio.get('/api/play_v2/$code', queryParameters: {
        'play': play,
        'q': q,
        if (token != null && token.isNotEmpty) 'token': token,
        'format': 'json',
      });
      final data = r.data;
      if (data is Map) {
        final m = data.map((k, v) => MapEntry(k.toString(), v));
        final code0 = i(m['code'], 0);
        if (code0 != 0) {
          throw ApiError(code0, _msg(code0, s(m['msg'])), raw: m);
        }
        final url = m['url'];
        String link = '';
        if (url is List) {
          for (final u in url) {
            final v = s(u);
            if (v.startsWith('http')) {
              link = v;
              break;
            }
          }
          if (link.isEmpty && url.isNotEmpty) link = s(url.last);
        } else {
          link = s(url);
        }
        if (link.isEmpty) throw ApiError(400, '播放地址解析失败');
        final headers = <String, String>{};
        final h = m['header'];
        if (h is Map) {
          h.forEach((k, v) {
            final key = k.toString();
            final val = s(v);
            if (val.isNotEmpty) headers[key] = val;
          });
        }
        return PlayInfo(url: link, headers: headers);
      }
      throw ApiError(r.statusCode ?? -1, _hint(r.statusCode ?? -1));
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // ── account ───────────────────────────────────────────────
  Future<AuthResult> login(String username, String password) async {
    final m = await _post('/api/portal/login', body: {'username': username, 'password': password});
    final u = m['user'];
    return AuthResult(user: u is Map ? User.fromJson(u.cast<String, dynamic>()) : null);
  }

  Future<AuthResult> register(String email, String password) async {
    final m = await _post('/api/portal/register', body: {'email': email, 'password': password});
    final u = m['user'];
    if (u is Map) return AuthResult(user: User.fromJson(u.cast<String, dynamic>()));
    return AuthResult(verifyRequired: b(m['verify_required']));
  }

  Future<User> me() async {
    final m = await _get('/api/portal/me');
    final u = m['user'];
    if (u is! Map) throw ApiError(401, '请先登录');
    return User.fromJson(u.cast<String, dynamic>());
  }

  Future<void> changePassword(String oldPwd, String newPwd) =>
      _post('/api/portal/password', body: {'old': oldPwd, 'new': newPwd});

  Future<void> resetKey() => _post('/api/portal/reset_key');
  Future<void> resetPlayToken() => _post('/api/portal/reset_play_token');
  Future<void> logout() => _post('/api/portal/logout');

  Future<void> sendFeedback(String content) =>
      _post('/api/portal/feedback', body: {'type': 'feedback', 'content': content});

  Future<List<FeedItem>> myFeedback() async {
    final m = await _get('/api/portal/feedback');
    final list = m['list'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => FeedItem.fromJson(e.cast<String, dynamic>())).toList();
  }

  List<Vod> _vods(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Vod.fromJson(e.cast<String, dynamic>())).toList();
  }
}
