import 'dart:typed_data';

/// バケツぬりつぶし用の領域探索(docs/game-design.md §6)。
/// [probe] は RGBA バイト列(判定用の見た目合成)。[start] から
/// 色が近いピクセルを4方向に広げ、塗るべきピクセル index 集合を返す。
/// [mask] が与えられた場合、alpha==0 の場所(体の外)へは広がらない。
Set<int> findFillRegion(
  Uint8List probe,
  int width,
  int height,
  int startX,
  int startY, {
  Uint8List? mask,
  int tolerance = 32,
}) {
  bool inMask(int i) => mask == null || mask[i * 4 + 3] > 0;

  final start = startY * width + startX;
  if (startX < 0 || startY < 0 || startX >= width || startY >= height) {
    return {};
  }
  if (!inMask(start)) return {};

  final tr = probe[start * 4];
  final tg = probe[start * 4 + 1];
  final tb = probe[start * 4 + 2];
  final ta = probe[start * 4 + 3];

  bool similar(int i) {
    final o = i * 4;
    return (probe[o] - tr).abs() <= tolerance &&
        (probe[o + 1] - tg).abs() <= tolerance &&
        (probe[o + 2] - tb).abs() <= tolerance &&
        (probe[o + 3] - ta).abs() <= tolerance;
  }

  final region = <int>{};
  final queue = <int>[start];
  final visited = Uint8List(width * height);
  visited[start] = 1;

  while (queue.isNotEmpty) {
    final i = queue.removeLast();
    if (!inMask(i) || !similar(i)) continue;
    region.add(i);
    final x = i % width;
    if (x > 0 && visited[i - 1] == 0) {
      visited[i - 1] = 1;
      queue.add(i - 1);
    }
    if (x < width - 1 && visited[i + 1] == 0) {
      visited[i + 1] = 1;
      queue.add(i + 1);
    }
    if (i >= width && visited[i - width] == 0) {
      visited[i - width] = 1;
      queue.add(i - width);
    }
    if (i < width * (height - 1) && visited[i + width] == 0) {
      visited[i + width] = 1;
      queue.add(i + width);
    }
  }
  return region;
}

/// [region] のピクセルを ARGB [color] で塗った新しい RGBA バッファを返す。
Uint8List applyFill(Uint8List layer, Set<int> region, int color) {
  final out = Uint8List.fromList(layer);
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final b = color & 0xFF;
  for (final i in region) {
    final o = i * 4;
    out[o] = r;
    out[o + 1] = g;
    out[o + 2] = b;
    out[o + 3] = 0xFF;
  }
  return out;
}
