#!/usr/bin/env bash
# アプリアイコンを test/render_app_icon_test.dart で描画し、各プラットフォームの
# サイズに縮小して配置する。元絵はゲーム内の CreaturePainter なので、
# いきものの見た目を変えたらこのスクリプトを再実行する。
#   cd app && tool/gen_icons.sh
# 依存: macOS 標準の sips(ImageMagick 等は不要)
set -euo pipefail
cd "$(dirname "$0")/.."

# 元絵は build/(gitignore 済み)に置く
work="build/app_icon"
mkdir -p "$work"
MOKOMON_PREVIEW_DIR="$work" flutter test test/render_app_icon_test.dart >/dev/null
src="$work/app_icon.png"

resize() { # resize <size> <dest>
  sips -z "$1" "$1" "$src" --out "$2" >/dev/null
}

# Web(PWA): any / maskable とも同じ全面絵(安全域は描画側で確保済み)
for s in 192 512; do
  resize $s web/icons/Icon-$s.png
  resize $s web/icons/Icon-maskable-$s.png
done
resize 64 web/favicon.png

# Android: 従来型ランチャーアイコン(mipmap)
resize 48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
resize 72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
resize 96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
resize 144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
resize 192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

# iOS: AppIcon.appiconset の Contents.json にあるサイズをすべて生成
ios=ios/Runner/Assets.xcassets/AppIcon.appiconset
python3 - "$ios/Contents.json" <<'PY' | while read -r px name; do resize "$px" "$ios/$name"; done
import json, sys
seen = set()
for i in json.load(open(sys.argv[1]))["images"]:
    pt = float(i["size"].split("x")[0]); scale = int(i["scale"].rstrip("x"))
    if i["filename"] not in seen:
        seen.add(i["filename"]); print(int(pt * scale), i["filename"])
PY

# macOS: 1024 の単一ソースから各サイズを生成
mac=macos/Runner/Assets.xcassets/AppIcon.appiconset
for s in 16 32 64 128 256 512 1024; do
  resize $s "$mac/app_icon_$s.png"
done

echo "icons updated (source: $src)"
