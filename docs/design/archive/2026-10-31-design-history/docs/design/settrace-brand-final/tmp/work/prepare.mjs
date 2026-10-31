import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const require=createRequire(import.meta.url);
const modules=process.env.SETTRACE_NODE_MODULES ?? 'D:/ProgramData/DevCache/Node/node_modules';
const sharp=require(path.join(modules,'sharp'));
const {GlobalFonts,convertSVGTextToPath,createCanvas}=require(path.join(modules,'@napi-rs/canvas'));
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const icon=path.join(root,'settrace-icon');
const logo=path.join(root,'logo');
await fs.mkdir(logo,{recursive:true});
await fs.mkdir(path.join(root,'exports/png'),{recursive:true});

const theta=13*Math.PI/180;
const weight=10.8, pitch=21, gap=9, top=28, bottom=72;
const length=(bottom-top)/Math.cos(theta);
const halfGapY=(weight+gap)*Math.cos(theta)/2;
const upperEnd=50-halfGapY, lowerStart=50+halfGapY;
const fullArea=weight*length+Math.PI*(weight/2)**2;
const brokenArea=weight*(length-weight-gap)+2*Math.PI*(weight/2)**2;
// The open third track carries less area. Its calculated mass compensation
// restores the foreground's horizontal centroid, while keeping the 21-unit grid.
const offset=pitch*(fullArea-brokenArea)/(2*fullArea+brokenArea);
const centers=[29+offset,50+offset,71+offset];
const q=n=>Number(n.toFixed(5));
const capsule=(cx,y0,y1,scale=1)=>{
  const point=y=>[cx+(50-y)*Math.tan(theta),y];
  const p=point(y0),r=point(y1),radius=weight/2;
  const nx=Math.cos(theta)*radius,ny=Math.sin(theta)*radius;
  const coord=(a,b)=>`${q(a*scale)} ${q(b*scale)}`;
  return `M${coord(p[0]+nx,p[1]+ny)}L${coord(r[0]+nx,r[1]+ny)}A${q(radius*scale)} ${q(radius*scale)} 0 0 1 ${coord(r[0]-nx,r[1]-ny)}L${coord(p[0]-nx,p[1]-ny)}A${q(radius*scale)} ${q(radius*scale)} 0 0 1 ${coord(p[0]+nx,p[1]+ny)}Z`;
};
const paths=[capsule(centers[0],top,bottom),capsule(centers[1],top,bottom),capsule(centers[2],top,upperEnd),capsule(centers[2],lowerStart,bottom)];
const svgPaths=(color,scale=1)=>{
  const data=scale===1?paths:[capsule(centers[0],top,bottom,scale),capsule(centers[1],top,bottom,scale),capsule(centers[2],top,upperEnd,scale),capsule(centers[2],lowerStart,bottom,scale)];
  return data.map(d=>`<path d="${d}" fill="${color}"/>`).join('');
};
const metrics={name:'SetTrace / Set Rhythm',version:'1.0',date:'2026-10-15',tracks:3,components:4,angleDegrees:13,weight,pitch,clearIntertrackGap:q(pitch*Math.cos(theta)-weight),clearInterruptionGap:gap,opticalTranslationX:q(offset),foregroundCentroid:[50,50],markBounds:[q(centers[0]-(bottom-50)*Math.tan(theta)-weight/2),top-weight/2,q(centers[2]+(50-top)*Math.tan(theta)+weight/2),bottom+weight/2],palette:{brand:'#153C34',onBrand:'#FFFFFF',uiAccent:'#087F6B',uiAccentDark:'#5DD9B6',soft:'#E2F2ED',ink:'#111518'},paths,source:'../../../logo-exploration-abcde/a-three-line/deep-green-study/deep-green-icon.preview.svg'};
await fs.writeFile(path.join(root,'tmp/work/geometry.json'),JSON.stringify(metrics,null,2));

const svgDoc=(body,width=100,height=100,extra='')=>`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" ${extra}>${body}</svg>`;
const title='<title>SetTrace — 组间节奏</title>';
for(const [suffix,color] of [['','#153C34'],['-white','#FFFFFF'],['-black','#111518']]){
  const content=svgDoc(title+svgPaths('currentColor'),100,100,`style="color:${color}" role="img" aria-label="SetTrace 组间节奏标记"`);
  await fs.writeFile(path.join(logo,`settrace-symbol${suffix}.svg`),content);
  await sharp(Buffer.from(content)).resize(1024,1024).png().toFile(path.join(logo,`settrace-symbol${suffix}.png`));
}

// Segoe UI Semibold is an installed local typeface. Only its shaped outlines
// are exported; no font file is redistributed and no external font is fetched.
GlobalFonts.registerFromPath('C:/Windows/Fonts/seguisb.ttf','SetTraceWordmark');
const ctx=createCanvas(800,180).getContext('2d');
ctx.font='64px SetTraceWordmark';
ctx.letterSpacing='-0.45px';
const wordWidth=ctx.measureText('SetTrace').width;
const wordSvg=svgDoc(`<text x="0" y="72" font-family="SetTraceWordmark" font-size="64" letter-spacing="-.45" fill="#153C34">SetTrace</text>`,450,100,'width="450" height="100"');
const converted=convertSVGTextToPath(wordSvg).toString();
if(/<text\b/.test(converted)||!/<path\b/.test(converted))throw new Error('Wordmark outline conversion failed');
await fs.writeFile(path.join(root,'tmp/work/wordmark-outlined.svg'),converted);
let wordBody=converted.slice(converted.indexOf('>',converted.indexOf('<svg'))+1,converted.lastIndexOf('</svg>'));
wordBody=wordBody.replaceAll('#153c34','currentColor').replaceAll('#153C34','currentColor');
let glyphIndex=0;
wordBody=wordBody.replace(/transform="translate\(([\d.]+) ([\d.]+)\)"/g,(_match,x,y)=>`transform="translate(${q(Number(x)-0.45*glyphIndex++)} ${y})"`);
await fs.writeFile(path.join(root,'tmp/work/wordmark-body.svg'),wordBody);
const horizontalWidth=Math.ceil(110+wordWidth+22);
for(const [suffix,color] of [['','#153C34'],['-white','#FFFFFF'],['-black','#111518']]){
  const body=svgPaths('currentColor')+`<g transform="translate(110 0)">${wordBody}</g>`;
  const lockup=svgDoc(title+body,horizontalWidth,100,`style="color:${color}" role="img" aria-label="SetTrace 横向 Logo"`);
  await fs.writeFile(path.join(logo,`settrace-lockup${suffix}.svg`),lockup);
  await sharp(Buffer.from(lockup)).resize({width:2000}).png().toFile(path.join(logo,`settrace-lockup${suffix}.png`));
}
const stackedWidth=260,wordScale=210/wordWidth;
const stack=svgDoc(title+`<g transform="translate(55 2) scale(1.5)">${svgPaths('currentColor')}</g><g transform="translate(25 122) scale(${wordScale})">${wordBody}</g>`,stackedWidth,210,'style="color:#153C34" role="img" aria-label="SetTrace 竖向 Logo"');
await fs.writeFile(path.join(logo,'settrace-stacked.svg'),stack);
await sharp(Buffer.from(stack)).resize({width:1200}).png().toFile(path.join(logo,'settrace-stacked.png'));

const scale=10.24;
const twoPaths=[capsule(centers[0],top,bottom,scale),capsule(centers[1],top,bottom,scale)];
const intervalPaths=[capsule(centers[2],top,upperEnd,scale),capsule(centers[2],lowerStart,bottom,scale)];
const components=[{id:'continuous-sets',layer:'continuous-sets',format:'svg',source_vector:'../../../../logo-exploration-abcde/a-three-line/a-three-line.svg',source_provenance:'generated-in-task',alignment_basis:'Two original continuous tracks retained; 13-degree analytical geometry and optical mass centering.',spec_constraints:['two filled capsules','equal 10.8-unit normal width','no stroke, no filters, no raster']},{id:'interval-set',layer:'interval-set',format:'svg',source_provenance:'generated-in-task',alignment_basis:'Original open third track retained with symmetric caps and a 9-unit clear interval.',spec_constraints:['two disconnected filled capsules are intentional','no cover layer or true carved counter','gap is the existing background between separate pieces']}];
const spec={name:'SetTraceFinal',canvas:1024,radius:241,target_platforms:['Android'],deliverable_type:'source-package',source_reference:'User selected the deep-green A three-track concept in this conversation; original vector preserved as settrace-icon.origin.svg.',brief:'Finalize the selected SetTrace training-rhythm identity: two continuous diagonal capsules, one interrupted track, white on #153C34. Refine optical alignment and small-size gaps without changing the concept.',semantic_review:{status:'exact-enough',identity_risk:'low',basis:'Original in-task concept selected by the user; explicit authorization to optimize its geometry and finish the design. No third-party mark or bitmap reconstruction.',route:'semantic-svg',notes:'Selected identity retained; deliberate finalization changes are 13-degree exact angle, 10.8-unit width, 9-unit interruption and calculated optical centering.'},source_analysis:{fidelity_target:'Preserve the selected deep-green three-track rhythm, round terminals and interrupted right track.',identity_risk:'low',route:'semantic-svg',must_preserve:['exactly three track positions and four disconnected capsules','two full tracks and an interrupted third track','white foreground on deep green #153C34','round caps and uniform parallel lean'],must_not_add:['fourth track','gradient, shadow, bevel, outline, text or extra accent color','background in the transparent foreground','round mask in the square source canvas'],components,acceptance_checks:['source foreground has four closed filled capsule contours','SVG/PNG square source and rounded preview are both provided','64, 48, 32, 24 and 16 px are visually inspected','circular crop does not touch the symbol','vector layer geometry and material checks pass']},fill:{solid:'extended-srgb:0.082353,0.235294,0.203922,1.000000'},layers:[{name:'background',svg:'<rect width="1024" height="1024" fill="#153C34"/>',composer:{include:false}},{name:'continuous-sets',svg:twoPaths.map(d=>`<path d="${d}" fill="#FFFFFF"/>`).join(''),composer:{format:'svg',reason:'Two intentional continuous capsule contours remain editable as filled vectors.'}},{name:'interval-set',svg:intervalPaths.map(d=>`<path d="${d}" fill="#FFFFFF"/>`).join(''),composer:{format:'svg',reason:'The two disconnected interval capsules retain independent clean boundaries.'}}]};
await fs.writeFile(path.join(icon,'tmp/work/spec.json'),JSON.stringify(spec,null,2));
await fs.copyFile(path.resolve(root,'../logo-exploration-abcde/a-three-line/deep-green-study/deep-green-icon.preview.svg'),path.join(icon,'settrace-icon.origin.svg'));
await fs.writeFile(path.join(root,'tmp/work/typography.json'),JSON.stringify({font:'Segoe UI Semibold',source:'C:/Windows/Fonts/seguisb.ttf',delivery:'SVG outlines, no font dependency',fontSize:64,letterSpacing:-0.45,wordWidth,horizontalWidth},null,2));
console.log(JSON.stringify({root,metrics:{weight,pitch,gap,offset:q(offset),angle:13},wordWidth,horizontalWidth,outlinedText:true}));
