"""Draws vignettes/figures/sampling-designs.svg, the figure that opens
vignette("sampling-designs"). Run from the package root:
python3 dev/figures/sampling_designs_svg.py

The same night of twelve hourly recordings is shown four times; each row
marks what one sampling_mode of select_clips() sends to review. The
predictions are illustrative, not data."""
from xml.sax.saxutils import escape

INK, GREY, LIGHT, RULE = "#222222", "#9a9a9a", "#d9d9d9", "#bdbdbd"
ACC, ACC_BG = "#c4501b", "#f6dfd3"
SANS = "Helvetica Neue, Helvetica, Arial, sans-serif"

# confidence of the predictions in each recording (18:00 to 05:00)
PRED = [[.35, .62], [.81, .44, .58], [], [.28], [.92, .71],
        [.52, .33, .66, .47], [], [.39, .88], [.24], [.57, .74], [],
        [.31, .49]]
THR = 0.5
DRAWN_DET = {1, 9}        # occasions drawn among those with a detection
DRAWN_REC = {2, 5, 8}     # recordings drawn among all
BREAKS = [0.1, 0.4, 0.7, 1.0]  # score bands of "score_bands"
# (recording, prediction) drawn in "score_bands": two per band
DRAWN_BAND = {(0, 0), (8, 0), (1, 2), (5, 3), (4, 1), (7, 1)}

W, H = 1000, 630
LEFT, RIGHT = 270, 750    # strip of recordings
ROW_H, ROW_GAP, TOP = 96, 34, 40
N = len(PRED)
CELL = (RIGHT - LEFT) / N
out = []


def text(x, y, s, size=12, fill=INK, anchor="start", weight="normal",
         style="normal"):
    out.append(f'<text x="{x:.1f}" y="{y:.1f}" font-family="{SANS}" '
               f'font-size="{size}" fill="{fill}" text-anchor="{anchor}" '
               f'font-weight="{weight}" font-style="{style}">{escape(s)}'
               f'</text>')


def line(x1, y1, x2, y2, stroke=INK, width=1, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    out.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" '
               f'y2="{y2:.1f}" stroke="{stroke}" stroke-width="{width}"{d}/>')


def rect(x, y, w, h, fill="none", stroke="none", width=1):
    out.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" '
               f'height="{h:.1f}" fill="{fill}" stroke="{stroke}" '
               f'stroke-width="{width}"/>')


def lollipop(x, base, h, conf, chosen):
    y = base - conf * h
    col = ACC if chosen else GREY
    line(x, base, x, y, col, 1.6 if chosen else 1)
    out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{3.6 if chosen else 2.6}" '
               f'fill="{col}"/>')


rows = [
    ("A", '"top"', "highest score per hour",
     ["classifier retraining;", "score calibration.", "Not a random sample:",
      "no false-positive rate."]),
    ("B", '"random_detections"', "random occasions with a detection",
     ["false-positive rate", "(observation-confirmation", "design)."]),
    ("C", '"random_recordings"', "random recordings, by ear",
     ["false-positive and", "false-negative rates", "(multiple-method design)."]),
    ("D", '"score_bands"', "random clips in each score band",
     ["thresholds and calibration", "across the score range.", "Chosen by score:",
      "no false-positive rate."]),
]

out.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
           f'width="{W}" height="{H}" role="img" aria-labelledby="t d">')
out.append('<title id="t">What each sampling design of select_clips() '
           'sends to review</title>')
out.append('<desc id="d">The same night of twelve hourly recordings is shown '
           'four times. Top keeps the highest-scoring prediction of each '
           'recording. Random_detections draws recordings with a detection '
           'above the threshold and reviews every detection in them. '
           'Random_recordings draws recordings among all, including ones '
           'without predictions, and annotates them by ear. Score_bands draws '
           'two predictions at random in each band of score (0.1 to 0.4, '
           '0.4 to 0.7, 0.7 to 1).</desc>')
rect(0, 0, W, H, "#ffffff")
text(LEFT, 22, "sampling_mode", 11, GREY)
text(RIGHT + 40, 22, "use", 11, GREY)

for r, (lab, mode, how, use) in enumerate(rows):
    y0 = TOP + r * (ROW_H + ROW_GAP)
    base = y0 + ROW_H
    hgt = ROW_H - 14
    text(16, y0 + 16, lab, 15, weight="bold")
    text(38, y0 + 16, mode, 13, weight="bold")
    text(38, y0 + 34, how, 11.5, GREY, style="italic")
    # recordings
    for i, preds in enumerate(PRED):
        x = LEFT + i * CELL
        if r == 2 and i in DRAWN_REC:
            rect(x + 2, y0 + 4, CELL - 4, ROW_H - 4, ACC_BG)
        if r == 1 and i in DRAWN_DET:
            rect(x + 2, y0 + 4, CELL - 4, ROW_H - 4, "none", ACC, 1.2)
        if not preds:
            line(x + CELL / 2 - 6, base - 1, x + CELL / 2 + 6, base - 1,
                 RULE, 1, "2 2")
        k = len(preds)
        top_i = preds.index(max(preds)) if preds else None
        for j, c in enumerate(preds):
            px = x + CELL / 2 + (j - (k - 1) / 2) * 6
            if r == 0:
                chosen = j == top_i
            elif r == 1:
                chosen = i in DRAWN_DET and c >= THR
            elif r == 3:
                chosen = (i, j) in DRAWN_BAND
            else:
                chosen = False
            lollipop(px, base, hgt, c, chosen)
    line(LEFT, base, RIGHT, base, INK, 1)
    # confidence axis
    line(LEFT - 8, base, LEFT - 8, base - hgt, RULE, 1)
    text(LEFT - 12, base + 4, "0", 10, GREY, "end")
    text(LEFT - 12, base - hgt + 4, "1", 10, GREY, "end")
    if r == 1:
        ty = base - THR * hgt
        line(LEFT, ty, RIGHT, ty, INK, 0.8, "4 3")
        text(RIGHT - 2, ty - 5, "threshold", 10, GREY, "end")
    if r == 3:
        for b in BREAKS[1:-1]:
            ty = base - b * hgt
            line(LEFT, ty, RIGHT, ty, GREY, 0.8, "1 3")
            text(RIGHT + 6, ty + 4, f"{b:.1f}", 10, GREY)
        text(RIGHT - 2, base - hgt - 2, "score bands", 10, GREY, "end")
    if r == 0:
        out.append(f'<text transform="translate({LEFT - 22},{base - hgt / 2})'
                   f' rotate(-90)" font-family="{SANS}" font-size="10" '
                   f'fill="{GREY}" text-anchor="middle">confidence</text>')
    for k, s in enumerate(use):
        text(RIGHT + 40, y0 + 16 + k * 16, s, 11.5)

# time axis
yb = TOP + 4 * ROW_H + 3 * ROW_GAP + 18
for i in range(0, N, 3):
    hh = (18 + i) % 24
    text(LEFT + i * CELL + CELL / 2, yb, f"{hh:02d}:00", 10, GREY, "middle")
text((LEFT + RIGHT) / 2, yb + 18, "one night, one recording per hour",
     10.5, GREY, "middle")

# legend
ly = H - 22
out.append(f'<circle cx="{LEFT + 4}" cy="{ly - 4}" r="3.6" fill="{ACC}"/>')
text(LEFT + 14, ly, "prediction sent to review", 10.5)
rect(LEFT + 168, ly - 11, 12, 12, "none", ACC, 1.2)
text(LEFT + 186, ly, "occasion drawn", 10.5)
rect(LEFT + 282, ly - 11, 14, 12, ACC_BG)
text(LEFT + 302, ly, "recording annotated by ear", 10.5)
line(LEFT + 466, ly - 1, LEFT + 478, ly - 1, RULE, 1, "2 2")
text(LEFT + 484, ly, "no prediction", 10.5)

out.append("</svg>")
open("vignettes/figures/sampling-designs.svg", "w").write("\n".join(out))
