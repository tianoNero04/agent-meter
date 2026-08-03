#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="$project_root/Build"
app_path="$build_root/AgentUsageDashboard.app"
binary_path="$(swift build -c release --show-bin-path)/AgentUsageDashboard"

mkdir -p "$build_root" "$app_path/Contents/MacOS" "$app_path/Contents/Resources"

swift build -c release
cp "$binary_path" "$app_path/Contents/MacOS/AgentUsageDashboard"
cp "$project_root/Resources/Info.plist" "$app_path/Contents/Info.plist"

echo "已生成：$app_path"
echo "运行：open \"$app_path\""
