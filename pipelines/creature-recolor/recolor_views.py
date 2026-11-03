"""Перекраска видов в T-позе по таблице цветов, без сети: форма остаётся точно той же.

Запуск: .venv/bin/python -I pipelines/creature-recolor/recolor_views.py <вход.png> <выход.png> <палитра>
Палитры — PALETTES ниже. Цвет выбирается по оттенку и яркости исходного пикселя.
"""

import colorsys
import sys

from PIL import Image


def lantern_archer(h, s, v, x, y, bow):
    """Фонарщик: плащ тёмно-синий, одежда тёмная, штаны серо-оливковые, лук красно-коричневый."""
    deg = h * 360
    if bow:
        if s >= 0.55:
            return 14 / 360, min(0.72, s), v * 0.68  # лук красно-коричневый
        return h, s, v  # кисть на луке и фон
    if s < 0.16:
        return h, s, v  # белое оперение и серый металл
    if v > 0.85 and s > 0.6 and 22 < deg < 52:
        return h, s, v  # огонь в фонаре
    if v > 0.55 and s <= 0.6 and 30 < deg < 56:
        return 40 / 360, 0.06, min(0.72, v * 0.8)  # латунь → тусклое серебро и железо
    if v > 0.55 and 0.15 < s < 0.55 and deg < 38:
        return h, s, v  # кожа рук и лица
    if 44 <= deg < 130:
        return 226 / 360, 0.6, min(0.34, v * 0.7)  # плащ и капюшон, глубокий тёмно-синий
    if 28 <= deg < 44:
        return 75 / 360, 0.16, v * 0.72  # штаны и рукава
    return 20 / 360, min(0.42, s * 0.5), v * 0.36  # кожа доспеха, ремни, сапоги


PALETTES = {"lantern-archer": lantern_archer}


def main(src, dst, palette, bow_x):
    im = Image.open(src).convert("RGB")
    out = im.copy()
    p, q = im.load(), out.load()
    paint = PALETTES[palette]
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b = p[x, y]
            hue, sat, val = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            bow = bow_x[0] <= x < bow_x[1]
            rr, gg, bb = colorsys.hsv_to_rgb(*paint(hue, sat, val, x, y, bow))
            q[x, y] = (round(rr * 255), round(gg * 255), round(bb * 255))
    out.save(dst)


if __name__ == "__main__":
    a = sys.argv
    main(a[1], a[2], a[3], (int(a[4]), int(a[5])) if len(a) > 5 else (0, 0))
