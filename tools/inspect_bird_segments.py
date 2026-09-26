import subprocess,array,math
raw=subprocess.check_output(['ffmpeg','-v','error','-i','C:/Cravera/art/forest-pass6/audio-source/chicken.mp3','-f','s16le','-ac','1','-ar','16000','-'])
a=array.array('h',raw)
for i in range(29):
 s=a[i*8000:(i+1)*8000];r=(sum(float(x)**2 for x in s)/max(1,len(s)))**.5/32768
 print(i*.5,round(20*math.log10(max(r,1e-8)),1))
