"""Assemble CC0 Quaternius mesh + compatible clips; keep only animation buffers used.
Source models are unmodified geometrically. Run once after fetching source assets.
"""
import json,struct,copy
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'assets/fighters'
j=json.loads((p/'source/Superhero_Male_FullBody.gltf').read_text())
f=open(p/'source/UAL1_Standard.glb','rb');f.read(12);l,_=struct.unpack('<II',f.read(8));a=json.loads(f.read(l));l,_=struct.unpack('<II',f.read(8));raw=f.read(l)
out=bytearray((p/'source/Superhero_Male_FullBody.bin').read_bytes())
j['images']=[{'uri':'T_Superhero_Male_Dark.png'},{'uri':'T_Superhero_Male_Normal.png'},{'uri':'T_Eye_Brown.png'}]
j['textures']=[{'source':i} for i in range(3)]
j['materials']=[{'name':'Brows','pbrMetallicRoughness':{'baseColorFactor':[.08,.045,.025,1],'metallicFactor':0,'roughnessFactor':.8}}, {'name':'Eyes','pbrMetallicRoughness':{'baseColorTexture':{'index':2},'metallicFactor':0,'roughnessFactor':.3}}, {'name':'Skin','normalTexture':{'index':1},'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':.72}}]
names={n.get('name'):i for i,n in enumerate(j['nodes'])}
cache={}
def acc(i):
 if i in cache:return cache[i]
 ac=copy.deepcopy(a['accessors'][i]);v=copy.deepcopy(a['bufferViews'][ac['bufferView']]);b=v.get('byteOffset',0)
 while len(out)%4:out.append(0)
 offset=len(out);out.extend(raw[b:b+v['byteLength']]);v['buffer']=0;v['byteOffset']=offset
 ac['bufferView']=len(j['bufferViews']);j['bufferViews'].append(v);cache[i]=len(j['accessors']);j['accessors'].append(ac)
 return cache[i]
j['animations']=[]
for an in a['animations']:
 if an['name'] not in ['Idle_Loop','Jog_Fwd_Loop','Punch_Cross','Punch_Jab','Hit_Chest','Death01','Jump_Start','Jump_Land','Sword_Idle']:continue
 an=copy.deepcopy(an)
 for s in an['samplers']:s['input']=acc(s['input']);s['output']=acc(s['output'])
 an['channels']=[c for c in an['channels'] if a['nodes'][c['target']['node']].get('name') in names]
 for c in an['channels']:c['target']['node']=names[a['nodes'][c['target']['node']]['name']]
 j['animations'].append(an)
j['buffers']=[{'uri':'boxer.bin','byteLength':len(out)}]
(p/'boxer.bin').write_bytes(out);(p/'boxer.gltf').write_text(json.dumps(j,separators=(',',':')))
print('Prepared',len(out),'bytes,',len(j['animations']),'clips')
