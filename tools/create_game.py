#!/usr/bin/env python3
"""Export an independent starter; workspace.py new creates a monorepo game."""
import argparse
from pathlib import Path
from workspace import create

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('destination', type=Path)
parser.add_argument('--name', default='Core Starter')
args = parser.parse_args()
create(args.destination.resolve(), args.name)
