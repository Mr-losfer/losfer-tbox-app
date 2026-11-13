import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/store.dart';
import 'detail.dart';
import 'player.dart';
import 'vip_sheet.dart';
import 'widgets.dart';

/// 统一的影片入口：根据「跳过详情页」开关，决定直接进入播放还是先进详情页。
Future<void> openVod(BuildContext context, Vod vod, {String? site}) async {
  final st = context.read<AppState>();
  final code = site ?? st.sourceCode;
  if (st.skipDetail) {
    await _playDirect(context, vod, code, st);
  } else {
    if (!context.mounted) return;
    Navigator.of(context).push(DetailPage.route(vod, site: code));
  }
}

/// 跳过详情时直接拉详情（补上 sources）再进播放器。
Future<void> _playDirect(BuildContext context, Vod vod, String code, AppState st) async {
  Vod full = vod;
  if (vod.sources.isEmpty) {
    try {
      final f = await st.api.detail(code, vod.id);
      if (f != null) full = f;
    } catch (_) {}
  }
  if (!context.mounted) return;
  if (!st.canPlay(st.byCode(code) ?? st.source)) {
    await showVipSheet(context);
    return;
  }
  if (full.sources.isEmpty || full.sources.first.episodes.isEmpty) {
    Toast.show(context, st.s.t('empty'));
    return;
  }
  await Navigator.of(context).push(PlayerPage.route(
    vod: full,
    site: code,
    sourceIndex: 0,
    episodeIndex: 0,
  ));
}
