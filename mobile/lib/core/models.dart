String s(dynamic v) => v == null ? '' : v.toString();

int i(dynamic v, [int d = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(s(v)) ?? d;
}

bool b(dynamic v, [bool d = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return d;
}

double dnum(dynamic v, [double d = 0]) {
  if (v is num) return v.toDouble();
  return double.tryParse(s(v)) ?? d;
}

class SiteConfig {
  const SiteConfig({
    this.siteName = 'Noqi',
    this.registerOpen = true,
    this.forceRegister = false,
    this.detailLogin = false,
    this.siteVip = false,
    this.oauthEnabled = false,
    this.oauthTypes = const [],
    this.adEnabled = false,
    this.adTitle = '',
    this.adContent = '',
    this.subscriptionUrl = '',
    this.wmEnabled = false,
    this.wmText = '',
    this.emailVerify = false,
  });

  final String siteName;
  final bool registerOpen;
  final bool forceRegister;
  final bool detailLogin;
  final bool siteVip;
  final bool oauthEnabled;
  final List<String> oauthTypes;
  final bool adEnabled;
  final String adTitle;
  final String adContent;
  final String subscriptionUrl;
  final bool wmEnabled;
  final String wmText;
  final bool emailVerify;

  factory SiteConfig.fromJson(Map<String, dynamic> j) => SiteConfig(
        siteName: s(j['site_name']).isEmpty ? 'Noqi' : s(j['site_name']),
        registerOpen: b(j['register_open'], true),
        forceRegister: b(j['force_register']),
        detailLogin: b(j['detail_login']),
        siteVip: b(j['site_vip']),
        oauthEnabled: b(j['oauth_enabled']),
        oauthTypes: (j['oauth_types'] is List) ? (j['oauth_types'] as List).map(s).toList() : const [],
        adEnabled: b(j['ad_enabled']),
        adTitle: s(j['ad_title']),
        adContent: s(j['ad_content']),
        subscriptionUrl: s(j['subscription_url']),
        wmEnabled: b(j['wm_enabled']),
        wmText: s(j['wm_text']),
        emailVerify: b(j['email_verify']),
      );
}

class SourceSite {
  const SourceSite({required this.code, required this.name, this.isDefault = false, this.isVip = false});
  final String code;
  final String name;
  final bool isDefault;
  final bool isVip;

  factory SourceSite.fromJson(Map<String, dynamic> j) => SourceSite(
        code: s(j['code']),
        name: s(j['name']),
        isDefault: i(j['is_default']) == 1,
        isVip: i(j['is_vip']) == 1,
      );
}

class VodClass {
  const VodClass({required this.id, required this.name});
  final String id;
  final String name;
  factory VodClass.fromJson(Map<String, dynamic> j) => VodClass(id: s(j['type_id']), name: s(j['type_name']));
}

class Vod {
  const Vod({
    required this.id,
    required this.name,
    this.pic = '',
    this.remarks = '',
    this.typeName = '',
    this.year = '',
    this.area = '',
    this.lang = '',
    this.score = '',
    this.content = '',
    this.actor = '',
    this.director = '',
    this.sources = const [],
  });

  final String id;
  final String name;
  final String pic;
  final String remarks;
  final String typeName;
  final String year;
  final String area;
  final String lang;
  final String score;
  final String content;
  final String actor;
  final String director;
  final List<PlaySource> sources;

  bool get hasEpisodes => sources.isNotEmpty && sources.first.episodes.isNotEmpty;

  List<Episode> get episodes => sources.isEmpty ? const [] : sources.first.episodes;

  factory Vod.fromJson(Map<String, dynamic> j) => Vod(
        id: s(j['vod_id']),
        name: s(j['vod_name']),
        pic: s(j['vod_pic']),
        remarks: s(j['vod_remarks']),
        typeName: s(j['type_name']),
        year: s(j['vod_year']),
        area: s(j['vod_area']),
        lang: s(j['vod_lang']),
        score: s(j['vod_score']),
        content: s(j['vod_content']),
        actor: s(j['vod_actor']),
        director: s(j['vod_director']),
        sources: _parseSources(j),
      );

  static List<PlaySource> _parseSources(Map<String, dynamic> j) {
    final out = <PlaySource>[];
    final raw = j['vod_play_sources'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final eps = <Episode>[];
        final list = item['episodes'];
        if (list is List) {
          for (final e in list) {
            if (e is! Map) continue;
            final pid = s(e['playId']);
            if (pid.isEmpty) continue;
            eps.add(Episode(name: s(e['name']), playId: pid));
          }
        }
        if (eps.isNotEmpty) out.add(PlaySource(name: s(item['name']), episodes: eps));
      }
    }
    if (out.isNotEmpty) return out;

    final url = s(j['vod_play_url']);
    if (url.trim().isEmpty) return out;
    final froms = s(j['vod_play_from']).split(r'$$$');
    final groups = url.split(r'$$$');
    for (var g = 0; g < groups.length; g++) {
      final eps = <Episode>[];
      for (final chunk in groups[g].split('#')) {
        final c = chunk.trim();
        if (c.isEmpty) continue;
        final cut = c.lastIndexOf(r'$');
        if (cut < 0) continue;
        final name = c.substring(0, cut).trim();
        final pid = c.substring(cut + 1).trim();
        if (pid.isEmpty) continue;
        eps.add(Episode(name: name.isEmpty ? '${eps.length + 1}' : name, playId: pid));
      }
      if (eps.isNotEmpty) {
        out.add(PlaySource(name: g < froms.length && froms[g].isNotEmpty ? froms[g] : '${g + 1}', episodes: eps));
      }
    }
    return out;
  }
}

class PlaySource {
  const PlaySource({required this.name, required this.episodes});
  final String name;
  final List<Episode> episodes;
}

class Episode {
  const Episode({required this.name, required this.playId});
  final String name;
  final String playId;

  /// playId 形如 `5740|1` 或 `3921|0|0`
  String get play {
    final p = playId.split('|');
    return p.isEmpty ? playId : p.first;
  }

  int get q {
    final p = playId.split('|');
    if (p.length >= 3) return int.tryParse(p[2]) ?? 1;
    if (p.length == 2) return int.tryParse(p[1]) ?? 1;
    return 1;
  }

  String get label => name.isEmpty ? '$q' : name;
}

class PlayInfo {
  const PlayInfo({required this.url, this.headers = const {}});
  final String url;
  final Map<String, String> headers;
}

class HotItem {
  const HotItem({required this.siteCode, required this.id, required this.name, this.pic = '', this.plays = 0});
  final String siteCode;
  final String id;
  final String name;
  final String pic;
  final int plays;

  factory HotItem.fromJson(Map<String, dynamic> j) => HotItem(
        siteCode: s(j['site_code']),
        id: s(j['vod_id']),
        name: s(j['vod_name']),
        pic: s(j['vod_pic']),
        plays: i(j['plays']),
      );

  Vod toVod() => Vod(id: id, name: name, pic: pic, remarks: plays > 0 ? '$plays' : '');
}

class Plan {
  const Plan({required this.id, required this.title, required this.days, required this.price});
  final int id;
  final String title;
  final int days;
  final String price;

  factory Plan.fromJson(Map<String, dynamic> j) =>
      Plan(id: i(j['id']), title: s(j['title']), days: i(j['days']), price: s(j['price']));
}

class NoticeItem {
  const NoticeItem({required this.id, required this.title, required this.content, required this.createdAt});
  final int id;
  final String title;
  final String content;
  final int createdAt;

  factory NoticeItem.fromJson(Map<String, dynamic> j) => NoticeItem(
        id: i(j['id']),
        title: s(j['title']),
        content: s(j['content']),
        createdAt: i(j['created_at']),
      );
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.content,
    required this.reply,
    required this.status,
    required this.createdAt,
  });
  final int id;
  final String content;
  final String reply;
  final int status;
  final int createdAt;

  bool get replied => status == 1 || reply.isNotEmpty;

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
        id: i(j['id']),
        content: s(j['content']),
        reply: s(j['reply']),
        status: i(j['status']),
        createdAt: i(j['created_at']),
      );
}

class User {
  const User({
    this.id = 0,
    this.username = '',
    this.email = '',
    this.role = 'user',
    this.apikey = '',
    this.playToken = '',
    this.vipActive = false,
    this.daysLeft = 0,
    this.vipUntil,
    this.joined = '',
  });

  final int id;
  final String username;
  final String email;
  final String role;
  final String apikey;
  final String playToken;
  final bool vipActive;
  final int daysLeft;
  final String? vipUntil;
  final String joined;

  String get displayName => username.isNotEmpty ? username : (email.contains('@') ? email.split('@').first : email);
  String get initial => displayName.isEmpty ? 'N' : displayName.substring(0, 1).toUpperCase();

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: i(j['id']),
        username: s(j['username']),
        email: s(j['email']),
        role: s(j['role']),
        apikey: s(j['apikey']),
        playToken: s(j['play_token']),
        vipActive: b(j['vip_active']),
        daysLeft: i(j['days_left']),
        vipUntil: j['vip_until'] == null ? null : s(j['vip_until']),
        joined: s(j['joined']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'role': role,
        'apikey': apikey,
        'play_token': playToken,
        'vip_active': vipActive,
        'days_left': daysLeft,
        'vip_until': vipUntil,
        'joined': joined,
      };
}

class PageResult {
  const PageResult({required this.items, this.page = 1, this.pageCount = 1, this.total = 0});
  final List<Vod> items;
  final int page;
  final int pageCount;
  final int total;
  bool get hasMore => page < pageCount;
}

/// 本地观看进度
class Progress {
  const Progress({required this.vodId, required this.site, required this.name, required this.pic,
    required this.epIndex, required this.position, required this.duration, required this.updatedAt});
  final String vodId;
  final String site;
  final String name;
  final String pic;
  final int epIndex;
  final int position;
  final int duration;
  final int updatedAt;

  double get ratio => duration <= 0 ? 0 : (position / duration).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'v': vodId, 's': site, 'n': name, 'p': pic, 'e': epIndex,
        'pos': position, 'dur': duration, 't': updatedAt,
      };

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
        vodId: s(j['v']), site: s(j['s']), name: s(j['n']), pic: s(j['p']),
        epIndex: i(j['e']), position: i(j['pos']), duration: i(j['dur']), updatedAt: i(j['t']),
      );
}
