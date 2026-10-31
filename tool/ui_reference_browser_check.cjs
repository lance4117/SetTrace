// Uses an existing managed Playwright installation; never installs packages.
const fs=require('node:fs');const path=require('node:path');const {pathToFileURL}=require('node:url');
const root=path.resolve(__dirname,'..');const out=path.join(root,'docs/design/current-ui/verification');
const moduleRoot=process.env.UI_REFERENCE_NODE_MODULES;
if(!moduleRoot)throw Error('Set UI_REFERENCE_NODE_MODULES to an existing managed node_modules directory');
const {chromium}=require(path.join(moduleRoot,'playwright'));
(async()=>{
 const profile=path.join(process.env.TEMP,'ui-reference-browser');
 if(!profile.toLowerCase().startsWith('d:\\'))throw Error('Browser profile must be on D:');
 const context=await chromium.launchPersistentContext(profile,{executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--no-first-run','--no-default-browser-check','--disable-background-networking'],viewport:{width:1440,height:1000}});
 const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const url=pathToFileURL(path.join(root,'docs/design/current-ui/overview.html')).href;
 const checks=[];
 try{
  await page.goto(url);await page.locator('.card').first().waitFor();
  checks.push({name:'identity',passed:(await page.title()).includes('SetTrace'),url:page.url()});
  const total=await page.locator('.card').count();checks.push({name:'not-blank',passed:total>0,cards:total});
  await page.screenshot({path:path.join(out,'atlas-desktop.png')});
  await page.locator('#kind').selectOption('release-emulator');
  const release=await page.locator('.card').count();checks.push({name:'source-filter',passed:release>0&&release<total,count:release});
  await page.locator('#language').selectOption('zh');await page.locator('#theme').selectOption('dark');
  await page.locator('#query').fill('L01');const matched=await page.locator('.card').count();
  checks.push({name:'combined-filter',passed:matched>0,count:matched});
  await page.locator('.image').first().click();await page.locator('#viewer').waitFor({state:'visible'});
  checks.push({name:'modal-detail',passed:(await page.locator('#detailTitle').innerText()).includes('L01')});
  await page.keyboard.press('Escape');checks.push({name:'escape-closes',passed:!(await page.locator('#viewer').isVisible())});
  await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(out,'atlas-mobile-filtered.png')});
  checks.push({name:'mobile-no-overflow',passed:await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)});
  const image=page.locator('.image img').first();await image.scrollIntoViewIfNeeded();
  checks.push({name:'local-image-load',passed:await image.evaluate(e=>e.complete&&e.naturalWidth>0)});
  checks.push({name:'console-health',passed:errors.length===0,errors});
 }finally{await context.close();}
 const result={created:new Date().toISOString(),browser:'Chrome / existing managed Playwright',browser_plugin:'Absent: Browser plugin and browser skill not listed in session',
  dependency_location:'Read-only application-managed runtime; no installation; browser profile and TEMP on D:',flow:'offline atlas -> source/language/theme/search filters -> screenshot detail -> Escape -> mobile',checks};
 fs.writeFileSync(path.join(out,'browser-qa.json'),JSON.stringify(result,null,2));
 console.log(JSON.stringify(result));if(checks.some(x=>!x.passed))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
