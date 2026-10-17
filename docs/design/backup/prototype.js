'use strict';
// Design-only state machine. No file APIs, persistence, network, or application data.
const $ = (s, root = document) => root.querySelector(s);
let language = 'zh', theme = 'light', accent = 'teal', scale = '1', device = '390';
let currentScreen = 'B01', galleryOpen = false, restoreSettings = true;
const t = (zh, en) => language === 'zh' ? zh : en;
const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const path = {
  back:'m15 6-6 6 6 6', next:'m9 6 6 6-6 6', arrow:'M4 12h16m-6-6 6 6-6 6',
  check:'m5 12 4 4L19 6', down:'M12 3v12m-5-5 5 5 5-5M5 15v5h14v-5',
  upload:'M12 16V4m-5 5 5-5 5 5M5 15v5h14v-5',
  file:'M14 3H6v18h12V7l-4-4v5h4M9 12h6M9 16h6',
  folder:'M3 6h7l2 3h9v11H3V6Z',
  history:'M3 10a9 9 0 1 1 1 7M3 4v6h6m3-4v6l4 2',
  undo:'M9 5 3 11l6 6M3 11h11a6 6 0 0 1 6 6',
  shield:'m12 3 8 3v5c0 5-3 8-8 10-5-2-8-5-8-10V6l8-3Zm-4 9 3 3 5-6',
  info:'M12 8h.01M12 11v6M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0',
  warning:'m12 3 10 18H2L12 3Zm0 6v5m0 3h.01',
  x:'m6 6 12 12M18 6 6 18',
  clock:'M12 6v6l4 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0',
  list:'M9 5h12M9 12h12M9 19h12M3 5h.01M3 12h.01M3 19h.01',
  settings:'m9 3-1 3-3 1-2 3 2 2-1 3 2 3 3-1 3 2 3-2 3 1 2-3-1-3 2-2-2-3-3-1-1-3H9Zm6 9a3 3 0 1 1-6 0 3 3 0 0 1 6 0',
  trash:'M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7m4-7v7',
  signal:'M4 18v-4m5 4V9m5 9V5m5 13V2', battery:'M2 7h17v10H2V7Zm20 3v4M5 10h11v4H5v-4Z',
  spinner:'M21 12a9 9 0 1 1-9-9', more:'M5 12h.01M12 12h.01M19 12h.01',
};
function icon(name, extra='') { return `<svg class="${extra}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${path[name] || path.info}"/></svg>`; }
function btn(label, action, kind='', disabled=false) { return `<button type="button" class="btn ${kind}" data-action="${action}" ${disabled?'disabled':''}>${label}</button>`; }
function ib(name, label, action, disabled=false) { return `<button type="button" class="icon-button" aria-label="${esc(label)}" data-action="${action}" ${disabled?'disabled':''}>${icon(name)}</button>`; }
function notice(text, kind='', symbol='info') { return `<div class="notice ${kind}">${icon(symbol)}<div>${text}</div></div>`; }
function row(symbol, title, description, action) { return `<button type="button" class="row-button" data-action="${action}">${icon(symbol,'leading')}<div><strong>${title}</strong>${description?`<small>${description}</small>`:''}</div>${icon('next','chevron')}</button>`; }
function meta(label, value) { return `<div class="meta-row"><span>${label}</span><strong>${value}</strong></div>`; }
function rules(items) { return `<div class="rule-list">${items.map(([title,detail])=>`<div class="rule-item">${icon('check')}<div><b>${title}</b><p>${detail}</p></div></div>`).join('')}</div>`; }
function result(symbol,title,subtitle,kind='') { return `<div class="result ${kind}"><div class="result-mark">${icon(symbol,symbol==='spinner'?'spinner':'')}</div><h2>${title}</h2><p>${subtitle}</p></div>`; }
function stats(d) { return `<div class="card"><dl class="number-pair"><div><dt>${t('训练记录','Saved workouts')}</dt><dd>${d.workouts}<span>${t('条','')}</span></dd></div><div><dt>${t('训练计划','Training plans')}</dt><dd>${d.plans}<span>${t('个','')}</span></dd></div></dl><div class="data-range">${d.workouts?t('训练日期：','Workout dates: ')+d.range:t('还没有已保存的训练记录','No saved workouts yet')}</div></div>`; }
function compare(a,b) { return `<div class="comparison"><div class="compare-side"><div class="caption">${t('当前设备','On this device')}</div><b>${a.workouts}</b><span class="unit">${t('条训练记录','workouts')}</span><div class="plan-count">${a.plans} ${t('个训练计划','plans')}</div></div>${icon('arrow','arrow')}<div class="compare-side target"><div class="caption">${t('恢复后','After restoring')}</div><b>${b.workouts}</b><span class="unit">${t('条训练记录','workouts')}</span><div class="plan-count">${b.plans} ${t('个训练计划','plans')}</div></div></div>`; }
function settingsCheck() { return `<label class="checkbox-row"><input type="checkbox" data-setting="restore-settings" ${restoreSettings?'checked':''}><span><b>${t('同时恢复应用设置','Restore app settings too')}</b><small>${t('外观、语言与休息提醒偏好。系统权限保持当前设备的状态。','Appearance, language and reminder preferences. Device permissions stay as they are.')}</small></span></label>`; }
const filename = 'SetTrace-backup-20261012-203000.settrace.json';
const exportFilename = 'SetTrace-backup-20261016-203000.settrace.json';
const source = () => ({plans:6, workouts:100, range:'2026.01.03 – 2026.10.12', date:'2026.10.12 · 20:30', file:filename});
const initial = () => ({plans:8,workouts:105,range:'2026.01.03 – 2026.10.16',date:'2026.10.16 · 20:30'});
function baseData() { return {data:initial(),backup:source(),copies:[],lastExport:'2026.10.12 · 20:30',changed:true,hasUndo:false,selectedCopy:null,mode:'restore',exportData:null,protected:false,lastResult:null,undoRestoreSettings:true}; }
let demo = baseData();
const scenes = [
  ['实施补充状态','B04a','文件已保存、记账待修复','公共文件已成功，不重复导出；仅核实既有目标并修复标记。'],
  ['', 'E02a','超过支持容量','首版上限64 MiB；整份无损停止，不截断或要求删除历史。'],
  ['', 'B16a','中断检查失败','核心结果未核实前限制正常写入，仅重试检查。'],
  ['', 'B01d','首页保留设置待处理入口','离开结果页后仍能只重试设置或使用当前设置继续。'],
  ['入口与备份','B00','设置入口','数据与备份放在提醒之后、关于之前，保留原设置顺序与三个主导航。'],
  ['', 'B01','备份与恢复','默认主操作为创建完整备份。上次成功导出只描述历史操作，不承诺文件仍存在或数据已同步。'],
  ['', 'B01a','从未备份','用“尚未创建备份”描述状态，不制造安全评分、紧迫倒计时或反复提醒。'],
  ['', 'B01b','空数据','允许创建空数据备份，明确 0 条记录；恢复入口始终可用，不强迫先建计划。'],
  ['', 'B01c','读取失败','无法读取不等于没有数据。隐藏未知数量，提供重试读取；恢复前也必须重新验证当前数据。'],
  ['', 'B02','创建备份','一次备份全部已保存计划、历史和可迁移设置。使用完整范围说明，不引入复杂的勾选导出。'],
  ['', 'B03','正在创建','用真实阶段描述读取、生成、保存和核对，不显示虚构百分比。原型由右侧推进演示。'],
  ['', 'B04','备份已保存','成功页给出文件名、公共下载位置和数据数量，用户能知道去哪找。只有完整写入与核对成功才进入。'],
  ['选择与恢复','B05','选择备份','先解释整份恢复，再调用系统文件选择器。不在应用内模仿 Android 文件界面。'],
  ['', 'B05a','等待文件选择','此画面只表示系统选择器打开期间的应用背景。真实 Android UI 不属于本设计稿；右侧选择模拟结果。'],
  ['', 'B06','恢复预览','当前与恢复后并排对照，说明数量差不等于精确的新增／删除差异。日期与完整文件名可查看。'],
  ['', 'B07','替换确认','一次后果明确的确认，不要求输入口令或重复勾选。取消是默认焦点，红色动作明确叫“替换并恢复”。'],
  ['', 'B08','保留当前数据','先创建并验证恢复前副本，成功后才能替换；不允许用户跳过这一步。'],
  ['', 'B08a','正在恢复','核心替换期间防重复与返回。原生提醒与其他写入需由未来实现统一协调，UI 不展示这些内部细节。'],
  ['', 'B09','恢复完成','显示真实恢复数量，提供查看记录与撤回入口；回到备份首页仍能找到撤回。'],
  ['副本与撤回','B10','恢复前副本','副本入口长期可达，逐项显示时间、用途和数量。保存在应用内，卸载会删除，可另行导出长期保留。'],
  ['', 'B11','撤回预览','撤回也会替换当前数据。清楚展示恢复后的新增变化，并先保护现在的数据，不把撤回当成无风险按钮。'],
  ['', 'B12','撤回确认','明确回到哪一天、恢复多少记录；不删除恢复后新增内容的唯一副本。'],
  ['', 'B13','保留撤回前数据','与恢复共用安全步骤。任何副本失败都必须停止，不能为了撤回而越过保护。'],
  ['', 'B13a','正在撤回','只执行一次替换，保留新建副本。中断后走统一检查流程。'],
  ['', 'B14','撤回完成','回到恢复前的数据，刚才的状态仍在副本列表。用明确完成状态结束，不只给瞬间提示条。'],
  ['', 'B19','副本详情','可导出、恢复或删除指定副本。删除只影响副本文件，不删除当前训练记录。'],
  ['', 'B20','删除副本确认','确认显示副本时间和训练数量。删除最后一个撤回依据时说明撤回入口将不可用。'],
  ['训练与中断','B15','尚有活动训练','建议规则：备份和恢复前先处理活动训练，入口直接回到既有训练页；不在此自动保存或丢弃。'],
  ['', 'B16','中断后检查','启动时先判定持久化结果。检查期间不显示空首页，也不直接宣称恢复失败或成功。'],
  ['', 'B17','已保留原数据','仅在确认旧数据仍完整时展示。可以重新预览文件，不能直接重放旧确认。'],
  ['', 'B18','已完成恢复','中断前已提交时报告成功；仅重新加载，不重复导入。'],
  ['异常与可恢复状态','E01','备份版本较新','不展示 schemaVersion 或数据库版本。解释需要更新应用，保留文件并明确当前数据未变。'],
  ['', 'E02','文件内容损坏','整份拒绝，不静默跳过坏记录，也不从部分可读内容开始恢复。'],
  ['', 'E03','选到计划文件','识别现有计划分享文件并引导原计划导入；不把计划文件当完整备份。'],
  ['', 'E04','导出空间不足','说明未创建完整备份、原数据未变。清理空间后重试，成功记录不提前更新。'],
  ['', 'E05','下载目录不可写','按平台实际原因提示。旧版 Android 仅在用户重试时走必要授权，不泛化为始终需要存储权限。'],
  ['', 'E06','保护副本失败','恢复没有开始，原数据保持。重试重新校验预览，不提供强制覆盖入口。'],
  ['', 'E07','恢复失败已回滚','仅在验证回滚成功后说明原数据完整。重试回到预览，避免误认为再次点击会重复新增。'],
  ['', 'E08','预览已过期','当前数据在预览后改变，必须重新读取并让用户确认新对比；旧确认不执行。'],
  ['', 'E09','仅设置恢复失败','训练数据已经恢复成功。只重试设置，或继续使用当前有效设置，不重新替换训练数据。'],
  ['', 'E10','恢复后刷新失败','区分已提交成功与读取失败。重试只读取，不重新恢复。'],
  ['', 'E11','副本不可用','找不到或无法读取副本时撤回不可提交；当前训练数据保持，并提供选择其他备份。'],
  ['', 'E12','副本删除失败','保留副本和撤回资格，只重试删除，不影响当前训练记录。'],
  ['', 'E13','撤回失败已回滚','验证当前数据完整后说明撤回未生效；原恢复前副本与撤回前副本均保留。'],
  ['', 'E14','文件读取失败','取消选择正常返回；真实读取失败单独解释，允许重新选择且不保留旧文件预览。'],
];
const lookup = Object.fromEntries(scenes.map(s=>[s[1],s]));
const undoPages = ['B11','B12','B13','B13a','E13'];
const completedPages = ['B09','B10','B19','B20','E09','E10','E11','E12','B18','B01d'];
const blockingPages = ['B03','B08','B08a','B13','B13a','B16','B16a'];
const modalPages = ['B07','B12','B20'];
function sceneData(id) {
  const d=baseData();
  if(id==='B01a') {d.lastExport=null;d.changed=false;}
  if(id==='B01b') {d.data={plans:0,workouts:0,range:'',date:initial().date};d.lastExport=null;d.changed=false;}
  if(completedPages.includes(id)||undoPages.includes(id)) {
    d.data={...source()};d.copies=[{...initial(),id:'copy-1',reason:'restore'}];d.selectedCopy=d.copies[0];d.undoTarget=d.copies[0];d.hasUndo=true;d.lastResult='restore';
  }
  if(undoPages.includes(id)){d.mode='undo';d.data.workouts=102;d.data.range='2026.01.03 – 2026.10.16';}
  if(id==='B14'){d.data=initial();d.copies=[{...source(),id:'copy-2',date:'2026.10.16 · 20:35',reason:'undo'},{...initial(),id:'copy-1',reason:'restore'}];d.hasUndo=false;d.lastResult='undo';}
  if(id==='B04') {d.exportData=initial();d.lastExport=initial().date;d.changed=false;}
  return d;
}
function header(title, root=false, busy=false) { return `<div class="app-header ${root?'root':''}">${root?'':ib('back',t('返回','Back'),'back',busy)}<h1 tabindex="-1">${title}</h1></div>`; }
function bottomNav() { return `<div class="bottom-nav"><button class="nav-item" data-action="outside:plans">${icon('list')}${t('计划','Plans')}</button><button class="nav-item" data-action="outside:history">${icon('history')}${t('记录','History')}</button><button class="nav-item selected" aria-current="page" data-action="page:B00">${icon('settings')}${t('设置','Settings')}</button></div><div class="gesture"></div>`; }
function footer(content) { return `<div class="app-footer">${content}<div class="gesture"></div></div>`; }
function wrap(id,title,body,foot='',options={}) {
  const root=options.root||false, busy=blockingPages.includes(id);
  return `<div class="phone ${theme==='dark'?'dark':''} ${device==='landscape'?'landscape':''} ${device==='tablet'?'tablet':''}" data-screen="${id}" data-accent="${accent}" data-scale="${scale}" lang="${language==='en'?'en':'zh-CN'}" style="--scale:${scale};--app-width:${device==='landscape'?740:device==='tablet'?768:device}px;--app-height:${device==='landscape'?390:device==='360'?800:device==='430'||device==='tablet'?900:844}px"><div class="statusbar" aria-hidden="true"><span>9:41</span><span class="status-icons">${icon('signal')}5G${icon('battery')}</span></div>${header(title,root,busy)}<div class="scroll" tabindex="0" aria-label="${esc(t('页面内容','Page content'))}">${body}</div>${options.nav?bottomNav():foot?footer(foot):'<div class="gesture"></div>'}<div class="app-live" role="status" aria-live="polite"></div></div>`;
}
function progressBody(title,subtitle,active,undo=false,exporting=false) {
  const labels=exporting?[t('读取完整数据','Read all data'),t('保存到下载目录','Save to Downloads'),t('核对备份文件','Verify the backup')]:[t(undo?'保留撤回前的数据':'保留当前数据',undo?'Keep a copy before undoing':'Keep a copy of current data'),t(undo?'恢复到之前的状态':'恢复计划与训练记录',undo?'Return to the previous state':'Restore plans and workouts'),t('核对结果并恢复设置','Check results and restore settings')];
  return `${result('spinner',title,subtitle)}<div class="progress-track" role="progressbar" aria-label="${esc(title)}" aria-valuetext="${esc(labels[active])}"><span></span></div><div class="card"><ol class="steps">${labels.map((s,i)=>`<li class="${i<active?'done':i===active?'current':''}" ${i===active?'aria-current="step"':''}><span class="step-dot">${i<active?icon('check'):i+1}</span><span>${s}</span></li>`).join('')}</ol></div><p class="small muted">${exporting?t('请等待文件保存完成。当前训练数据不会改变。','Please wait for the file to finish saving. Your training data will not change.'):t('正在处理，请稍候。完成前暂时无法返回或开始其他操作。','Please wait. Back and other actions are temporarily unavailable until this finishes.')}</p>`;
}
function home(d) {
  return `${stats(d.data)}<div><div class="section-label">${t('文件备份','Backup file')}</div><div class="card"><div class="label-icon">${icon('clock')}<div><h3>${d.lastExport?t('上次成功导出','Last successful export'):t('尚未创建备份','No backup created yet')}</h3><p>${d.lastExport||t('把训练积累保存成一份文件。','Save your training history in a file.')}</p></div></div>${d.lastExport&&d.changed?notice(t('此后数据已有变化，建议创建新备份。','Your data has changed since then. Create a new backup.'),'warn','info'):''}${btn(icon('down')+t('创建完整备份','Create full backup'),'page:B02')}<p class="tiny muted">${t('文件保存在下载目录，卸载应用后仍保留。','The file is saved in Downloads and remains after uninstalling.')}</p></div></div>${row('history',t('从备份恢复','Restore from backup'),t('选择文件，预览后整份恢复','Choose a file, review it, then restore'),'page:B05')}${d.hasUndo?notice(`<strong>${t('需要回到恢复前？','Need your previous data?')}</strong>${btn(t('撤回上次恢复','Undo last restore'),'page:B11','ghost')}`):''}${row('undo',t('恢复前副本','Recovery copies'),d.copies.length?t(`${d.copies.length} 份 · 可找回恢复前的数据`,`${d.copies.length} saved · Return to earlier data`):t('恢复时自动保留，方便撤回','Kept automatically before a restore'),'page:B10')}<p class="tiny muted">${t('备份文件不会自动更新。换机或卸载前，请再保存一份。','Backup files do not update automatically. Save a new one before moving devices or uninstalling.')}</p>`;
}
function preview(d,undo=false) {
  const target=undo?(d.selectedCopy||d.copies[0]||initial()):d.backup;
  return `<div class="label-icon">${icon(undo?'undo':'file')}<div><h3>${t(undo?'恢复前的数据':'备份内容',undo?'Your previous data':'Backup contents')}</h3><p>${target.date}</p></div></div>${compare(d.data,target)}<p class="small muted">${t('训练日期：','Workout dates: ')}${target.range}</p>${notice(t(undo?'撤回会整份替换当前计划和记录。恢复后新产生的数据，也会先保留为副本。':'恢复会整份替换当前计划和记录，不会与现有数据合并。','This replaces all current plans and workouts. '+(undo?'Any data added since restoring will be kept in a recovery copy first.':'It does not merge with existing data.')),'warn','warning')}${undo?notice(d.undoRestoreSettings?t('撤回同时恢复原设置。','Undo also restores the original app settings.'):t('本次撤回保留当前应用设置。','This undo keeps the current app settings.')):settingsCheck()}<div class="label-icon">${icon('shield')}<div><h3>${t('先保留，再替换','Keep a copy before replacing')}</h3><p>${t('当前数据会先保存为恢复前副本。副本保存失败时，恢复不会开始。','Your current data is saved as a recovery copy first. If that fails, the restore will not start.')}</p></div></div><details class="disclosure"><summary>${t('查看文件与备份详情','File and backup details')}</summary><div class="details-body"><div class="file">${esc(target.file||t('应用内恢复前副本','Recovery copy in this app'))}</div><p style="margin-top:12px">${t('包含计划、动作配置、完整训练快照与应用设置。完成、跳过和未完成组保持原样。','Includes plans, exercise settings, complete workout snapshots and app settings. Completed, skipped and unfinished sets stay distinct.')}</p>${meta(t('创建备份的应用版本','Created with app version'),'0.2.5')}${meta(t('文件大小','File size'),'186 KB')}</div></details>`;
}
function modal(title,text,content,action,label,extra='') {
  return `<div class="modal-scrim"><section class="modal" role="dialog" aria-modal="true" aria-label="${esc(title)}" tabindex="-1"><h2>${title}</h2><p>${text}</p>${content}${extra}${btn(label,action,'danger')}${btn(t('取消','Cancel'),'cancel-modal','ghost')}</section></div>`;
}
const errors = {
  E01:['warning','需要更新应用才能恢复','Update the app to restore this backup','这份备份使用了当前应用尚不支持的格式。请更新 SetTrace 后再试，或选择其他备份。','This backup uses a newer format. Update SetTrace and try again, or choose another backup.','选择其他备份','Choose another backup','page:B05'],
  E02:['file','这份备份无法使用','This backup cannot be used','文件可能不完整，或包含无法恢复的内容。请选择原始的完整备份文件。','The file may be incomplete or contain invalid data. Choose the original, complete backup file.','重新选择文件','Choose another file','page:B05'],
  E03:['list','这是训练计划文件','This is a training plan file','它只包含计划和动作配置，没有训练记录。可以通过原有的计划导入功能添加。','It contains plans and exercise settings, without workout history. Use Import plans to add it.','前往计划导入','Go to Import plans','outside:import'],
  E04:['folder','空间不足，备份未保存','Not enough space to save','请腾出一些设备空间后重试。本次没有生成完整的备份文件。','Free up some device storage and try again. No complete backup file was created.','重试创建备份','Try creating a backup again','retry-export'],
  E05:['folder','无法保存到下载目录','Cannot save to Downloads','下载目录暂时不可写。请检查设备存储和必要的访问权限，再重试。','Downloads is currently unavailable. Check device storage and any required access permission, then try again.','重试保存','Try saving again','retry-export'],
  E06:['shield','未能保留当前数据','Could not keep a recovery copy','可能是设备空间不足。请检查存储后重试；为保护现有记录，本次恢复尚未开始。','Device storage may be full. Check storage and try again. The restore has not started, so your existing records are protected.','重新检查并预览','Check and review again','page:B06'],
  E07:['history','恢复未完成，原数据已保留','Restore failed; original data kept','本次更改已经回退，原来的计划和训练记录完整保留。可以重新预览后再试。','The changes were rolled back. Your original plans and workouts are intact. Review the backup again before retrying.','重新预览备份','Review the backup again','page:B06'],
  E08:['info','当前数据有变化','Your current data has changed','预览后又有数据更新。请重新查看对比，再确认恢复。','Data changed after the preview. Review the updated comparison before confirming.','更新预览','Refresh preview','refresh-preview'],
  E09:['info','记录已恢复，部分设置未恢复','Workouts restored; settings need attention','计划和训练记录已经恢复成功。未恢复的设置继续使用当前有效值，可以单独重试。','Your plans and workouts were restored. Settings that could not be restored keep their current valid values. Retry settings separately.','重试恢复设置','Retry settings only','retry-settings'],
  E10:['info','恢复成功，页面暂未刷新','Restored; page could not refresh','备份中的数据已经保存。请重新加载查看结果，无需再次恢复。','The backup data was saved. Reload the result; there is no need to restore again.','重新加载','Reload result','page:B09'],
  E11:['file','恢复前副本暂不可用','Recovery copy unavailable','这份副本可能已被移除，或暂时无法读取。可以重试读取，或选择其他备份。','This copy may have been removed or cannot be read. Retry reading it, or choose another backup.','重试读取','Retry reading','page:B19'],
  E12:['trash','副本未能删除','Could not delete the copy','这份副本仍然保留。请稍后重试。','The recovery copy has been kept. Please try again.','重试删除','Retry deleting','page:B20'],
  E13:['undo','撤回未完成，当前数据已保留','Undo failed; current data kept','本次撤回已经回退。当前记录与恢复前副本都保留，可以重新预览后再试。','The undo was rolled back. Current records and recovery copies have been kept. Review the comparison again before retrying.','重新预览撤回','Review undo again','page:B11'],
  E14:['file','无法读取文件','Cannot read this file','文件可能已移动，或文件提供方暂时不可用。请重新选择可读取的备份。','The file may have moved, or its provider may be unavailable. Choose an accessible backup file.','重新选择文件','Choose a file again','page:B05'],
};
function render(id, gallery=false) {
  const d=gallery?sceneData(id):demo;
  let title=t('备份与恢复','Backup & restore'),body='',foot='';
  if(id==='B04a') return wrap(id,t('备份文件已保存','Backup file saved'),`${result('check',t('文件已保存在下载目录','The file is in Downloads'),exportFilename)}${notice(t('导出标记未更新。只核实既有文件并修复标记，不再创建文件。','The export marker needs attention. Verify the existing file and repair the marker without creating another file.'),'warn')}`,btn(t('修复导出标记','Repair export marker'),'page:B04'));
  if(id==='E02a') return wrap(id,title,result('warning',t('文件超过64 MiB','File exceeds 64 MiB'),t('未更改当前数据。请选择支持容量内的完整备份；不会截断记录。','Current data is unchanged. Choose a supported full backup; records are never truncated.')),btn(t('重新选择文件','Choose another file'),'open-picker'));
  if(id==='B16a') return wrap(id,title,result('warning',t('暂时无法核实上次操作','Unable to verify the previous operation'),t('保留所有数据和保护副本，正常写入暂不可用。请重试检查。','All data and recovery copies are kept. Writes remain unavailable until the check succeeds.')),btn(t('重试检查','Retry check'),'page:B16'));
  if(id==='B01d') return wrap(id,title,`${notice(t('记录已恢复，部分设置仍待处理。','Workouts are restored; settings still need attention.'),'warn')}${home(d)}`,btn(t('只重试设置','Retry settings only'),'retry-settings')+btn(t('使用当前设置继续','Continue with current settings'),'page:B01','ghost'));
  if(id==='B00') return wrap(id,t('设置','Settings'),`<div class="section-label">${t('休息提醒','Rest reminders')}</div><div class="card">${meta(t('休息结束提醒','Rest reminders'),t('已开启','On'))}${meta(t('重复提醒','Repeat reminders'),t('每 10 秒','Every 10 seconds'))}</div><div><div class="section-label">${t('数据','Data')}</div>${row('folder',title,t('完整备份、恢复与撤回','Full backup, restore and undo'),'page:B01')}</div><div><div class="section-label">${t('关于 SetTrace','About SetTrace')}</div><div class="card"><h3>SetTrace</h3><p class="small muted">${t('轻量、离线的训练记录工具','A simple, offline workout notebook')}</p>${meta(t('版本','Version'),'0.2.4 (10)')}</div></div>`,'',{root:true,nav:true});
  if(['B01','B01a','B01b'].includes(id)) return wrap(id,title,home(d));
  if(id==='B01c') return wrap(id,title,`${result('info',t('暂时无法读取数据','Unable to read your data'),t('没有更改任何计划或记录。请重试读取，恢复前也会再次检查当前数据。','No plans or workouts were changed. Try reading again; current data will also be checked before restoring.'),'warn')}${btn(t('重试读取','Try reading again'),'page:B01')}${row('history',t('从备份恢复','Restore from backup'),t('选择文件后先预览','Choose a file to review'),'page:B05')}`);
  if(id==='B02') {
    title=t('创建完整备份','Create full backup');
    body=`<p class="small muted">${t('保存此刻的计划与训练积累。','Save your plans and training history as they are now.')}</p>${stats(d.exportData||d.data)}<div><div class="section-label">${t('这份备份包含','Included in this backup')}</div>${rules([[t('全部训练计划','All training plans'),t('动作、顺序与默认配置','Exercises, order and default settings')],[t('全部已保存训练','All saved workouts'),t('包括提前结束的训练及每组的真实状态','Including partial workouts and each set’s actual state')],[t('应用设置','App settings'),t('外观、语言与休息提醒偏好','Appearance, language and reminder preferences')]])}</div><div class="card"><div class="label-icon">${icon('folder')}<div><h3>${t('保存到下载目录','Save to Downloads')}</h3><p>${t('生成独立文件，卸载后仍保留。','A separate file that remains after uninstalling.')}</p></div></div></div><p class="small muted">${t('文件包含个人训练记录，请保存在你信任的位置。','The file contains personal workout records. Keep it somewhere you trust.')}</p>`;
    foot=btn(icon('down')+t('保存备份文件','Save backup file'),'start-export');
  } else if(id==='B03') {title=t('创建备份','Create backup');body=progressBody(t('正在保存备份','Saving your backup'),t('正在整理计划与训练记录。','Preparing your plans and workouts.'),1,false,true);}
  else if(id==='B04') {title=t('备份已保存','Backup saved');body=`${result('check',title,t('你的训练积累，已有一份独立文件。','Your training history is saved in a separate file.'))}${stats(d.exportData||d.data)}<div class="card"><div class="label-icon">${icon('file')}<div><h3>${t('备份文件','Backup file')}</h3><p class="file">${exportFilename}</p></div></div>${meta(t('保存位置','Saved in'),t('公共下载目录 / Downloads','Public Downloads folder'))}${meta(t('导出时间','Exported at'),'2026.10.16 · 20:30')}</div><p class="small muted">${t('可在系统“文件”应用的下载目录找到它。换机时，把这个文件复制到新设备再恢复。','Find it in Downloads in your system Files app. Copy it to your new device to restore there.')}</p>`;foot=btn(t('完成','Done'),'export-done');}
  else if(id==='B05') {title=t('从备份恢复','Restore from backup');body=`${result('history',t('找回你的训练积累','Bring your training history back'),t('选择 SetTrace 完整备份文件，先预览内容，再决定是否恢复。','Choose a full SetTrace backup. Review its contents before deciding to restore.'))}${rules([[t('计划与记录一起恢复','Plans and workouts together'),t('包括训练快照与真实完成情况','Including workout snapshots and actual set states')],[t('替换前先保护当前数据','Protect current data first'),t('自动保留恢复前副本，之后可以撤回','A recovery copy is kept automatically so you can undo')],[t('确认前不会修改数据','No changes before confirmation'),t('选错文件或取消，都不会影响现有记录','A wrong file or cancellation leaves your data as it is')]])}<p class="small muted">${t('恢复会整份替换，不自动合并。仅分享训练安排时，请使用“计划导入”。','Restoring replaces all data without merging. To add shared training plans, use Import plans.')}</p>`;foot=btn(icon('folder')+t('选择备份文件','Choose backup file'),'open-picker');}
  else if(id==='B05a') {title=t('选择备份文件','Choose backup file');body=result('folder',t('等待选择文件','Waiting for a file'),t('请在系统文件选择器中选择备份。取消选择不会修改数据。','Choose your backup in the system file picker. Cancelling will not change your data.'));}
  else if(id==='B06'||id==='B07') {
    title=t('恢复预览','Review restore');body=preview(d);foot=btn(t('继续','Continue'),'page:B07')+btn(t('重新选择文件','Choose another file'),'open-picker','ghost');
    if(id==='B07') {const html=wrap('B06',title,body,foot);return html.replace(/<\/div>$/,`${modal(t('替换当前数据？','Replace current data?'),t('当前计划和训练记录将替换为这份备份中的内容。','Your current plans and workouts will be replaced with the contents of this backup.'),`<div class="target-file">${d.backup.date}<br><strong>${d.backup.workouts} ${t('条训练记录','workouts')} · ${d.backup.plans} ${t('个计划','plans')}</strong></div>${notice(t('我们会先保留当前数据。副本保存成功后才开始恢复。','We will keep a copy of your current data before starting the restore.'),'','shield')}`, 'begin-restore',t('替换并恢复','Replace and restore'),`<p class="small muted">${restoreSettings?t('同时恢复应用设置','App settings will also be restored'):t('保留当前应用设置','Current app settings will be kept')}</p>` )}</div>`).replace('data-screen="B06"','data-screen="B07"');}
  } else if(id==='B08'||id==='B08a') {title=t('恢复备份','Restore backup');body=progressBody(t(id==='B08'?'正在保留当前数据':'正在恢复训练记录',id==='B08'?'Keeping your current data':'Restoring your workouts'),t(id==='B08'?'保存并核对恢复前副本。':'恢复前副本已保存。',id==='B08'?'Saving and checking a recovery copy.':'Your recovery copy has been saved.'),id==='B08'?0:1);}
  else if(id==='B09'||id==='B18') {title=t('恢复完成','Restore complete');body=`${result('check',t('训练记录已恢复','Your workouts are back'),t(id==='B18'?'上次操作已完成，数据已经核对。':'计划和训练记录已恢复，统计已更新。',id==='B18'?'The previous operation completed. Your data has been checked.':'Plans and workouts are restored, and statistics are updated.'))}${stats(d.data)}${notice(t('恢复前的数据已保留，需要时可以撤回本次恢复。','Your previous data has been kept. You can undo this restore if needed.'),'','shield')}${row('undo',t('撤回本次恢复','Undo this restore'),t('回到恢复前的计划与记录','Return to your previous plans and workouts'),'page:B11')}`;foot=btn(t('查看训练记录','View workouts'),'outside:history')+btn(t('返回备份与恢复','Back to Backup & restore'),'page:B01','ghost');}
  else if(id==='B10') {
    title=t('恢复前副本','Recovery copies');body=`<p class="small muted">${t('每次恢复或撤回前，自动保留当时的数据。','A copy is kept before each restore or undo.')}</p>${d.copies.length?`<div class="copy-list">${d.copies.map((c,i)=>`<div class="copy-entry"><div class="entry-title"><span>${c.date}</span>${i===0?`<span class="badge">${t('最近','Latest')}</span>`:''}</div><p>${c.reason==='undo'?t('撤回前保留','Kept before undoing'):t('恢复前保留','Kept before restoring')}</p><p>${c.workouts} ${t('条记录','workouts')} · ${c.plans} ${t('个计划','plans')}</p>${btn(t('查看副本','View copy'),'copy:'+i,'ghost')}</div>`).join('')}</div>`:result('undo',t('还没有恢复前副本','No recovery copies yet'),t('进行恢复时，会先为当前数据保留一份。','A copy of your current data will be kept when you restore.'))}${notice(t('副本保存在应用内，卸载会删除。需要长期保留时，请将副本导出为文件。','These copies are stored inside the app and are removed on uninstall. Export a copy to a file to keep it long term.'),'warn','info')}`;
  } else if(id==='B11'||id==='B12') {
    title=t('撤回上次恢复','Undo last restore');body=preview(d,true);foot=btn(t('继续','Continue'),'page:B12');
    if(id==='B12') {const target=d.selectedCopy||d.copies[0]||initial();return wrap('B11',title,body,foot).replace(/<\/div>$/,`${modal(t('回到恢复前的数据？','Return to your previous data?'),t('当前数据将替换为下面的恢复前副本。恢复后新增的数据，也会先另存一份。','Current data will be replaced with this recovery copy. Any data added after restoring will be saved in another copy first.'),`<div class="target-file">${target.date}<br><strong>${target.workouts} ${t('条训练记录','workouts')} · ${target.plans} ${t('个计划','plans')}</strong></div>`,'begin-undo',t('保留当前数据并撤回','Keep current data and undo'))}</div>`).replace('data-screen="B11"','data-screen="B12"');}
  } else if(id==='B13'||id==='B13a') {title=t('撤回恢复','Undo restore');body=progressBody(t(id==='B13'?'正在保留当前数据':'正在撤回恢复',id==='B13'?'Keeping your current data':'Undoing the restore'),t('完成后回到上次恢复前的状态。','Your data will return to the state before the last restore.'),id==='B13'?0:1,true);}
  else if(id==='B14') {title=t('已撤回恢复','Restore undone');body=`${result('check',t('已回到恢复前','Your previous data is back'),t('计划与训练记录已恢复到之前的状态。','Plans and workouts are back to their previous state.'))}${stats(d.data)}${notice(t('撤回前的数据也已保留，可在“恢复前副本”中查看。','The data from before undoing has also been kept in Recovery copies.'),'','shield')}`;foot=btn(t('完成','Done'),'page:B01')+btn(t('查看恢复前副本','View recovery copies'),'page:B10','ghost');}
  else if(id==='B15') {title=t('先处理当前训练','Finish your current workout first');body=`${result('clock',t('还有一场训练未结束','A workout is still in progress'),t('先回到训练页继续，或使用已有的结束保存操作，再进行备份或恢复。','Return to your workout to continue or use the existing save-and-finish action, then back up or restore.'))}<div class="card"><h3>练背</h3><p class="small muted">${t('已完成 8 / 15 组 · 今天 18:02 开始','8 / 15 sets completed · Started today at 18:02')}</p></div><p class="small muted">${t('此处不会自动结束、保存或丢弃训练。','Your workout is not automatically finished, saved or discarded here.')}</p>`;foot=btn(t('返回当前训练','Return to current workout'),'outside:workout')+btn(t('稍后处理','Later'),'page:B01','ghost');}
  else if(id==='B16') {title=t('检查上次恢复','Checking the last restore');body=`${result('spinner',t('正在检查上次操作','Checking the previous operation'),t('上次恢复时应用关闭了。正在确认数据状态，请稍候。','The app closed during the last restore. Please wait while the data state is checked.'))}<div class="progress-track" role="progressbar" aria-label="${esc(title)}"><span></span></div><p class="small muted">${t('检查完成后会显示结果。现在不会重复恢复，也不会创建空白数据。','The result will appear when the check finishes. The restore is not repeated, and no empty data is created.')}</p>`;}
  else if(id==='B17') {title=t('上次恢复未完成','The last restore did not finish');body=`${result('shield',t('原来的数据已保留','Your original data is kept'),t('已确认计划和训练记录完整。你可以继续使用，或重新选择备份。','Your plans and workouts have been checked and are intact. Continue using the app or choose a backup again.'))}${stats(d.data)}`;foot=btn(t('继续使用','Continue'),'page:B01')+btn(t('重新选择备份','Choose backup again'),'page:B05','ghost');}
  else if(id==='B19'||id==='B20') {
    const c=d.selectedCopy||d.copies[0]||initial();title=t('副本详情','Recovery copy details');
    body=`<div class="label-icon">${icon('undo')}<div><h3>${t('恢复前副本','Recovery copy')}</h3><p>${c.date}</p></div></div>${stats(c)}${notice(t('此副本保存在应用内。导出后，可以在卸载或换机时使用。','This copy is stored inside the app. Export it to use after uninstalling or moving devices.'))}${btn(icon('down')+t('导出这份副本','Export this copy'),'export-copy','secondary')}${btn(t('使用此副本恢复','Restore this copy'),'restore-copy','outline')}<p class="small muted">${t('删除副本只移除这份副本，不会删除当前训练记录。','Deleting this copy does not delete any current workout records.')}</p>${btn(t('删除这份副本','Delete this copy'),'page:B20','danger-text')}`;
    if(id==='B20')return wrap('B19',title,body).replace(/<\/div>$/,`${modal(t('删除这份副本？','Delete this recovery copy?'),t('删除后无法再使用这份副本恢复。当前计划和训练记录不受影响。','You will no longer be able to restore this copy. Your current plans and workouts will not change.'),`<div class="target-file">${c.date}<br>${c.workouts} ${t('条训练记录','workouts')}</div>${notice(t('如果这是上次恢复的副本，删除后将无法撤回那次恢复。','If this is the copy from the last restore, deleting it will remove that undo option.'),'warn','warning')}`,'delete-copy',t('删除副本','Delete copy'))}</div>`).replace('data-screen="B19"','data-screen="B20"');
  } else if(errors[id]) {
    const e=errors[id],partial=['E09','E10'].includes(id);title=partial?t('恢复结果','Restore result'):['E04','E05'].includes(id)?t('创建备份','Create backup'):t('备份与恢复','Backup & restore');
    body=`${result(e[0],t(e[1],e[2]),t(e[3],e[4]),partial?'warn':'error')}${partial?stats(d.data):notice(t('当前计划与训练记录没有改变。','Your current plans and workouts have not changed.'),'','shield')}${id==='E01'?`<details class="disclosure"><summary>${t('查看备份信息','Backup information')}</summary><div class="details-body"><p class="file">${filename}</p>${meta(t('创建备份的应用版本','Created with app version'),'0.3.0')}</div></details>`:''}`;
    let action=e[7]; if(id==='E06'&&d.mode==='undo')action='page:B11';
    foot=btn(t(e[5],e[6]),action)+(id==='E09'?btn(t('使用当前设置继续','Continue with current settings'),'page:B09','ghost'):id==='E03'||id==='E11'?btn(t('选择其他备份','Choose another backup'),'page:B05','ghost'):btn(t('返回','Back'),'error-back','ghost'));
  }
  return wrap(id,title,body,foot);
}
function noteTools(id) {
  let items=[];
  if(id==='B03')items=[['完成保存并核对','finish-export'],['演示空间不足','page:E04'],['演示目录不可写','page:E05']];
  if(id==='B05a')items=[['模拟选择完整备份','picked-valid'],['模拟取消选择','picker-cancel'],['模拟版本较新','page:E01'],['模拟文件损坏','page:E02'],['模拟计划分享文件','page:E03'],['模拟读取失败','page:E14']];
  if(id==='B08'||id==='B13')items=[['副本保存并校验成功','protection-done'],['演示副本保存失败','page:E06']];
  if(id==='B08a'||id==='B13a')items=[['恢复／撤回成功','commit-operation'],['演示写入失败并回滚',id==='B13a'?'page:E13':'page:E07'],['演示进程中断','page:B16']];
  if(id==='B16')items=[['检查：原数据完整','page:B17'],['检查：操作已提交','startup-committed']];
  if(id==='B06')items=[['演示预览后数据变化','stale-preview'],['演示尚有活动训练','page:B15']];
  if(id==='B09')items=[['演示仅设置恢复失败','page:E09'],['演示结果刷新失败','page:E10']];
  if(id==='B11')items=[['演示副本不可读取','page:E11']];
  if(id==='B20')items=[['演示删除失败','page:E12']];
  if(!items.length)return '';
  return `<div class="demo-tools"><p>评审工具 · 模拟平台或处理结果<br>这些按钮不属于应用界面。</p>${items.map(([label,action])=>`<button data-action="${action}" type="button">${label}</button>`).join('')}</div>`;
}
function navRender() {
  $('#screen-nav').innerHTML=scenes.map(([group,id,name])=>`${group?`<div class="nav-group">${group}</div>`:''}<button class="nav-link ${id===currentScreen?'active':''}" data-scene="${id}" ${id===currentScreen?'aria-current="page"':''}><span>${id}</span>${name}</button>`).join('');
}
function renderStage(focus=true) {
  const meta=lookup[currentScreen];
  $('#device-host').innerHTML=render(currentScreen);
  $('#screen-code').textContent=currentScreen;$('#screen-title').textContent=meta[2];$('#note-title').textContent=meta[2];$('#note-body').textContent=meta[3];$('#demo-tools').innerHTML=noteTools(currentScreen);
  $('#stage').classList.toggle('wide-device',['landscape','tablet'].includes(device));
  navRender();
  const phone=$('#device-host .phone'),dialog=$('.modal',phone);
  if(dialog){for(const child of phone.children)if(!child.classList.contains('modal-scrim'))child.inert=true;if(focus)$('[data-action="cancel-modal"]',dialog).focus({preventScroll:true});}
  else if(focus)$('.app-header h1',phone)?.focus({preventScroll:true});
  if(focus)history.replaceState(null,'','#'+currentScreen);
}
function page(id,focus=true){currentScreen=id;renderStage(focus);}
function openScene(id){if(!lookup[id])return;demo=sceneData(id);restoreSettings=true;page(id);if(galleryOpen)toggleGallery(false);}
function goBack(){
  if(blockingPages.includes(currentScreen))return;
  if(modalPages.includes(currentScreen)){const previous=currentScreen;page({B07:'B06',B12:'B11',B20:'B19'}[previous]);$(`#device-host [data-action="page:${previous}"]`)?.focus({preventScroll:true});return;}
  if(currentScreen==='B00'){showOutside('settings');return;}
  if(currentScreen==='B05a'){demo.backup=source();page('B05');return;}
  if(currentScreen==='B19'){page('B10');return;}
  if(['B06','E01','E02','E03','E14'].includes(currentScreen)){page('B05');return;}
  if(currentScreen==='B01'){page('B00');return;}
  if(currentScreen==='B04'){exportDone();return;}
  page('B01');
}
function exportDone(){demo.exportData=null;page(demo.copyExport?'B19':'B01');demo.copyExport=false;}
function showOutside(which){
  const texts={history:['训练记录入口','接入既有 H01 记录列表，重新读取当前数据。设计原型止于此处；真实训练记录不会被创建或修改。'],plans:['训练计划入口','接入既有 P01 计划列表。现有训练计划功能保持原样。'],workout:['继续训练入口','接入当前活动训练，由原有流程继续、保存或放弃。原型不代替真实训练处理。'],import:['计划导入入口','接入既有 X02 计划导入，保留本次选择的计划文件，不自动导入。'],settings:['设置入口','返回既有设置页。']};
  const [a,b]=texts[which]||texts.settings;
  $('#demo-tools').innerHTML=`<div class="demo-tools" role="status"><p><strong>${a}</strong><br>${b}</p><button data-action="page:B01">返回备份原型</button></div>`;
  $('#demo-tools').scrollIntoView({block:'nearest',behavior:'auto'});
}
function handle(action){
  if(!action)return;
  if(action.startsWith('page:')){const next=action.slice(5);if(next==='B11'&&demo.undoTarget)demo.selectedCopy=demo.undoTarget;page(next);return;}
  if(action.startsWith('outside:')){showOutside(action.slice(8));return;}
  if(action.startsWith('copy:')){demo.selectedCopy=demo.copies[Number(action.slice(5))];page('B19');return;}
  switch(action){
    case 'back':goBack();break;
    case 'cancel-modal':goBack();break;
    case 'error-back':page(currentScreen==='E12'?'B19':currentScreen==='E13'?'B11':'B01');break;
    case 'start-export':demo.exportData={...(demo.exportData||demo.data)};page('B03');break;
    case 'retry-export':page('B02');break;
    case 'finish-export':if(!demo.copyExport){demo.lastExport=initial().date;demo.changed=false;}page('B04');break;
    case 'export-done':exportDone();break;
    case 'open-picker':demo.backup=null;page('B05a');break;
    case 'picker-cancel':demo.backup=source();page('B05');break;
    case 'picked-valid':demo.backup=source();page('B06');break;
    case 'begin-restore':demo.undoRestoreSettings=restoreSettings;demo.mode='restore';demo.protected=false;page('B08');break;
    case 'begin-undo':demo.mode='undo';demo.protected=false;demo.selectedCopy=demo.selectedCopy||demo.copies[0]||initial();page('B13');break;
    case 'protection-done': {
      if(!demo.protected){const c={...demo.data,id:'copy-'+Date.now(),date:'2026.10.16 · 20:35',reason:demo.mode};demo.copies.unshift(c);demo.protected=true;if(demo.mode==='restore')demo.undoTarget=c;}
      page(demo.mode==='undo'?'B13a':'B08a');break;
    }
    case 'commit-operation': {
      if(demo.mode==='undo'){demo.data={...(demo.selectedCopy||initial())};demo.hasUndo=false;demo.lastResult='undo';demo.changed=true;page('B14');}
      else {demo.data={...(demo.backup||source())};demo.hasUndo=true;demo.selectedCopy=demo.undoTarget||demo.copies[0];demo.lastResult='restore';demo.changed=true;page('B09');}break;
    }
    case 'startup-committed':if(demo.mode==='undo'){demo.data={...(demo.selectedCopy||initial())};demo.hasUndo=false;demo.lastResult='undo';page('B14');}else{demo.data={...(demo.backup||source())};demo.hasUndo=true;if(!demo.copies.length)demo.copies=[{...initial(),id:'startup-copy',reason:'restore'}];demo.selectedCopy=demo.copies[0];demo.undoTarget=demo.copies[0];page('B18');}break;
    case 'stale-preview':demo.data.workouts++;demo.changed=true;page('E08');break;
    case 'refresh-preview':page('B06');break;
    case 'retry-settings':page('B09');break;
    case 'export-copy':demo.exportData={...(demo.selectedCopy||demo.copies[0]||initial())};demo.copyExport=true;page('B02');break;
    case 'restore-copy':demo.backup={...(demo.selectedCopy||demo.copies[0]||initial()),file:t('应用内恢复前副本','Recovery copy in this app')};page('B06');break;
    case 'delete-copy':{const c=demo.selectedCopy||demo.copies[0];demo.copies=demo.copies.filter(x=>x.id!==c?.id);if(demo.undoTarget?.id===c?.id)demo.hasUndo=false;demo.selectedCopy=null;page('B10');break;}
  }
}
function renderGallery(){
  const groups=[['01 / 创建一份完整备份',['B00','B01','B02','B03','B04','B01a','B01b','B01c']],['02 / 看清内容，再确认恢复',['B05','B05a','B06','B07','B08','B08a','B09']],['03 / 恢复前副本与撤回',['B10','B11','B12','B13','B13a','B14','B19','B20']],['04 / 活动训练与中断恢复',['B15','B16','B17','B18']],['05 / 异常状态与下一步',Object.keys(errors)]];
  $('#gallery-content').innerHTML=groups.map(([label,ids])=>`<section class="gallery-group"><h3>${label}</h3><div class="gallery-grid">${ids.map(id=>`<article class="gallery-card"><div class="screen-heading"><span>${id}</span><span>${lookup[id][2]}</span></div><div inert>${render(id,true)}</div><p>${lookup[id][3]}</p><button type="button" class="review-button" data-scene="${id}">打开交互 →</button></article>`).join('')}</div></section>`).join('');
}
function toggleGallery(force){galleryOpen=typeof force==='boolean'?force:!galleryOpen;$('#gallery').hidden=!galleryOpen;$('#stage').hidden=galleryOpen;$('#gallery-toggle').textContent=galleryOpen?'返回交互原型':'查看流程总览';if(galleryOpen)renderGallery();}
document.addEventListener('click',e=>{const scene=e.target.closest('[data-scene]');if(scene){openScene(scene.dataset.scene);return;}const action=e.target.closest('[data-action]');if(action&&!action.disabled&&!action.closest('[inert]'))handle(action.dataset.action);});
document.addEventListener('change',e=>{if(e.target.matches('[data-setting]'))restoreSettings=e.target.checked;});
document.addEventListener('keydown',e=>{
  const modal=$('#device-host .modal');
  if(modal&&modal.contains(e.target)&&e.key==='Tab'){const focusable=[...modal.querySelectorAll('button,a,input,[tabindex="0"]')].filter(x=>!x.disabled),first=focusable[0],last=focusable.at(-1);if(e.shiftKey&&e.target===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&e.target===last){e.preventDefault();first.focus();}}
  if(e.key==='Escape'&&$('#device-host').contains(e.target)){e.preventDefault();goBack();}
});
for(const id of ['language','theme','accent','scale','device'])$('#'+id).addEventListener('change',e=>{
  const value=e.target.value;
  if(id==='language')language=value;if(id==='theme')theme=value;if(id==='accent')accent=value;if(id==='scale')scale=value;if(id==='device')device=value;
  const scroll=$('#device-host .scroll')?.scrollTop||0;
  renderStage(false);if($('#device-host .scroll'))$('#device-host .scroll').scrollTop=scroll;if(galleryOpen)renderGallery();
});
$('#reset').addEventListener('click',()=>{demo=baseData();restoreSettings=true;page('B01');if(galleryOpen)toggleGallery(false);});
$('#gallery-toggle').addEventListener('click',()=>toggleGallery());
const requested=location.hash.slice(1);if(lookup[requested]){currentScreen=requested;demo=sceneData(requested);}renderStage(false);
// Exposed only for repeatable design QA, with no application integration.
window.backupDesign={scenes:scenes.map(s=>s[1]),openScene,renderGallery,get state(){return {screen:currentScreen,data:demo.data,copies:demo.copies.length,hasUndo:demo.hasUndo,restoreSettings};}};
