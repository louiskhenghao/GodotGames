"""Original short impact/exhale and landing Foley, with no external samples."""
from pathlib import Path
from array import array
import wave, math, random
root=Path(__file__).resolve().parents[1]/'assets'
rng=random.Random(20260905);rate=22050
for name,duration in [('hurt',.32),('fall',.48)]:
 samples=array('h');smooth=0.0
 for i in range(int(duration*rate)):
  t=i/rate;n=rng.uniform(-1,1);smooth=.91*smooth+.09*n
  if name=='hurt':
   v=.43*math.sin(2*math.pi*(125*t-70*t*t))*math.exp(-t*15)+smooth*1.5*math.sin(math.pi*t/duration)*math.exp(-t*8)
  else:
   v=.55*math.sin(2*math.pi*(62*t-27*t*t))*math.exp(-t*14)+smooth*.8*math.exp(-t*9)+n*.12*math.exp(-t*60)
  samples.append(round(max(-1,min(1,v))*.72*32767))
 with wave.open(str(root/(name+'.wav')),'wb') as f:
  f.setparams((1,2,rate,0,'NONE',''));f.writeframes(samples.tobytes())
print('Generated hurt.wav and fall.wav')
