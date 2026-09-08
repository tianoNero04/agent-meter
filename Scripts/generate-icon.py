#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
为 macOS 生成符合 Apple 人机交互指南 (HIG) 标准的纯净 App 图标：
- 1024x1024 透明画布
- 824x824 居中连续超椭圆底板 (Squircle)
- 纯净平滑抗锯齿边缘过渡，彻底去除人工外描边与人工黑阴影（macOS 系统 Dock 会自动渲染原生层次投影）
"""

import sys
import os
from PIL import Image

def generate_macos_icon(source_path: str, mask_path: str, output_path: str, logo_scale: float = 1.0):
    """
    生成 1024x1024 尺寸的标准 macOS 风格圆角图标。
    
    :param source_path: 原始图标路径（assets/image.png）
    :param mask_path: 居中超椭圆蒙版路径（assets/appicon_mask.png）
    :param output_path: 输出 1024x1024 PNG 图标路径
    :param logo_scale: Logo 相对 824x824 底板缩放比例（默认 1.0）
    """
    if not os.path.isfile(source_path):
        raise FileNotFoundError(f"找不到图标源文件: {source_path}")
    if not os.path.isfile(mask_path):
        raise FileNotFoundError(f"找不到圆角蒙版文件: {mask_path}")

    # 1. 打开原图和圆角蒙版
    src_image = Image.open(source_path).convert("RGBA")
    mask_image = Image.open(mask_path).convert("L")

    # 2. 创建 1024x1024 透明底板
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))

    # 3. 创建 824x824 白色方块作为底板并填充原图
    tile = Image.new("RGBA", (824, 824), (255, 255, 255, 255))
    if logo_scale >= 0.999:
        resized_logo = src_image.resize((824, 824), Image.Resampling.LANCZOS)
        tile.paste(resized_logo, (0, 0), resized_logo)
    else:
        scaled_size = int(824 * logo_scale)
        resized_logo = src_image.resize((scaled_size, scaled_size), Image.Resampling.LANCZOS)
        offset = (824 - scaled_size) // 2
        tile.paste(resized_logo, (offset, offset), resized_logo)

    # 4. 提取 824x824 区域的圆角蒙版并裁切底板
    sub_mask = mask_image.crop((100, 100, 924, 924))
    tile.putalpha(sub_mask)

    # 5. 将无人工黑边、无外圈重复脏阴影的纯净圆角底板贴入画布 (100, 100)
    canvas.paste(tile, (100, 100), tile)

    # 6. 保存输出文件
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    canvas.save(output_path, "PNG")
    print(f"成功生成 macOS 纯净标准圆角图标：{output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("用法: python3 generate-icon.py <source_path> <mask_path> <output_path> [scale]")
        sys.exit(1)
    
    src = sys.argv[1]
    mask = sys.argv[2]
    out = sys.argv[3]
    scale = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
    generate_macos_icon(src, mask, out, scale)
