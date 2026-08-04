import 'package:flutter/material.dart';

import '../widgets/game_chooser.dart';
import '../widgets/ui_kit.dart';
import 'balloon_screen.dart';
import 'catch_screen.dart';
import 'compare_screen.dart';
import 'count_screen.dart';
import 'kana_find_screen.dart';
import 'kata_match_screen.dart';
import 'math_screen.dart';
import 'memory_screen.dart';
import 'odd_one_screen.dart';
import 'order_screen.dart';
import 'pika_screen.dart';
import 'puzzle_screen.dart';
import 'rhythm_screen.dart';
import 'simon_screen.dart';
import 'stop_screen.dart';
import 'stroop_screen.dart';
import 'trace_screen.dart';
import 'whack_screen.dart';
import 'word_build_screen.dart';

/// あそぶ20種の一覧(表示順)。docs/game-design.md §5。
/// ゲームを追加するときはここに1行足すだけでよい(選択モーダルの表示と
/// 画面生成の両方がこの定義を使う。docs/review-findings.md #69)。
final gameRegistry = <GameEntry>[
  GameEntry(
    'catch',
    '🍎',
    'フルーツキャッチ',
    blueGradient,
    (c) => CatchScreen(controller: c),
  ),
  GameEntry(
    'balloon',
    '🎈',
    'ふうせんわり',
    pinkGradient,
    (c) => BalloonScreen(controller: c),
  ),
  GameEntry(
    'whack',
    '🔨',
    'もぐらたたき',
    greenGradient,
    (c) => WhackScreen(controller: c),
  ),
  GameEntry(
    'trace',
    '✏️',
    'なぞってかこう',
    orangeGradient,
    (c) => TraceScreen(controller: c),
  ),
  GameEntry(
    'puzzle',
    '🧩',
    'おなじの どれ?',
    purpleGradient,
    (c) => PuzzleScreen(controller: c),
  ),
  GameEntry('odd', '👀', 'ちがうの どっち?', [
    Color(0xFF5BC8E8),
    Color(0xFF2E9BC0),
  ], (c) => OddOneScreen(controller: c)),
  GameEntry('memory', '🃏', 'ペアさがし', [
    Color(0xFF9B8CFF),
    Color(0xFF6B5BD6),
  ], (c) => MemoryScreen(controller: c)),
  GameEntry('order', '🔢', 'じゅんばんタッチ', [
    Color(0xFF7ED6A5),
    Color(0xFF4CAF7D),
  ], (c) => OrderScreen(controller: c)),
  GameEntry('count', '🧮', 'かぞえてタッチ', [
    Color(0xFFFFB65C),
    Color(0xFFE8892A),
  ], (c) => CountScreen(controller: c)),
  GameEntry('simon', '💡', 'おぼえてタッチ', [
    Color(0xFFB78CFF),
    Color(0xFF7E5BD6),
  ], (c) => SimonScreen(controller: c)),
  GameEntry('compare', '⚖️', 'どっちが おおい?', [
    Color(0xFF8FD48A),
    Color(0xFF4C9F55),
  ], (c) => CompareScreen(controller: c)),
  GameEntry('pika', '🔆', 'ぴかっとタッチ', [
    Color(0xFFFFD26B),
    Color(0xFFE8A02A),
  ], (c) => PikaScreen(controller: c)),
  GameEntry('math', '➕', 'けいさんタッチ', [
    Color(0xFF7FB8F0),
    Color(0xFF3D7BC8),
  ], (c) => MathScreen(controller: c)),
  GameEntry('reverse', '🔁', 'さかさまタッチ', [
    Color(0xFFDA8FDE),
    Color(0xFFA84BB0),
  ], (c) => SimonScreen(controller: c, reversed: true)),
  GameEntry('stop', '🎯', 'ぴったりストップ', [
    Color(0xFFE8837A),
    Color(0xFFC24B42),
  ], (c) => StopScreen(controller: c)),
  GameEntry('stroop', '🌈', 'いろタッチ', [
    Color(0xFF64C8B4),
    Color(0xFF2E9B85),
  ], (c) => StroopScreen(controller: c)),
  GameEntry('kana', '🔤', 'もじさがし', [
    Color(0xFF9FCE63),
    Color(0xFF6B9E2E),
  ], (c) => KanaFindScreen(controller: c)),
  GameEntry('kata', '🔠', 'ペアもじ', [
    Color(0xFFE8A0B4),
    Color(0xFFC2607E),
  ], (c) => KataMatchScreen(controller: c)),
  GameEntry('word', '💬', 'ことばづくり', [
    Color(0xFF8FA8E8),
    Color(0xFF5B6BC2),
  ], (c) => WordBuildScreen(controller: c)),
  GameEntry('rhythm', '🎵', 'リズムタッチ', [
    Color(0xFFED87C8),
    Color(0xFFB84A96),
  ], (c) => RhythmScreen(controller: c)),
];
