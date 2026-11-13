import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 极简 DLNA / UPnP AVTransport 投屏实现（零插件，纯 dart:io）。
///
/// 流程：SSDP M-SEARCH 发现 MediaRenderer → 拉设备描述取 AVTransport 控制地址
/// → SOAP 下发 SetAVTransportURI + Play。电视端只要支持标准 DLNA 即可（小米、
/// 索尼、三星、LG、当贝、各类投屏盒子等）。
class CastDevice {
  const CastDevice({
    required this.name,
    required this.location,
    required this.controlUrl,
    required this.host,
  });

  final String name;
  final String location;
  final String controlUrl;
  final String host;

  @override
  bool operator ==(Object other) => other is CastDevice && other.location == location;

  @override
  int get hashCode => location.hashCode;
}

class DlnaException implements Exception {
  DlnaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Dlna {
  static const _searchTarget = 'urn:schemas-upnp-org:device:MediaRenderer:1';

  static const _searchMessage = 'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: $_searchTarget\r\n'
      'USER-AGENT: Noqi/1.0 UPnP/1.1 DLNADOC/1.50\r\n'
      '\r\n';

  /// 局域网发现，默认 4 秒；同一设备只保留一条。
  static Future<List<CastDevice>> discover({Duration timeout = const Duration(seconds: 4)}) async {
    final found = <String, String>{}; // location -> usn/host
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket!.receive();
        if (dg == null) return;
        final text = utf8.decode(dg.data, allowMalformed: true);
        if (!text.toUpperCase().contains('200 OK') && !text.toUpperCase().contains('HTTP/1.1 200')) return;
        final headers = _headers(text);
        final location = headers['location'];
        if (location == null || location.isEmpty) return;
        found.putIfAbsent(location, () => dg.address.address);
      });

      final target = InternetAddress('239.255.255.250');
      for (var i = 0; i < 3; i++) {
        socket.send(utf8.encode(_searchMessage), target, 1900);
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
      await Future<void>.delayed(timeout);

      await sub.cancel();
      socket.close();
      socket = null;

      final devices = await Future.wait(found.entries.map((e) => _describe(e.key, e.value)));
      final clean = devices.whereType<CastDevice>().toList();
      clean.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return clean;
    } catch (_) {
      socket?.close();
      return const [];
    }
  }

  static Future<CastDevice?> _describe(String location, String fallbackHost) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client.getUrl(Uri.parse(location));
      final res = await req.close().timeout(const Duration(seconds: 4));
      final xml = await res.transform(utf8.decoder).join();
      final name = _tag(xml, 'friendlyName') ?? Uri.parse(location).host;
      var control = _avTransportControl(xml);
      if (control == null) return null;
      control = _absolute(location, control);
      return CastDevice(
        name: name.trim(),
        location: location,
        controlUrl: control,
        host: Uri.parse(location).host.isEmpty ? fallbackHost : Uri.parse(location).host,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 从设备描述里找 AVTransport 的 controlURL（相对路径按 location 解析）
  static String? _avTransportControl(String xml) {
    final services = RegExp(r'<service>(.*?)</service>', dotAll: true).allMatches(xml);
    for (final m in services) {
      final block = m.group(1) ?? '';
      final type = _tag(block, 'serviceType') ?? '';
      if (!type.contains('AVTransport')) continue;
      final c = _tag(block, 'controlURL');
      if (c != null && c.isNotEmpty) return c;
    }
    // 有的设备把服务直接平铺在 device 下
    if (xml.contains('AVTransport')) return _tag(xml, 'controlURL');
    return null;
  }

  static String? _tag(String xml, String tag) {
    final m = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(xml);
    return m?.group(1);
  }

  static Map<String, String> _headers(String raw) {
    final out = <String, String>{};
    for (final line in raw.split('\r\n')) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      out[line.substring(0, i).trim().toLowerCase()] = line.substring(i + 1).trim();
    }
    return out;
  }

  static String _absolute(String base, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final uri = Uri.parse(base);
    return uri.resolve(path).toString();
  }
}

/// 一次投屏会话：下发地址、播放 / 暂停 / 停止。
class CastSession {
  CastSession(this.device);

  final CastDevice device;
  bool _playing = false;

  bool get playing => _playing;

  Future<void> open(String url, {String title = 'Noqi', String mime = 'video/mp4'}) async {
    final meta = _didl(url, title, mime);
    await _soap('SetAVTransportURI', '''
<InstanceID>0</InstanceID>
<CurrentURI>${_esc(url)}</CurrentURI>
<CurrentURIMetaData>${_esc(meta)}</CurrentURIMetaData>''');
    await _soap('Play', '<InstanceID>0</InstanceID><Speed>1</Speed>');
    _playing = true;
  }

  Future<void> pause() async {
    await _soap('Pause', '<InstanceID>0</InstanceID>');
    _playing = false;
  }

  Future<void> resume() async {
    await _soap('Play', '<InstanceID>0</InstanceID><Speed>1</Speed>');
    _playing = true;
  }

  Future<void> stop() async {
    try {
      await _soap('Stop', '<InstanceID>0</InstanceID>');
    } finally {
      _playing = false;
    }
  }

  Future<void> _soap(String action, String body) async {
    const service = 'urn:schemas-upnp-org:service:AVTransport:1';
    final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body><u:$action xmlns:u="$service">$body</u:$action></s:Body></s:Envelope>''';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(Uri.parse(device.controlUrl));
      req.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      req.headers.set('SOAPACTION', '"$service#$action"');
      req.headers.set('Connection', 'close');
      req.add(utf8.encode(envelope));
      final res = await req.close().timeout(const Duration(seconds: 6));
      await res.drain<void>();
      if (res.statusCode >= 400) {
        throw DlnaException('电视拒绝了请求（${res.statusCode}）');
      }
    } on SocketException {
      throw DlnaException('连接电视失败，请确认在同一 Wi-Fi');
    } finally {
      client.close(force: true);
    }
  }

  static String _didl(String url, String title, String mime) =>
      '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
      '<item id="0" parentID="-1" restricted="1">'
      '<dc:title>${_esc(title)}</dc:title>'
      '<upnp:class>object.item.videoItem</upnp:class>'
      '<res protocolInfo="http-get:*:$mime:*">${_esc(url)}</res>'
      '</item></DIDL-Lite>';

  static String _esc(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
