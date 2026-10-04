#!/usr/bin/env python3
"""No-install, non-executing checks for a local Lumi HTML checkout."""
import argparse
import hashlib
import json
from html.parser import HTMLParser
from pathlib import Path
import subprocess
import sys
from urllib.parse import unquote, urlsplit


class HTMLAssets(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.refs = []
        self.scripts = []
        self.script = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        key = 'href' if tag == 'link' else 'src'
        if tag in ('script', 'img', 'audio', 'video', 'source', 'link') and attrs.get(key):
            self.refs.append({'tag': tag, 'url': attrs[key]})
        if tag == 'script':
            self.script = {'attributes': attrs, 'parts': []}

    def handle_data(self, value):
        if self.script is not None:
            self.script['parts'].append(value)

    def handle_endtag(self, tag):
        if tag == 'script' and self.script is not None:
            self.scripts.append(self.script)
            self.script = None


def version(*args):
    run = subprocess.run(args, text=True, capture_output=True)
    return run.stdout.strip() if run.returncode == 0 else 'unavailable'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('html', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    html = args.html.resolve(strict=True)
    root = html.parent
    source = html.read_bytes()
    parsed = HTMLAssets()
    parsed.feed(source.decode('utf-8'))
    checks = []
    remote = []
    checked_scripts = set()
    for ref in parsed.refs:
        uri = urlsplit(ref['url'])
        if uri.scheme or uri.netloc:
            if uri.scheme not in ('data', 'blob'):
                remote.append(ref)
            continue
        if not uri.path:
            continue
        asset = (root / unquote(uri.path).lstrip('/')).resolve()
        in_root = asset.is_relative_to(root)
        exists = in_root and asset.is_file()
        checks.append({'name': 'local_asset', 'asset': ref['url'], 'pass': exists,
                       'detail': 'outside project root' if not in_root else None})
        if exists and ref['tag'] == 'script' and asset not in checked_scripts:
            checked_scripts.add(asset)
            run = subprocess.run(['node', '--check', str(asset)], text=True, capture_output=True)
            checks.append({'name': 'external_script_syntax', 'asset': ref['url'],
                           'pass': run.returncode == 0, 'detail': run.stderr.strip() or None})
    for index, script in enumerate(parsed.scripts, 1):
        attrs = script['attributes']
        kind = attrs.get('type', '').lower()
        if 'src' in attrs or kind not in ('', 'module', 'text/javascript', 'application/javascript'):
            continue
        mode = 'module' if kind == 'module' else 'commonjs'
        run = subprocess.run(['node', '--check', '--input-type=' + mode],
                             input=''.join(script['parts']), text=True, capture_output=True)
        checks.append({'name': 'inline_script_syntax', 'script': index,
                       'pass': run.returncode == 0, 'detail': run.stderr.strip() or None})
    commit = subprocess.run(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True, capture_output=True)
    result = {
        'ok': all(check['pass'] for check in checks),
        'mode': 'Static HTML asset and JavaScript syntax checks; project JavaScript is not executed',
        'html': str(html),
        'html_sha256': hashlib.sha256(source).hexdigest(),
        'commit': commit.stdout.strip() if commit.returncode == 0 else None,
        'runtimes': {'node': version('node', '--version'), 'python': sys.version.split()[0]},
        'checks': checks,
        'remote_references_not_fetched': remote,
        'limits': ['Does not inspect dynamically constructed asset URLs',
                   'Does not test rendering, input, audio, storage, or gameplay',
                   'A passing baseline does not validate a newer transferred checkout'],
    }
    text = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + '\n', encoding='utf-8')
    print(text)
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
