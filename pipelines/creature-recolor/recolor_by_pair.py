"""Перекраска видов по паре «старый вид спереди → новый концепт спереди» (та же поза и кадр).

Запуск (системный python3 с numpy/scipy): python3 recolor_by_pair.py <старый_front> <новый_front> <папка_видов> <папка_выхода>
Таблица цветов RGB (32 уровня) снимается попиксельно с пары, пустые ячейки — от ближайшей заполненной.
Форма видов не меняется. Применено на молотобойце hammerer2 (задача 170).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.spatial import cKDTree

Q = 8


def key(im):
    return (im[..., 0] // Q) * 1024 + (im[..., 1] // Q) * 32 + (im[..., 2] // Q)


def main(old_front, new_front, views, out):
    a = np.asarray(Image.open(old_front).convert("RGB")).astype(int)
    b = np.asarray(Image.open(new_front).convert("RGB").resize((a.shape[1], a.shape[0]))).astype(float)
    k, t = key(a).ravel(), b.reshape(-1, 3)
    cnt = np.bincount(k, minlength=32768).astype(float)
    lut = np.stack([np.bincount(k, weights=t[:, c], minlength=32768) for c in range(3)], 1)
    have = cnt > 0
    lut[have] /= cnt[have, None]
    idx = np.argwhere(have.reshape(32, 32, 32))
    _, nn = cKDTree(idx).query(np.argwhere(np.ones((32, 32, 32), bool)))
    lut = lut.reshape(32, 32, 32, 3)[tuple(idx.T)][nn].reshape(32768, 3)
    print("ошибка на виде спереди:", round(float(np.abs(lut[k] - t).mean()), 1))
    Path(out).mkdir(parents=True, exist_ok=True)
    for v in ["front", "left", "back", "right"]:
        im = np.asarray(Image.open(Path(views) / f"{v}.png").convert("RGB")).astype(int)
        Image.fromarray(lut[key(im)].clip(0, 255).astype(np.uint8)).save(Path(out) / f"{v}.png")


if __name__ == "__main__":
    main(*sys.argv[1:5])
