import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/logic/flood_fill.dart';

/// 4x4 の RGBA バッファを作る(値は [colors] のARGB)。
Uint8List grid(List<int> colors, {int w = 4}) {
  final out = Uint8List(colors.length * 4);
  for (var i = 0; i < colors.length; i++) {
    out[i * 4] = (colors[i] >> 16) & 0xFF;
    out[i * 4 + 1] = (colors[i] >> 8) & 0xFF;
    out[i * 4 + 2] = colors[i] & 0xFF;
    out[i * 4 + 3] = (colors[i] >> 24) & 0xFF;
  }
  return out;
}

void main() {
  const white = 0xFFFFFFFF;
  const black = 0xFF000000;

  test('fill spreads over similar pixels and stops at boundaries', () {
    // 白い领域の真ん中に黒い縦線(x=2)がある 4x4
    final probe = grid([
      white, white, black, white, //
      white, white, black, white,
      white, white, black, white,
      white, white, black, white,
    ]);
    final region = findFillRegion(probe, 4, 4, 0, 0);
    // 左側の白8ピクセルのみ(線は越えない)
    expect(region, {0, 1, 4, 5, 8, 9, 12, 13});
  });

  test('mask restricts the region (body の外へ出ない)', () {
    final probe = grid(List.filled(16, white));
    // マスク: 上半分のみ有効
    final mask = grid([
      ...List.filled(8, white),
      ...List.filled(8, 0x00000000),
    ]);
    final region = findFillRegion(probe, 4, 4, 1, 0, mask: mask);
    expect(region, {0, 1, 2, 3, 4, 5, 6, 7});
  });

  test('applyFill writes the color only inside the region', () {
    final layer = grid(List.filled(16, 0x00000000));
    final out = applyFill(layer, {5, 6}, 0xFFFF0000);
    expect(out[5 * 4], 0xFF); // R
    expect(out[5 * 4 + 3], 0xFF); // A
    expect(out[0], 0);
    expect(out[3], 0); // region外は透明のまま
  });

  test('start outside the mask fills nothing', () {
    final probe = grid(List.filled(16, white));
    final mask = grid(List.filled(16, 0x00000000));
    expect(findFillRegion(probe, 4, 4, 2, 2, mask: mask), isEmpty);
  });
}
