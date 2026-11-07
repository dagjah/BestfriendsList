"""Upload the tested package using the official CurseForge Upload API."""
import argparse
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.request
import uuid


def available_versions():
    token = os.environ.get('CF_API_TOKEN', '')
    if not token:
        raise SystemExit('Set CF_API_TOKEN to query supported game versions.')
    request = urllib.request.Request(
        'https://wow.curseforge.com/api/game/versions',
        headers={'X-Api-Token': token})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            versions = json.load(response)
    except urllib.error.HTTPError as error:
        raise SystemExit(f'CurseForge version lookup failed (HTTP {error.code}).') from None
    except urllib.error.URLError:
        raise SystemExit('Could not reach CurseForge for game-version lookup.') from None
    if not isinstance(versions, list) or not all(isinstance(item, dict) and 'id' in item and 'name' in item for item in versions):
        raise SystemExit('Unexpected game-version response from CurseForge.')
    return {int(item['id']): str(item['name']) for item in versions}


def check_configuration():
    project = os.environ.get('CF_PROJECT_ID', '')
    raw = os.environ.get('CF_GAME_VERSION_IDS', '')
    if not re.fullmatch(r'[1-9][0-9]*', project):
        raise SystemExit('Set a numeric CF_PROJECT_ID.')
    if not re.fullmatch(r'[1-9][0-9]*(\s*,\s*[1-9][0-9]*)*', raw):
        raise SystemExit('Set CF_GAME_VERSION_IDS to comma-separated CurseForge game-version IDs.')
    selected = [int(value) for value in raw.split(',')]
    versions = available_versions()
    missing = [value for value in selected if value not in versions]
    if missing:
        raise SystemExit(f'Unknown CurseForge game-version IDs: {missing}')
    print(f'Configured project ID: {project}')
    for value in selected:
        print(f'Game version: {value} = {versions[value]}')
    print('Version lookup passed. Confirm these versions match Forever. Project upload permission is checked only by an actual upload.')


def main():
    token = os.environ.get('CF_API_TOKEN', '')
    project = os.environ.get('CF_PROJECT_ID', '')
    versions = os.environ.get('CF_GAME_VERSION_IDS', '')
    if not token or not re.fullmatch(r'[1-9][0-9]*', project):
        raise SystemExit('Set CF_API_TOKEN and a numeric CF_PROJECT_ID.')
    if not re.fullmatch(r'[1-9][0-9]*(\s*,\s*[1-9][0-9]*)*', versions):
        raise SystemExit('Set CF_GAME_VERSION_IDS to comma-separated CurseForge game-version IDs.')
    tag = os.environ['RELEASE_TAG']
    metadata = {
        'changelog': Path('CHANGELOG.md').read_text(), 'changelogType': 'markdown',
        'displayName': f'BestfriendsList {tag}', 'releaseType': 'release',
        'gameVersions': [int(value) for value in versions.split(',')],
    }
    boundary = 'BFL-' + uuid.uuid4().hex
    data = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
        'Content-Type: application/json\r\n\r\n' + json.dumps(metadata) + '\r\n'
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="BestfriendsList-install.zip"\r\n'
        'Content-Type: application/zip\r\n\r\n'
    ).encode() + Path('dist/BestfriendsList-install.zip').read_bytes() + f'\r\n--{boundary}--\r\n'.encode()
    request = urllib.request.Request(
        f'https://wow.curseforge.com/api/projects/{project}/upload-file', data=data,
        headers={'X-Api-Token': token, 'Content-Type': f'multipart/form-data; boundary={boundary}'},
        method='POST')
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        raise SystemExit(f'CurseForge rejected upload (HTTP {error.code}); check project permissions and game-version IDs.') from None
    except urllib.error.URLError:
        raise SystemExit('Could not reach CurseForge. Check the project file list before retrying to avoid duplicates.') from None
    print(f'Uploaded CurseForge file ID: {result["id"]}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--check', action='store_true', help='Validate configuration against live game versions without uploading')
    modes.add_argument('--list-versions', action='store_true', help='List supported game-version IDs without uploading')
    args = parser.parse_args()
    if args.list_versions:
        for version_id, name in available_versions().items():
            print(f'{version_id}: {name}')
    elif args.check:
        check_configuration()
    else:
        check_configuration()
        main()
