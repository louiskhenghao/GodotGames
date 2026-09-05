#!/usr/bin/env python3
"""Create a new independent Godot project using only the reusable mobile core."""
import argparse,json,shutil
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('destination',type=Path);parser.add_argument('--name',default='Core Starter');args=parser.parse_args()
root=Path(__file__).resolve().parents[1];destination=args.destination.resolve()
if destination.exists():raise SystemExit('Destination already exists; choose a new empty path.')
shutil.copytree(root/'templates/core_starter',destination)
shutil.copytree(root/'addons/mobile_core',destination/'addons/mobile_core')
project=destination/'project.godot';project.write_text(project.read_text().replace('config/name="Core Starter"','config/name='+json.dumps(args.name)))
print(destination)
