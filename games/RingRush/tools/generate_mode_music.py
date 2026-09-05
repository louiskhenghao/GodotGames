"""Nine original mode scores, with distinct harmony, meter, rhythm and instrumentation."""
from pathlib import Path
import json, subprocess, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];SR=22050
SCORES={
 'fight':dict(title='Corner Bell',style='funk breaks / brass stabs',bpm=128,meter=4,roots=[38,34,41,36],bass=[0,0,7,10,12,7,3,5],lead=[12,15,19,17,15,12,10,7],sound='brass',kick=[0,1.5,2,3.25],snare=[1,3],hats=.5),
 'blitz':dict(title='Overdrive',style='drum and bass / acid pluck',bpm=174,meter=4,roots=[40,43,38,35],bass=[0,12,0,7,0,3,10,7],lead=[24,19,22,15,19,12,14,22],sound='acid',kick=[0,1.75,2.5],snare=[1,3],hats=.25),
 'survival':dict(title='After Hours',style='trip hop / glass keys',bpm=108,meter=4,roots=[36,44,39,46],bass=[0,0,7,0,10,7,3,0],lead=[19,14,15,10,12,7,14,3],sound='bell',kick=[0,2.75],snare=[2],hats=.5),
 'onslaught':dict(title='Iron March',style='industrial march / metallic percussion',bpm=136,meter=4,roots=[36,37,43,41],bass=[0,0,1,0,7,0,5,1],lead=[0,7,1,0,12,7,5,1],sound='metal',kick=[0,1,2,3],snare=[1.5,3.5],hats=.25),
 'hell':dict(title='Redline',style='heavy power riffs / double kick',bpm=148,meter=4,roots=[38,41,36,37],bass=[0,0,12,0,1,0,7,6],lead=[0,7,12,1,0,6,7,0],sound='fuzz',kick=[0,.25,.5,1.5,2,2.25,2.5,3.5],snare=[1,3],hats=.5),
 'bossrush':dict(title='Main Event',style='cinematic brass / timpani',bpm=118,meter=4,roots=[33,29,40,32],bass=[0,0,7,7,12,12,7,11],lead=[12,19,24,23,19,15,14,11],sound='horn',kick=[0,2],snare=[3],hats=1),
 'ladder':dict(title='Summit',style='pentatonic plucks / hand drums',bpm=124,meter=4,roots=[38,43,45,41],bass=[0,7,12,7,0,7,10,7],lead=[12,14,19,21,24,21,19,14],sound='wood',kick=[0,1.5,2.75],snare=[1,2.5,3.5],hats=.5),
 'classic':dict(title='Last Bell',style='arcade pulse / bright arpeggios',bpm=150,meter=4,roots=[41,38,46,48],bass=[0,12,7,12,0,12,7,19],lead=[12,16,19,24,19,16,14,19],sound='chip',kick=[0,2,2.75],snare=[1,3],hats=.25),
 'rift':dict(title='Beyond the Gate',style='dark waltz / spectral bells',bpm=96,meter=3,roots=[36,37,44,31],bass=[0,7,12,0,1,7],lead=[24,13,19,12,25,18],sound='ghost',kick=[0],snare=[2],hats=1),
}
def hz(note):return 440*2**((note-69)/12)
def generate(name,cfg,index):
 rng=np.random.default_rng(701+index);beat=60/cfg['bpm'];meter=cfg['meter'];n=round(16*meter*beat*SR);mix=np.zeros((n,2))
 def add(at,duration,fn,gain=.3,pan=0):
  t=np.arange(round(duration*SR))/SR;v=fn(t)*gain;ids=(round(at*SR)+np.arange(len(t)))%n
  mix[ids,0]+=v*(1-pan*.35);mix[ids,1]+=v*(1+pan*.35)
 def noise(t):return rng.normal(0,.5,len(t))
 def voice(t,f,kind):
  attack=np.minimum(1,t*120)
  if kind=='brass':v=np.sin(2*np.pi*f*t)+.4*np.sin(4*np.pi*f*t)+.16*np.sin(6*np.pi*f*t);env=np.exp(-t*7)
  elif kind=='acid':v=np.sin(2*np.pi*f*t+2.5*np.sin(2*np.pi*f*t)*np.exp(-t*12));env=np.exp(-t*15)
  elif kind=='bell':v=np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*f*2.76*t);env=np.exp(-t*5)
  elif kind=='metal':v=np.sin(2*np.pi*f*t)*np.sin(2*np.pi*f*1.414*t)+.3*np.sin(2*np.pi*f*3.12*t);env=np.exp(-t*13)
  elif kind=='fuzz':v=np.tanh(2*(np.sin(2*np.pi*f*t)+.6*np.sin(2*np.pi*f*1.5*t)));env=np.exp(-t*8)
  elif kind=='horn':v=np.sin(2*np.pi*f*t)+.25*np.sin(4*np.pi*f*t)+.10*np.sin(6*np.pi*f*t);attack=np.minimum(1,t*18);env=np.exp(-t*2)
  elif kind=='wood':v=np.sin(2*np.pi*f*t)+.38*np.sin(2*np.pi*f*2*t)*np.exp(-t*30);env=np.exp(-t*9)
  elif kind=='chip':v=sum(np.sin(2*np.pi*f*k*t)/k for k in [1,3,5,7]);env=np.exp(-t*11)
  else:v=np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*f*1.006*t)+.13*np.sin(2*np.pi*f*2.71*t);attack=np.minimum(1,t*35);env=np.exp(-t*2.5)
  return v*env*attack
 for bar in range(16):
  base=bar*meter*beat;root=cfg['roots'][(bar//2)%4]
  for b in cfg['kick']:
   add(base+b*beat,.4,lambda t:np.sin(2*np.pi*(45*t+1.5*(1-np.exp(-40*t))))*np.exp(-t*16),.66)
  for b in cfg['snare']:
   if name in ['ladder','bossrush','rift']:
    add(base+b*beat,.35,lambda t:np.sin(2*np.pi*105*t+2*np.exp(-t*30))*np.exp(-t*12)+noise(t)*np.exp(-t*45)*.18,.45)
   else:add(base+b*beat,.19,lambda t:(noise(t)+.18*np.sin(2*np.pi*182*t))*np.exp(-t*20),.36)
  for i,b in enumerate(np.arange(0,meter,cfg['hats'])):
   add(base+b*beat,.045,lambda t:noise(t)*np.exp(-t*90),.08 if i%2 else .12,(-1)**i*.75)
  for i in range(meter*2):
   interval=cfg['bass'][i%len(cfg['bass'])];f=hz(root+interval)
   add(base+i*.5*beat,.28 if name!='rift' else .7,lambda t,f=f:(np.sin(2*np.pi*f*t)+.17*np.sin(4*np.pi*f*t))*np.minimum(1,t*150)*np.exp(-t*9),.37)
  # Mode-specific phrasing: sustained fanfares, syncopated stabs, arps, or slow bells.
  positions={'horn':[0,1.5,3],'ghost':[0,1,2.5],'brass':[.5,1.75,2.5,3.5],'bell':[.75,2.5],'metal':[0,.75,1.5,2.25,3],'wood':[0,.75,1.5,2,3.5]}.get(cfg['sound'],list(np.arange(0,meter,.5)))
  for j,b in enumerate(positions):
   note=root+cfg['lead'][(j+bar*2)%len(cfg['lead'])]
   if cfg['sound'] in ['metal','fuzz']:note+=12
   f=hz(note);duration=1.2 if cfg['sound'] in ['horn','ghost'] else .5
   add(base+b*beat,duration,lambda t,f=f:voice(t,f,cfg['sound']),.18 if cfg['sound']!='fuzz' else .13,(-1)**j*.35)
  if name in ['bossrush','rift','survival']:
   for interval in [12,15 if name!='bossrush' else 19,22]:
    f=hz(root+interval)
    add(base,meter*beat,lambda t,f=f:np.sin(2*np.pi*f*t)*(np.sin(np.pi*t/(meter*beat))**2),.045,(-1)**interval*.7)
  if bar%4==3:
   for j in range(4):
    f=150-j*18
    add(base+(meter-1+j*.25)*beat,.2,lambda t,f=f:(np.sin(2*np.pi*f*t)+noise(t)*.12)*np.exp(-t*20),.12+j*.02,(-1)**j*.5)
 mix+=np.roll(mix[:,::-1],round(beat*.75*SR),axis=0)*(.2 if name=='rift' else .1)
 mix=np.tanh(mix);mix-=mix.mean(axis=0);mix*=.86/np.max(np.abs(mix))
 path=ROOT/'assets'/('music_'+name+'.wav')
 with wave.open(str(path),'wb') as output:output.setparams((2,2,SR,0,'NONE',''));output.writeframes((mix*32767).astype('<i2').tobytes())
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-c:a','vorbis','-strict','-2','-q:a','5',str(path.with_suffix('.ogg'))],check=True)
 path.unlink();print(name,cfg['title'],cfg['style'])
for index,(name,cfg) in enumerate(SCORES.items()):generate(name,cfg,index)
(ROOT/'docs/mode-music.json').write_text(json.dumps(SCORES,indent=2))
