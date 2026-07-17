import 'package:flutter/material.dart';

import '../data/species.dart';
import '../logic/game_controller.dart';
import '../models/game_state.dart';
import '../widgets/creature_painter.dart';
import 'ui_kit.dart';

/// ずかんの操作結果。
sealed class BookResult {
  const BookResult();
}

/// 「あたらしいたまごを むかえる」(抽選済み種族index)
class BookNewEgg extends BookResult {
  final int species;
  const BookNewEgg(this.species);
}

/// 過去に育てた子と交代したい(種族index)
class BookSwitch extends BookResult {
  final int species;
  const BookSwitch(this.species);
}

/// いきものずかん(プロトタイプ #bookModal)。
/// 入手済みの子をタップすると交代([BookSwitch])、
/// キング中は新しいたまごも迎えられる([BookNewEgg])。
Future<BookResult?> showBookModal(
    BuildContext context, GameController controller) {
  return showDialog<BookResult>(
    context: context,
    builder: (dialogContext) {
      final s = controller.state;
      final kinged = s.stage == 3;
      return MokoModalShell(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ModalTitle('📖 いきもの ずかん'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
                children: [
                  for (var i = 0; i < speciesList.length; i++)
                    _BookCell(
                      key: ValueKey('book-$i'),
                      speciesIndex: i,
                      owned: s.collection[i],
                      current: i == s.species,
                      snapshot: i == s.species ? null : s.roster[i],
                      liveState: i == s.species ? s : null,
                      onTap: (s.collection[i] || s.roster.containsKey(i)) &&
                              i != s.species
                          ? () => Navigator.of(dialogContext).pop(BookSwitch(i))
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                kinged
                    ? 'あたらしい たまごを むかえよう! そだてた子は タップで あそびに こられるよ'
                    : 'キングまで そだてると ずかんに とうろく! そだてた子は タップで こうたいできるよ',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                    color: ink2Color),
              ),
              if (kinged) ...[
                const SizedBox(height: 10),
                PressableGradient(
                  colors: greenGradient,
                  onTap: () => Navigator.of(dialogContext)
                      .pop(BookNewEgg(controller.newEgg())),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      children: [
                        Text('🥚', style: TextStyle(fontSize: 26)),
                        Text('あたらしい たまごを むかえる',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ModalCloseButton(
                  label: 'とじる', onTap: () => Navigator.of(dialogContext).pop()),
            ],
          ),
        ),
      );
    },
  );
}

class _BookCell extends StatelessWidget {
  final int speciesIndex;
  final bool owned;
  final bool current;

  /// 名簿のスナップショット(きせかえ・体色・なまえを反映)
  final CreatureSnapshot? snapshot;

  /// 現在育成中の子はライブ状態を反映
  final GameState? liveState;
  final VoidCallback? onTap;
  const _BookCell({
    super.key,
    required this.speciesIndex,
    required this.owned,
    required this.current,
    this.snapshot,
    this.liveState,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sp = speciesList[speciesIndex];
    final color = liveState?.color ?? snapshot?.color;
    final stage = liveState?.stage ?? snapshot?.stage ?? 3;
    Widget mini = CustomPaint(
      size: const Size(44, 44),
      painter: CreaturePainter(
        speciesIndex: speciesIndex,
        stage: stage == 0 ? 1 : stage,
        sad: false,
        bodyColor: color != null && color != 0 ? Color(color) : null,
        equipHead: liveState?.equipHead ?? snapshot?.equipHead,
        equipFace: liveState?.equipFace ?? snapshot?.equipFace,
      ),
    );
    if (!owned) {
      // 未入手はシルエット+「?」
      mini = Stack(
        alignment: Alignment.center,
        children: [
          ColorFiltered(
            colorFilter:
                const ColorFilter.mode(Color(0xFFD5D9E6), BlendMode.srcIn),
            child: mini,
          ),
          const Text('?',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFAAB0C5))),
        ],
      );
    }
    final nickname = liveState?.nickname ?? snapshot?.nickname;
    return Material(
      color: owned ? const Color(0xFFEAFAF1) : const Color(0xFFF4F6FB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: current
                ? Border.all(color: const Color(0xFF34C98E), width: 3)
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 64, height: 64, child: mini),
              const SizedBox(height: 2),
              Text(owned ? (nickname ?? sp.names[3]) : '???',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: owned ? inkColor : ink2Color)),
              if (current)
                const Text('そだてちゅう',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF34C98E))),
            ],
          ),
        ),
      ),
    );
  }
}
