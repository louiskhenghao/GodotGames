#!/usr/bin/env python3
"""Read-only release gate. A playtest export is not proof of store readiness."""
import argparse, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def inspect():
 config=json.loads((ROOT/'config/release.json').read_text());presets=(ROOT/'export_presets.cfg').read_text();issues=[]
 for field in ['publisher','support_email','website','privacy_url']:
  if not config.get(field):issues.append('Configure '+field+' in config/release.json')
 if 'com.example.' in presets:issues.append('Replace example Android/iOS bundle identifiers with registered IDs')
 if 'application/app_store_team_id=""' in presets:issues.append('Configure Apple team, signing and distribution/notarization')
 issues.append('Verify Android release keystore, AAB signing and Play App Signing')
 for provider in ['ads_provider','iap_provider']:
  if config.get(provider) in ['',None,'unavailable','mock']:issues.append('Integrate and validate native '+provider+'; mock purchases/ads are playtest-only')
 issues.extend(['Complete device QA on Android and iOS, including pause/resume, restore purchases, offline and low-memory behavior','Publish privacy policy; complete Apple privacy and Google Play Data safety disclosures for actual SDK behavior','Verify ad consent/age handling, reward callbacks and store receipt validation with production product IDs'])
 versions=re.findall(r'(?:version/name|application/short_version)="([^"]+)"',presets)
 if any(v!=config['version'] for v in versions):issues.append('Version mismatch between release config and export presets')
 for field in ['assets/creatures/sources.json','assets/creatures/Monsters-LICENSE.txt','assets/creatures/Animals-LICENSE.txt','assets/creatures/Cyberpunk-LICENSE.txt','assets/licenses/Godot-LICENSE.txt','assets/licenses/Godot-COPYRIGHT.txt','assets/fonts/OFL-BarlowCondensed.txt']:
  if not (ROOT/field).is_file():issues.append('Missing bundled attribution: '+field)
 return config,issues
def main():
 p=argparse.ArgumentParser();p.add_argument('--strict',action='store_true');args=p.parse_args();config,issues=inspect()
 print(f"RingRush {config['version']} ({config['build']}) / {'NOT STORE READY' if issues else 'CHECKS PASSED'}")
 for issue in issues:print(' - '+issue)
 if args.strict and issues:raise SystemExit(1)
if __name__=='__main__':main()
