"""Original deterministic layered synth score and combat SFX. No sampled songs.
Stereo 22.05 kHz, four-bar loops, 128 BPM combat / 96 BPM menu.
"""
import math, random, wave, struct, subprocess
from pathlib import Path
from array import array
P=Path(__file__).resolve().parents[1]/'assets';SR=22050;rng=random.Random(58)
def write(name, left, right=None):
 right=right or left
 peak=max(.7,max(abs(x) for x in left),max(abs(x) for x in right));gain=.82/peak
 pcm=array('h')
 for a,b in zip(left,right):pcm.extend([int(a*gain*32767),int(b*gain*32767)])
 with wave.open(str(P/(name+'.wav')),'wb') as f:f.setparams((2,2,SR,0,'NONE',''));f.writeframes(pcm.tobytes())
def note(n):return 440*2**((n-69)/12)
for kind in ['punch','slam','whoosh','electric','ko']:
 d={'punch':.20,'slam':.8,'whoosh':.65,'electric':.45,'ko':.8}[kind];L=[];noise=0
 for i in range(int(SR*d)):
  t=i/SR;r=rng.uniform(-1,1);noise=.85*noise+.15*r
  if kind=='punch':v=.65*math.sin(2*math.pi*(100*t-140*t*t))*math.exp(-t*27)+r*.23*math.exp(-t*65)
  elif kind=='slam':v=.7*math.sin(2*math.pi*(64*t-22*t*t))*math.exp(-t*7)+noise*1.3*math.exp(-t*5)+r*.1*math.exp(-t*80)
  elif kind=='whoosh':v=noise*math.sin(math.pi*t/d)*1.6+.12*math.sin(2*math.pi*(400*t-230*t*t))*math.sin(math.pi*t/d)
  elif kind=='electric':v=(math.sin(2*math.pi*160*t+6*math.sin(2*math.pi*47*t))*.4+r*.2)*math.exp(-t*8)
  else:v=(math.sin(2*math.pi*note(48)*t)+.5*math.sin(2*math.pi*note(55)*t)+.3*math.sin(2*math.pi*note(60)*t))*math.exp(-t*5)*.3
  L.append(v)
 write(kind,L)
for name in ['menu','fight','street']:
 bpm=96 if name=='menu' else 128;beat=60/bpm;duration=beat*32;N=round(SR*duration);L=array('f',[0])*N;R=array('f',[0])*N
 def add(start,dur,fn,vol=1,pan=0):
  offset=round(start*SR)
  for i in range(int(dur*SR)):
   t=i/SR;v=fn(t)*vol;j=(offset+i)%N;L[j]+=v*(1-pan*.4);R[j]+=v*(1+pan*.4)
 for bar,root in enumerate([38,38,41,36,38,45,41,36]):
  for b in range(4):
   pos=(bar*4+b)*beat
   if name!='menu' or b%2==0:
    add(pos,.27,lambda t: math.sin(2*math.pi*(48*t+2.3*(1-math.exp(-t*40))))*math.exp(-t*19),.65 if name!='menu' else .28)
   if b%2:
    add(pos,.17,lambda t:(rng.uniform(-1,1)*.7+math.sin(2*math.pi*185*t)*.3)*math.exp(-t*25),.32)
   for sub in range(2):add(pos+sub*beat/2,.045,lambda t:rng.uniform(-1,1)*math.exp(-t*90),.13,(-1)**sub*.6)
   for sub in [0,.5,.75]:
    freq=note(root)
    add(pos+sub*beat,beat*.22,lambda t,f=freq:(math.sin(2*math.pi*f*t)+.22*math.sin(2*math.pi*f*2*t))*min(1,t*180)*math.exp(-t*12),.34)
  for interval in [0,7,12]:
   freq=note(root+12+interval)
   add(bar*4*beat,4*beat,lambda t,f=freq:(math.sin(2*math.pi*f*t)+.14*math.sin(2*math.pi*(f*1.003)*t))*math.sin(math.pi*t/(4*beat)),.06,interval/12-.5)
  pattern=[12,19,15,22,19,15,12,10] if name!='street' else [12,12,15,19,22,19,15,7]
  for step,interval in enumerate(pattern):
   freq=note(root+12+interval)
   add((bar*4+step*.5)*beat,beat*.7,lambda t,f=freq:(math.sin(2*math.pi*f*t)+.25*math.sin(2*math.pi*f*3*t))*min(1,t*140)*math.exp(-t*11),.12 if name=='menu' else .10,(-1)**step*.7)
 # Short rhythmic delay wraps exactly across the loop boundary.
 oldL=L[:];oldR=R[:];delay=round(beat*.75*SR)
 for i in range(N):L[i]+=oldR[(i-delay)%N]*.14;R[i]+=oldL[(i-delay)%N]*.14
 write('music_'+name,L,R)
 subprocess.run(['/opt/homebrew/bin/ffmpeg','-v','error','-y','-i',str(P/('music_'+name+'.wav')),'-c:a','vorbis','-strict','-2','-q:a','4',str(P/('music_'+name+'.ogg'))],check=True)
 (P/('music_'+name+'.wav')).unlink()
print('Original score and five combat effects generated.')
