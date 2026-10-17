import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const runtime = process.env.SETTRACE_NODE_MODULES ?? 'D:/ProgramData/DevCache/Node/node_modules';
const sharp = require(path.join(runtime, 'sharp'));
const delivery = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const palette = { green: '#087F6B', ink: '#19262C', gray: '#586970', dark: '#111518', mint: '#5DD9B6', background: '#F5F7F8' };

// Original concepts authored from product behavior and the Focus UI palette.
// No existing SetTrace icon artwork is read or imported.
const concepts = [
  {
    id: 'A', slug: 'set-rhythm', title: '组间节奏', english: 'SET RHYTHM',
    summary: ['重复的组，清楚的间歇。', '四道短节形成稳定节拍。'],
    rationale: '三道连续短节与一道断开的短节，共同表达训练与休息的交替。相同长度保持稳定节奏，轻微倾斜提供行动感。',
    focus: '重复单元 / 间歇 / 行动感',
    geometry: '<g fill="none" stroke="currentColor" stroke-width="11" stroke-linecap="round"><path d="M28 28 18 72 M46 28 36 72 M64 28 54 72 M82 28 78.5 43.4 M75.5 56.6 72 72"/></g>',
  },
  {
    id: 'B', slug: 'trace-s', title: '行进的 S', english: 'TRACE S',
    summary: ['一条轨迹，持续向前。', '用完整的回折形成字母 S。'],
    rationale: '一笔等粗轨迹经过两次圆角回折，形成 SetTrace 的 S。保留宽阔负形与完整路径，表达训练持续进行、每组都留下记录。',
    focus: '连续轨迹 / 字母 S / 留白',
    geometry: '<g fill="none" stroke="currentColor" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"><path d="M74 25H39C30.7 25 25 30.7 25 38S30.7 50 39 50H61C69.3 50 75 55.7 75 63S69.3 76 61 76H26"/></g>',
  },
  {
    id: 'C', slug: 'current-cell', title: '当前一格', english: 'CURRENT CELL',
    summary: ['有序的组，明确的当前。', '用一格留白建立视觉焦点。'],
    rationale: '四个圆角模块组成紧凑方阵，三格实心、一格镂空。把训练页中的组状态提炼成整体符号，让当前关注点由形体而非颜色区分。',
    focus: '模块 / 当前焦点 / 秩序',
    geometry: '<g fill="currentColor"><rect x="20" y="20" width="25" height="25" rx="6"/><rect x="55" y="20" width="25" height="25" rx="6"/><rect x="20" y="55" width="25" height="25" rx="6"/><rect x="58.5" y="58.5" width="18" height="18" rx="3" fill="none" stroke="currentColor" stroke-width="7"/></g>',
  },
  {
    id: 'D', slug: 'training-ticks', title: '训练刻度', english: 'TRAINING TICKS',
    summary: ['一根主轴，逐组记录。', '把计数刻度融入字母 T。'],
    rationale: 'T 形主轴配两道短刻度，表达逐组计数与清楚定位。圆角端点承接界面语言，主轴和横向刻度形成可靠的工具感。',
    focus: '字母 T / 计数 / 工具感',
    geometry: '<g fill="none" stroke="currentColor" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"><path d="M25 25H75 M50 25V75 M50 46H69 M50 64H63"/></g>',
  },
  {
    id: 'E', slug: 'trace-imprint', title: '留痕印记', english: 'TRACE IMPRINT',
    summary: ['完成一组，留下一笔。', '在完整形体中刻出轨迹。'],
    rationale: '以实心圆形作为印记，将一笔带回折的轨迹从内部挖空。通过实与虚的关系表达记录被留下，突出紧凑、稳定、易识别的轮廓。',
    focus: '负形 / 印记 / 记录感',
    geometry: '<g fill="currentColor"><path fill-rule="evenodd" d="M83 50A33 33 0 1 1 17 50A33 33 0 1 1 83 50Z M35 58H43V41Q43 32 52 32H65A6 6 0 0 1 65 44H57V59Q57 70 46 70H35A6 6 0 0 1 35 58Z"/></g>',
  },
];

const escape = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('"', '&quot;');
const symbol = (c, attrs = '') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" ${attrs}>${c.geometry}</svg>`;
const imageAt = (c, x, y, size, color) => symbol(c, `x="${x}" y="${y}" width="${size}" height="${size}" style="color:${color}"`);
const appAt = (c, x, y, size, bg, fg) => `<rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${size * .235}" fill="${bg}"/>${imageAt(c, x, y, size, fg)}`;
const text = (x, y, value, size = 18, fill = palette.ink, extra = '') => `<text x="${x}" y="${y}" font-size="${size}" fill="${fill}" ${extra}>${escape(value)}</text>`;

await fs.mkdir(path.join(delivery, 'marks'), { recursive: true });
await fs.mkdir(path.join(delivery, 'tmp/reports'), { recursive: true });

for (const c of concepts) {
  const svg = symbol(c, `role="img" aria-labelledby="title-${c.id}"`).replace('>'+c.geometry, `><title id="title-${c.id}">SetTrace ${c.id} — ${c.title}</title>${c.geometry}`);
  await fs.writeFile(path.join(delivery, 'marks', `${c.id.toLowerCase()}-${c.slug}.svg`), svg);
  await sharp(Buffer.from(symbol(c, `width="512" height="512" style="color:${palette.green}"`))).png().toFile(path.join(delivery, 'marks', `${c.id.toLowerCase()}-${c.slug}.png`));
}

const columns = concepts.map((c, i) => {
  const x = 64 + i * 339;
  return `<g>
    <rect x="${x}" y="196" width="316" height="858" rx="20" fill="#FFFFFF" stroke="#DBE3E5"/>
    <rect x="${x+24}" y="220" width="34" height="34" rx="9" fill="#E2F2ED"/>
    ${text(x+35, 244, c.id, 20, palette.green, 'font-weight="700"')}
    ${text(x+24, 293, c.title, 26, palette.ink, 'font-weight="700"')}
    ${text(x+24, 321, c.english, 12, palette.gray, 'letter-spacing="1.4"')}
    ${appAt(c, x+62, 359, 192, palette.green, '#FFFFFF')}
    ${text(x+24, 608, c.summary[0], 19, palette.ink, 'font-weight="600"')}
    ${text(x+24, 639, c.summary[1], 17, palette.gray)}
    <path d="M${x+24} 678H${x+292}" stroke="#DBE3E5"/>
    ${text(x+24, 710, 'LOGO 组合', 11, palette.gray, 'letter-spacing="1.2"')}
    ${imageAt(c, x+27, 731, 52, palette.green)}
    ${text(x+90, 768, 'SetTrace', 29, palette.ink, 'font-weight="600" letter-spacing="-.6"')}
    ${text(x+24, 830, '深色 / 浅色 / 单色缩略', 12, palette.gray)}
    ${appAt(c, x+28, 854, 64, palette.dark, palette.mint)}
    ${appAt(c, x+135, 870, 48, '#E2F2ED', palette.green)}
    ${imageAt(c, x+235, 886, 32, palette.ink)}
    ${text(x+48, 942, '64', 12, palette.gray)}
    ${text(x+150, 942, '48', 12, palette.gray)}
    ${text(x+242, 942, '32', 12, palette.gray)}
    <path d="M${x+24} 972H${x+292}" stroke="#DBE3E5"/>
    ${text(x+24, 1015, c.focus, 14, palette.gray)}
  </g>`;
}).join('');

const board = `<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1150" viewBox="0 0 1800 1150">
  <rect width="1800" height="1150" fill="${palette.background}"/>
  <g font-family="Segoe UI, Microsoft YaHei, sans-serif">
    ${text(64, 87, 'SetTrace', 43, palette.ink, 'font-weight="650" letter-spacing="-1"')}
    ${text(274, 84, '/  Logo 与 App 图标 · 五方向草图', 29, palette.ink, 'font-weight="500"')}
    ${text(64, 133, '同一配色、同一尺寸，先比较图形。每个方向各一稿，尚未定稿。', 19, palette.gray)}
    ${text(1572, 82, 'ROUND 01', 13, palette.gray, 'letter-spacing="2"')}
    ${text(1572, 113, '2026.10.15', 15, palette.gray)}
    ${columns}
    <circle cx="72" cy="1106" r="7" fill="${palette.green}"/>
    ${text(90, 1112, '青绿 #087F6B', 14, palette.gray)}
    <circle cx="272" cy="1106" r="7" fill="${palette.dark}"/>
    ${text(290, 1112, '石墨 #111518', 14, palette.gray)}
    <circle cx="472" cy="1106" r="7" fill="${palette.mint}"/>
    ${text(490, 1112, '薄荷 #5DD9B6', 14, palette.gray)}
    ${text(1290, 1112, 'Focus UI 视觉基线 / 仅用于方案选择', 15, palette.gray)}
  </g>
</svg>`;
await fs.writeFile(path.join(delivery, 'comparison.svg'), board);
await sharp(Buffer.from(board)).png().toFile(path.join(delivery, 'comparison.png'));

const card = c => `<article class="card" data-id="${c.id}">
  <div class="card-header"><span class="letter">${c.id}</span><span class="english">${c.english}</span></div>
  <h2>${c.title}</h2>
  <button class="hero-preview" aria-label="放大方案 ${c.id}：${c.title}" data-open="${c.id}"><span class="app-icon">${symbol(c, 'aria-hidden="true"')}</span></button>
  <div class="summary"><p>${c.summary[0]}</p><p>${c.summary[1]}</p></div>
  <div class="wordmark">${symbol(c, 'aria-hidden="true"')}<span>SetTrace</span></div>
  <div class="mini-heading">深色 / 浅色 / 单色缩略</div>
  <div class="small-sizes"><figure><span class="mini dark" style="--size:64px">${symbol(c, 'aria-hidden="true"')}</span><figcaption>64 px</figcaption></figure><figure><span class="mini light" style="--size:48px">${symbol(c, 'aria-hidden="true"')}</span><figcaption>48 px</figcaption></figure><figure><span class="mono">${symbol(c, 'aria-hidden="true"')}</span><figcaption>32 px</figcaption></figure></div>
  <p class="focus">${c.focus}</p>
  <div class="card-actions"><button data-open="${c.id}">放大查看</button><a href="marks/${c.id.toLowerCase()}-${c.slug}.svg" download>SVG ↓</a></div>
</article>`;

const html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="color-scheme" content="light"><title>SetTrace · A–E Logo 草图</title>
<style>
:root{--green:#087F6B;--ink:#19262C;--gray:#586970;--page:#F5F7F8;--line:#DBE3E5;--icon-bg:#087F6B;--icon-fg:#fff;--card:#fff}
*{box-sizing:border-box}body{margin:0;background:var(--page);color:var(--ink);font-family:"Segoe UI","Microsoft YaHei UI","Microsoft YaHei",sans-serif;-webkit-font-smoothing:antialiased}button,a{-webkit-tap-highlight-color:transparent}button{font:inherit;cursor:pointer}a{color:var(--green)}button:focus-visible,a:focus-visible{outline:3px solid var(--green);outline-offset:5px}main{max-width:1840px;margin:auto;padding:46px 40px 30px}header{display:flex;justify-content:space-between;gap:24px;align-items:center;margin-bottom:28px}.eyebrow{font-size:12px;letter-spacing:2px;color:var(--gray);margin:0 0 12px}h1{font-size:32px;letter-spacing:-.8px;margin:0;font-weight:650}h1 span{font-weight:450;font-size:23px;margin-left:12px}.intro{color:var(--gray);font-size:15px;line-height:1.7;margin:12px 0 0}.toolbar{display:flex;flex-wrap:wrap;gap:6px;padding:5px;background:#E7EDEF;border-radius:12px;flex-shrink:0}.toolbar button{border:0;background:transparent;min-height:42px;padding:0 15px;border-radius:8px;color:var(--gray)}.toolbar button[aria-pressed="true"]{background:#fff;color:var(--green);box-shadow:0 1px 3px #19262c10}.grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:20px}.card{min-width:0;background:var(--card);border:1px solid var(--line);border-radius:18px;padding:22px 22px 18px}.card-header{display:flex;align-items:center;gap:12px}.letter{display:grid;place-items:center;width:32px;height:32px;border-radius:8px;background:#E2F2ED;color:var(--green);font-size:19px;font-weight:700}.english{font-size:10px;letter-spacing:1.2px;color:var(--gray)}h2{font-size:24px;margin:18px 0 15px;font-weight:650}.hero-preview{display:grid;place-items:center;width:100%;padding:18px 0 29px;background:transparent;border:0;border-radius:12px}.app-icon{display:block;flex-shrink:0;width:170px;height:170px;border-radius:23.5%;background:var(--icon-bg);color:var(--icon-fg);transition:background .16s,color .16s}.app-icon svg{display:block;width:100%;height:100%}.hero-preview:hover .app-icon{transform:translateY(-2px)}.summary{padding:0 0 25px;border-bottom:1px solid var(--line)}.summary p{margin:0;line-height:1.8;font-size:13px;color:var(--gray)}.summary p:first-child{color:var(--ink);font-size:15px;font-weight:600}.wordmark{display:flex;align-items:center;gap:9px;margin:24px 0 28px}.wordmark svg{width:43px;height:43px;color:var(--green);flex-shrink:0}.wordmark span{font-size:25px;letter-spacing:-.7px;font-weight:600}.mini-heading{font-size:11px;color:var(--gray)}.small-sizes{display:flex;align-items:flex-end;justify-content:space-between;margin:18px 0 20px;gap:10px}.small-sizes figure{margin:0;text-align:center}.mini{display:block;width:var(--size);height:var(--size);border-radius:23.5%}.mini svg{display:block;width:100%;height:100%}.dark{background:#111518;color:#5DD9B6}.light{background:#E2F2ED;color:#087F6B}.mono{display:block;width:32px;height:32px;color:#19262C}.mono svg{display:block;width:100%;height:100%}figcaption{font-size:10px;color:var(--gray);margin-top:10px}.focus{border-top:1px solid var(--line);padding-top:17px;font-size:11px;color:var(--gray);line-height:1.7;margin:0 0 12px}.card-actions{display:flex;justify-content:space-between;align-items:center;gap:10px}.card-actions button{background:transparent;border:0;color:var(--green);min-height:36px;padding:0;font-size:12px}.card-actions a{font-size:12px;text-decoration:none;min-height:36px;display:flex;align-items:center}footer{display:flex;justify-content:space-between;gap:20px;flex-wrap:wrap;color:var(--gray);font-size:12px;line-height:1.8;margin-top:24px}footer a{text-underline-offset:3px}.swatch{display:inline-block;vertical-align:middle;width:9px;height:9px;border-radius:50%;margin-right:5px}.palette{display:flex;gap:20px;flex-wrap:wrap}dialog{border:1px solid var(--line);border-radius:24px;padding:32px;max-width:680px;width:calc(100% - 32px);color:var(--ink);background:var(--card)}dialog::backdrop{background:#111518a8;backdrop-filter:blur(5px)}.dialog-top{display:flex;justify-content:space-between;align-items:center}.dialog-top h2{margin:0;font-size:26px}.close{background:#F5F7F8;border:0;width:44px;height:44px;border-radius:12px;font-size:23px;line-height:1}.dialog-art{display:grid;place-items:center;padding:30px 0}.dialog-art .app-icon{width:280px;height:280px}.dialog-copy{line-height:1.9;font-size:15px;color:var(--gray);margin:0}.dialog-links{margin:22px 0 0;display:flex;gap:24px;font-size:14px}.dialog-links a{min-height:40px;display:flex;align-items:center}body[data-theme="dark"]{--icon-bg:#111518;--icon-fg:#5DD9B6}body[data-theme="mono"]{--icon-bg:#fff;--icon-fg:#19262C}body[data-theme="mono"] .app-icon{box-shadow:inset 0 0 0 1px #DBE3E5}
@media(min-width:1700px){.app-icon{width:192px;height:192px}.summary p{font-size:15px}.summary p:first-child{font-size:17px}.wordmark span{font-size:29px}.english{font-size:11px}.focus{font-size:13px}.card-actions a,.card-actions button{font-size:14px}}
@media(max-width:1220px){main{padding:30px 24px}.grid{gap:12px}.card{padding:18px 14px}.app-icon{width:145px;height:145px}.wordmark{gap:5px}.wordmark svg{width:34px;height:34px}.wordmark span{font-size:23px}.english{font-size:9px;letter-spacing:.7px}header{align-items:flex-start}h1 span{display:block;margin:5px 0 0;font-size:21px}}
@media(max-width:1000px){.grid{grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}.card{padding:22px}.app-icon{width:180px;height:180px}.summary p{font-size:14px}.summary p:first-child{font-size:16px}.wordmark span{font-size:27px}.wordmark svg{width:44px;height:44px}}
@media(max-width:720px){main{padding:26px 18px}header{flex-direction:column;gap:20px}.grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.card{padding:18px 14px}.app-icon{width:145px;height:145px}.summary p{font-size:12px}.summary p:first-child{font-size:13px}.wordmark span{font-size:22px}.wordmark svg{width:32px;height:32px}.small-sizes{gap:6px}.mini.dark{--size:48px!important}.mini.light{--size:40px!important}.english{font-size:9px}.dialog-art .app-icon{width:240px;height:240px}}
@media(max-width:410px){.grid{grid-template-columns:1fr}.card{padding:24px}.app-icon{width:210px;height:210px}.wordmark span{font-size:29px}.wordmark svg{width:48px;height:48px}.summary p{font-size:15px}.summary p:first-child{font-size:17px}.small-sizes{justify-content:flex-start;gap:40px}.mini.dark{--size:64px!important}.mini.light{--size:48px!important}.english{font-size:11px}.focus{font-size:13px}}
@media(prefers-reduced-motion:reduce){*{transition:none!important}.hero-preview:hover .app-icon{transform:none}}
</style></head><body data-theme="green"><main>
<header><div><p class="eyebrow">SETTRACE / LOGO EXPLORATION / ROUND 01</p><h1>SetTrace<span>五个方向，各一张草图。</span></h1><p class="intro">同一配色、同一尺寸，先比较图形。点击图标放大，再决定值得继续的方向。</p></div><div class="toolbar" role="group" aria-label="切换图标配色"><button data-theme="green" aria-pressed="true">青绿</button><button data-theme="dark" aria-pressed="false">深色</button><button data-theme="mono" aria-pressed="false">单色</button></div></header>
<section class="grid" aria-label="A 到 E 五个 Logo 方案">${concepts.map(card).join('')}</section>
<footer><div class="palette"><span><i class="swatch" style="background:#087F6B"></i>青绿 #087F6B</span><span><i class="swatch" style="background:#111518"></i>石墨 #111518</span><span><i class="swatch" style="background:#5DD9B6"></i>薄荷 #5DD9B6</span></div><span>概念草图 · 仅用于方案选择 · <a href="comparison.png" target="_blank" rel="noopener">打开五方案对比图 ↗</a></span></footer>
</main><dialog aria-labelledby="dialog-title"><div class="dialog-top"><h2 id="dialog-title"></h2><button class="close" aria-label="关闭放大预览">×</button></div><div class="dialog-art"></div><p class="dialog-copy"></p><div class="dialog-links"></div></dialog>
<script>
const concepts=${JSON.stringify(concepts).replaceAll('<','\\u003c')};
const dialog=document.querySelector('dialog');
document.querySelectorAll('.toolbar [data-theme]').forEach(button=>button.addEventListener('click',()=>{document.body.dataset.theme=button.dataset.theme;document.querySelectorAll('.toolbar [data-theme]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)))}));
document.querySelectorAll('[data-open]').forEach(button=>button.addEventListener('click',()=>{const concept=concepts.find(c=>c.id===button.dataset.open);document.querySelector('#dialog-title').textContent=concept.id+' · '+concept.title;document.querySelector('.dialog-art').innerHTML='<span class="app-icon"><svg viewBox="0 0 100 100" aria-hidden="true">'+concept.geometry+'</svg></span>';document.querySelector('.dialog-copy').textContent=concept.rationale;document.querySelector('.dialog-links').innerHTML='<a download href="marks/'+concept.id.toLowerCase()+'-'+concept.slug+'.svg">下载 SVG 标记</a><a download href="marks/'+concept.id.toLowerCase()+'-'+concept.slug+'.png">下载透明 PNG</a>';dialog.showModal()}));
document.querySelector('.close').addEventListener('click',()=>dialog.close());
dialog.addEventListener('click',event=>{if(event.target===dialog){const bounds=dialog.getBoundingClientRect();if(event.clientX<bounds.left||event.clientX>bounds.right||event.clientY<bounds.top||event.clientY>bounds.bottom)dialog.close()}});
</script></body></html>`;
await fs.writeFile(path.join(delivery, 'index.html'), html);
await fs.writeFile(path.join(delivery, 'tmp/work/concepts.json'), JSON.stringify({ status: 'concept-sketches', date: '2026-10-15', selection: null, palette, concepts }, null, 2));
await fs.writeFile(path.join(delivery, 'README.md'), `# SetTrace · A–E Logo 草图\n\n2026-10-15，第一轮概念比较，每个方向一稿。\n\n- 打开 index.html 比较、切换配色及放大查看；无需网络或安装依赖。\n- comparison.png / comparison.svg 是五方案静态对比图。\n- marks/ 下是五套透明 SVG / PNG 标记。SVG 使用 currentColor，可改变颜色。\n- App 圆角底板仅用于桌面图标效果示意；尚未制作平台图标包或接入 App。\n- SetTrace 字标使用系统字体进行组合示意，尚未进行专属字体设计。\n- 依据 docs/design 当前 Focus UI 的配色、圆角、专注与秩序感独立创作，未读取现有图标素材。\n\n| 方向 | 名称 | 构想 |\n| --- | --- | --- |\n${concepts.map(c=>`| ${c.id} | ${c.title} | ${c.rationale} |`).join('\n')}\n\n生成脚本：tmp/work/generate.mjs。\n`);
console.log(JSON.stringify({ delivery, concepts: concepts.map(c=>({id:c.id,title:c.title})), comparison: {width:1800,height:1150}, status:'generated' }));
