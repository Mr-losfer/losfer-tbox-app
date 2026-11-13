// QA 专用：不依赖 video_player，直接渲染播放器皮肤，用于截图核对控制层。
// 用 --dart-define=QA=player / playerSeek / playerVol / playerNext 切换状态。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/store.dart';
import '../core/theme.dart';
import 'player_skin.dart';

class PlayerSkinPreview extends StatelessWidget {
  const PlayerSkinPreview({super.key, this.mode = 'player'});

  final String mode;

  static const _pos = Duration(minutes: 12, seconds: 34);
  static const _dur = Duration(minutes: 45, seconds: 20);
  static const _buf = Duration(minutes: 26);

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 模拟画面：一张渐变当视频帧
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B2430), Color(0xFF0B0D12), Color(0xFF241A12)],
                ),
              ),
            ),

            if (mode == 'playerAll' || mode == 'playerNext')
              Positioned(
                right: 22,
                bottom: 74,
                child: NextUpCard(s: s, title: '第 8 集', countdown: 4, onPlay: () {}, onCancel: () {}),
              ),
            if (mode == 'playerAll' || mode == 'playerSeek')
              Center(child: SeekHud(forward: true, seconds: 10, position: _pos, duration: _dur)),
            if (mode == 'playerVol')
              const Center(child: SliderHud(icon: Icons.volume_up_rounded, value: .62, label: '音量')),
            if (mode == 'playerSeek')
              Center(child: SeekHud(forward: true, seconds: 10, position: _pos, duration: _dur)),

            SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Positioned(top: 0, left: 0, right: 0, child: TopVeil()),
                  const Positioned(bottom: 0, left: 0, right: 0, child: BottomVeil()),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: PlayerTopBar(
                      title: 'تەنھا ئوغرى',
                      subtitle: '第 7 集  ·  线路 1',
                      onBack: () {},
                      actions: [
                        SkinIconButton(icon: Icons.cast_rounded, onTap: () {}),
                        SkinIconButton(icon: Icons.more_vert_rounded, onTap: () {}),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: PlayerBottomBar(
                      s: s,
                      playing: true,
                      position: _pos,
                      duration: _dur,
                      buffered: _buf,
                      onToggle: () {},
                      onSeek: (_) {},
                      speedLabel: '1x',
                      onSpeed: () {},
                      onFit: () {},
                      onEpisodes: () {},
                      onLock: () {},
                      onRotate: () {},
                      episodeLabel: s.t('episodes'),
                      landscape: true,
                    ),
                  ),
                ],
              ),
            ),

            if (mode == 'playerGuide')
              Positioned(
                left: 0,
                right: 0,
                bottom: 96,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0E0E12),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.white.withValues(alpha: .10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gesture_rounded, size: 15, color: C.accent),
                        const SizedBox(width: 9),
                        Text(s.t('gestureTip'),
                            style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: .82))),
                        const SizedBox(width: 10),
                        Text(s.t('gotIt'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.accent)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
