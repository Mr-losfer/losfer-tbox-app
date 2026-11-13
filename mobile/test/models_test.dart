import 'package:flutter_test/flutter_test.dart';
import 'package:noqi/core/api.dart';
import 'package:noqi/core/fonts.dart';
import 'package:noqi/core/i18n.dart';
import 'package:noqi/core/models.dart';

void main() {
  group('Vod 解析', () {
    test('优先使用 vod_play_sources，并保留 playId', () {
      final vod = Vod.fromJson({
        'vod_id': 12,
        'vod_name': 'تەنها ئوغرى',
        'vod_pic': 'https://img/a.jpg',
        'vod_year': '2024',
        'vod_score': '8.6',
        'vod_play_sources': [
          {
            'name': 'HD',
            'episodes': [
              {'name': '第1集', 'playId': '5740|1'},
              {'name': '第2集', 'playId': '5740|2'},
            ],
          },
        ],
      });
      expect(vod.id, '12');
      expect(vod.name, 'تەنها ئوغرى');
      expect(vod.year, '2024');
      expect(vod.score, '8.6');
      expect(vod.sources.length, 1);
      expect(vod.sources.first.name, 'HD');
      expect(vod.sources.first.episodes.length, 2);
      expect(vod.sources.first.episodes.last.playId, '5740|2');
      // 播放接口只用竖线第一段，q 取线路序号
      expect(vod.sources.first.episodes.last.play, '5740');
      expect(vod.sources.first.episodes.last.q, 2);
    });

    test('vod_play_sources 为空时回退解析 vod_play_url', () {
      final vod = Vod.fromJson({
        'vod_id': '7',
        'vod_name': 'A',
        'vod_play_from': r'线路一$$$线路二',
        'vod_play_url': r'第1集$https://cdn/a1.m3u8#第2集$https://cdn/a2.m3u8$$$第1集$https://cdn/b1.m3u8',
      });
      expect(vod.sources.length, 2);
      expect(vod.sources.first.name, '线路一');
      expect(vod.sources.first.episodes.length, 2);
      expect(vod.sources.first.episodes.first.name, '第1集');
      expect(vod.sources.first.episodes.first.playId, 'https://cdn/a1.m3u8');
      expect(vod.sources.last.name, '线路二');
      expect(vod.sources.last.episodes.length, 1);
    });

    test('线路缺名时以序号兜底，缺集名时以 q 兜底', () {
      final vod = Vod.fromJson({
        'vod_id': '9',
        'vod_name': 'B',
        'vod_play_url': r'$https://cdn/x1.m3u8#$https://cdn/x2.m3u8',
      });
      expect(vod.sources.length, 1);
      expect(vod.sources.first.name, '1');
      expect(vod.sources.first.episodes.length, 2);
      expect(vod.sources.first.episodes.first.name, '1');
    });

    test('字段缺失时安全降级，不抛异常', () {
      final vod = Vod.fromJson({});
      expect(vod.id, '');
      expect(vod.name, '');
      expect(vod.sources, isEmpty);
      expect(vod.hasEpisodes, isFalse);
      expect(vod.episodes, isEmpty);
    });
  });

  group('鉴权与错误码', () {
    test('ApiError 分类与文档错误码表一致', () {
      expect(ApiError(401, 'x').isAuth, isTrue);
      expect(ApiError(402, 'x').isVip, isTrue);
      expect(ApiError(403, 'x').isBlocked, isTrue);
      expect(ApiError(429, 'x').isRate, isTrue);
      expect(ApiError(502, 'x').isUpstream, isTrue);
      expect(ApiError(400, 'x').isAuth, isFalse);
      expect(ApiError(404, 'x').isUpstream, isFalse);
    });

    test('User 会员状态与昵称派生', () {
      final vip = User.fromJson({'apikey': 'k', 'vip_active': true, 'vip_until': '2026-01-01'});
      final free = User.fromJson({'apikey': 'k', 'vip_active': false});
      expect(vip.vipActive, isTrue);
      expect(vip.vipUntil, '2026-01-01');
      expect(free.vipActive, isFalse);
      expect(User.fromJson({'email': 'abc@x.com'}).displayName, 'abc');
      expect(User.fromJson({'username': 'nur'}).initial, 'N');
      expect(const User().initial, 'N');
    });

    test('服务器地址规范化', () {
      expect(Api.normalize('x.noqi.pro'), 'https://x.noqi.pro');
      expect(Api.normalize('https://x.noqi.pro/'), 'https://x.noqi.pro');
      expect(Api.normalize('  http://a.b/c/  '), 'http://a.b/c');
    });
  });

  group('播放进度', () {
    test('JSON 往返保持字段', () {
      final p = Progress(
        vodId: '5740',
        site: 'balli',
        name: 'X',
        pic: '',
        epIndex: 3,
        position: 120,
        duration: 600,
        updatedAt: 1700000000000,
      );
      final back = Progress.fromJson(p.toJson());
      expect(back.site, 'balli');
      expect(back.epIndex, 3);
      expect(back.position, 120);
      expect(back.duration, 600);
      expect(back.ratio, closeTo(0.2, 1e-9));
    });

    test('时长为 0 时比率为 0，不产生除零', () {
      const p = Progress(
        vodId: '1',
        site: 's',
        name: 'n',
        pic: '',
        epIndex: 1,
        position: 5,
        duration: 0,
        updatedAt: 0,
      );
      expect(p.ratio, 0);
    });
  });

  group('多语言', () {
    test('维吾尔语为 RTL，中文为 LTR', () {
      expect(const S('ug').isRtl, isTrue);
      expect(const S('zh').isRtl, isFalse);
    });

    test('缺失键回退为键名而非抛异常', () {
      expect(const S('ug').t('__missing__'), '__missing__');
      expect(const S('zh').t('__missing__'), '__missing__');
    });

    test('两套文案的常用键都已翻译', () {
      for (final k in ['home', 'browse', 'search', 'me', 'play', 'hot', 'retry', 'back']) {
        expect(const S('ug').t(k), isNot(k), reason: 'ug 缺少 $k');
        expect(const S('zh').t(k), isNot(k), reason: 'zh 缺少 $k');
      }
    });
  });

  group('字体目录', () {
    test('内置 10 款可选维语字体，默认字体在列表内', () {
      expect(kFonts.length, 10);
      expect(kFonts.map((f) => f.id).toSet().length, 10);
      expect(kFonts.any((f) => f.id == kDefaultFont), isTrue);
      expect(fontLabelOf(kDefaultFont), isNotEmpty);
      expect(fontLabelOf('not-exist'), kFonts.first.label);
    });
  });
}
