from pathlib import Path
import subprocess,re,json
root=Path('C:/Cravera/game/Forest/audio/creatures')
rows=[]
for p in root.glob('*.ogg'):
 result=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af','volumedetect','-f','null','-'],capture_output=True,text=True)
 vals={k:float(v) for k,v in re.findall(r'(mean_volume|max_volume): (-?[0-9.]+)',result.stderr)}
 rows.append({'file':p.name,**vals})
print(json.dumps(rows,indent=1))
