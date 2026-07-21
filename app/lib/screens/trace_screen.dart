import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/trace_game.dart';
import '../widgets/game_overlays.dart';
import '../widgets/ui_kit.dart';
import 'timer_bag.dart';

/// なぞってかこう(docs/game-design.md §5)。点線の形をなぞって星をもらう。
/// お絵描き好きのこども向けのゲーム。
class TraceScreen extends StatefulWidget {
  final GameController controller;

  /// テストで形の順番を固定するフック。
  final List<String>? shapes;

  const TraceScreen({super.key, required this.controller, this.shapes});

  @override
  State<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends State<TraceScreen>
    with TimerBagMixin<TraceScreen> {
  late final List<String> _shapes = widget.shapes ??
      ([...traceShapeKeys]..shuffle(Random()))
          .take(traceShapesPerSession)
          .toList();
  var _shapeIndex = 0;
  final _strokePoints = <Offset>[];
  final _starsEarned = <int>[];
  var _coins = 0;
  var _ended = false;
  int? _lastStars; // 直前の判定結果(★表示用)

  String get _currentShape => _shapes[_shapeIndex];

  void _judge() {
    final coverage = traceCoverage(traceTargets(_currentShape), _strokePoints);
    final (stars, coins) = traceScore(coverage);
    widget.controller.sfx
        .play(stars >= 3 ? Sfx.happy : (stars == 2 ? Sfx.pop : Sfx.tap));
    setState(() {
      _starsEarned.add(stars);
      _coins += coins;
      _lastStars = stars;
    });
    later(const Duration(milliseconds: 900), () {
      setState(() {
        _lastStars = null;
        _strokePoints.clear();
        if (_shapeIndex + 1 >= _shapes.length) {
          widget.controller.finishMinigame(_coins);
          _ended = true;
        } else {
          _shapeIndex++;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8E4FF), Color(0xFFFFF3E0)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    GameHeaderBar(
                      title: '✏️ なぞって かこう!',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 6),
                    Text('${_shapeIndex + 1} / ${_shapes.length}  てんせんを なぞってね',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ink2Color)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: LayoutBuilder(builder: (context, box) {
                          final size =
                              min(min(box.maxWidth, box.maxHeight), 340.0);
                          return Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [cardShadow],
                            ),
                            child: GestureDetector(
                              onPanStart: (d) => setState(() => _strokePoints
                                  .add(d.localPosition * (300 / size))),
                              onPanUpdate: (d) => setState(() => _strokePoints
                                  .add(d.localPosition * (300 / size))),
                              child: CustomPaint(
                                painter: _TracePainter(
                                  shapeKey: _currentShape,
                                  strokePoints: _strokePoints,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_lastStars != null)
                      Text('⭐' * _lastStars!,
                          style: const TextStyle(fontSize: 40))
                    else
                      Row(
                        children: [
                          Expanded(
                            child: BigActionButton(
                              icon: '🧽',
                              label: 'やりなおす',
                              colors: const [
                                Color(0xFFC3C9DD),
                                Color(0xFFA6ADC7)
                              ],
                              onTap: () =>
                                  setState(() => _strokePoints.clear()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: BigActionButton(
                              icon: '✨',
                              label: 'できた!',
                              colors: greenGradient,
                              onTap: _strokePoints.isEmpty ? () {} : _judge,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (_ended)
                GameEndOverlay(
                  emoji: '🏆',
                  result:
                      '${'⭐' * _starsEarned.fold(0, (a, b) => a + b)}\n+$_coins コイン!',
                  onDone: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 点線ターゲット+なぞり線の描画(300x300座標系)。
class _TracePainter extends CustomPainter {
  final String shapeKey;
  final List<Offset> strokePoints;
  _TracePainter({required this.shapeKey, required this.strokePoints});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300;
    canvas.scale(s, s);

    // ターゲットの点線(サンプル点を丸で)
    final dot = Paint()..color = const Color(0xFFB9C2D0);
    for (final p in traceTargets(shapeKey, count: 60)) {
      canvas.drawCircle(p, 4, dot);
    }

    // なぞった線
    if (strokePoints.length > 1) {
      final path = Path()..moveTo(strokePoints.first.dx, strokePoints.first.dy);
      for (final p in strokePoints.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFF6EA6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}
