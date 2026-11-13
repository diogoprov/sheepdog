// Intro figure of the sheepdog app (inst/app/intro.png).
//
// Draws one simulated night of 30-minute recordings and what each sampling
// mode, occasion and stratum of select_clips() picks from it. The draw logic
// mirrors select_clips() for one site and one species; the scores are made up.
//
// Usage, from the root of the repository (needs Node and Playwright):
//   node data-raw/intro-figure/fig.js   # writes intro.svg next to this script
//   node data-raw/intro-figure/png.js   # renders it to inst/app/intro.png
const fs = require('fs');
const path = require('path');
function rng(seed){let a=seed>>>0;return function(){a=(a+0x6D2B79F5)>>>0;let t=a;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296;};}
function shuffle(arr,r){const a=arr.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;}
const NF=14, NM=30, fileHour=f=>17+Math.floor(f/2);
// same simulated recordings as the explorer; night 1 only
const DATA=(function(){const r=rng(42);const base={17:.25,18:1.5,19:2.1,20:1.4,21:.7,22:.35,23:.2};const nightMult=[1,.55,1.3];
const poisson=lam=>{let L=Math.exp(-lam),k=0,p=1;do{k++;p*=r();}while(p>L);return k-1;};const out=[];
for(let n=0;n<3;n++){const nights=[];for(let f=0;f<NF;f++){const quiet=r()<.18;const chorus=quiet?.04:.3+r()*1.6;const lam=base[fileHour(f)]*nightMult[n]*chorus;const mins=[];let run=r()<.5?1:0;
for(let m=0;m<NM;m++){if(r()<.12)run=1-run;const k=Math.min(20,poisson(lam*(run?1.6:.35)));const s=[];for(let i=0;i<k;i++){const real=r()<.72;s.push(+(real?.42+.57*Math.pow(r(),.7):.1+.32*r()*r()).toFixed(3));}
if(r()<.07)s.push(+(.1+.35*r()*r()).toFixed(3));mins.push(s);}nights.push(mins);}out.push(nights);}return out;})()[0];

const THR=0.5;
const occKey=(occ,f,m)=>occ==='file'?`${f}`:`${f}-${m}`;
function select(st){
  const res={drawn:new Set(),cand:new Set(),clips:{},nclips:0,strata:{},p:[]};
  const addClip=(f,m,c)=>{const k=`${f}-${m}`;res.clips[k]=(res.clips[k]||0)+c;res.nclips+=c;};
  if(st.mode==='top'){
    const g={};for(let f=0;f<NF;f++)for(let m=0;m<NM;m++)DATA[f][m].forEach(s=>{if(s<0.1)return;(g[fileHour(f)]||(g[fileHour(f)]=[])).push({s,f,m});});
    Object.values(g).forEach(a=>{a.sort((x,y)=>y.s-x.s);a.slice(0,st.ntop).forEach(p=>addClip(p.f,p.m,1));});return res;}
  if(st.mode==='score_bands'){ // n_top predictions at random in each score band
    const B=st.breaks,P=B.slice(0,-1).map(()=>[]);
    for(let f=0;f<NF;f++)for(let m=0;m<NM;m++)DATA[f][m].forEach(s=>{for(let b=0;b<P.length;b++){const last=b===P.length-1;if(s>=B[b]&&(s<B[b+1]||(last&&s<=B[b+1]))){P[b].push({f,m});break;}}});
    const r=rng(st.seed);P.forEach(a=>{shuffle(a,r).slice(0,st.ntop).forEach(p=>addClip(p.f,p.m,1));res.p.push(Math.min(st.ntop,a.length)/a.length);});return res;}
  if(st.mode==='random_detections'){
    const S={};for(let f=0;f<NF;f++)for(let m=0;m<NM;m++){if(!DATA[f][m].some(s=>s>=st.thr))continue;const k=occKey(st.occ,f,m);if(res.cand.has(k))continue;res.cand.add(k);
      const sk=st.strata==='night_hour'?String(fileHour(f)):'all';(S[sk]||(S[sk]=[])).push(k);}
    const r=rng(st.seed);Object.keys(S).sort().forEach(sk=>{const t=shuffle(S[sk],r).slice(0,st.ntop);t.forEach(k=>res.drawn.add(k));res.p.push(Math.min(st.ntop,S[sk].length)/S[sk].length);res.strata[sk]=S[sk].length;});
    for(let f=0;f<NF;f++)for(let m=0;m<NM;m++){if(!res.drawn.has(occKey(st.occ,f,m)))continue;const c=DATA[f][m].filter(s=>s>=st.thr).length;if(c)addClip(f,m,c);}return res;}
  const all=[];for(let f=0;f<NF;f++)for(let m=0;m<NM;m++)all.push(occKey(st.occ,f,m));const u=[...new Set(all)];
  const n=Math.max(1,Math.round(st.frac*u.length));shuffle(u,rng(st.seed)).slice(0,n).forEach(k=>res.drawn.add(k));res.p=[n/u.length];res.total=u.length;return res;}

// ---------- palette ----------
const C={bg:'#ffffff',ink:'#17202a',muted:'#5d6873',line:'#d6dbdb',panel:'#f5f7f6',empty:'#e7eae8',b1:'#cfd4d3',b2:'#aab1b2',
 s1:'#f6dc92',s2:'#efb04a',s3:'#d7772a',s4:'#9f441a',draw:'#1f5fbf',warn:'#9a5a00',warnbg:'#fff3d6'};
const F='Inter, "Helvetica Neue", Arial, sans-serif';
function fill(sc,thr){if(!sc.length)return C.empty;const mx=Math.max(...sc);if(thr!=null&&mx<thr)return mx<.3?C.b1:C.b2;return mx<.4?C.s1:mx<.6?C.s2:mx<.8?C.s3:C.s4;}
const esc=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;');
function text(x,y,str,o={}){const {size=13,weight=400,color=C.ink,anchor='start',family=F,italic=false}=o;
  return `<text x="${x}" y="${y}" font-family='${family}' font-size="${size}" font-weight="${weight}" fill="${color}" text-anchor="${anchor}"${italic?' font-style="italic"':''}>${str}</text>`;}
function para(x,y,str,width,o={}){const size=o.size||13,lh=o.lh||size*1.38;const cw=size*0.53;const max=Math.floor(width/cw);
  const words=str.split(' ');const lines=[];let cur='';words.forEach(w=>{const plain=(cur+' '+w).replace(/<[^>]+>/g,'');if(plain.trim().length>max&&cur){lines.push(cur.trim());cur=w;}else cur+=' '+w;});if(cur.trim())lines.push(cur.trim());
  return {svg:lines.map((l,i)=>text(x,y+i*lh,l,o).replace(/\*\*(.+?)\*\*/g,'<tspan font-weight="700">$1</tspan>')).join(''),h:lines.length*lh};}

let pid=0;
// block: one night, 14 rows x 30 minutes
function block(x0,y0,cell,st,res,opt={}){
  const thr=opt.thr!==undefined?opt.thr:THR, gap=cell>10?1.4:1;let s='';const id='h'+(pid++);
  s+=`<defs><pattern id="${id}" width="3.2" height="3.2" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="1.3" height="3.2" fill="${C.draw}"/></pattern></defs>`;
  for(let f=0;f<NF;f++){
    if(f%2===0){const fs=cell>10?11:9.5;s+=text(x0-6,y0+(f+1)*cell-gap/2+fs*0.36,`${fileHour(f)}h`,{size:fs,color:C.muted,anchor:'end'});}
    for(let m=0;m<NM;m++)s+=`<rect x="${x0+m*cell}" y="${y0+f*cell}" width="${cell-gap}" height="${cell-gap}" rx="${cell>10?2:1.2}" fill="${fill(DATA[f][m],thr)}"/>`;}
  if(!st)return s;
  if(st.mode==='random_detections'){ // strata brackets
    const groups=st.strata==='night_hour'?[...Array(7)].map((_,i)=>[2*i,2*i+2]):[[0,14]];
    groups.forEach(([a,b],i)=>{const x=x0-26,ya=y0+a*cell+1.5,yb=y0+b*cell-1.5-gap;s+=`<path d="M${x+4} ${ya}H${x}V${yb}H${x+4}" fill="none" stroke="${i%2?C.draw:C.muted}" stroke-width="1.4"/>`;});}
  for(let f=0;f<NF;f++){const y=y0+f*cell;
    if(st.occ==='file'){const k=`${f}`;
      if(res.drawn.has(k)){if(st.mode==='random_recordings')s+=`<rect x="${x0}" y="${y}" width="${NM*cell-gap}" height="${cell-gap}" fill="url(#${id})" opacity=".6"/>`;
        s+=`<rect x="${x0-1}" y="${y-1}" width="${NM*cell-gap+2}" height="${cell-gap+2}" rx="2.5" fill="none" stroke="${C.draw}" stroke-width="2"/>`;}
      else if(res.cand.has(k))s+=`<rect x="${x0-.6}" y="${y-.6}" width="${NM*cell-gap+1.2}" height="${cell-gap+1.2}" rx="2.5" fill="none" stroke="${C.draw}" stroke-width=".9" stroke-dasharray="3 2.5"/>`;}
    else for(let m=0;m<NM;m++){if(!res.drawn.has(`${f}-${m}`))continue;const x=x0+m*cell;
      if(st.mode==='random_recordings')s+=`<rect x="${x}" y="${y}" width="${cell-gap}" height="${cell-gap}" fill="url(#${id})" opacity=".65"/>`;
      s+=`<rect x="${x-1}" y="${y-1}" width="${cell-gap+2}" height="${cell-gap+2}" rx="2" fill="none" stroke="${C.draw}" stroke-width="2"/>`;}
    if(st.mode!=='random_recordings')for(let m=0;m<NM;m++)if(res.clips[`${f}-${m}`])s+=`<circle cx="${x0+m*cell+(cell-gap)/2}" cy="${y+(cell-gap)/2}" r="${cell>10?2.6:2.1}" fill="${C.ink}" stroke="#fff" stroke-width=".9"/>`;}
  return s;}

// ---------- layout ----------
const W=2020,H=1022;let out=[];
out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`);
out.push(`<rect width="${W}" height="${H}" fill="${C.bg}"/>`);
out.push(text(40,58,'How sheepdog picks the clips you review',{size:30,weight:700}));
out.push(text(40,86,'One site, one species, one night of 30-minute recordings from 17:00 to midnight (simulated scores). Threshold 0.50 throughout (score_bands uses score bands instead).',{size:15,color:C.muted}));

// Panel A
const ax=40,ay=120,aw=560,ah=H-160;
out.push(`<rect x="${ax}" y="${ay}" width="${aw}" height="${ah}" rx="14" fill="${C.panel}"/>`);
out.push(text(ax+24,ay+40,'The recordings',{size:20,weight:700}));
const cell=13,bx=ax+64,by=ay+86;
out.push(text(bx,by-12,'1\'',{size:11,color:C.muted}));out.push(text(bx+29*cell+cell/2,by-12,'30\'',{size:11,color:C.muted,anchor:'middle'}));
out.push(block(bx,by,cell,null,null));
// annotations
const bw=NM*cell, bh=NF*cell;
out.push(`<path d="M${bx+bw+10} ${by}h6v${cell-1.4}h-6" fill="none" stroke="${C.ink}" stroke-width="1.2"/>`);
out.push(text(bx+bw+22,by+11,'1 row = 1 file',{size:12,weight:700}));out.push(text(bx+bw+22,by+26,'30 minutes',{size:12,color:C.muted}));
out.push(`<rect x="${bx+3*cell-1.5}" y="${by+5*cell-1.5}" width="${cell+1.6}" height="${cell+1.6}" rx="3" fill="none" stroke="${C.ink}" stroke-width="1.6"/>`);
out.push(`<path d="M${bx+3*cell+cell/2} ${by+6*cell+1}V${by+bh+22}" stroke="${C.ink}" stroke-width="1.1"/>`);
out.push(text(bx+3*cell-4,by+bh+38,'1 square = 1 minute',{size:12,weight:700}));
out.push(`<path d="M${bx+bw+10} ${by}h3v${bh}h-3" fill="none" stroke="${C.muted}" stroke-width="1"/>`);
out.push(text(bx+bw+22,by+bh/2+4,'14 files',{size:12,color:C.muted}));out.push(text(bx+bw+22,by+bh/2+19,'one night',{size:12,color:C.muted}));
// legend
let ly=by+bh+78;
out.push(text(ax+24,ly,'Square colour: highest BirdNET score in that minute',{size:13,weight:700}));ly+=20;
const leg=[[C.empty,'no prediction'],[C.b2,'predictions, all below the threshold'],];
leg.forEach(([c,l],i)=>{out.push(`<rect x="${ax+24}" y="${ly+i*22}" width="14" height="14" rx="2" fill="${c}"/>`);out.push(text(ax+46,ly+i*22+12,l,{size:12.5}));});
ly+=44;[C.s1,C.s2,C.s3,C.s4].forEach((c,i)=>out.push(`<rect x="${ax+24+i*16}" y="${ly}" width="14" height="14" rx="2" fill="${c}"/>`));
out.push(text(ax+94,ly+12,'detections ≥ threshold, from 0.5 to 1',{size:12.5}));
ly+=40;
out.push(text(ax+24,ly,'Marks in the panels',{size:13,weight:700}));ly+=20;
out.push(`<circle cx="${ax+31}" cy="${ly+7}" r="3" fill="${C.ink}"/>`);out.push(text(ax+46,ly+12,'a clip to review (3-s prediction)',{size:12.5}));ly+=22;
out.push(`<rect x="${ax+24}" y="${ly}" width="14" height="14" rx="2" fill="none" stroke="${C.draw}" stroke-width="2"/>`);out.push(text(ax+46,ly+12,'drawn occasion',{size:12.5}));ly+=22;
out.push(`<rect x="${ax+24}" y="${ly}" width="14" height="14" rx="2" fill="none" stroke="${C.draw}" stroke-width="1" stroke-dasharray="3 2.5"/>`);out.push(text(ax+46,ly+12,'candidate occasion, not drawn',{size:12.5}));ly+=22;
out.push(`<defs><pattern id="lh" width="3.2" height="3.2" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="1.3" height="3.2" fill="${C.draw}"/></pattern></defs><rect x="${ax+24}" y="${ly}" width="14" height="14" rx="2" fill="url(#lh)" opacity=".7"/>`);out.push(text(ax+46,ly+12,'listened to whole, detections or not',{size:12.5}));ly+=22;
out.push(`<path d="M${ax+31} ${ly+1}h-4v13h4" fill="none" stroke="${C.muted}" stroke-width="1.4"/>`);out.push(text(ax+46,ly+12,'stratum of the draw',{size:12.5}));
ly+=44;
const defs=[['Occasion','the unit counted as detected or not: a whole **file** or one **minute**.'],
 ['Threshold','score from which a prediction is a detection. It sets the candidates of random_detections.'],
 ['Strata','groups in which random_detections draws n_top occasions, e.g. each hour of the night.']];
defs.forEach(([k,v])=>{out.push(text(ax+24,ly,k,{size:13,weight:700}));const p=para(ax+112,ly,v,aw-140,{size:12.5});out.push(p.svg);ly+=Math.max(22,p.h)+8;});

// Grid
const gx=640,gy=120,cw=318,gapx=12;
const colsX=i=>gx+30+i*(cw+gapx);
const heads=[['top','only the highest-scored clips'],['random_detections','clips from occasions drawn at random'],['random_recordings','random recordings, with or without detections'],['score_bands','random clips in each score band']];
heads.forEach(([h,s],i)=>{out.push(text(colsX(i)+8,gy+18,h,{size:17,weight:700}));out.push(text(colsX(i)+8,gy+38,s,{size:12.5,color:C.muted}));});
const rowY=r=>gy+56+r*300;
['Occasion = file (30 min)','Occasion = minute'].forEach((t,r)=>{const y=rowY(r)+120;out.push(`<text transform="translate(${gx+12} ${y}) rotate(-90)" font-family='${F}' font-size="14" font-weight="700" fill="${C.ink}" text-anchor="middle">${t}</text>`);});
function cellPanel(i,r,st,cap,warn){const x=colsX(i),y=rowY(r);const res=select(st);
  out.push(`<rect x="${x}" y="${y}" width="${cw}" height="290" rx="12" fill="${C.panel}"/>`);
  const c=9,x0=x+44,y0=y+16;out.push(block(x0,y0,c,st,res));
  let cy=y0+NF*c+24;const capt=typeof cap==='function'?cap(res):cap;const p=para(x+14,cy,capt,cw-28,{size:12.5});out.push(p.svg);cy+=p.h;
  if(warn){const w=typeof warn==='function'?warn(res):warn;if(w){const q=para(x+26,cy+12,w,cw-46,{size:12,color:C.warn});out.push(`<rect x="${x+12}" y="${cy-4}" width="${cw-24}" height="${q.h+12}" rx="6" fill="${C.warnbg}"/>`);out.push(q.svg);}}
  return res;}
const SEED=2026;
cellPanel(0,0,{mode:'top',occ:'file',ntop:2},r=>`**Only the 2 highest scores** of each hour are kept, wherever they fall: **${r.nclips}** clips. For retraining and calibration.`,'Not a random sample: do not use it for false-positive rates.');
cellPanel(0,1,{mode:'top',occ:'minute',ntop:2},r=>`Same **${r.nclips}** clips: still only the top scores. In top, the occasion only labels each clip.`);
cellPanel(1,0,{mode:'random_detections',occ:'file',thr:THR,ntop:2,strata:'night_hour',seed:SEED},r=>`n_top 2 per night × hour: **${r.drawn.size}** of ${r.cand.size} files drawn. **Every detection ≥ 0.50** inside a drawn file is a clip: **${r.nclips}** clips.`,r=>r.p.every(p=>p===1)?'Each hour holds only 2 files, so all are taken (p = 1): no real draw.':'');
cellPanel(1,1,{mode:'random_detections',occ:'minute',thr:THR,ntop:2,strata:'night_hour',seed:SEED},r=>`n_top 2 per night × hour: **${r.drawn.size}** of ${r.cand.size} minutes drawn. **Every detection ≥ 0.50** inside a drawn minute is a clip: **${r.nclips}** clips.`);
cellPanel(2,0,{mode:'random_recordings',occ:'file',frac:0.15,thr:THR,seed:SEED},r=>`Fraction 0.15: **${r.drawn.size}** of 14 files drawn at random. Each file should be listened to in full (30 min), irrespective of the classifier's outputs.`);
cellPanel(2,1,{mode:'random_recordings',occ:'minute',frac:0.02,thr:THR,seed:SEED+3},r=>`Fraction 0.02: **${r.drawn.size}** of 420 minutes drawn at random, with or without detections.`);
const BANDS=[0.1,0.4,0.7,1];
cellPanel(3,0,{mode:'score_bands',occ:'file',ntop:2,breaks:BANDS,seed:SEED},r=>`**2 clips per score band** (0.1–0.4, 0.4–0.7, 0.7–1), drawn at random among all predictions: **${r.nclips}** clips. For thresholds and calibration curves across the score range.`,'Chosen by score: no false-positive rate, and crywolf drops them.');
cellPanel(3,1,{mode:'score_bands',occ:'minute',ntop:2,breaks:BANDS,seed:SEED},r=>`Same **${r.nclips}** clips: the bands, not the occasion, set the draw. Each clip carries its inclusion probability (drawn / predictions of its band).`);

// Strata strip
const sy=rowY(2)-4;
{const ax2=colsX(1)+cw/2, a0=rowY(1)+290+4, a1=sy+50-4;
 out.push(`<defs><marker id="ah" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10z" fill="${C.draw}"/></marker></defs>`);
 out.push(`<path d="M${ax2} ${a0}V${a1}" stroke="${C.draw}" stroke-width="2.2" fill="none" marker-end="url(#ah)"/>`);}
out.push(text(gx+30,sy+16,'Strata spread the random_detections draw',{size:17,weight:700}));
out.push(text(gx+30,sy+36,'Minute occasions, n_top 2. Same candidates, different groups.',{size:12.5,color:C.muted}));
function strip(i,st,cap){const w=(3*cw+2*gapx-gapx)/2;const x=gx+30+i*(w+gapx),y=sy+50;const res=select(st);
  out.push(`<rect x="${x}" y="${y}" width="${w}" height="${H-40-y}" rx="12" fill="${C.panel}"/>`);
  out.push(block(x+44,y+16,8,st,res));
  const p=para(x+44+NM*8+18,y+30,typeof cap==='function'?cap(res):cap,w-NM*8-80,{size:12.5});out.push(p.svg);return res;}
strip(0,{mode:'random_detections',occ:'minute',thr:THR,ntop:2,strata:'night_hour',seed:SEED},r=>`**night × hour** (7 strata): 2 minutes from every hour, ${r.drawn.size} in all. Quiet hours are sampled as much as the chorus.`);
strip(1,{mode:'random_detections',occ:'minute',thr:THR,ntop:2,strata:'night',seed:SEED},r=>`**night** (1 stratum): only 2 minutes for the whole night, wherever they fall. Inclusion p = 2 / ${r.cand.size}.`);
out.push('</svg>');
fs.writeFileSync(path.join(__dirname, 'intro.svg'), out.join('\n'));
console.log('ok', out.join('').length);
