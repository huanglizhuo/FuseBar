"""Original deterministic 34-second synth score; no samples or third-party music."""
import math, wave
import numpy as np
from pathlib import Path
sr=48000; duration=34; n=sr*duration
mix=np.zeros((n,2),dtype=np.float64)
rng=np.random.default_rng(6812443369)
def place(sig,start,amp=.1,pan=0):
 i=int(start*sr); length=min(len(sig),n-i)
 if length<=0:return
 mix[i:i+length,0]+=sig[:length]*amp*math.sqrt((1-pan)/2)
 mix[i:i+length,1]+=sig[:length]*amp*math.sqrt((1+pan)/2)
def note(midi,start,length=.44,amp=.075,pan=0):
 t=np.arange(int(length*sr))/sr;f=440*2**((midi-69)/12)
 sig=(np.sin(2*np.pi*f*t)+.22*np.sin(2*np.pi*2*f*t))
 env=(1-np.exp(-t*250))*np.exp(-t*7)*np.clip((length-t)/.05,0,1)
 place(sig*env,start,amp,pan)
# 120 BPM. Four-chord progression, clean plucks and restrained percussion.
chords=[[62,66,69,73],[59,62,66,69],[55,59,62,66],[57,61,64,69]]
for b in range(68):
 start=b*.5;ch=chords[(b//8)%4]
 if start<32:
  for j in range(2):note(ch[(b+j)%4]+12,start+j*.25,amp=.065,pan=(-.25 if j==0 else .25))
  if b%2==0:
   t=np.arange(int(.23*sr))/sr
   sig=np.sin(2*np.pi*(48*t+65*(1-np.exp(-t*35))/35))*np.exp(-t*22)*(1-np.exp(-t*350))
   place(sig,start,.19)
  if b%2==1:
   t=np.arange(int(.12*sr))/sr;noise=rng.standard_normal(len(t));sig=np.diff(noise,prepend=0)*np.exp(-t*42)*np.minimum(t*500,1)
   place(sig,start,.024, .15)
  if b%4==0:note(ch[0]-12,start,1.2,.14)
# restrained rising transitions aligned with fusion and UI entrance
for start in [1.8,5.3,9.2,20.8,27.6]:
 t=np.arange(int(.58*sr))/sr;env=np.sin(np.pi*t/.58)**2
 sig=(np.sin(2*np.pi*(450*t+1250*t*t))*.32+rng.standard_normal(len(t))*.025)*env
 place(sig,start,.028,-.1)
for m in [62,66,69,74]:note(m,31.9,2.0,.10)
# no clipped sample; source score has authored tail, final mix handles fade
peak=np.max(np.abs(mix));mix*=.69/max(peak,.69)
Path('assets/audio').mkdir(parents=True,exist_ok=True)
with wave.open('assets/audio/fusebar-original-score.wav','wb') as w:
 w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes((mix*32767).astype('<i2').tobytes())
print(f'Original 34s stereo score; peak {20*np.log10(np.max(np.abs(mix))):.1f} dBFS')
