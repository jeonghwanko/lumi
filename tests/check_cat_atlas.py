#!/usr/bin/env python3
"""Numerical source-mask analysis only; no bitmap edits or browser rendering."""
import argparse, hashlib, json, subprocess
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('project',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();root=a.project.resolve()
node="const vm=require('node:vm'),fs=require('node:fs');const c={window:{}};vm.createContext(c);vm.runInContext(fs.readFileSync(process.argv[1],'utf8'),c);console.log(JSON.stringify(c.window.PuzzleTileTheme));"
theme=json.loads(subprocess.check_output(['node','-e',node,str(root/'puzzle-theme.js')],text=True))
source=root/theme['atlas']['sourcePath'];raw=source.read_bytes();expected='309463da9235aea05d8cc0398508c3d02e2b0a534a2258f3940bd14558ad47c6'
assert hashlib.sha256(raw).hexdigest()==expected,'Approved source changed'
image=Image.open(source);assert image.mode=='RGB' and image.size==(1536,1024)
rgb=np.asarray(image).astype(np.int16);checks=[]
for label,f in zip(theme['labels'],theme['atlas']['frames']):
 x,y,w,h,r=[f[k] for k in ['x','y','width','height','radius']];pad=8
 sub=rgb[y-pad:y+h+pad,x-pad:x+w+pad]
 yy,xx=np.indices(sub.shape[:2]);px=xx-pad+.5;py=yy-pad+.5
 qx=np.abs(px-w/2)-(w/2-r);qy=np.abs(py-h/2)-(h/2-r)
 distance=np.sqrt(np.maximum(qx,0)**2+np.maximum(qy,0)**2)+np.minimum(np.maximum(qx,qy),0)-r
 spread=sub.max(axis=2)-sub.min(axis=2);perimeter=np.abs(distance)<=2
 minimum=int(spread[perimeter].min());assert minimum>=60,(label,minimum)
 neutral=spread<45;seen=np.zeros(neutral.shape,dtype=bool);queue=deque();hh,ww=neutral.shape
 for row in range(hh):
  for col in [0,ww-1]:
   if neutral[row,col] and not seen[row,col]:seen[row,col]=True;queue.append((row,col))
 for col in range(ww):
  for row in [0,hh-1]:
   if neutral[row,col] and not seen[row,col]:seen[row,col]=True;queue.append((row,col))
 while queue:
  row,col=queue.popleft()
  for dr,dc in ((1,0),(-1,0),(0,1),(0,-1)):
   rr,cc=row+dr,col+dc
   if 0<=rr<hh and 0<=cc<ww and neutral[rr,cc] and not seen[rr,cc]:seen[rr,cc]=True;queue.append((rr,cc))
 intrusion=int(np.count_nonzero(seen&(distance<=0)));assert intrusion==0,(label,intrusion)
 checks.append({'label':label,'frame':f,'min_rgb_spread_in_2px_perimeter':minimum,'exterior_neutral_pixels_inside_clip':intrusion,'pass':True})
result={'ok':True,'mode':'Source pixel/mask geometry analysis; no browser QA or bitmap edits','source_sha256':expected,'checks':checks,'limits':['Actual Canvas/Pixi rendering and touch QA deferred at user request','White eye highlights inside tiles are intentionally preserved','Native-resolution mask caching must precede downsampling']}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False,indent=2))
