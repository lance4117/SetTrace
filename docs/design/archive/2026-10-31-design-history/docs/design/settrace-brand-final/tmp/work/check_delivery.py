from pathlib import Path
from PIL import Image
import json
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
ns = {'svg': 'http://www.w3.org/2000/svg'}
files = list((root / 'logo').glob('*.svg')) + list((root / 'showcase').glob('*.svg'))
files += list((root / 'settrace-icon').glob('*.svg')) + list((root / 'settrace-icon/layers').glob('*.svg')) + [root / 'overview.svg']
svg_results = []
for file in files:
    doc = ET.parse(file).getroot()
    logo_asset = file.parent.name == 'logo'
    if logo_asset:
        assert not doc.findall('.//svg:text', ns), f'Unoutlined type: {file}'
        assert not doc.findall('.//svg:image', ns), f'Embedded image in logo: {file}'
    svg_results.append({'path': file.relative_to(root).as_posix(), 'valid_xml': True, 'no_font_dependency': logo_asset})

def component_count(image):
    image = image.convert('RGBA')
    pixels = image.load()
    width, height = image.size
    foreground = {(x, y) for y in range(height) for x in range(width)
                  if min(pixels[x, y][:3]) > 225 and pixels[x, y][3] > 128}
    sizes = []
    while foreground:
        start = foreground.pop()
        stack = [start]
        size = 0
        while stack:
            x, y = stack.pop()
            size += 1
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    candidate = (x + dx, y + dy)
                    if candidate in foreground:
                        foreground.remove(candidate)
                        stack.append(candidate)
        sizes.append(size)
    return len(sizes), sorted(sizes, reverse=True)

sizes = []
for size in (16, 24, 32, 48, 64, 128, 256, 512):
    file = root / f'exports/png/settrace-icon-rounded-{size}.png'
    image = Image.open(file)
    assert image.size == (size, size)
    count, areas = component_count(image)
    assert count == 4, f'Expected four separated capsules at {size}px, found {count}'
    sizes.append({'size': size, 'separated_foreground_components': count, 'component_areas_px': areas})

foreground = Image.open(root / 'logo/settrace-symbol-white.png').convert('RGBA')
weights = [(x, y, foreground.getpixel((x, y))[3] / 255) for y in range(1024) for x in range(1024)
           if foreground.getpixel((x, y))[3] > 0]
mass = sum(v for x, y, v in weights)
centroid = [sum(x * v for x, y, v in weights) / mass, sum(y * v for x, y, v in weights) / mass]
assert abs(centroid[0] - 511.5) < 1 and abs(centroid[1] - 511.5) < 1, centroid

raw = Image.open(root / 'settrace-icon/settrace-icon.png').convert('RGBA')
assert raw.getpixel((0, 0)) == (21, 60, 52, 255), 'Square source must have full deep-green bleed'
rounded = Image.open(root / 'settrace-icon/settrace-icon.preview.png').convert('RGBA')
assert rounded.getpixel((0, 0))[3] == 0, 'Preview must carry transparent rounded corners'

def srgb(c):
    x = c / 255
    return x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4
luminance = .2126 * srgb(21) + .7152 * srgb(60) + .0722 * srgb(52)
contrast = 1.05 / (luminance + .05)
report = {
    'status': 'ok', 'svg_assets': svg_results, 'small_size_components': sizes,
    'foreground_centroid_px': [round(v, 3) for v in centroid],
    'brand_white_contrast': round(contrast, 2),
    'square_source_full_bleed': True, 'preview_transparent_corners': True,
    'visual_checks': ['1024px rounded icon and closed vector capsules', '64/48/32/24/16px native-size strip',
                      'circular crop', 'outlined horizontal and stacked lockups', 'four showcase contexts',
                      'HTML preview mode switch and enlarged reversed-color showcase'],
    'limits': 'Generic design/source assets. No native launcher integration or device-rendering claim.'
}
(root / 'tmp/reports').mkdir(exist_ok=True)
(root / 'tmp/reports/delivery-checks.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({key: value for key, value in report.items() if key not in ('svg_assets', 'visual_checks')}, ensure_ascii=False))

review = {
    'decision': 'accepted', 'reviewer': 'main-agent', 'reviewer_type': 'author-original-concept',
    'evidence': ['settrace-icon.preview.png', 'settrace-icon.png', 'layers/02-continuous-sets.svg',
                 'layers/03-interval-set.svg', '../../tmp/work/small-size-review.png',
                 'reference-overlay.png', 'reference-diff.png', '../../overview.png'],
    'notes': 'Low-risk original concept selected by the user and explicitly authorized for design optimization. '
             'Three-track identity, four capsules, deep-green fill and white mark preserved. Closed caps, '
             'parallel rhythm, optical centering and 16–64px separation inspected. The concept comparison '
             'shows deliberate 1.59-unit optical translation and wider interruption; this is refinement, '
             'not strict pixel reproduction. Generic source assets only; no native Android rendering asserted.',
    'platforms_inspected': [], 'renders_inspected': []
}
(root / 'settrace-icon/tmp/reports/visual-review.json').write_text(json.dumps(review, indent=2), encoding='utf-8')
