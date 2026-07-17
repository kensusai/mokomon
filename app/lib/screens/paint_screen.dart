import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../widgets/creature_painter.dart';
import '../widgets/game_overlays.dart';
import '../widgets/ui_kit.dart';

/// ブラシ8色(プロトタイプ PALETTE)
const _palette = [
  0xFFFF6EA6,
  0xFFFFAB49,
  0xFFFFD23E,
  0xFF34C98E,
  0xFF54B9FF,
  0xFF9B8CFF,
  0xFF8D6748,
  0xFFFFFFFF,
];

/// 体色6色(プロトタイプ BODY_COLORS)
const _bodyColors = [
  0xFF7ED6A5,
  0xFFFFD23E,
  0xFFFF9CC2,
  0xFF8FC9FF,
  0xFFC9A7FF,
  0xFFFFB37E,
];

/// おもしろスタンプ(タップでペタッ、なぞると連続)
const _stamps = ['⭐', '🌸', '💖', '⚡', '🌈', '🎀', '🍓', '💩', '😎', '🐟'];

/// 描画座標は体パスと同じ 300x300。線幅はプロトタイプ(320px canvas の 20)相当。
const _paintSize = 300.0;
const _brushWidth = 20.0 * 300 / 320;
const _stampFontSize = 46.0;

/// おえかき(もようがえ)。docs/game-design.md §6。
/// 保存したら true を返して閉じる(報酬は controller.savePaint が付与)。
/// パレット類は誤タップ防止のため画面下部に置く(手のひらがキャンバス直下に乗るため)。
class PaintScreen extends StatefulWidget {
  final GameController controller;
  const PaintScreen({super.key, required this.controller});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

sealed class _PaintOp {}

class _Stroke extends _PaintOp {
  final int color;
  final points = <Offset>[];
  _Stroke(this.color);
}

class _Stamp extends _PaintOp {
  final String emoji;
  final Offset pos;
  _Stamp(this.emoji, this.pos);
}

class _PaintScreenState extends State<PaintScreen> {
  int? _brush = _palette.first;
  String? _stamp;
  final _ops = <_PaintOp>[];
  ui.Image? _baseImage; // 保存済み模様(この上に描き足す)
  Offset? _lastStampPos;

  @override
  void initState() {
    super.initState();
    final pattern = widget.controller.state.pattern;
    if (pattern != null) {
      decodeImageFromList(base64Decode(pattern)).then((img) {
        if (mounted) setState(() => _baseImage = img);
      });
    }
  }

  Offset _toBodyCoords(Offset local, double canvasSize) =>
      local * (_paintSize / canvasSize);

  void _onPanStart(Offset p) {
    setState(() {
      if (_stamp != null) {
        _ops.add(_Stamp(_stamp!, p));
        _lastStampPos = p;
      } else {
        _ops.add(_Stroke(_brush!)..points.add(p));
      }
    });
  }

  void _onPanUpdate(Offset p) {
    setState(() {
      if (_stamp != null) {
        // なぞると一定間隔でペタペタ
        if (_lastStampPos == null || (p - _lastStampPos!).distance > 52) {
          _ops.add(_Stamp(_stamp!, p));
          _lastStampPos = p;
        }
      } else if (_ops.isNotEmpty && _ops.last is _Stroke) {
        (_ops.last as _Stroke).points.add(p);
      }
    });
  }

  Future<void> _save() async {
    // 体色は含めず、模様レイヤーだけを透明PNGで書き出す(色を後から変えられる)
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, const Rect.fromLTWH(0, 0, _paintSize, _paintSize));
    _paintOps(canvas, _baseImage, _ops);
    final image = await recorder
        .endRecording()
        .toImage(_paintSize.toInt(), _paintSize.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null || !mounted) return;
    widget.controller.savePaint(base64Encode(bytes.buffer.asUint8List()));
    Navigator.of(context).pop(true);
  }

  void _clear() {
    setState(() {
      _ops.clear();
      _baseImage = null;
    });
    widget.controller.clearPattern();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE9F2)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    BackIconButton(onTap: () => Navigator.of(context).pop()),
                    const Expanded(
                      child: Text('🎨 もようを かこう!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: inkColor)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    // 下部のパレット類のぶんを差し引いてキャンバスを収める
                    final canvasSize =
                        min(min(box.maxWidth - 40, 340.0), box.maxHeight - 218)
                            .clamp(120.0, 340.0);
                    return Column(
                      children: [
                        // キャンバスは上寄せ(直下は空けて誤タップを防ぐ)
                        _canvas(canvasSize),
                        const Spacer(),
                        _stampRow(),
                        const SizedBox(height: 8),
                        _swatchRow(_palette, 40,
                            selected: _brush,
                            onTap: (c) => setState(() {
                                  _brush = c;
                                  _stamp = null;
                                })),
                        const SizedBox(height: 6),
                        const Text('からだの いろも えらべるよ ↓',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ink2Color)),
                        const SizedBox(height: 6),
                        _swatchRow(_bodyColors, 34,
                            onTap: widget.controller.setBodyColor),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: BigActionButton(
                        icon: '🧽',
                        label: 'けす',
                        colors: const [Color(0xFFC3C9DD), Color(0xFFA6ADC7)],
                        onTap: _clear,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: BigActionButton(
                        icon: '✨',
                        label: 'できた!',
                        colors: greenGradient,
                        onTap: _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _canvas(double canvasSize) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F3A3F52), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: SizedBox(
        width: canvasSize,
        height: canvasSize,
        child: GestureDetector(
          onPanStart: (d) =>
              _onPanStart(_toBodyCoords(d.localPosition, canvasSize)),
          onPanUpdate: (d) =>
              _onPanUpdate(_toBodyCoords(d.localPosition, canvasSize)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => CustomPaint(
                painter: _PaintCanvasPainter(
                  bodyColor: Color(widget.controller.state.color),
                  baseImage: _baseImage,
                  ops: _ops,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stampRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final e in _stamps)
          GestureDetector(
            onTap: () => setState(() {
              _stamp = e;
              _brush = null;
            }),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  if (_stamp == e)
                    const BoxShadow(color: inkColor, spreadRadius: 3)
                  else
                    const BoxShadow(
                        color: Color(0x1F3A3F52),
                        blurRadius: 10,
                        offset: Offset(0, 3)),
                ],
              ),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          ),
      ],
    );
  }

  Widget _swatchRow(List<int> colors, double size,
      {int? selected, required void Function(int) onTap}) {
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onTap(c),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  if (selected == c)
                    const BoxShadow(color: inkColor, spreadRadius: 3)
                  else
                    const BoxShadow(
                        color: Color(0x1F3A3F52),
                        blurRadius: 12,
                        offset: Offset(0, 4)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 模様レイヤー(baseImage+線+スタンプ)を体パスでクリップして描く。
void _paintOps(Canvas canvas, ui.Image? baseImage, List<_PaintOp> ops) {
  canvas.save();
  canvas.clipPath(CreaturePainter.bodyPath());
  if (baseImage != null) {
    canvas.drawImageRect(
      baseImage,
      Rect.fromLTWH(
          0, 0, baseImage.width.toDouble(), baseImage.height.toDouble()),
      const Rect.fromLTWH(0, 0, _paintSize, _paintSize),
      Paint(),
    );
  }
  for (final op in ops) {
    switch (op) {
      case _Stroke():
        if (op.points.length == 1) {
          canvas.drawCircle(op.points.first, _brushWidth / 2,
              Paint()..color = Color(op.color));
        } else {
          final paint = Paint()
            ..color = Color(op.color)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _brushWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
          final path = Path()..moveTo(op.points.first.dx, op.points.first.dy);
          for (final p in op.points.skip(1)) {
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, paint);
        }
      case _Stamp():
        final tp = TextPainter(
          text: TextSpan(
              text: op.emoji, style: const TextStyle(fontSize: _stampFontSize)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, op.pos - Offset(tp.width / 2, tp.height / 2));
    }
  }
  canvas.restore();
}

class _PaintCanvasPainter extends CustomPainter {
  final Color bodyColor;
  final ui.Image? baseImage;
  final List<_PaintOp> ops;

  _PaintCanvasPainter({
    required this.bodyColor,
    required this.baseImage,
    required this.ops,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _paintSize;
    canvas.scale(s, s);
    canvas.drawPath(CreaturePainter.bodyPath(), Paint()..color = bodyColor);
    _paintOps(canvas, baseImage, ops);
  }

  @override
  bool shouldRepaint(_PaintCanvasPainter old) => true; // ops はミュータブル
}
