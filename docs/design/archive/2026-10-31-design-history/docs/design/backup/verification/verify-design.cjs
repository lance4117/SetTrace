const { pathToFileURL } = require('node:url');
const path = require('node:path');
const modules = process.env.SETTRACE_NODE_MODULES ?? 'D:/ProgramData/DevCache/Node/node_modules';
const { chromium } = require(path.join(modules, 'playwright'));
const fs = require('node:fs');
const root = path.resolve(__dirname, '..');
const findings = [], checks = [], runtimeErrors = [];
function assert(ok, detail) { checks.push({detail, passed:!!ok}); if(!ok) findings.push(detail); }
(async()=>{
  const browser = await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--allow-file-access-from-files']});
  const page=await browser.newPage({viewport:{width:1440,height:1200},deviceScaleFactor:1});
  page.on('pageerror',e=>runtimeErrors.push(e.message));
  await page.goto(pathToFileURL(path.join(root,'index.html')).href);
  await page.waitForFunction(()=>window.backupDesign);
  const click=async action=>page.locator('#device-host [data-action="'+action+'"], #demo-tools [data-action="'+action+'"]').first().click();
  const state=()=>page.evaluate(()=>window.backupDesign.state);
  const scene=async id=>page.evaluate(id=>window.backupDesign.openScene(id),id);
  await click('page:B02');await click('start-export');await click('finish-export');
  assert((await state()).screen==='B04'&&(await state()).data.workouts===105,'Export succeeds without changing workout data');
  await click('export-done');await click('page:B05');await click('open-picker');await click('picker-cancel');
  assert((await state()).screen==='B05'&&(await state()).data.workouts===105,'Cancelling picker preserves data and returns to selection');
  await click('open-picker');await click('picked-valid');
  await page.locator('#device-host input[data-setting]').uncheck();await click('page:B07');
  assert(await page.locator('#device-host .modal [data-action="cancel-modal"]').evaluate(e=>e===document.activeElement),'Danger confirmation starts with focus on Cancel');
  await click('cancel-modal');
  assert((await state()).screen==='B06'&&!(await state()).restoreSettings,'Cancel keeps data and preview settings');
  assert(await page.locator('#device-host [data-action="page:B07"]').evaluate(e=>e===document.activeElement),'Cancelling modal returns focus to its trigger');
  await click('page:B07');await click('begin-restore');
  assert((await state()).data.workouts===105&&(await state()).copies===0,'Confirming does not replace data before protection succeeds');
  await click('page:E06');assert((await state()).data.workouts===105,'Protection failure keeps original data');
  await click('page:B06');await click('page:B07');await click('begin-restore');await click('protection-done');
  assert((await state()).copies===1&&(await state()).data.workouts===105,'Verified recovery copy exists before replacement');
  await click('commit-operation');assert((await state()).data.workouts===100&&(await state()).hasUndo,'Restore replaces once and makes undo available');
  await click('page:B01');await click('page:B11');await click('page:B12');await click('begin-undo');await click('protection-done');await click('commit-operation');
  assert((await state()).data.workouts===105&&(await state()).copies===2,'Undo restores original workouts and protects the replaced state');
  await scene('B06');await click('stale-preview');await click('refresh-preview');
  assert((await state()).screen==='B06'&&(await state()).data.workouts===106,'Stale preview refreshes comparison without applying old confirmation');
  await scene('E09');const before=(await state()).copies;await click('retry-settings');
  assert((await state()).data.workouts===100&&(await state()).copies===before,'Retrying settings does not repeat data restore');
  await scene('B10');await click('copy:0');await click('page:B20');await click('delete-copy');
  assert((await state()).data.workouts===100&&(await state()).copies===0,'Deleting a recovery copy does not delete workouts');
  await scene('B10');await click('copy:0');await click('export-copy');await click('start-export');await click('finish-export');
  assert((await state()).screen==='B04'&&(await state()).data.workouts===100,'Exporting a recovery copy leaves current records unchanged');
  assert((await page.locator('#device-host .number-pair dd').first().innerText()).includes('105'),'Recovery copy export shows the selected copy count, not current data count');
  await click('export-done');assert((await state()).screen==='B19','Exporting a recovery copy returns to that copy');
  await scene('B07');await page.keyboard.press('Tab');
  assert(await page.locator('#device-host .modal [data-action="begin-restore"]').evaluate(e=>e===document.activeElement),'Modal Tab loop stays within confirmation');
  await page.keyboard.press('Escape');assert((await state()).screen==='B06','Escape cancels confirmation without writing');
  const ids=await page.evaluate(()=>window.backupDesign.scenes);
  let cases=0;const layoutFailures=[];
  for(const locale of ['zh','en'])for(const mode of ['light','dark'])for(const font of ['1','1.6'])for(const width of ['360','430']){
    await page.selectOption('#language',locale);await page.selectOption('#theme',mode);await page.selectOption('#scale',font);await page.selectOption('#device',width);
    for(const id of ids){await scene(id);cases++;
      const issues=await page.locator('#device-host .phone').evaluate(phone=>{
        const errors=[];const scroll=phone.querySelector('.scroll');
        if(scroll.scrollWidth>scroll.clientWidth+2)errors.push('horizontal content overflow '+scroll.scrollWidth+'/'+scroll.clientWidth);
        if(scroll.clientHeight<64)errors.push('content viewport too short '+scroll.clientHeight);
        const modal=phone.querySelector('.modal');if(modal&&modal.scrollWidth>modal.clientWidth+2)errors.push('modal horizontal overflow');
        for(const b of phone.querySelectorAll('button')){if(b.getBoundingClientRect().height<47.5)errors.push('small touch target '+b.textContent.trim());}
        return errors;
      });if(issues.length)layoutFailures.push({id,locale,mode,font,width,issues});
    }
  }
  assert(!layoutFailures.length,`${cases} screen/language/theme/type/width layout cases have no horizontal overflow, short content viewport or small button targets`);
  const extra=[];
  for(const device of ['landscape','tablet'])for(const font of ['1','1.6']){
    await page.selectOption('#device',device);await page.selectOption('#scale',font);
    for(const id of ['B01','B06','B07','B10','B11','B12','B19','E01','E09']){await scene(id);const metrics=await page.locator('#device-host .phone').evaluate(p=>({overflow:p.querySelector('.scroll').scrollWidth-p.querySelector('.scroll').clientWidth,bodyHeight:p.querySelector('.scroll').clientHeight}));if(metrics.overflow>2||metrics.bodyHeight<48)extra.push({device,font,id,...metrics});}
  }
  assert(!extra.length,'Landscape and tablet samples retain readable scroll regions');
  await page.selectOption('#device','360');await page.selectOption('#scale','2');
  for(const id of ['B01','B06','B07','B11','B12','E09']){await scene(id);const overflow=await page.locator('#device-host .phone').evaluate(p=>p.querySelector('.scroll').scrollWidth-p.querySelector('.scroll').clientWidth);assert(overflow<3,'200% type sample '+id+' has no horizontal overflow');}
  await page.emulateMedia({reducedMotion:'reduce'});await scene('B03');
  assert(await page.locator('#device-host .progress-track span').evaluate(e=>getComputedStyle(e).animationName==='none'),'Reduced motion disables progress animation');
  await page.emulateMedia({reducedMotion:'no-preference'});
  const contrast=[];
  for(const mode of ['light','dark'])for(const accent of ['teal','blue','violet','graphite']){
    await page.selectOption('#theme',mode);await page.selectOption('#accent',accent);await scene('B01');
    contrast.push(...await page.locator('#device-host .phone').evaluate((p,{mode,accent})=>{
      const s=getComputedStyle(p),lum=hex=>{let raw=hex.trim().slice(1);if(raw.length===3)raw=raw.split('').map(x=>x+x).join('');const v=raw.match(/.{2}/g).map(x=>parseInt(x,16)/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4);return .2126*v[0]+.7152*v[1]+.0722*v[2]};
      return [['ink','bg',4.5],['ink','surface',4.5],['muted','bg',4.5],['muted','surface',4.5],['on','accent',4.5],['onsoft','soft',4.5],['danger','danger-soft',4.5],['on-danger','danger',4.5],['warn','warn-soft',4.5],['border','surface',3]].map(([a,b,min])=>{const x=lum(s.getPropertyValue('--'+a)),y=lum(s.getPropertyValue('--'+b)),ratio=(Math.max(x,y)+.05)/(Math.min(x,y)+.05);return {mode,accent,pair:a+'/'+b,ratio:+ratio.toFixed(2),minimum:min,passed:ratio>=min};});
    },{mode,accent}));
  }
  assert(contrast.every(x=>x.passed),'All four presets in light/dark meet text and necessary border contrast thresholds');
  await page.selectOption('#accent','teal');
  await page.selectOption('#device','390');await page.selectOption('#scale','1');await page.selectOption('#language','zh');await page.selectOption('#theme','light');
  await scene('B01');await page.locator('.edition').click();await page.screenshot({path:path.join(root,'previews','design-workspace.png'),fullPage:true});
  for(const [id,name,mode,locale] of [['B01','home-light-zh','light','zh'],['B06','restore-preview-light-zh','light','zh'],['B07','restore-confirm-light-zh','light','zh'],['B11','undo-preview-dark-en','dark','en'],['B12','undo-confirm-dark-en','dark','en'],['E09','settings-partial-dark-en','dark','en']]){
    await page.selectOption('#theme',mode);await page.selectOption('#language',locale);await scene(id);await page.locator('.edition').click();await page.locator('#device-host .phone').screenshot({path:path.join(root,'previews',name+'.png')});
  }
  await page.setViewportSize({width:375,height:900});await page.selectOption('#device','360');await page.selectOption('#scale','1.6');await scene('B06');
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+1),'Design preview also fits a 375px browser viewport');
  await page.locator('.edition').click();await page.locator('#device-host .phone').screenshot({path:path.join(root,'previews','small-large-type-dark-en.png')});
  await page.setViewportSize({width:1440,height:1200});await page.selectOption('#device','390');await page.selectOption('#scale','1');
  await page.selectOption('#theme','light');await page.selectOption('#language','zh');await scene('B01');
  await page.click('#gallery-toggle');
  // Contact sheets use actual rendered phone components, not generated mock data images.
  await page.addStyleTag({content:'.rail,.book-header,.controls,.simulation-label,.book-footer,.gallery-heading{display:none!important}.book{margin:0;padding:28px}#gallery-content>.gallery-group{display:none}#gallery-content>.gallery-group:nth-child(2){display:block}.gallery-grid{grid-template-columns:repeat(3,390px);gap:28px}.gallery-card{max-width:390px}.gallery-card .phone{height:844px!important}.gallery-card>.review-button{display:none}.gallery-group>h3{margin-top:0}'});
  await page.setViewportSize({width:1282,height:1100});
  await page.locator('#gallery-content>.gallery-group:nth-child(2)').screenshot({path:path.join(root,'previews','restore-flow-light-zh.png')});
  await page.evaluate(()=>{
    const container=document.getElementById('gallery-content');
    const cards=['B01','B06','B07'].map(id=>[...container.querySelectorAll('.gallery-card')].find(c=>c.querySelector('.phone').dataset.screen===id).cloneNode(true));
    container.innerHTML='<section id="overview-sheet"><div class="edition">SETTRACE / BACKUP & RESTORE</div><h2 style="font-size:32px;margin:16px 0 8px">备份与恢复</h2><p style="color:#586970;margin:0 0 28px">A · 专注工具 / 先看清内容，再确认替换。恢复前自动保留当前数据。</p><div class="gallery-grid"></div></section>';
    container.querySelector('.gallery-grid').append(...cards);
  });
  await page.locator('#overview-sheet').screenshot({path:path.join(root,'previews','overview-light-zh.png')});
  assert(!runtimeErrors.length,'No JavaScript runtime errors');
  const report={scope:'HTML design prototype only; not Flutter, Android storage or database verification',screenCount:ids.length,matrixCases:cases,contrast,checks,layoutFailures,extraLayoutFailures:extra,runtimeErrors,findings};
  fs.writeFileSync(path.join(__dirname,'qa-results.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({screens:ids.length,matrixCases:cases,checks:checks.length,findings,layoutFailureCount:layoutFailures.length,extraLayoutFailures:extra,runtimeErrors},null,2));
  await browser.close();
  if(findings.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
