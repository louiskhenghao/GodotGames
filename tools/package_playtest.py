#!/usr/bin/env python3
"""Add player instructions and attribution, then package the static Web build."""
from pathlib import Path
import hashlib, shutil, zipfile
ROOT=Path(__file__).resolve().parents[1]
def package():
 web=ROOT/'builds/web';mac=ROOT/'builds/mac/RingRush.zip'
 notices={
  'README-试玩.md':ROOT/'docs/playtest.md',
  'LICENSES/Model-Credits.md':ROOT/'assets/fighters/CREDITS.md',
  'LICENSES/KayKit-CC0.txt':ROOT/'assets/fighters/kaykit/LICENSE.txt',
  'LICENSES/Barlow-OFL.txt':ROOT/'assets/fonts/OFL-BarlowCondensed.txt',
  'LICENSES/Godot-LICENSE.txt':ROOT/'assets/licenses/Godot-LICENSE.txt',
  'LICENSES/Godot-COPYRIGHT.txt':ROOT/'assets/licenses/Godot-COPYRIGHT.txt',
 }
 for name,source in notices.items():
  target=web/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
 # Repackage entries without duplicates on repeated runs; preserve executable attributes.
 temp=mac.with_suffix('.packaging.zip')
 with zipfile.ZipFile(mac) as source,zipfile.ZipFile(temp,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as dest:
  for info in source.infolist():
   if info.filename not in notices:dest.writestr(info,source.read(info.filename))
  for name,path in notices.items():dest.write(path,name)
 temp.replace(mac)
 target=ROOT/'builds/RingRush-Web-Playtest.zip'
 with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as dest:
  for path in sorted(web.rglob('*')):
   if path.is_file() and not path.name.endswith('.import') and not path.name.startswith('.'):
    dest.write(path,path.relative_to(web))
 lines=[]
 for artifact in [mac,target]:
  with zipfile.ZipFile(artifact) as archive:assert archive.testzip() is None
  digest=hashlib.sha256(artifact.read_bytes()).hexdigest()
  lines.append(digest+'  '+str(artifact.relative_to(ROOT/'builds')))
  print(artifact.name,round(artifact.stat().st_size/1024**2,1),'MiB',digest)
 (ROOT/'builds/SHA256SUMS.txt').write_text('\n'.join(lines)+'\n')
 shutil.copyfile(ROOT/'docs/playtest.md',ROOT/'builds/PLAYTEST.md')
if __name__=='__main__':package()
