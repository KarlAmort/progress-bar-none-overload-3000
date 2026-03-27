#!/usr/bin/env python3

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def blend(a, b, t):
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def draw_gradient(image):
    width, height = image.size
    draw = ImageDraw.Draw(image)
    top_left = (7, 17, 31)
    mid = (16, 26, 45)
    bottom_right = (6, 16, 26)

    for y in range(height):
      t = y / max(height - 1, 1)
      row_color = blend(top_left, mid if t < 0.55 else bottom_right, min(t / 0.55, 1.0) if t < 0.55 else min((t - 0.55) / 0.45, 1.0))
      draw.line((0, y, width, y), fill=row_color)


def rounded_panel(draw, width, height):
    panel_box = (32, 28, width - 32, height - 28)
    shadow_box = (32, 36, width - 32, height - 20)
    draw.rounded_rectangle(shadow_box, radius=22, fill=(2, 6, 23, 120))
    draw.rounded_rectangle(panel_box, radius=22, fill=(17, 31, 55, 242), outline=(34, 48, 76, 255), width=2)
    draw.rounded_rectangle((48, 44, 198, 72), radius=14, fill=(19, 37, 61, 255), outline=(41, 72, 111, 255), width=1)


def text_width(draw, font, text):
    return draw.textlength(text, font=font)


def draw_segment(draw, position, segment, font, background):
    x, y = position
    fill = tuple(segment["rgb"]) + (255,)
    if segment["dim"]:
        dimmed = blend(tuple(segment["rgb"]), background, 0.38)
        fill = dimmed + (220,)

    if segment["bold"]:
        draw.text((x + 1, y), segment["text"], font=font, fill=fill)
    draw.text((x, y), segment["text"], font=font, fill=fill)
    return x + text_width(draw, font, segment["text"])


def render_frame(spec, font):
    width = spec["width"]
    height = spec["height"]
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw_gradient(image)
    draw = ImageDraw.Draw(image)
    rounded_panel(draw, width, height)

    badge_font = ImageFont.truetype(spec["font_path"], 16)
    draw.text((64, 50), "LIVE DEMO", font=badge_font, fill=(150, 184, 255, 255))

    background = (17, 31, 55)
    top = 86
    line_height = 36

    for idx, line in enumerate(spec["lines"]):
        x = 48
        y = top + idx * line_height
        for segment in line:
            x = draw_segment(draw, (x, y), segment, font, background)

    return image


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: render_demo_assets.py <frames.json> <output.gif>")

    payload_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    payload = json.loads(payload_path.read_text())
    font = ImageFont.truetype(payload["font_path"], 26)

    frames = []
    for frame in payload["frames"]:
        spec = {
            "width": payload["width"],
            "height": payload["height"],
            "font_path": payload["font_path"],
            "lines": frame["lines"],
        }
        frames.append(render_frame(spec, font))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=payload["delay_ms"],
        loop=0,
        disposal=2,
        optimize=False,
    )


if __name__ == "__main__":
    main()
