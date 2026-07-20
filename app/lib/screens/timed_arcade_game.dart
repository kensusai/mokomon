import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../logic/game_controller.dart';

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
