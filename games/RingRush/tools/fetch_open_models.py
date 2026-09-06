#!/usr/bin/env python3
"""Fetch only the eight selected CC0 files; refuse changed upstream content."""
import argparse, hashlib, json, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=ROOT.parents[1]/'builds/model-source');args=p.parse_args()
 args.output.mkdir(parents=True,exist_ok=True)
 for asset in json.loads((ROOT/'assets/creatures/sources.json').read_text())['assets']:
  target=args.output/(asset['id']+'.gltf')
  data=target.read_bytes() if target.exists() else urllib.request.urlopen(asset['download'],timeout=60).read()
  if hashlib.sha256(data).hexdigest()!=asset['sha256']:raise ValueError('Upstream content changed: '+asset['id'])
  json.loads(data);target.write_bytes(data);print(asset['id'],len(data),'verified')
if __name__=='__main__':main()
