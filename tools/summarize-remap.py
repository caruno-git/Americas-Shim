"""Summarize remap timings adjacent to heavy frame telemetry."""
import argparse
import collections
import json
import math
import re

ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
FRAME = re.compile(r'fps, .*?\), (\d+) draws/frame')
FIELDS = ('wait_ms', 'held_ms', 'unmap_ms', 'install_os_ms', 'install_gpu_ms')


def summarize(lines):
    pending = {}
    totals = collections.defaultdict(collections.Counter)
    heavy = 0
    for raw in lines:
        line = ANSI.sub('', raw)
        # The meter emits this marker even when its FPS line is suppressed.
        if 'indirect mesh dispatches: the largest group count asked for' in line:
            pending.clear()
        if 'title remap writer timing (interval totals)' in line:
            fields = dict(re.findall(r'(\w+)="?([^\s"]+)"?', line))
            if all(f in fields for f in (*FIELDS, 'site', 'count')):
                site = fields['site']
                if site in pending:
                    raise ValueError(f'duplicate remap sample: {site}')
                row = {f: float(fields[f]) for f in FIELDS}
                if not all(math.isfinite(v) and v >= 0 for v in row.values()):
                    raise ValueError(f'invalid timing: {row}')
                if row['unmap_ms'] + row['install_os_ms'] + row['install_gpu_ms'] > row['held_ms'] + 1e-6:
                    raise ValueError(f'phase timings exceed lock hold: {row}')
                sample = dict(row, calls=int(fields['count']), intervals=1)
                if 'alias_pages' in fields and 'same_view_pages' in fields:
                    pages = int(fields['alias_pages'])
                    same_view = int(fields['same_view_pages'])
                    if not 0 <= same_view <= pages:
                        raise ValueError(f'invalid alias page counts: {same_view}/{pages}')
                    sample.update(alias_pages=pages, same_view_pages=same_view)
                    if 'adjacent_section_pages' in fields:
                        adjacent = int(fields['adjacent_section_pages'])
                        if not 0 <= adjacent <= pages:
                            raise ValueError(f'invalid section page counts: {adjacent}/{pages}')
                        sample['adjacent_section_pages'] = adjacent
                pending[site] = sample
        match = FRAME.search(line)
        if match:
            if int(match[1]) >= 1000:
                heavy += 1
                for site, row in pending.items():
                    totals[site].update(row)
            pending.clear()
    return {'heavy_intervals': heavy, 'sites': dict(totals)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=argparse.FileType('r', encoding='utf-8', errors='replace'))
    args = parser.parse_args()
    with args.log as log:
        result = summarize(log)
    print(json.dumps(result))
    if set(result['sites']) != {'alias', 'physical_pages'}:
        parser.exit(1, 'Expected both remap sites in heavy intervals.\n')
