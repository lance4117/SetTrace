import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const sharp = require('C:/Users/Lance/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const ink = '#111518', secondary = '#586970', line = '#DBE3E5';
// Same lean, round caps and stroke weight as the first A concept.
// Three tracks, larger track spacing, and a slightly wider breathing gap.
const geometry = '<g fill="none" stroke="currentColor" stroke-width="11" stroke-linecap="round"><path d="M34 28 24 72 M55 28 45 72 M76 28 72.82 42 M69.18 58 66 72"/></g>';
const oldGeometry = '<g fill="none" stroke="currentColor" stroke-width="11" stroke-linecap="round"><path d="M28 28 18 72 M46 28 36 72 M64 28 54 72 M82 28 78.5 43.4 M75.5 56.6 72 72"/></g>';
const escape = s => s.replaceAll('&','&amp;').replaceAll('<','&lt;');
const text = (x,y,s,size=18,fill=ink,extra='') => `<text x="${x}" y="${y}" font-size="${size}" fill="${fill}" ${extra}>${escape(s)}</text>`;
const mark = (x,y,size,color=ink,old=false) => `<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="0 0 100 100" style="color:${color}">${old?oldGeometry:geometry}</svg>`;
const tile = (x,y,size,bg,fg,border=false) => `<rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${size*.235}" fill="${bg}" ${border?`stroke="${line}"`:''}/>${mark(x,y,size,fg)}`;

await fs.mkdir(out,{recursive:true});
await fs.mkdir(path.join(out,'tmp/reports'),{recursive:true});
const source = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-labelledby="title"><title id="title">SetTrace A — 三线组间节奏</title>${geometry}</svg>`;
await fs.writeFile(path.join(out,'a-three-line.svg'),source);
for(const [name,color] of [['black',ink],['white','#FFFFFF']]){
  await sharp(Buffer.from(source.replace('viewBox=',`width="1024" height="1024" style="color:${color}" viewBox=`))).png().toFile(path.join(out,`a-three-line-${name}.png`));
}

const colorCases = [
  {name:'石墨黑',note:'深色底 + 白色标记',bg:ink,fg:'#FFFFFF'},
  {name:'低彩灰绿',note:'降低彩度，保留一点色温',bg:'#52615C',fg:'#FFFFFF'},
  {name:'界面青绿',note:'原 UI 主色铺满底板',bg:'#087F6B',fg:'#FFFFFF'},
  {name:'青绿只作标记',note:'缩小色彩面积，保留留白',bg:'#FFFFFF',fg:'#087F6B'},
];
const colorRow = colorCases.map((c,i)=>{
  const x=64+i*374;
  return `<rect x="${x}" y="785" width="350" height="216" rx="16" fill="#FFFFFF" stroke="${line}"/>
    ${tile(x+25,823,112,c.bg,c.fg,c.bg==='#FFFFFF')}
    ${text(x+156,861,c.name,20,ink,'font-weight="600"')}
    ${text(x+156,890,c.note.slice(0,11),13,secondary)}
    ${c.note.length>11?text(x+156,912,c.note.slice(11),13,secondary):''}`;
}).join('');

const board=`<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1280" viewBox="0 0 1600 1280">
<rect width="1600" height="1280" fill="#F5F7F8"/>
<g font-family="Segoe UI, Microsoft YaHei, sans-serif">
  ${text(64,64,'SETTRACE / LOGO EXPLORATION / ROUND 02',12,secondary,'letter-spacing="2"')}
  ${text(64,118,'A · 组间节奏',38,ink,'font-weight="650"')}
  ${text(328,116,'三条主线，两条完整，一条断开。',24,secondary)}
  ${text(1380,65,'2026.10.15',14,secondary)}
  <rect x="64" y="165" width="1472" height="532" rx="22" fill="#FFFFFF" stroke="${line}"/>
  <path d="M554 196V666 M1045 196V666" stroke="${line}"/>
  ${text(96,210,'01 / 标记与字标',14,secondary,'letter-spacing="1"')}
  ${text(587,210,'02 / 浅色图标',14,secondary,'letter-spacing="1"')}
  ${text(1077,210,'03 / 深色图标',14,secondary,'letter-spacing="1"')}
  ${mark(166,246,286)}
  ${text(309,586,'SetTrace',42,ink,'text-anchor="middle" font-weight="600" letter-spacing="-1.2"')}
  ${text(309,650,'单色标记，保留形体与留白。',17,secondary,'text-anchor="middle"')}
  ${tile(660,268,280,'#FFFFFF',ink,true)}
  ${text(800,586,'SetTrace',22,ink,'text-anchor="middle" font-weight="500"')}
  ${text(800,650,'白底黑标，线条本身成为主角。',17,secondary,'text-anchor="middle"')}
  ${tile(1150,268,280,ink,'#FFFFFF')}
  ${text(1290,586,'SetTrace',22,ink,'text-anchor="middle" font-weight="500"')}
  ${text(1290,650,'黑底白标，紧凑而清晰。',17,secondary,'text-anchor="middle"')}

  ${text(64,751,'同一图形，比较色彩分配。',23,ink,'font-weight="600"')}
  ${text(1030,750,'统一图形与尺寸，观察色彩面积的影响。',15,secondary)}
  ${colorRow}

  <rect x="64" y="1035" width="1472" height="170" rx="18" fill="#FFFFFF" stroke="${line}"/>
  ${text(91,1075,'数量调整',14,secondary)}
  ${mark(103,1082,90,ink,true)}
  ${text(210,1137,'→',25,secondary)}
  ${mark(250,1082,90,ink)}
  ${text(363,1118,'四道 → 三道',19,ink,'font-weight="600"')}
  ${text(363,1152,'笔画厚度和倾斜角度保持一致。',14,secondary)}
  <path d="M686 1063V1177" stroke="${line}"/>
  ${text(721,1075,'小尺寸检查',14,secondary)}
  ${tile(748,1096,64,ink,'#FFFFFF')}
  ${tile(872,1112,48,ink,'#FFFFFF')}
  ${tile(982,1128,32,ink,'#FFFFFF')}
  ${text(780,1187,'64 px',11,secondary,'text-anchor="middle"')}
  ${text(896,1187,'48 px',11,secondary,'text-anchor="middle"')}
  ${text(998,1187,'32 px',11,secondary,'text-anchor="middle"')}
  ${text(1080,1118,'少一条线，多一点呼吸。',19,ink,'font-weight="600"')}
  ${text(1080,1152,'保留断口作为唯一的形体变化。',14,secondary)}
  ${text(64,1249,'两条完整线 + 一条断开线 / 圆头 / 恒定线宽 / 固定倾斜',14,secondary)}
  ${text(1170,1249,'概念细化 · 仅用于方向选择',14,secondary)}
</g></svg>`;
await fs.writeFile(path.join(out,'overview.svg'),board);
await sharp(Buffer.from(board)).png().toFile(path.join(out,'overview.png'));

await fs.writeFile(path.join(out,'README.md'),`# A · 组间节奏：三线概念稿\n\n2026-10-15，按用户反馈从四条主线减到三条：两条完整，一条带断口。\n\n- overview.png / overview.svg：单色主方案、配色对照、数量变化与小尺寸概览。\n- a-three-line.svg：可编辑、可用 currentColor 换色的透明矢量标记。\n- a-three-line-black.png / a-three-line-white.png：1024 px 透明底标记。\n- 图标底板仅用于效果示意，尚未制作平台图标包。\n\n与上一轮 A 稿保持相同的 11 单位线宽、圆头、10:44 的倾斜比；主线横向间距从 18 增至 21，整体轮廓更紧凑。断口略放宽，便于缩小后区分。\n`);
await fs.writeFile(path.join(out,'tmp/work/design.json'),JSON.stringify({status:'concept-refinement',concept:'A',tracks:3,segments:4,strokeWidth:11,trackSpacing:21,geometry,colorCases},null,2));
console.log(JSON.stringify({output:out,overview:'overview.png',size:[1600,1280],tracks:3,segments:4}));
