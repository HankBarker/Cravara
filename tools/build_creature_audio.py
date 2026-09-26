from pathlib import Path
import subprocess,json,sys
# `python build_creature_audio.py parasaur ossuar` builds only those species
# (the rest keep their files byte for byte).
only=set(sys.argv[1:])
root=Path('C:/Cravera');src=root/'art/forest-pass6/audio-source';out=root/'game/Forest/audio/creatures'
monster=src/'monster/monster_sfx_pack_2'
# Recorded CC0 source transformations: pitch/formant character, filtering, restraint.
# (species: pitch, highpass, lowpass, variants for ambient/attack/hurt: seconds
# into the chicken recording for birds, else monster clip numbers)
profiles={'dodo':(1.08,320,6200,[0.95,4.45,7.2]),'raptor':(0.72,550,4200,[1.2,4.6,7.05]),'rex':(0.48,35,1800,[1,4,9]),'stego':(0.76,65,2300,[2,5,8]),'trike':(0.94,100,3000,[11,12,14]),'longneck':(0.57,45,1200,[13,15,16]),
 # Pass 10: the allosaurus (a lighter rex growl), the lystrosaurus (small
 # snorts) and the alpha (a raptor's shriek, much deeper).
 'allo':(0.62,50,2200,[3,6,10]),'lystro':(1.3,180,4200,[7,17,6]),'alpha':(0.52,160,3400,[2.1,5.1,6.4]),
 # Pass 11: the parasaur (hooting calls, higher than the longneck's) and
 # Ossuar, the Buried King (hollow, bony, deeper than the rex).
 'parasaur':(0.82,90,2600,[13,15,16]),'ossuar':(0.42,40,1500,[9,1,4])}
birds=['dodo','raptor','alpha']
manifest=[]
for species,(pitch,low,high,variants) in profiles.items():
 if only and species not in only: continue
 for cue,value in zip(['ambient','attack','hurt'],variants):
  bird=species in birds;file=src/'chicken.mp3' if bird else monster/f'monster-{value}.wav'
  filters=[]
  if bird: filters+= [f'atrim=start={value}:duration=0.9','asetpts=PTS-STARTPTS']
  filters += ['aresample=44100',f'asetrate={int(44100*pitch)}','aresample=22050',f'highpass=f={low}',f'lowpass=f={high}']
  if species=='rex': filters+=['aecho=0.8:0.45:58|113:0.22|0.12']
  if species=='longneck': filters+=['aecho=0.7:0.35:95:0.18']
  if species in ['allo','alpha']: filters+=['aecho=0.8:0.4:48|96:0.18|0.1']
  if species=='parasaur': filters+=['aecho=0.8:0.5:40|85:0.3|0.18']
  if species=='ossuar': filters+=['aecho=0.85:0.55:80|170|300:0.3|0.2|0.12']
  filters+= ['afade=t=in:d=0.025','loudnorm=I=-18:TP=-3:LRA=7','alimiter=limit=0.7:level=false']
  dest=out/f'{species}-{cue}.ogg'
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(file),'-af',','.join(filters),'-ac','1','-ar','22050','-c:a','libvorbis','-q:a','4',str(dest)],check=True)
  subprocess.run(['ffmpeg','-v','error','-i',str(dest),'-f','null','-'],check=True)
  probe=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_format','-of','json',str(dest)]))
  manifest.append({'file':dest.name,'source':file.name,'pitch':pitch,'duration':float(probe['format']['duration'])})
# Roars (pass 10): the big hunters' full-throated roar on locking on, layered
# from two slowed, deepened clips with a long echo tail: rex (the ground
# shakes), allosaurus (shorter, rougher), alpha (a shriek that drops into a
# growl). Each: [(source, start, seconds, pitch, delay ms, gain)], lowpass, echo.
roars={
 'rex':([(monster/'monster-1.wav',0,1.0,0.46,0,1.0),(monster/'monster-9.wav',0,0.52,0.4,180,0.8),(monster/'monster-4.wav',0,0.58,0.5,420,0.6)],1600,'aecho=0.85:0.55:70|140|260:0.3|0.2|0.12'),
 'allo':([(monster/'monster-3.wav',0,0.5,0.55,0,1.0),(monster/'monster-10.wav',0,0.36,0.5,160,0.8)],2200,'aecho=0.8:0.45:60|130:0.22|0.12'),
 'alpha':([(src/'chicken.mp3',4.4,0.9,0.5,0,1.0),(monster/'monster-17.wav',0,0.35,0.52,260,0.9),(monster/'monster-7.wav',0,0.45,0.48,480,0.7)],3000,'aecho=0.8:0.5:55|120|240:0.25|0.16|0.1'),
 # Pass 11: the parasaur's trumpet through its crest; the Buried King's roar.
 'parasaur':([(monster/'monster-13.wav',0,0.9,0.72,0,1.0),(monster/'monster-15.wav',0,0.7,0.78,120,0.7)],2400,'aecho=0.85:0.6:60|130|240:0.35|0.22|0.12'),
 'ossuar':([(monster/'monster-9.wav',0,0.7,0.36,0,1.0),(monster/'monster-1.wav',0,0.9,0.34,220,0.9),(monster/'monster-17.wav',0,0.4,0.5,480,0.6)],1400,'aecho=0.9:0.6:90|200|380:0.35|0.25|0.15'),
}
for species,(layers,high,echo) in roars.items():
 if only and species not in only: continue
 dest=out/f'{species}-roar.ogg'
 args=['ffmpeg','-v','error','-y'];chains=[];labels=[]
 for i,(file,start,length,pitch,delay,gain) in enumerate(layers):
  args+=['-i',str(file)]
  chains.append(f'[{i}:a]atrim=start={start}:duration={length},asetpts=PTS-STARTPTS,aresample=44100,asetrate={int(44100*pitch)},aresample=44100,adelay={delay}|{delay},volume={gain}[l{i}]')
  labels.append(f'[l{i}]')
 graph=';'.join(chains)+';'+''.join(labels)+f'amix=inputs={len(layers)}:normalize=0,highpass=f=30,lowpass=f={high},{echo},afade=t=in:d=0.03,loudnorm=I=-16:TP=-2:LRA=9,alimiter=limit=0.8:level=false[out]'
 args+=['-filter_complex',graph,'-map','[out]','-ac','1','-ar','22050','-c:a','libvorbis','-q:a','4',str(dest)]
 subprocess.run(args,check=True)
 subprocess.run(['ffmpeg','-v','error','-i',str(dest),'-f','null','-'],check=True)
 probe=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_format','-of','json',str(dest)]))
 manifest.append({'file':dest.name,'source':'+'.join(Path(l[0]).name for l in layers),'pitch':layers[0][3],'duration':float(probe['format']['duration'])})
if only:
 # Merge into the manifest the other species already have.
 old=[e for e in json.loads((out/'manifest.json').read_text()) if e['file'] not in {m['file'] for m in manifest}]
 manifest=old+manifest
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('CREATURE_AUDIO_DECODE %d/%d passed'%(len(manifest),len(manifest)))
