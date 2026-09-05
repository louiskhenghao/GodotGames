#!/usr/bin/env python3
"""Portable Godot monorepo entry point. Python standard library only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def projects():
    return sorted(p.parent for p in (ROOT / 'games').glob('*/game.json'))


def project(name):
    matches = [p for p in projects() if p.name == name]
    if not matches:
        raise ValueError(f'Unknown game: {name}. Run the list command.')
    return matches[0]


def inventory(folder):
    return {str(p.relative_to(folder)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(folder.rglob('*')) if p.is_file() and p.name != '.DS_Store'}


def sync(game, check=False):
    config = json.loads((ROOT / 'workspace.json').read_text())
    dependencies = json.loads((game / 'game.json').read_text())['packages']
    for name in dependencies:
        package = config['packages'][name]
        source = ROOT / package['source']
        target = game / package['mount']
        marker = target.parent / ('.' + target.name + '.sync.json')
        expected, actual = inventory(source), inventory(target)
        if check:
            if expected != actual:
                raise ValueError(f'{game.name}: {name} needs sync')
            continue
        if actual == expected:
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text(json.dumps(expected, indent=2) + '\n')
            continue
        previous = json.loads(marker.read_text()) if marker.exists() else {}
        if actual and actual != previous:
            raise ValueError(f'Local edits in {target}. Move your edits to {source} before syncing.')
        target.mkdir(parents=True, exist_ok=True)
        for relative in actual.keys() - expected.keys():
            (target / relative).unlink()
        for relative, digest in expected.items():
            if actual.get(relative) != digest:
                dest = target / relative
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source / relative, dest)
        marker.write_text(json.dumps(expected, indent=2) + '\n')
        print(f'{game.name}: synced {name} ({len(expected)} files)', flush=True)


def create(destination, name):
    if destination.exists():
        raise ValueError('Destination already exists; existing games are never overwritten.')
    shutil.copytree(ROOT / 'templates/core_starter', destination,
                    ignore=shutil.ignore_patterns('.godot', 'addons', '.gdignore'))
    config = destination / 'project.godot'
    config.write_text(config.read_text().replace('config/name="Core Starter"',
                                                'config/name=' + json.dumps(name)))
    (destination / 'game.json').write_text('{"packages": ["mobile-core"]}\n')
    sync(destination)
    print(destination)


def godot(binary, game, *args):
    subprocess.run([binary, '--path', str(game), *args], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('list')
    for name in ['sync', 'check']:
        commands.add_parser(name).add_argument('game', nargs='?')
    for name in ['run', 'editor', 'test', 'build']:
        sub = commands.add_parser(name)
        sub.add_argument('game')
        if name == 'test':
            sub.add_argument('--suite', help='One Godot test script basename')
            sub.add_argument('--native', action='store_true', help='Use a real rendering window')
        if name == 'build': sub.add_argument('--templates', type=Path)
    commands.add_parser('test-core')
    new = commands.add_parser('new')
    new.add_argument('name')
    args = parser.parse_args()
    if args.command == 'list':
        for game in projects(): print(game.name)
        return
    if args.command == 'new':
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]*', args.name):
            raise ValueError('Use a game folder name such as SpaceDash (letters, digits, _ or -).')
        create(ROOT / 'games' / args.name, args.name)
        return
    if args.command in ['sync', 'check']:
        for game in [project(args.game)] if args.game else projects():
            sync(game, check=args.command == 'check')
        print('All package mounts are current.', flush=True)
        return
    if args.command == 'test-core':
        game = ROOT / 'builds/core-test'
        if not game.exists(): create(game, 'Mobile Core Tests')
        sync(game)
        shutil.copytree(ROOT / 'packages/mobile-core/tests', game / 'tests', dirs_exist_ok=True)
        godot(args.godot, game, '--headless', '--editor', '--import')
        godot(args.godot, game, '--headless', '--script', 'res://tests/services_tests.gd')
        return
    game = project(args.game)
    sync(game)
    godot(args.godot, game, '--headless', '--editor', '--import')
    if args.command in ['run', 'editor']:
        godot(args.godot, game, *(['--editor'] if args.command == 'editor' else []))
    elif args.command == 'test':
        suites = sorted((game / 'tests').glob('*tests.gd'))
        if args.suite: suites = [s for s in suites if s.stem == args.suite]
        if not suites: raise ValueError('No matching test suite')
        for suite in suites:
            godot(args.godot, game, *([] if args.native else ['--headless']),
                  '--script', 'res://' + str(suite.relative_to(game)))
    elif args.command == 'build':
        script = game / 'tools/export_playtest.py'
        if not script.exists(): raise ValueError('This game needs its own export presets and build script.')
        subprocess.run([sys.executable, str(script), '--godot', args.godot] +
                       (['--templates', str(args.templates.resolve())] if args.templates else []), check=True)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
