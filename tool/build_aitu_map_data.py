"""Index room polygons from the exported, styled SVG plans."""

import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path


root = Path(__file__).resolve().parents[1]
svg_dir = root / 'assets/map/svg'
floors = []

for path in sorted(svg_dir.glob('C1_*.svg')):
    _, block_name, floor_name = path.stem.split('_')
    block = 0 if block_name == 'all' else int(block_name)
    floor = int(floor_name)
    svg = ET.parse(path).getroot()
    _, _, width, height = (float(value) for value in svg.attrib['viewBox'].split())
    rooms = []
    for group in svg.iter():
        number = group.attrib.get('data-name', '')
        if not re.fullmatch(r'C1\.[123]\.[123]\d{2,3}[A-Z]?', number):
            continue
        shape = next((element for element in group.iter()
                      if element.tag.rsplit('}', 1)[-1] in ('polygon', 'polyline')
                      and 'points' in element.attrib), None)
        if shape is None:
            continue
        values = [float(value) for value in shape.attrib['points'].replace(',', ' ').split()]
        outline = [[values[i], values[i + 1]] for i in range(0, len(values), 2)]
        if len(outline) >= 3:
            rooms.append({'number': number, 'outline': outline})
    floors.append({
        'building': 'C1', 'block': block, 'floor': floor,
        'width': width, 'height': height,
        'footprint': [], 'stairs': [], 'rooms': rooms,
    })

out = root / 'assets/map/aitu_rooms.json'
out.write_text(json.dumps({'floors': floors}, ensure_ascii=False, separators=(',', ':')))
print('Indexed', len(floors), 'plans and', sum(len(f['rooms']) for f in floors), 'room shapes')
