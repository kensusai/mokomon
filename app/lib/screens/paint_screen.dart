import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../widgets/creature_painter.dart';
import '../widgets/game_overlays.dart';

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

/// 描画座標は体パスと同じ 300x300。線幅はプロトタイプ(320px canvas の 20)相当。
const _paintSize = 300.0;
const _brushWidth = 20.0 * 300 / 320;

/// おえかき(もようがえ)。docs/game-design.md §6。
/// 保存したら true を返して閉じる(報酬は controller.savePaint が付与)。
class PaintScreen extends StatefulWidget {
  final GameController controller;
  const PaintScreen({super.key, required this.controller});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _Stroke {
  final int color;
  final points = <Offset>[];
  _Stroke(this.color);
}

class _PaintScreenState extends State<PaintScreen> {
  var _brush = _palette.first;
  final _strokes = <_Stroke>[];
  ui.Image? _baseImage; // 保存済み模様(この上に描き足す)

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

  Future<void> _save() async {
    // 体色は含めず、模様レイヤーだけを透明PNGで書き出す(色を後から変えられる)
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, const Rect.fromLTWH(0, 0, _paintSize, _paintSize));
    _paintStrokes(canvas, _baseImage, _strokes);
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
      _strokes.clear();
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
                              color: Color(0xFF3A3F52))),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    // パレット等の高さを差し引いてキャンバスを正方形で収める
                    final canvasSize =
                        min(min(box.maxWidth - 40, 340.0), box.maxHeight - 170)
                            .clamp(120.0, 340.0);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x1F3A3F52),
                                  blurRadius: 24,
                                  offset: Offset(0, 10)),
                            ],
                          ),
                          child: SizedBox(
                            width: canvasSize,
                            height: canvasSize,
                            child: GestureDetector(
                              onPanStart: (d) => setState(() {
                                _strokes.add(_Stroke(_brush)
                                  ..points.add(_toBodyCoords(
                                      d.localPosition, canvasSize)));
                              }),
                              onPanUpdate: (d) => setState(() {
                                _strokes.last.points.add(
                                    _toBodyCoords(d.localPosition, canvasSize));
                              }),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: ListenableBuilder(
                                  listenable: widget.controller,
                                  builder: (context, _) => CustomPaint(
                                    painter: _PaintCanvasPainter(
                                      bodyColor:
                                          Color(widget.controller.state.color),
                                      baseImage: _baseImage,
                                      strokes: _strokes,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _swatchRow(_palette, 40,
                            selected: _brush,
                            onTap: (c) => setState(() => _brush = c)),
                        const SizedBox(height: 8),
                        const Text('からだの いろも えらべるよ ↓',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8A90A8))),
                        const SizedBox(height: 8),
                        _swatchRow(_bodyColors, 34,
                            onTap: widget.controller.setBodyColor),
                      ],
                    );
                  }),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        emoji: '🧽',
                        label: 'けす',
                        colors: const [Color(0xFFC3C9DD), Color(0xFFA6ADC7)],
                        onTap: _clear,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _actionButton(
                        emoji: '✨',
                        label: 'できた!',
                        colors: const [Color(0xFF34C98E), Color(0xFF1FAE76)],
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
                    const BoxShadow(color: Color(0xFF3A3F52), spreadRadius: 3)
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

  Widget _actionButton({
    required String emoji,
    required String label,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x24000000), offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 模様レイヤー(baseImage+strokes)を体パスでクリップして描く。
void _paintStrokes(Canvas canvas, ui.Image? baseImage, List<_Stroke> strokes) {
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
  for (final stroke in strokes) {
    final paint = Paint()
      ..color = Color(stroke.color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _brushWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, _brushWidth / 2,
          Paint()..color = Color(stroke.color));
    } else {
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final p in stroke.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }
  canvas.restore();
}

class _PaintCanvasPainter extends CustomPainter {
  final Color bodyColor;
  final ui.Image? baseImage;
  final List<_Stroke> strokes;

  _PaintCanvasPainter({
    required this.bodyColor,
    required this.baseImage,
    required this.strokes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _paintSize;
    canvas.scale(s, s);
    canvas.drawPath(CreaturePainter.bodyPath(), Paint()..color = bodyColor);
    _paintStrokes(canvas, baseImage, strokes);
  }

  @override
  bool shouldRepaint(_PaintCanvasPainter old) => true; // strokes はミュータブル
}
