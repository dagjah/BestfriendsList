"""Build the install ZIP using an explicit allowlist, including data-only loaders."""
import argparse
import re
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ['Lists.lua', 'Factions.lua', 'PartySync.lua', 'BestfriendsList.lua']


def build(output, tag=None):
    toc = (ROOT / 'BestfriendsList.toc').read_text()
    version = re.search(r'^## Version: (.+)$', toc, re.M).group(1)
    interface = re.search(r'^## Interface: ([0-9]+)$', toc, re.M).group(1)
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        raise ValueError('Release versions must use major.minor.patch')
    if tag and tag != 'v' + version:
        raise ValueError(f'Tag {tag} must match TOC version v{version}')
    compat = (ROOT / 'KillList.toc').read_text()
    assert f'## Version: {version}\n' in compat, 'Manifest versions differ'
    for manifest in (toc, compat):
        assert [line for line in manifest.splitlines() if line and not line.startswith('#')] == RUNTIME
    entries = {f'BestfriendsList/{name}': (ROOT / name).read_bytes()
               for name in RUNTIME + ['BestfriendsList.toc', 'README.md', 'LICENSE']}
    for old, description in [('KillOnSight', 'previous name'), ('KillOnSite', 'older name'), ('KillList', 'original name')]:
        entries[f'{old}/{old}.toc'] = (
            f'## Interface: {interface}\n'
            f'## Title: BestfriendsList Legacy Data ({description})\n'
            '## Notes: Loads saved lists from a previous addon name for migration.\n'
            f'## Version: {version}\n## SavedVariables: {old}DB\n\n').encode()
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
        for name, data in sorted(entries.items()):
            info = ZipInfo(name, (2020, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    with ZipFile(output) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == set(entries)
        for name, data in entries.items():
            assert archive.read(name) == data
    print(f'Built {output}: {version}, {len(entries)} files')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='dist/BestfriendsList-install.zip')
    parser.add_argument('--tag')
    args = parser.parse_args()
    build(args.output, args.tag)
