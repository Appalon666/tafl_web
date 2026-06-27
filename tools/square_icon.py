"""Убирает скруглённые (прозрачные) углы иконки → полный квадрат без рамок.
Требование Яндекс.Игр 8.3.3: иконка без скруглённых углов и без рамок.

Что делает: берёт RGBA-иконку со скруглёнными (прозрачными) углами и
«дорисовывает» фон в прозрачные области, продолжая существующий градиент
(итеративная заливка от непрозрачных пикселей к прозрачным). Итог —
непрозрачный квадрат тех же цветов по краям, без видимой рамки.

Запуск:  py tools/square_icon.py
Вход:    assets/branding/icon_512.png   (бэкап → icon_512_rounded.bak.png)
Выход:   assets/branding/icon_512.png         (квадрат, alpha=255)
         assets/branding/icon_512_square.png  (та же копия, для драфта)
"""

import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "branding", "icon_512.png")
BAK = os.path.join(ROOT, "assets", "branding", "icon_512_rounded.bak.png")
OUT_SQUARE = os.path.join(ROOT, "assets", "branding", "icon_512_square.png")

# Порог «непрозрачности»: пиксели с alpha выше считаем известным фоном/контентом.
ALPHA_KNOWN = 16


def fill_transparent(rgb: np.ndarray, known: np.ndarray) -> np.ndarray:
    """Заливает неизвестные (прозрачные) пиксели средним по известным соседям,
    итеративно расширяясь внутрь углов. Края не заворачиваем (без wrap-артефактов)."""
    filled = rgb.astype(np.float32).copy()
    known = known.copy()
    h, w = known.shape
    shifts = [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)]
    guard = 0
    while not known.all():
        accum = np.zeros_like(filled)
        cnt = np.zeros((h, w), np.float32)
        for dy, dx in shifts:
            rolled = np.roll(np.roll(filled, dy, 0), dx, 1)
            rk = np.roll(np.roll(known, dy, 0), dx, 1).astype(np.float32)
            # Обнуляем «завёрнутые» через край строки/столбцы.
            if dy == -1: rk[h - 1, :] = 0
            elif dy == 1: rk[0, :] = 0
            if dx == -1: rk[:, w - 1] = 0
            elif dx == 1: rk[:, 0] = 0
            accum += rolled * rk[:, :, None]
            cnt += rk
        newly = (~known) & (cnt > 0)
        filled[newly] = accum[newly] / cnt[newly][:, None]
        known = known | newly
        guard += 1
        if guard > 2000:
            break
    return np.clip(filled, 0, 255).astype(np.uint8)


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    arr = np.array(im)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]
    known = alpha >= ALPHA_KNOWN
    transparent = int((~known).sum())
    print("прозрачных пикселей (углы):", transparent)
    if transparent == 0:
        print("углы уже непрозрачные — иконка квадратная, выходим")
        return

    if not os.path.exists(BAK):
        im.save(BAK)
        print("бэкап оригинала ->", BAK)

    filled_rgb = fill_transparent(rgb, known)
    out = np.dstack([filled_rgb, np.full(alpha.shape, 255, np.uint8)])
    out_im = Image.fromarray(out, "RGBA")
    out_im.save(SRC)
    out_im.save(OUT_SQUARE)
    # Контроль: углы должны стать непрозрачными.
    c = np.array(out_im)
    print("углы после:", c[2, 2], c[2, -3], c[-3, 2], c[-3, -3])
    print("готово ->", SRC)


if __name__ == "__main__":
    main()
