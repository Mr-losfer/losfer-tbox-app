import 'package:dio/dio.dart';

import 'api.dart';

/// 第三方下载服务客户端（兼容 Media Super 风格的 REST API）。
/// 通过「设置 → 下载服务」配置 Base URL 与 API Key。
///
/// 端点总览（参考）：
///   GET  /api/health                  健康检查（免鉴权）
///   POST /api/tasks                   提交下载任务
///   GET  /api/tasks                   任务列表
///   GET  /api/tasks/`id`              单个任务详情
///   POST /api/tasks/`id`/cancel       取消
///   POST /api/tasks/`id`/retry        重新排队
///   DELETE /api/tasks/`id`            删除任务 ?file=true 连文件
///   GET  /api/tasks/`id`/stream       在线播放（支持 Range）
class DlTask {
  const DlTask({
    required this.id,
    required this.title,
    required this.status,
    required this.progress,
    required this.size,
    required this.downloaded,
    required this.saveDir,
    required this.url,
    required this.speed,
  });

  final String id;
  final String title;
  final String status;
  final int progress; // 0-100
  final int size; // bytes
  final int downloaded; // bytes
  final String saveDir;
  final String url;
  final String speed; // 文本，如 "3.2 MB/s"

  bool get active => status == 'queued' || status == 'running' || status == 'merging';
  bool get completed => status == 'completed';
  bool get failed => status == 'failed';
  bool get canceled => status == 'canceled';

  factory DlTask.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] ?? 'queued').toString();
    final size = _num(j['size']);
    final downloaded = _num(j['downloaded']) != 0 ? _num(j['downloaded']) : _num(j['downloaded_size']);
    int progress = _num(j['progress']);
    if (progress <= 0 && size > 0 && downloaded > 0) {
      progress = ((downloaded / size) * 100).round().clamp(0, 100);
    }
    return DlTask(
      id: (j['id'] ?? '').toString(),
      title: s(j['title']).isEmpty ? s(j['name']) : s(j['title']),
      status: status,
      progress: progress.clamp(0, 100),
      size: size,
      downloaded: downloaded,
      saveDir: s(j['save_dir']),
      url: s(j['url']),
      speed: s(j['speed']),
    );
  }
}

class DlClient {
  DlClient(this.base, this.apiKey) {
    final b = Api.normalize(base);
    _dio = Dio(BaseOptions(
      baseUrl: b,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: _headers,
    ));
  }

  final String base;
  final String apiKey;
  late final Dio _dio;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      };

  Future<void> health() async {
    final r = await _dio.get('/api/health');
    if (r.statusCode == null || r.statusCode! >= 400) {
      throw DlException('服务连接失败 (${r.statusCode})');
    }
  }

  Future<List<DlTask>> tasks({String? status, int limit = 50, int offset = 0}) async {
    final r = await _dio.get('/api/tasks', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      'limit': limit,
      'offset': offset,
    });
    _assert(r);
    final data = r.data;
    final list = data is Map ? data['items'] ?? data['list'] : data;
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => DlTask.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<DlTask> task(String id) async {
    final r = await _dio.get('/api/tasks/$id');
    _assert(r);
    final data = r.data;
    final m = data is Map ? data : {'id': id};
    return DlTask.fromJson(m.cast<String, dynamic>());
  }

  Future<void> submit({
    required String url,
    String? title,
    String? saveDir,
    Map<String, String>? headers,
  }) async {
    final r = await _dio.post('/api/tasks', data: {
      'url': url,
      if (title != null && title.isNotEmpty) 'title': title,
      if (saveDir != null && saveDir.isNotEmpty) 'save_dir': saveDir,
      if (headers != null && headers.isNotEmpty) 'headers': headers,
    });
    _assert(r);
  }

  Future<void> cancel(String id) async {
    final r = await _dio.post('/api/tasks/$id/cancel');
    _assert(r);
  }

  Future<void> retry(String id) async {
    final r = await _dio.post('/api/tasks/$id/retry');
    _assert(r);
  }

  Future<void> delete(String id, {bool file = false}) async {
    final r = await _dio.delete('/api/tasks/$id', queryParameters: {if (file) 'file': 'true'});
    _assert(r);
  }

  /// 在线播放地址：浏览器 / <video> 直接用，token 走 query 方便播放器使用。
  String streamUrl(String id) => '$base/api/tasks/$id/stream?token=$apiKey';

  /// 文件下载地址（带 token）。
  String downloadUrl(String id) => '$base/api/tasks/$id/download?token=$apiKey';

  void _assert(Response r) {
    if (r.statusCode == 401) throw DlException('密钥无效或未授权 (401)');
    if (r.statusCode == 404) throw DlException('任务不存在 (404)');
    if (r.statusCode == 409) throw DlException('文件尚未就绪 (409)');
    if (r.statusCode == 429) throw DlException('请求过于频繁 (429)');
    if (r.statusCode != null && r.statusCode! >= 400) {
      throw DlException(_errMsg(r));
    }
  }

  String _errMsg(Response r) {
    final data = r.data;
    if (data is Map && data['error'] != null) return s(data['error']);
    if (data is Map && data['msg'] != null) return s(data['msg']);
    return '请求失败 (${r.statusCode})';
  }
}

class DlException implements Exception {
  DlException(this.message);
  final String message;
  @override
  String toString() => message;
}

int _num(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(s(v)) ?? 0;
}

String s(dynamic v) => v == null ? '' : v.toString();
