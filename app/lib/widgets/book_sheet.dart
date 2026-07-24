import 'package:flutter/material.dart';

import '../data/species.dart';
import '../logic/game_controller.dart';
import '../models/game_state.dart';
import 'creature_painter.dart';
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

/// 名簿の個体と交代したい(roster index)
class BookSwitchRoster extends BookResult {
  final int rosterIndex;
  const BookSwitchRoster(this.rosterIndex);
}

/// ずかん登録ずみだが名簿に個体がいない種族をキング姿で迎えたい(種族index)
class BookAdoptKing extends BookResult {
  final int species;
  const BookAdoptKing(this.species);
}

/// いきものずかん(プロトタイプ #bookModal)。
/// 入手済みの子をタップすると交代([BookSwitchRoster] / [BookAdoptKing])、
/// キング中は新しいたまごも迎えられる([BookNewEgg])。
/// 同じ種族の個体が複数いるセルは、タップで「どの子と こうたい?」を出す。
Future<BookResult?> showBookModal(
  BuildContext context,
  GameController controller,
) {
  return showDialog<BookResult>(
    context: context,
    builder: (dialogContext) {
      final s = controller.state;
      final kinged = s.stage == kingStage;
      // こどもFB: キング前でも新しいたまごを迎えられる(たまご中は除く)。
      // いまの子は名簿に保存され、セルから交代して続きを育てられる。
      final canNewEgg = s.stage >= 1;
      // 種族ごとの名簿個体(roster index のリスト)
      List<int> rosterOf(int i) => [
        for (var r = 0; r < s.roster.length; r++)
          if (s.roster[r].species == i) r,
      ];
      Future<void> chooseAndPop(int i, List<int> entries) async {
        final res = switch (entries.length) {
          0 => BookAdoptKing(i) as BookResult?,
          1 => BookSwitchRoster(entries.single),
          _ => await _pickIndividual(dialogContext, s, entries),
        };
        if (res != null && dialogContext.mounted) {
          Navigator.of(dialogContext).pop(res);
        }
      }

      return MokoModalShell(
        header: const [ModalTitle('📖 いきもの ずかん')],
        body: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
            children: [
              for (var i = 0; i < speciesList.length; i++)
                Builder(
                  builder: (context) {
                    final entries = rosterOf(i);
                    return _BookCell(
                      key: ValueKey('book-$i'),
                      speciesIndex: i,
                      owned: s.collection[i],
                      current: i == s.species,
                      snapshot: _bestSnapshot(s, entries),
                      liveState: i == s.species ? s : null,
                      count: entries.length + (i == s.species ? 1 : 0),
                      onTap:
                          entries.isNotEmpty ||
                              (s.collection[i] && i != s.species)
                          ? () => chooseAndPop(i, entries)
                          : null,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            kinged
                ? 'あたらしい たまごを むかえよう! そだてた子は タップで あそびに こられるよ'
                : 'キングまで そだてると ずかんに とうろく! とちゅうの子も タップで こうたいできるよ',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: ink2Color,
            ),
          ),
        ],
        footer: [
          if (canNewEgg) ...[
            PressableGradient(
              colors: greenGradient,
              onTap: () => Navigator.of(
                dialogContext,
              ).pop(BookNewEgg(controller.newEgg())),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Column(
                  children: [
                    Text('🥚', style: TextStyle(fontSize: 26)),
                    Text(
                      'あたらしい たまごを むかえる',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          ModalCloseButton(
            label: 'とじる',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}

/// セルの代表として見せる個体(いちばん育っている子。同stageなら後に入った子)。
CreatureSnapshot? _bestSnapshot(GameState s, List<int> entries) {
  CreatureSnapshot? best;
  for (final r in entries) {
    if (best == null || s.roster[r].stage >= best.stage) best = s.roster[r];
  }
  return best;
}

/// 同じ種族の個体が複数いるときの「どの子と こうたい?」ダイアログ。
Future<BookResult?> _pickIndividual(
  BuildContext context,
  GameState s,
  List<int> entries,
) {
  return showDialog<BookResult>(
    context: context,
    builder: (pickContext) => MokoModalShell(
      header: const [ModalTitle('どの子と こうたい?')],
      body: [
        for (final r in entries) ...[
          Material(
            key: ValueKey('pick-$r'),
            color: const Color(0xFFEAFAF1),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(pickContext).pop(BookSwitchRoster(r)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CustomPaint(
                        painter: CreaturePainter(
                          speciesIndex: s.roster[r].species,
                          stage: s.roster[r].stage == 0 ? 1 : s.roster[r].stage,
                          sad: false,
                          bodyColor: s.roster[r].color != 0
                              ? Color(s.roster[r].color)
                              : null,
                          equipHead: s.roster[r].equipHead,
                          equipFace: s.roster[r].equipFace,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.roster[r].nickname ??
                            speciesList[s.roster[r].species].names[s
                                .roster[r]
                                .stage],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: inkColor,
                        ),
                      ),
                    ),
                    Text(
                      speciesList[s.roster[r].species].emojis[s
                          .roster[r]
                          .stage],
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
      footer: [
        ModalCloseButton(
          label: 'やめる',
          onTap: () => Navigator.of(pickContext).pop(),
        ),
      ],
    ),
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

  /// この種族の個体数(いまの子+名簿)。2匹以上で ×N バッジを出す
  final int count;
  final VoidCallback? onTap;
  const _BookCell({
    super.key,
    required this.speciesIndex,
    required this.owned,
    required this.current,
    this.snapshot,
    this.liveState,
    this.count = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sp = speciesList[speciesIndex];
    final color = liveState?.color ?? snapshot?.color;
    final stage = liveState?.stage ?? snapshot?.stage ?? kingStage;
    // 図鑑登録(キング)前でも、いまの子と名簿の子はすがたと名前を見せる。
    // シルエット+「???」は未知の種族だけ。
    final known = owned || snapshot != null || liveState != null;
    Widget mini = CustomPaint(
      size: const Size(40, 40),
      painter: CreaturePainter(
        speciesIndex: speciesIndex,
        stage: stage == 0 ? 1 : stage,
        sad: false,
        bodyColor: color != null && color != 0 ? Color(color) : null,
        equipHead: liveState?.equipHead ?? snapshot?.equipHead,
        equipFace: liveState?.equipFace ?? snapshot?.equipFace,
      ),
    );
    if (!known) {
      // 未入手はシルエット+「?」
      mini = Stack(
        alignment: Alignment.center,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0xFFD5D9E6),
              BlendMode.srcIn,
            ),
            child: mini,
          ),
          const Text(
            '?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFFAAB0C5),
            ),
          ),
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
            border: current ? Border.all(color: accentGreen, width: 3) : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(width: 40, height: 40, child: mini),
                  if (count >= 2)
                    Positioned(
                      right: -8,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: accentGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '×$count',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                known ? (nickname ?? sp.names[stage]) : '???',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: known ? inkColor : ink2Color,
                ),
              ),
              if (current)
                const Text(
                  'そだてちゅう',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: accentGreen,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
