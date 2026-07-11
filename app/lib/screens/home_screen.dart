import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../models/game_state.dart';
import '../widgets/creature_painter.dart';

/// ホーム画面の骨組み。プロトタイプの screen-home に対応。
/// TODO: たまご表示、なでなで/💨判定、ごはんモーダル、ミニゲーム遷移、
///       おえかき、おみせ、ずかん、あいことば、進化カットシーン。
class HomeScreen extends StatelessWidget {
  final GameController controller;
  const HomeScreen({super.key, required this.controller});

  GameState get s => controller.state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFE9FF), Color(0xFFE8F9EF)],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              children: [
                _topBar(),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      // TODO: 下部30%タップで💨 / たまご孵化
                      onTapDown: (d) => controller.pet(),
                      child: CustomPaint(
                        size: const Size(260, 260),
                        painter: CreaturePainter(
                          speciesIndex: s.species,
                          stage: s.stage == 0 ? 1 : s.stage,
                          sad: s.isSad,
                        ),
                      ),
                    ),
                  ),
                ),
                _bottomCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _pill('🪙 ${s.coins}'),
            const Spacer(),
            _pill(s.displayName),
            const Spacer(),
            // TODO: ずかん/セーブ/サウンドのアイコンボタン
          ],
        ),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: Color(0x1F3A3F52), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
      );

  Widget _bottomCard() => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            _meter('🍖', s.hunger, const Color(0xFFFF9A3D)),
            const SizedBox(height: 8),
            _meter('💖', s.happy, const Color(0xFFFF6EA6)),
            const SizedBox(height: 12),
            const Text('TODO: ごはん / あそぶ / おえかき / おみせ ボタン'),
          ],
        ),
      );

  Widget _meter(String icon, double value, Color color) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 16,
                backgroundColor: const Color(0xFFEEF0F7),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      );
}
