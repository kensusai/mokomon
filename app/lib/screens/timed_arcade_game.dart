import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../widgets/game_overlays.dart';
import '../widgets/ui_kit.dart';

enum ArcadePhase { intro, countdown, running, ended }

/// 時間制のミニゲーム(フルーツキャッチ/ふうせんわり/もぐらたたき)共通の
/// Ticker駆動・フェーズ管理をまとめる(docs/review-findings.md #7)。
/// プレイ領域のサイズが要らないゲーム(もぐらたたき)は [tickGame] の中で
/// 単に無視すればよい。
mixin TimedArcadeGameMixin<T extends StatefulWidget> on State<T> {
  var phase = ArcadePhase.intro;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  TickerProvider get vsync;
  GameController get controller;

  /// 新しいゲームインスタンスを作る(テスト注入ファクトリの解決も含む)。
  void startGameInstance();

  /// dt秒進める。
  void tickGame(double dt);

  bool get gameFinished;
  int get gameScore;
  int get gameTimeLeft;

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void startGame() {
    startGameInstance();
    _lastTick = Duration.zero;
    setState(() => phase = ArcadePhase.running);
    _ticker = vsync.createTicker(_onTick)..start();
  }

  /// 「⏰ 残り時間 / スコア」のヘッダ行。3画面で同一だったためここに集約
  /// (docs/review-findings.md #55)。
  Widget buildScoreHeader(String scoreEmoji) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [StatPill('⏰ $gameTimeLeft'), StatPill('$scoreEmoji $gameScore')],
  );

  /// カウントダウン→開始説明→終了の3オーバーレイ。3画面で同一だったため
  /// ここに集約(docs/review-findings.md #28)。build の Stack 末尾に
  /// spread して使う。
  List<Widget> buildArcadeOverlays({
    required String title,
    required String desc,
  }) {
    return [
      if (phase == ArcadePhase.countdown)
        GameCountdown(
          onDone: startGame,
          onTick: () => controller.sfx.play(Sfx.tap),
        ),
      if (phase == ArcadePhase.intro)
        GameStartOverlay(
          title: title,
          desc: desc,
          onStart: () => setState(() => phase = ArcadePhase.countdown),
          onBack: () => Navigator.of(context).pop(),
        ),
      if (phase == ArcadePhase.ended)
        GameEndOverlay(
          emoji: '🎉',
          result: '+$gameScore コイン げっと!',
          onDone: () => Navigator.of(context).pop(),
        ),
    ];
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : min(0.05, (elapsed - _lastTick).inMicroseconds / 1e6);
    _lastTick = elapsed;
    tickGame(dt);
    if (gameFinished) {
      _ticker?.stop();
      controller.finishMinigame(gameScore);
      setState(() => phase = ArcadePhase.ended);
      return;
    }
    setState(() {});
  }
}
