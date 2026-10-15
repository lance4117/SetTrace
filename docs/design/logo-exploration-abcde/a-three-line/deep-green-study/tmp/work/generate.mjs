import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const sharp = require('C:/Users/Lance/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const { geometry } = JSON.parse(await fs.readFile(path.join(out, '../tmp/work/design.json'), 'utf8'));
const ink='#111518', green='#087F6B', forest='#153C34', gray='#586970', line='#DBE3E5';
const text=(x,y,value,size=18,color=ink,attr='')=>`<text x="${x}" y="${y}" font-size="${size}" fill="${color}" ${attr}>${value}</text>`;
const mark=(x,y,size,color)=>`<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="0 0 100 100" style="color:${color}">${geometry}</svg>`;
const tile=(x,y,size,bg,fg='#FFFFFF')=>`<rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${size*.235}" fill="${bg}"/>${mark(x,y,size,fg)}`;
const cases=[
  {title:'石墨黑',color:ink,note:'先看轮廓，色彩最克制。'},
  {title:'深墨绿',color:forest,note:'保留深色质感，带一点绿色。'},
  {title:'界面青绿',color:green,note:'与主按钮同色，色彩更鲜明。'},
];
await fs.mkdir(path.join(out,'tmp/reports'),{recursive:true});
const cards=cases.map((c,i)=>{
  const x=64+i*499;
  return `<rect x="${x}" y="174" width="474" height="540" rx="20" fill="#FFFFFF" stroke="${line}"/>
    ${text(x+28,221,c.title,24,ink,'font-weight="600"')}
    ${text(x+28,253,c.color,14,gray,'letter-spacing="1"')}
    ${tile(x+107,289,260,c.color)}
    ${text(x+237,595,'SetTrace',23,ink,'text-anchor="middle" font-weight="500"')}
    ${text(x+237,660,c.note,17,gray,'text-anchor="middle"')}`;
}).join('');

const swatches=[{x:105,color:forest,label:'图标底色',code:forest},{x:350,color:green,label:'界面主色',code:green},{x:595,color:'#E2F2ED',label:'低强调底色',code:'#E2F2ED'}].map(c=>
  `<rect x="${c.x}" y="1021" width="52" height="52" rx="12" fill="${c.color}"/>
  ${text(c.x+67,1042,c.label,14,gray)}${text(c.x+67,1067,c.code,17,ink,'font-weight="500"')}`
).join('');
const states=[{label:'✓ 1',bg:'#E2F2ED',color:green},{label:'✓ 2',bg:'#E2F2ED',color:green},{label:'3',bg:'#FFFFFF',color:green,border:green},{label:'4',bg:'#F5F7F8',color:gray,border:line}].map((s,i)=>{
  const x=1044+i*105;
  return `<rect x="${x}" y="985" width="95" height="34" rx="7" fill="${s.bg}" ${s.border?`stroke="${s.border}"`:''}/>${text(x+47.5,1007,s.label,14,s.color,'text-anchor="middle" font-weight="500"')}`;
}).join('');
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1220" viewBox="0 0 1600 1220">
<rect width="1600" height="1220" fill="#F5F7F8"/>
<g font-family="Segoe UI, Microsoft YaHei, sans-serif">
  ${text(64,62,'SETTRACE / COLOR STUDY / ROUND 03',12,gray,'letter-spacing="2"')}
  ${text(64,116,'A · 三线标记',38,ink,'font-weight="650"')}
  ${text(320,114,'深墨绿底 + 白色标记',26,gray)}
  ${text(64,149,'相同图形、相同尺寸，只比较底色。',17,gray)}
  ${text(1385,64,'2026.10.15',14,gray)}
  ${cards}
  ${text(64,773,'从桌面图标到绿色界面',24,ink,'font-weight="600"')}
  ${text(1094,772,'下方为现有主题色的组件示意。',16,gray)}
  <rect x="64" y="805" width="1472" height="360" rx="20" fill="#FFFFFF" stroke="${line}"/>
  ${tile(105,855,128,forest)}
  ${text(268,911,'SetTrace',40,forest,'font-weight="600" letter-spacing="-1"')}
  ${text(268,948,'图标用深墨绿，界面用青绿强调当前操作。',19,gray)}
  ${swatches}
  ${text(105,1124,'共享绿色系，区分品牌标记与操作按钮的强调程度。',17,gray)}
  <path d="M966 839V1131" stroke="${line}"/>
  <rect x="1013" y="839" width="480" height="292" rx="17" fill="#F5F7F8"/>
  ${text(1044,876,'当前待练组',16,green,'font-weight="600"')}
  ${text(1040,951,'03',70,'#19262C','font-weight="650" letter-spacing="-3"')}
  ${text(1177,933,'共 4 组 · 已完成 2 组',16,gray)}
  ${states}
  <rect x="1044" y="1041" width="410" height="58" rx="14" fill="${green}"/>
  ${text(1249,1078,'完成本组',19,'#FFFFFF','text-anchor="middle" font-weight="600"')}
  ${text(64,1200,'图形保持三线版本不变 / 仅作配色与视觉衔接讨论',14,gray)}
  ${text(1278,1200,'概念效果图 · 尚未定稿',14,gray)}
</g></svg>`;
await fs.writeFile(path.join(out,'overview.svg'),svg);
await sharp(Buffer.from(svg)).png().toFile(path.join(out,'overview.png'));
const logo=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" style="color:${forest}" role="img" aria-labelledby="title"><title id="title">SetTrace A — 深墨绿三线标记</title>${geometry}</svg>`;
await fs.writeFile(path.join(out,'deep-green-mark.svg'),logo);
await sharp(Buffer.from(logo.replace('viewBox=', 'width="1024" height="1024" viewBox='))).png().toFile(path.join(out,'deep-green-mark.png'));
const preview=`<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 100 100">${tile(0,0,100,forest)}</svg>`;
await fs.writeFile(path.join(out,'deep-green-icon.preview.svg'),preview);
await sharp(Buffer.from(preview)).png().toFile(path.join(out,'deep-green-icon.preview.png'));
await fs.writeFile(path.join(out,'tmp/work/design.json'),JSON.stringify({status:'color-study',geometryUnchanged:true,source:'../tmp/work/design.json',foreground:'#FFFFFF',iconBackground:forest,uiAccent:green,cases},null,2));
await fs.writeFile(path.join(out,'README.md'),`# A 三线标记 · 深墨绿配色效果\n\n主方案为深墨绿 ${forest} 底、白色标记，与石墨黑 ${ink} 和界面青绿 ${green} 并排比较。\n\n- overview.png / overview.svg：配色对比和现有界面主题的组件衔接示意。\n- deep-green-mark.svg / .png：透明底墨绿标记。\n- deep-green-icon.preview.svg / .png：圆角桌面图标概念预览，不是平台图标包。\n\n图形直接复用上一轮 A 三线稿，未调整笔画、间距、断口、角度及占比。App 代码和主题未变动。\n`);
console.log(JSON.stringify({output:out,dimensions:[1600,1220],iconBackground:forest,geometryUnchanged:true}));
