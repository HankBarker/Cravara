from pathlib import Path
import subprocess,json
root=Path('C:/Cravera')
files=list((root/'art/forest-pass6/audio-source/monster').rglob('monster-*.wav'))
for p in files:
 d=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_format','-of','json',str(p)]))['format']['duration']
 print(p.name,d,str(p))
