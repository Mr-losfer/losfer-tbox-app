import 'package:dio/dio.dart';

import 'store.dart';

/// 内置更新：从 GitHub Releases 拉取最新版本并对比。
/// 检测与下载优先走 gh-proxy.com 代理，失败自动回退直连。
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, required this.size});
  final String name;
  final String url;
  final int size;
}

class UpdateInfo {
  const UpdateInfo({
    required this.tag,
    required this.version,
    required this.notes,
    required this.assets,
    this.apkUrl,
  });
  final String tag;
  final String version;
  final String notes;
  final List<ReleaseAsset> assets;
  final String? apkUrl;
}

class Updater {
  static const String _repo = 'Mr-losfer/losfer-tbox-app';
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.json,
    validateStatus: (_) => true,
  ));

  /// 依次尝试：gh-proxy 代理 → 直连。任一成功即返回。
  static Future<UpdateInfo> fetchLatest() async {
    final candidates = <String>[
      '${AppState.ghProxy}https://api.github.com/repos/$_repo/releases/latest',
      'https://api.github.com/repos/$_repo/releases/latest',
    ];
    DioException? lastErr;
    for (final url in candidates) {
      try {
        final r = await _dio.get<Map<String, dynamic>>(
          url,
          options: Options(headers: {'Accept': 'application/vnd.github+json'}),
        );
        if (r.statusCode == 200 && r.data is Map) {
          return _parse(r.data!);
        }
      } on DioException catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? DioException(requestOptions: RequestOptions(path: ''), message: '无法获取更新信息');
  }

  static UpdateInfo _parse(Map<String, dynamic> d) {
    final tag = (d['tag_name'] ?? '').toString();
    final notes = (d['body'] ?? '').toString();
    final assets = <ReleaseAsset>[];
    String? apkUrl;
    final raw = d['assets'];
    if (raw is List) {
      for (final a in raw) {
        if (a is! Map) continue;
        final name = (a['name'] ?? '').toString();
        final url = (a['browser_download_url'] ?? '').toString();
        final size = a['size'] is int ? a['size'] as int : int.tryParse('${a['size']}') ?? 0;
        if (url.isEmpty) continue;
        final asset = ReleaseAsset(name: name, url: url, size: size);
        assets.add(asset);
        if (apkUrl == null && name.toLowerCase().endsWith('.apk')) apkUrl = url;
      }
    }
    return UpdateInfo(
      tag: tag,
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      notes: notes,
      assets: assets,
      apkUrl: apkUrl,
    );
  }

  /// 传入的版本是否比当前已安装版本更新（语义化版本比对）。
  static bool isNewer(String latest) => _compare(latest, AppState.versionName) > 0;

  static int _compare(String a, String b) {
    List<int> parse(String v) => v
        .replaceFirst(RegExp(r'^v'), '')
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9].*\$'), '')) ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    for (var i = 0; i < 3; i++) {
      final x = pa.length > i ? pa[i] : 0;
      final y = pb.length > i ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  /// 返回一个最优的下载地址：优先 gh-proxy 代理（若是直连的 github 资源），
  /// 否则直连。这样「检测」与「下载」一致地优先代理、无效自动直连。
  static String proxiedUrl(String raw) {
    if (raw.startsWith('https://github.com/') || raw.startsWith('https://raw.githubusercontent.com/')) {
      return '${AppState.ghProxy}$raw';
    }
    return raw;
  }
}
