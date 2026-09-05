#!/usr/bin/env python3
"""Build both friend playtests using installed or explicitly supplied Godot templates."""
import argparse, json, re, subprocess, sys
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--godot',default='godot')
p.add_argument('--templates',type=Path,help='Folder containing matching web_nothreads_release.zip and macos.zip')
a=p.parse_args();root=Path(__file__).resolve().parents[1]
output=root.parents[1]/'builds'/root.name
for folder in ['web','mac']:(output/folder).mkdir(parents=True,exist_ok=True)
(output/'.gdignore').touch()
presets=root/'export_presets.cfg';original=presets.read_text()
configured=original
if a.templates:
 files=iter([a.templates.resolve()/'web_nothreads_release.zip',a.templates.resolve()/'macos.zip'])
 def template(match):
  path=next(files)
  if not path.is_file():raise FileNotFoundError(path)
  return 'custom_template/release='+json.dumps(str(path))
 configured=re.sub(r'custom_template/release="[^"]*"',template,original)
try:
 if configured!=original:presets.write_text(configured)
 for name,path in [('Web Playtest',output/'web/index.html'),('Mac Playtest',output/'mac/RingRush.zip')]:
  subprocess.run([a.godot,'--headless','--path',str(root),'--export-release',name,str(path)],check=True)
 subprocess.run([sys.executable,str(root/"tools/package_playtest.py")],check=True)
finally:
 if presets.read_text()==configured:presets.write_text(original)
