"""Export faithful, styled SVG plans from the bundled AITU web build.

Requires Google Chrome on macOS. The exported plans remain under the original
map's MIT license (see assets/map/SOURCE.md).
"""

import html
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


root = Path(__file__).resolve().parents[1]
site = root / 'assets/map_site'
output = root / 'assets/map/svg'
output.mkdir(parents=True, exist_ok=True)
chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
source_html = (site / 'index.html').read_text()

for block in (0, 1, 2, 3):
    for floor in (1, 2, 3):
        script = f'''<script>
setTimeout(() => {{
  const select = document.querySelector('#search__select-block');
  if ({block} > 0) {{ select.value='B{block}'; select.dispatchEvent(new Event('change',{{bubbles:true}})); }}
  document.querySelector('button[name="F{floor}"]')?.click();
}}, 700);
setTimeout(() => {{
  const svg = document.querySelector('.react-transform-component > svg');
  if (!svg) return;
  const clone = svg.cloneNode(true);
  const originals = [svg, ...svg.querySelectorAll('*')];
  const copies = [clone, ...clone.querySelectorAll('*')];
  for (let i=0; i<originals.length; i++) {{
    const computed = getComputedStyle(originals[i]);
    const copy = copies[i];
    for (const property of ['fill','stroke','stroke-width','fill-rule','opacity',
      'fill-opacity','stroke-opacity','stroke-linecap','stroke-linejoin']) {{
      copy.setAttribute(property, computed.getPropertyValue(property));
    }}
    copy.removeAttribute('class');
    copy.removeAttribute('style');
  }}
  const box = clone.viewBox.baseVal;
  clone.setAttribute('width', box.width);
  clone.setAttribute('height', box.height);
  const dump = document.createElement('textarea');
  dump.id='taskhub-export'; dump.textContent=clone.outerHTML;
  document.body.replaceChildren(dump);
}}, 1600);
</script>'''
        harness = site / '_export.html'
        harness.write_text(source_html.replace('</body>', script + '</body>'))
        command = [chrome, '--headless', '--disable-gpu', '--no-sandbox',
                   '--allow-file-access-from-files', '--virtual-time-budget=2500',
                   '--dump-dom', harness.as_uri()]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        match = re.search(r'<textarea id="taskhub-export">(.*?)</textarea>', result.stdout, re.S)
        if not match:
            raise RuntimeError(f'No SVG for block {block}, floor {floor}')
        svg = html.unescape(match.group(1))
        ET.fromstring(svg)
        filename = f'C1_{block or "all"}_{floor}.svg'
        (output / filename).write_text(svg)
        print(filename, len(svg))

harness.unlink()
