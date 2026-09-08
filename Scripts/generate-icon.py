#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
为 macOS 生成符合 Apple 人机交互指南 (HIG) 标准的 App 图标：
- 1024x1024 透明画布
- 824x824 居中超椭圆底板 (Squircle)
- 原生圆角平滑过渡 (连续超椭圆曲率)
- 双层微投影 (Ambient Shadow 柔和环境光 + Key Shadow 主光源阴影)
- 1px 微描边 (Rim Border)，在各种背景与浅色壁纸下保持轮廓分明
"""

import sys
import os
from PIL import Image, ImageFilter, ImageOps, ImageChops

def generate_macos_icon(source_path: str, mask_path: str, output_path: str, logo_scale: float = 1.0):
    """
    生成 1024x1024 尺寸的标准 macOS 风格图标。
    
    :param source_path: 原始图标路径（assets/image.png）
    :param mask_path: 居中超椭圆蒙版路径（assets/appicon_mask.png）
    :param output_path: 输出 1024x1024 PNG 图标路径
    :param logo_scale: Logo 相对 824x824 底板缩放比例（默认 1.0，源图已自带标准边距）
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

    # 5. 生成 macOS HIG 标准双层阴影
    # (a) Ambient Shadow: 柔和漫反射环境光投影
    shadow_mask = Image.new("L", (1024, 1024), 0)
    shadow_mask.paste(sub_mask, (100, 100))

    ambient_shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, int(255 * 0.18)))
    ambient_shadow.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(16)))
    ambient_offset = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    ambient_offset.paste(ambient_shadow, (0, 6))

    # (b) Key Shadow: 垂直主光源微阴影
    key_shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, int(255 * 0.22)))
    key_shadow.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(8)))
    key_offset = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    key_offset.paste(key_shadow, (0, 14))

    # 合成阴影到画布
    canvas = Image.alpha_composite(canvas, ambient_offset)
    canvas = Image.alpha_composite(canvas, key_offset)

    # 6. 将圆角底板居中贴入画布 (100, 100)
    canvas.paste(tile, (100, 100), tile)

    # 7. 绘制边缘 1px 微细描边 (Rim Border)
    eroded_mask = ImageOps.invert(mask_image).filter(ImageFilter.MaxFilter(3))
    eroded_mask = ImageOps.invert(eroded_mask)
    rim_mask = ImageChops.subtract(mask_image, eroded_mask)

    rim_layer = Image.new("RGBA", (1024, 1024), (0, 0, 0, int(255 * 0.12)))
    rim_layer.putalpha(rim_mask)
    canvas = Image.alpha_composite(canvas, rim_layer)

    # 8. 保存输出文件
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    canvas.save(output_path, "PNG")
    print(f"成功生成 macOS 标准圆角图标：{output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("用法: python3 generate-icon.py <source_path> <mask_path> <output_path> [scale]")
        sys.exit(1)
    
    src = sys.argv[1]
    mask = sys.argv[2]
    out = sys.argv[3]
    scale = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
    generate_macos_icon(src, mask, out, scale)
