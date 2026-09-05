"""Original 16-bar electronic fight loops: drums, syncopated bass, stabs, riffs and fills."""
from pathlib import Path
import numpy as np
import wave,subprocess
P=Path(__file__).resolve().parents[1]/'assets';sr=22050;rng=np.random.default_rng(120)
def hz(n):return 440*2**((n-69)/12)
for name,bpm in [('menu',104),('fight',144),('street',138),('hell',156)]:
 beat=60/bpm;bars=16;N=round(sr*beat*bars*4);mix=np.zeros((N,2),np.float64)
 def add(at,duration,signal,gain=1,pan=0):
  t=np.arange(round(duration*sr))/sr;v=signal(t)*gain;indices=(round(at*sr)+np.arange(len(t)))%N
  mix[indices,0]+=v*(1-pan*.3);mix[indices,1]+=v*(1+pan*.3)
 def noise(t):return rng.uniform(-1,1,len(t))
 for bar in range(bars):
  root=[38,38,41,36,38,45,41,36][bar%8];drop=bar in [7,15];menu=name=='menu'
  for b in range(4):
   at=(bar*4+b)*beat
   if not drop or b<2:
    add(at,.34,lambda t:np.sin(2*np.pi*(47*t+2.2*(1-np.exp(-45*t))))*np.exp(-15*t),.85 if not menu else .45)
   if b%2:
    add(at,.20,lambda t:(noise(t)*.7+np.sin(2*np.pi*184*t)*.3)*np.exp(-23*t),.36)
    add(at+.013,.12,lambda t:noise(t)*np.exp(-40*t),.12,.5)
   for step in range(4 if name=='hell' else 2):
    sub=step/(4 if name=='hell' else 2)
    add(at+sub*beat,.055,lambda t:(noise(t)-np.roll(noise(t),1))*np.exp(-85*t),.06 if step%2 else .095,(-1)**step*.7)
   if not menu and b in [1,3]:add(at+beat*.5,.16,lambda t:noise(t)*np.exp(-24*t),.10,-.5)
   for sub,interval in [(0,0),(.5,0),(.75,7 if b==3 else 0)]:
    f=hz(root+interval)
    add(at+sub*beat,beat*.24,lambda t,f=f:(np.sin(2*np.pi*f*t)+.22*np.sin(4*np.pi*f*t)+.09*np.sin(6*np.pi*f*t))*np.minimum(1,t*180)*np.exp(-12*t),.48 if not menu else .23)
  # Percussive minor chord stabs on offbeats; gaps leave room for punches.
  for pos in [0.5,1.75,2.5,3.5]:
   def chord(t):
    v=sum(np.sin(2*np.pi*hz(root+12+k)*t)+.18*np.sin(2*np.pi*hz(root+12+k)*t*2) for k in [0,3,7])
    return np.tanh(v)*np.minimum(1,t*160)*np.exp(-t*9)
   add((bar*4+pos)*beat,beat*.55,chord,.16 if not menu else .10,(-1)**bar*.35)
  pattern=[12,19,15,12,22,19,15,10] if name!='hell' else [12,12,19,15,24,22,19,15]
  if bar%4 in [1,2,3]:
   for step,interval in enumerate(pattern):
    f=hz(root+12+interval)
    add((bar*4+step*.5)*beat,.20,lambda t,f=f:np.sin(2*np.pi*f*t+1.4*np.sin(2*np.pi*f*2*t))*np.exp(-t*14)*np.minimum(1,t*180),.09,(-1)**step*.75)
  if drop:
   for step in range(8):
    add((bar*4+2+step*.25)*beat,.11,lambda t:noise(t)*np.exp(-35*t),.09+step*.014,(-1)**step*.4)
  if bar%4==0:add(bar*4*beat,.7,lambda t:noise(t)*np.exp(-6*t),.085,.6)
 # Mild saturation and cross-delay; circular indexing gives sample-exact looping.
 mix+=np.roll(mix[:,::-1],round(beat*.75*sr),axis=0)*.10
 mix=np.tanh(mix*1.08);mix-=mix.mean(axis=0);mix*=.88/np.max(np.abs(mix))
 out=P/f'music_{name}.wav'
 with wave.open(str(out),'wb') as f:f.setparams((2,2,sr,0,'NONE',''));f.writeframes((mix*32767).astype('<i2').tobytes())
 subprocess.run(['/opt/homebrew/bin/ffmpeg','-v','error','-y','-i',str(out),'-c:a','vorbis','-strict','-2','-q:a','5',str(out.with_suffix('.ogg'))],check=True)
 out.unlink();print(name,bpm,round(N/sr,2),'seconds')
