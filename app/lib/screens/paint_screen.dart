import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/flood_fill.dart';
import '../logic/game_controller.dart';
import '../widgets/creature_painter.dart';
import '../widgets/game_overlays.dart';
import '../widgets/ui_kit.dart';

/// ブラシ16色(こどもFBで増量。くろ・あか・あお等を追加)
const _palette = [
  0xFFFF6EA6,
  0xFFFFAB49,
  0xFFFFD23E,
  0xFF34C98E,
  0xFF54B9FF,
  0xFF9B8CFF,
  0xFF8D6748,
  0xFFFFFFFF,
  0xFF3A3F52,
  0xFFF4442E,
  0xFF2D71E5,
  0xFF2E9E6B,
  0xFFA8E063,
  0xFF9CE8FF,
  0xFFFFC7DC,
  0xFFB9C2D0,
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

/// おもしろスタンプ20種(タップでペタッ、なぞると連続)
const _stamps = [
  '⭐', '🌸', '💖', '⚡', '🌈', '🎀', '🍓', '💩', '😎', '🐟', //
  '🚀', '🦖', '🍭', '👾', '⚽', '🐱', '🌻', '🍕', '💎', '🎈',
];

/// ブラシのふとさ3段階
const _widths = [9.0, 18.75, 34.0];

/// 描画座標は体パスと同じ 300x300。
const _paintSize = 300.0;
const _stampFontSize = 46.0;

enum _Tool { brush, stamp, bucket, eraser }

/// おえかき(もようがえ)。docs/game-design.md §6。
/// ツール: ふで(3サイズ)/スタンプ/バケツぬりつぶし/けしごむ。
/// パレット類は誤タップ防止のため画面下部に置く(手のひら対策)。
class PaintScreen extends StatefulWidget {
  final GameController controller;
  const PaintScreen({super.key, required this.controller});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

sealed class _PaintOp {}

class _Stroke extends _PaintOp {
  final int color;
  final double width;
  final bool erase;
  final points = <Offset>[];
  _Stroke(this.color, this.width, {this.erase = false});
}

class _Stamp extends _PaintOp {
  final String emoji;
  final Offset pos;
  _Stamp(this.emoji, this.pos);
}

class _PaintScreenState extends State<PaintScreen> {
  var _tool = _Tool.brush;
  var _brush = _palette.first;
  var _stamp = _stamps.first;

  /// 基本スタンプ+おみやげで解放された限定スタンプ(docs §14)。
  late final List<String> _allStamps = [
    ..._stamps,
    ...kingGiftStamps
        .where((e) => widget.controller.state.unlockedStamps.contains(e)),
  ];
  var _widthIndex = 1;
  final _ops = <_PaintOp>[];
  ui.Image? _baseImage; // 確定済みレイヤー(保存済み模様+ぬりつぶし結果)
  Offset? _lastStampPos;
  var _filling = false;

  static Uint8List? _bodyMask; // 300x300 体マスク(全インスタンス共有)

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
    switch (_tool) {
      case _Tool.bucket:
        _bucketFill(p);
      case _Tool.stamp:
        setState(() {
          _ops.add(_Stamp(_stamp, p));
          _lastStampPos = p;
        });
      case _Tool.brush || _Tool.eraser:
        setState(() {
          _ops.add(_Stroke(_brush, _widths[_widthIndex],
              erase: _tool == _Tool.eraser)
            ..points.add(p));
        });
    }
  }

  void _onPanUpdate(Offset p) {
    switch (_tool) {
      case _Tool.bucket:
        break;
      case _Tool.stamp:
        if (_lastStampPos == null || (p - _lastStampPos!).distance > 52) {
          setState(() {
            _ops.add(_Stamp(_stamp, p));
            _lastStampPos = p;
          });
        }
      case _Tool.brush || _Tool.eraser:
        if (_ops.isNotEmpty && _ops.last is _Stroke) {
          setState(() => (_ops.last as _Stroke).points.add(p));
        }
    }
  }

  // ---------- バケツぬりつぶし ----------

  Future<ui.Image> _renderImage({required bool withBody}) async {
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, const Rect.fromLTWH(0, 0, _paintSize, _paintSize));
    if (withBody) {
      canvas.drawPath(CreaturePainter.bodyPath(),
          Paint()..color = Color(widget.controller.state.color));
    }
    _paintOps(canvas, _baseImage, _ops);
    return recorder
        .endRecording()
        .toImage(_paintSize.toInt(), _paintSize.toInt());
  }

  static Future<Uint8List> _maskBytes() async {
    if (_bodyMask != null) return _bodyMask!;
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, const Rect.fromLTWH(0, 0, _paintSize, _paintSize));
    canvas.drawPath(CreaturePainter.bodyPath(), Paint()..color = Colors.white);
    final img = await recorder
        .endRecording()
        .toImage(_paintSize.toInt(), _paintSize.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    _bodyMask = data!.buffer.asUint8List();
    return _bodyMask!;
  }

  Future<void> _bucketFill(Offset p) async {
    if (_filling) return;
    _filling = true;
    try {
      final probe = await _renderImage(withBody: true);
      final layer = await _renderImage(withBody: false);
      final probeBytes =
          (await probe.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
      final layerBytes =
          (await layer.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
      final region = findFillRegion(
        probeBytes,
        _paintSize.toInt(),
        _paintSize.toInt(),
        p.dx.round().clamp(0, 299),
        p.dy.round().clamp(0, 299),
        mask: await _maskBytes(),
        tolerance: 40,
      );
      if (region.isEmpty) return;
      final filled = applyFill(layerBytes, region, _brush);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(filled, _paintSize.toInt(), _paintSize.toInt(),
          ui.PixelFormat.rgba8888, completer.complete);
      final newLayer = await completer.future;
      if (!mounted) return;
      widget.controller.sfx.play(Sfx.pop);
      setState(() {
        _baseImage = newLayer;
        _ops.clear();
      });
    } finally {
      _filling = false;
    }
  }

  Future<void> _save() async {
    final image = await _renderImage(withBody: false);
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

  // ---------- UI ----------

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
                    final canvasSize =
                        min(min(box.maxWidth - 40, 340.0), box.maxHeight - 264)
                            .clamp(120.0, 340.0);
                    return Column(
                      children: [
                        _canvas(canvasSize),
                        const Spacer(),
                        _toolRow(),
                        const SizedBox(height: 6),
                        if (_tool == _Tool.stamp)
                          _stampRows()
                        else
                          _paletteRows(),
                        const SizedBox(height: 6),
                        _swatchRow(_bodyColors, 30,
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
                        label: 'ぜんぶけす',
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
          onTapDown: (d) =>
              _onPanStart(_toBodyCoords(d.localPosition, canvasSize)),
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

  /// ツール選択: ふで / スタンプ / バケツ / けしごむ + ふとさ
  Widget _toolRow() {
    Widget toolChip(_Tool tool, String emoji, String label) {
      final selected = _tool == tool;
      return GestureDetector(
        onTap: () => setState(() => _tool = tool),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAFAF1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? const Color(0xFF34C98E) : Colors.white,
                width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x143A3F52),
                  blurRadius: 8,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: inkColor)),
            ],
          ),
        ),
      );
    }

    Widget widthDot(int index) {
      final selected = _widthIndex == index &&
          (_tool == _Tool.brush || _tool == _Tool.eraser);
      final d = 10.0 + index * 7;
      return GestureDetector(
        onTap: () => setState(() {
          _widthIndex = index;
          if (_tool == _Tool.stamp || _tool == _Tool.bucket) {
            _tool = _Tool.brush;
          }
        }),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: selected ? const Color(0xFF34C98E) : Colors.white,
                width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x143A3F52),
                  blurRadius: 8,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Container(
            width: d,
            height: d,
            decoration:
                const BoxDecoration(color: inkColor, shape: BoxShape.circle),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        toolChip(_Tool.brush, '🖌️', 'ふで'),
        toolChip(_Tool.stamp, '⭐', 'スタンプ'),
        toolChip(_Tool.bucket, '🪣', 'ぬりつぶし'),
        toolChip(_Tool.eraser, '🧼', 'けしごむ'),
        const SizedBox(width: 4),
        widthDot(0),
        widthDot(1),
        widthDot(2),
      ],
    );
  }

  Widget _stampRows() => Wrap(
        spacing: 5,
        runSpacing: 5,
        alignment: WrapAlignment.center,
        children: [
          for (final e in _allStamps)
            GestureDetector(
              onTap: () => setState(() => _stamp = e),
              child: Container(
                width: 34,
                height: 34,
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
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                  ],
                ),
                child: Text(e, style: const TextStyle(fontSize: 19)),
              ),
            ),
        ],
      );

  Widget _paletteRows() =>
      _swatchRow(_palette, 34, selected: _brush, onTap: (c) {
        setState(() {
          _brush = c;
          if (_tool == _Tool.stamp || _tool == _Tool.eraser) {
            _tool = _Tool.brush;
          }
        });
      });

  Widget _swatchRow(List<int> colors, double size,
      {int? selected, required void Function(int) onTap}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
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
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  if (selected == c)
                    const BoxShadow(color: inkColor, spreadRadius: 3)
                  else
                    const BoxShadow(
                        color: Color(0x1F3A3F52),
                        blurRadius: 10,
                        offset: Offset(0, 3)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 模様レイヤー(baseImage+線+スタンプ)を体パスでクリップして描く。
/// けしごむ(BlendMode.clear)が体色まで消さないよう saveLayer で分離する。
void _paintOps(Canvas canvas, ui.Image? baseImage, List<_PaintOp> ops) {
  canvas.save();
  canvas.clipPath(CreaturePainter.bodyPath());
  canvas.saveLayer(const Rect.fromLTWH(0, 0, _paintSize, _paintSize), Paint());
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
        final paint = Paint()
          ..color = op.erase ? Colors.transparent : Color(op.color)
          ..style = PaintingStyle.stroke
          ..strokeWidth = op.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        if (op.erase) paint.blendMode = BlendMode.clear;
        if (op.points.length == 1) {
          final dot = Paint()
            ..color = op.erase ? Colors.transparent : Color(op.color);
          if (op.erase) dot.blendMode = BlendMode.clear;
          canvas.drawCircle(op.points.first, op.width / 2, dot);
        } else {
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
  canvas.restore(); // saveLayer
  canvas.restore(); // clip
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
