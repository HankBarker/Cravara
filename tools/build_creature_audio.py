from pathlib import Path
import subprocess,json
root=Path('C:/Cravera');src=root/'art/forest-pass6/audio-source';out=root/'game/Forest/audio/creatures'
monster=src/'monster/monster_sfx_pack_2'
# Recorded CC0 source transformations: pitch/formant character, filtering, restraint.
profiles={'dodo':(1.08,320,6200,[0.95,4.45,7.2]),'raptor':(0.72,550,4200,[1.2,4.6,7.05]),'rex':(0.48,35,1800,[1,4,9]),'stego':(0.76,65,2300,[2,5,8]),'trike':(0.94,100,3000,[11,12,14]),'longneck':(0.57,45,1200,[13,15,16])}
manifest=[]
for species,(pitch,low,high,variants) in profiles.items():
 for cue,value in zip(['ambient','attack','hurt'],variants):
  bird=species in ['dodo','raptor'];file=src/'chicken.mp3' if bird else monster/f'monster-{value}.wav'
  filters=[]
  if bird: filters+= [f'atrim=start={value}:duration=0.9','asetpts=PTS-STARTPTS']
  filters += ['aresample=44100',f'asetrate={int(44100*pitch)}','aresample=22050',f'highpass=f={low}',f'lowpass=f={high}']
  if species=='rex': filters+=['aecho=0.8:0.45:58|113:0.22|0.12']
  if species=='longneck': filters+=['aecho=0.7:0.35:95:0.18']
  filters+= ['afade=t=in:d=0.025','loudnorm=I=-18:TP=-3:LRA=7','alimiter=limit=0.7:level=false']
  dest=out/f'{species}-{cue}.ogg'
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(file),'-af',','.join(filters),'-ac','1','-ar','22050','-c:a','libvorbis','-q:a','4',str(dest)],check=True)
  subprocess.run(['ffmpeg','-v','error','-i',str(dest),'-f','null','-'],check=True)
  probe=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_format','-of','json',str(dest)]))
  manifest.append({'file':dest.name,'source':file.name,'pitch':pitch,'duration':float(probe['format']['duration'])})
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('CREATURE_AUDIO_DECODE 18/18 passed')

