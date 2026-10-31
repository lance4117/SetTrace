import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const require=createRequire(import.meta.url);
const modules=process.env.SETTRACE_NODE_MODULES ?? 'D:/ProgramData/DevCache/Node/node_modules';
const sharp=require(path.join(modules,'sharp'));
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const data=JSON.parse(await fs.readFile(path.join(root,'tmp/work/geometry.json'),'utf8'));
const typo=JSON.parse(await fs.readFile(path.join(root,'tmp/work/typography.json'),'utf8'));
const word=await fs.readFile(path.join(root,'tmp/work/wordmark-body.svg'),'utf8');
const {brand,uiAccent,ink}=data.palette;
const gray='#586970',border='#DBE3E5';
const text=(x,y,s,size=18,color=ink,extra='')=>`<text x="${x}" y="${y}" font-size="${size}" fill="${color}" ${extra}>${s}</text>`;
const paths=data.paths.map(d=>`<path d="${d}" fill="currentColor"/>`).join('');
const symbol=(x,y,size,color)=>`<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="0 0 100 100" style="color:${color}">${paths}</svg>`;
const tile=(x,y,size,bg=brand,fg='#FFFFFF')=>`<rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${size*241/1024}" fill="${bg}"/>${symbol(x,y,size,fg)}`;
const lockup=(x,y,width,color)=>`<svg x="${x}" y="${y}" width="${width}" height="${width*100/typo.horizontalWidth}" viewBox="0 0 ${typo.horizontalWidth} 100" style="color:${color}">${paths}<g transform="translate(110 0)">${word}</g></svg>`;
const doc=(content,w,h)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><g font-family="Segoe UI, Microsoft YaHei, sans-serif">${content}</g></svg>`;
const save=async(name,body,w,h)=>{const svg=doc(body,w,h);await fs.writeFile(path.join(root,`${name}.svg`),svg);await sharp(Buffer.from(svg)).png().toFile(path.join(root,`${name}.png`));};
await fs.mkdir(path.join(root,'showcase'),{recursive:true});
const preview=await fs.readFile(path.join(root,'settrace-icon/settrace-icon.preview.svg'));
const square=await fs.readFile(path.join(root,'settrace-icon/settrace-icon.svg'));
for(const size of [16,24,32,48,64,128,256,512]){
  await sharp(square).resize(size,size).png().toFile(path.join(root,`exports/png/settrace-icon-${size}.png`));
  await sharp(preview).resize(size,size).png().toFile(path.join(root,`exports/png/settrace-icon-rounded-${size}.png`));
}
const circle=(x,y,size)=>`<defs><clipPath id="circle-${x}-${y}-${size}"><circle cx="${x+size/2}" cy="${y+size/2}" r="${size/2}"/></clipPath></defs><g clip-path="url(#circle-${x}-${y}-${size})"><rect x="${x}" y="${y}" width="${size}" height="${size}" fill="${brand}"/>${symbol(x,y,size,'#FFFFFF')}</g>`;

// Main design sheet, with a separate native-size sample strip below.
const small=[64,48,32,24,16].map((s,i)=>{
  const x=[870,1000,1112,1208,1298][i];
  return tile(x,838-s,s)+text(x+s/2,865,`${s} px`,12,gray,'text-anchor="middle"');
}).join('');
const masterSymbol=symbol(95,689,230,brand);
const board=`<rect width="1600" height="1360" fill="#F5F7F8"/>
${text(64,61,'SETTRACE / FINAL IDENTITY / 1.0',12,gray,'letter-spacing="2"')}
${text(64,120,'组间节奏 · 正式设计',39,ink,'font-weight="650"')}
${text(1050,115,'深墨绿 / 三线标记',24,gray)}
<rect x="64" y="165" width="1472" height="430" rx="22" fill="#FFFFFF" stroke="${border}"/>
${lockup(90,254,790,brand)}
${text(133,507,'一组一组，留下训练的轨迹。',24,ink,'font-weight="500"')}
${text(133,548,'两条连续线，一条间歇线。稳定的重复，明确的节奏。',17,gray)}
${tile(1105,215,304)}
${text(1257,558,'App 图标 · 深墨绿 + 白',17,gray,'text-anchor="middle"')}
${text(64,653,'统一结构，细化小尺寸表现。',24,ink,'font-weight="600"')}
<rect x="64" y="683" width="720" height="286" rx="18" fill="#FFFFFF" stroke="${border}"/>
${masterSymbol}
<path d="M145 741H306 M145 866H306" stroke="#DBE3E5" stroke-dasharray="4 5"/>
${text(360,739,'13° 固定倾斜',20,ink,'font-weight="600"')}
${text(360,780,'10.8 / 统一笔画厚度',17,gray)}
${text(360,817,'9.0 / 断口净留白',17,gray)}
${text(360,854,'9.66 / 线间净留白',17,gray)}
${text(360,906,'光学补偿 +1.59，平衡右侧较轻的形体。',15,gray)}
<rect x="808" y="683" width="728" height="286" rx="18" fill="#FFFFFF" stroke="${border}"/>
${text(840,727,'实际像素尺寸',15,gray)}
${small}
${circle(1410,772,64)}
${text(1442,865,'圆形裁切',12,gray,'text-anchor="middle"')}
${text(840,928,'检查轮廓、断口与相邻线条的区分。',16,gray)}
${text(64,1027,'同一标记，两套基础用法。',24,ink,'font-weight="600"')}
<rect x="64" y="1056" width="720" height="220" rx="18" fill="#FFFFFF" stroke="${border}"/>
${lockup(105,1101,585,brand)}
<rect x="808" y="1056" width="728" height="220" rx="18" fill="${brand}"/>
${lockup(852,1101,585,'#FFFFFF')}
${text(64,1324,'品牌主色 #153C34 / 白色 #FFFFFF / 界面强调 #087F6B',15,gray)}
${text(1203,1324,'SVG 轮廓 / PNG / 使用规范',15,gray)}`;
await save('overview',board,1600,1360);

const sampleStrip=doc(`<rect width="1000" height="320" fill="#F5F7F8"/>${text(30,42,'SetTrace / actual-size readability',18,ink)}${[64,48,32,24,16].map((s,i)=>{const x=48+i*150;return tile(x,160-s,s)+text(x+s/2,190,`${s}px`,13,gray,'text-anchor="middle"');}).join('')}${circle(820,96,64)}${text(852,190,'circle 64px',13,gray,'text-anchor="middle"')}${text(30,260,'16px 为极小识别检查；常规图标优先使用 24px 以上。',17,gray)}`,1000,320);
await fs.writeFile(path.join(root,'tmp/work/small-size-review.svg'),sampleStrip);
await sharp(Buffer.from(sampleStrip)).png().toFile(path.join(root,'tmp/work/small-size-review.png'));

await save('showcase/01-swiss-flat',`<rect width="1200" height="800" fill="#F5F7F8"/>${text(76,85,'SETTRACE / FOCUSED TRAINING',13,gray,'letter-spacing="3"')}${lockup(136,278,920,brand)}${text(172,629,'一组一组，留下训练的轨迹。',31,ink,'font-weight="500"')}${text(172,680,'Plan. Train. Trace.',18,gray)}`,1200,800);
await save('showcase/02-ink-field',`<rect width="1200" height="800" fill="${brand}"/>${symbol(420,128,360,'#FFFFFF')}<g transform="translate(${(1200-typo.wordWidth*1.35)/2} 515) scale(1.35)" style="color:#FFFFFF">${word}</g>${text(600,705,'STEADY SETS. LASTING TRACES.',13,'#B8D0C8','text-anchor="middle" letter-spacing="3"')}`,1200,800);
await save('showcase/03-product-context',`<rect width="1200" height="800" fill="#F5F7F8"/>${text(64,85,'SETTRACE / PRODUCT CONTEXT',13,gray,'letter-spacing="2"')}${lockup(50,305,565,brand)}${text(103,540,'品牌深绿，衔接界面青绿。',23,ink)}<rect x="730" y="140" width="386" height="534" rx="24" fill="#FFFFFF" stroke="${border}"/>${text(762,192,'训练',22,ink,'font-weight="600"')}${text(762,267,'当前待练组',14,uiAccent,'font-weight="600"')}${text(757,363,'03',84,ink,'font-weight="650"')}${text(762,409,'共 4 组 · 已完成 2 组',15,gray)}<rect x="762" y="468" width="322" height="58" rx="14" fill="${uiAccent}"/>${text(923,504,'完成本组',18,'#FFFFFF','text-anchor="middle" font-weight="600"')}${text(762,597,'现有主题配色的组件示意',13,gray)}`,1200,800);
await save('showcase/04-monochrome',`<rect width="600" height="800" fill="#FFFFFF"/><rect x="600" width="600" height="800" fill="${ink}"/>${text(60,83,'MONO / POSITIVE',12,gray,'letter-spacing="2"')}${text(660,83,'MONO / REVERSE',12,'#ABB9BF','letter-spacing="2"')}${symbol(122,198,360,ink)}${symbol(722,198,360,'#FFFFFF')}<g transform="translate(142 555) scale(1.35)" style="color:${ink}">${word}</g><g transform="translate(742 555) scale(1.35)" style="color:#FFFFFF">${word}</g>`,1200,800);

const guide=`# SetTrace · 组间节奏 / 正式设计 1.0

2026-10-15。用户已选定 A 三线标记和深墨绿方向，并授权完成设计细化。

## 设计定义

两条完整的平行线与一条断开的线组成标记。重复代表逐组训练，断口代表训练之间的间歇。图形没有固定组数或训练完成状态的含义。

本轮优化保留了选定概念的三线结构、圆头、深墨绿和白色，仅调整轮廓精度、断口和视觉居中。正式稿为封闭填色轮廓，不依赖描边扩展。

| 参数（100 单位母版） | 正式值 |
| --- | --- |
| 主线数量 / 独立形体 | 3 / 4 |
| 倾斜角（相对竖直） | 13° |
| 笔画厚度 / 端头半径 | 10.8 / 5.4 |
| 水平中心距 | 21 |
| 线间垂直净距 | 9.66 |
| 断口沿主线方向的净距 | 9.0 |
| 向右的视觉补偿 | 1.5887 |
| 白色形体的面积重心 | 50, 50 |

草图断口约 5.4，正式稿调整为 9.0，避免缩小时两段挤在一起。断开线较轻，因此整体略向右补偿。几何外接框不要求机械居中；视觉平衡以实际形体为依据。

## 色彩

| 用途 | 色值 |
| --- | --- |
| 品牌主色 / 图标背景 | #153C34 |
| 深色底上的标记 | #FFFFFF |
| 黑白单色版本 | #111518 / #FFFFFF |
| 既有浅色界面的交互强调 | #087F6B |
| 既有深色界面的交互强调 | #5DD9B6 |
| 既有界面浅强调背景 | #E2F2ED |

品牌深绿负责稳定的外部识别，界面青绿负责可操作元素。不要通过整体替换 UI 主色来统一图标与界面。保持标记单色，不为第三条线单独加色。

## 使用规则

- 使用 logo/ 内的矢量母版，保持整体比例，不单独移动线条或断口。
- 独立标记的净空至少一倍笔画厚度；母版已有的留白可计入净空，不要把相邻文字压进标记内部。
- 标记常规最小显示尺寸为 24 px。16 px 已检查为极小尺寸识别，不建议带字标或低对比使用。
- 横向 Logo 建议不小于 140 px 宽；更小场景使用独立标记。
- 图标不放文字、描边、光晕、阴影、渐变或额外边框。
- 白色标记放在深墨绿或其他足够深的单色背景；深绿标记放在白色或很浅的中性背景。
- 不旋转整体标记、不拉伸、不改变三条线数量、不把断口合并为完整线。
- 字标基于本机 Segoe UI Semibold，统一字距后转为 SVG 轮廓；交付文件无需安装该字体，不包含字体文件。

## 文件入口

- index.html：离线展示与下载，可切换图标、标记及横向组合，也可放大四张应用展示图。
- overview.png / .svg：正式设计概览。
- logo/：深绿、白色、黑色的透明独立标记与横向 Logo；另有竖向组合。SVG 为可缩放轮廓，PNG 为透明底。
- settrace-icon/settrace-icon.svg / .png：1024 × 1024、不预裁圆角的通用源画布。
- settrace-icon/settrace-icon.preview.svg / .png：圆角预览。
- settrace-icon/layers/：背景、连续组、间歇组，三层可编辑 SVG。
- settrace-icon/settrace-icon.origin.svg：用户选定的深墨绿三线草图证据，保留供追溯。
- exports/png/：16、24、32、48、64、128、256、512 px 的通用方形导出与圆角展示导出。
- showcase/：纸白横向、深绿反白、界面衔接、黑白四种矢量展示。
- SetTrace-Brand-Final.zip：轻量交付包，含母版、导出、使用说明和验证报告，不含工具运行依赖。

本次完成的是正式品牌设计及通用图标源文件。平台信息记录为 Android；没有修改 Flutter、启动器资源或界面主题，没有制作原生平台图标包。

## 验证与复现

几何审计检查闭合轮廓、重复端点与路径噪声；通用图标验证检查源画布、预览、图层、颜色和素材清洁度。另检查 64/48/32/24/16 px、圆形裁切、透明素材与轮廓字标。

与概念稿的差异图保留在 settrace-icon/tmp/reports/reference-*.png，原比较数据在 settrace-icon/tmp/work/concept-comparison.json。它们记录了本次获授权的断口和视觉居中调整，不代表逐像素复刻目标；没有将旧草图的严格复刻检查当作正式设计完成标准。

复现步骤：先运行 tmp/work/prepare.mjs 写入母版与 icon spec，再使用 settrace-icon/tmp/work/runtime/scripts/author_icon.mjs 生成图标，运行 tmp/work/present.mjs 生成展示。运行依赖仅在本地工作目录中；工具副本的 Windows 路径深度判断已同时支持斜线与反斜线，其余路径安全检查保留。原技能文件未修改。
`;
await fs.writeFile(path.join(root,'design-guide.md'),guide);
await fs.writeFile(path.join(root,'README.md'),'# SetTrace · 正式品牌设计\n\n已选定的深墨绿三线方案。\n\n打开 [index.html](index.html) 查看完整展示，或阅读 [设计与使用规范](design-guide.md)。\n\n![正式设计](overview.png)\n\nLogo 母版位于 logo/，图标通用源文件位于 settrace-icon/，整包见 SetTrace-Brand-Final.zip。\n');

const html=`<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>SetTrace · 正式品牌设计</title><style>
*{box-sizing:border-box}body{margin:0;font-family:"Segoe UI","Microsoft YaHei UI",sans-serif;color:#19262C;background:#F5F7F8}main{max-width:1320px;margin:auto;padding:40px 24px 50px}header{display:flex;justify-content:space-between;align-items:center;gap:20px;margin-bottom:28px}.eyebrow{color:#586970;font-size:11px;letter-spacing:2px;margin:0 0 10px}h1{font-weight:650;font-size:30px;margin:0}a{color:#153C34;text-underline-offset:4px}button,a{touch-action:manipulation}button{font:inherit;cursor:pointer}a:focus-visible,button:focus-visible{outline:3px solid #087F6B;outline-offset:4px}.download{background:#153C34;color:#fff;border-radius:12px;padding:15px 20px;text-decoration:none;white-space:nowrap;font-size:14px}.hero{display:grid;grid-template-columns:1fr 1fr;background:white;border:1px solid #DBE3E5;border-radius:20px;overflow:hidden}.preview{display:flex;align-items:center;justify-content:center;min-height:370px;background:#EDF1EF;padding:30px}.preview img{width:260px;height:260px;object-fit:contain}.preview img[data-kind="lockup"]{width:100%;max-width:460px;height:auto}.details{padding:34px}.details h2{font-size:24px;margin:0 0 14px}.details p{font-size:15px;line-height:1.9;color:#586970;margin:0 0 18px}.choices{display:flex;flex-wrap:wrap;gap:8px;margin:22px 0}.choices button{border:1px solid #DBE3E5;border-radius:9px;background:white;padding:11px 13px;color:#586970}.choices button[aria-pressed="true"]{border-color:#153C34;background:#E2F2ED;color:#153C34}.links{display:flex;gap:18px;flex-wrap:wrap;font-size:14px}.colors{display:flex;gap:18px;margin-top:24px;color:#586970;font-size:12px}.colors i{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:6px}section{margin-top:34px}.section-title{font-size:23px;margin:0 0 18px}.sheet{width:100%;display:block;border-radius:16px}.gallery{display:grid;grid-template-columns:repeat(2,1fr);gap:18px}.gallery button{padding:0;border:1px solid #DBE3E5;border-radius:15px;overflow:hidden;background:white}.gallery img{width:100%;display:block}.gallery span{display:block;text-align:left;padding:14px 18px;color:#586970;font-size:13px}footer{margin-top:32px;font-size:13px;color:#586970;line-height:1.9;display:flex;justify-content:space-between;gap:18px;flex-wrap:wrap}dialog{padding:0;border:0;border-radius:18px;max-width:1000px;width:calc(100% - 32px);background:white}dialog::backdrop{background:#111518b0}dialog img{display:block;width:100%}.close{position:absolute;right:14px;top:14px;background:white;border:1px solid #DBE3E5;border-radius:10px;width:42px;height:42px;font-size:25px}@media(max-width:750px){main{padding:24px 16px}header{align-items:flex-start}h1{font-size:24px}.download{font-size:12px;padding:12px}.hero{grid-template-columns:1fr}.preview{min-height:310px}.details{padding:24px}.gallery{grid-template-columns:1fr}.colors{flex-wrap:wrap}.preview img{width:230px;height:230px}}
</style></head><body><main><header><div><p class="eyebrow">SETTRACE / FINAL IDENTITY / 1.0</p><h1>组间节奏 · 正式设计</h1></div><a class="download" href="SetTrace-Brand-Final.zip" download>下载完整设计包 ↓</a></header>
<div class="hero"><div class="preview"><img id="hero-image" src="settrace-icon/settrace-icon.preview.svg" alt="深墨绿底、白色三线 SetTrace 图标" data-kind="icon"></div><div class="details"><h2>一组一组，留下训练的轨迹。</h2><p>两条连续线，一条间歇线。保留选定的深墨绿与三线结构，统一圆头和倾斜角，细化断口与视觉居中。</p><div class="choices" role="group" aria-label="切换品牌素材预览"><button data-kind="icon" aria-pressed="true">App 图标</button><button data-kind="symbol" aria-pressed="false">独立标记</button><button data-kind="lockup" aria-pressed="false">横向 Logo</button></div><div class="links"><a href="logo/settrace-symbol.svg" download>标记 SVG</a><a href="logo/settrace-lockup.svg" download>横向 Logo SVG</a><a href="settrace-icon/settrace-icon.png" download>1024 px 图标源文件</a></div><div class="colors"><span><i style="background:#153C34"></i>品牌 #153C34</span><span><i style="background:#087F6B"></i>界面 #087F6B</span></div></div></div>
<section><h2 class="section-title">正式设计概览</h2><a href="overview.png" target="_blank" rel="noopener"><img class="sheet" src="overview.png" alt="SetTrace 正式设计概览，包含图形参数、小尺寸、圆形裁切和正反色组合"></a></section>
<section><h2 class="section-title">四种应用展示</h2><div class="gallery">${[['01-swiss-flat','纸白 · 横向组合'],['02-ink-field','墨绿 · 反白组合'],['03-product-context','产品 · 主题衔接'],['04-monochrome','黑白 · 单色适配']].map(([id,label])=>`<button data-image="showcase/${id}.png" aria-label="放大：${label}"><img src="showcase/${id}.png" alt="${label}" loading="lazy"><span>${label} ↗</span></button>`).join('')}</div></section>
<footer><span>正式 SVG 轮廓 / 透明 PNG / 1024 px 图标通用源文件 / 多尺寸导出</span><span><a href="design-guide.md">设计与使用规范</a> · 2026.10.15</span></footer></main><dialog aria-label="品牌应用展示放大图"><button class="close" aria-label="关闭放大图">×</button><img alt="品牌应用展示"></dialog><script>
const sources={icon:['settrace-icon/settrace-icon.preview.svg','深墨绿底、白色三线 SetTrace 图标'],symbol:['logo/settrace-symbol.svg','SetTrace 深墨绿三线独立标记'],lockup:['logo/settrace-lockup.svg','SetTrace 深墨绿横向 Logo']};
document.querySelectorAll('.choices button').forEach(button=>button.addEventListener('click',()=>{const image=document.querySelector('#hero-image');image.src=sources[button.dataset.kind][0];image.alt=sources[button.dataset.kind][1];image.dataset.kind=button.dataset.kind;document.querySelectorAll('.choices button').forEach(item=>item.setAttribute('aria-pressed',String(item===button)))}));
const modal=document.querySelector('dialog');document.querySelectorAll('[data-image]').forEach(button=>button.addEventListener('click',()=>{modal.querySelector('img').src=button.dataset.image;modal.querySelector('img').alt=button.querySelector('img').alt;modal.showModal()}));document.querySelector('.close').addEventListener('click',()=>modal.close());
</script></body></html>`;
await fs.writeFile(path.join(root,'index.html'),html);
await fs.writeFile(path.join(root,'settrace-icon/tmp/work/windows-portability-note.md'),'The local execution copy of author_icon.mjs changes canonical.split("/") to canonical.split(/[\\\\/]+/) for the shallow-directory guard on Windows. The check remains in place; output root was resolved under docs/design/settrace-brand-final/settrace-icon. The installed skill was not modified.\n');
console.log(JSON.stringify({root,overview:[1600,1360],showcases:4,exportSizes:[16,24,32,48,64,128,256,512]}));
