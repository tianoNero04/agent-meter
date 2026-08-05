#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="$project_root/Build"
app_path="$build_root/AgentUsageDashboard.app"
binary_path="$(swift build -c release --show-bin-path)/AgentUsageDashboard"
icon_source="$project_root/assets/image.png"
icon_workspace="$(mktemp -d "${TMPDIR:-/tmp}/agent-meter-icon.XXXXXX")"
iconset_path="$icon_workspace/AppIcon.iconset"
icon_output="$icon_workspace/AppIcon.icns"

cleanup() {
  rm -rf "$icon_workspace"
}
trap cleanup EXIT

if [[ ! -f "$icon_source" ]]; then
  echo "找不到 App 图标源文件：$icon_source" >&2
  exit 1
fi

mkdir -p "$iconset_path"
for size in 16 32 128 256 512; do
  double_size=$((size * 2))
  sips -z "$size" "$size" "$icon_source" --out "$iconset_path/icon_${size}x${size}.png" >/dev/null
  sips -z "$double_size" "$double_size" "$icon_source" --out "$iconset_path/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_path" -o "$icon_output"

mkdir -p "$build_root" "$app_path/Contents/MacOS" "$app_path/Contents/Resources"

swift build -c release
cp "$binary_path" "$app_path/Contents/MacOS/AgentUsageDashboard"
cp "$project_root/Resources/Info.plist" "$app_path/Contents/Info.plist"
cp "$icon_output" "$app_path/Contents/Resources/AppIcon.icns"

echo "已生成：$app_path"
echo "运行：open \"$app_path\""
