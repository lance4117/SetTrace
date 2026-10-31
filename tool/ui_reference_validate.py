"""Check the self-contained UI reference, historical bytes and protected scope."""
import html
import json
import re
import struct
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote,urlsplit
from ui_reference import ROOT,RUN,CURRENT,DESIGN,ARCHIVE,load,dump,sha,now,links,protected_files,git

def anchors(path):
    if path.suffix not in ['.md','.html']:return set()
    text=path.read_text(encoding='utf-8-sig');out=set(re.findall(r'\bid=["\']([^"\']+)',text));seen={}
    for title in re.findall(r'^#{1,6}\s+(.+)$',text,re.M):
        title=re.sub(r'\[([^\]]+)\]\([^)]+\)',r'\1',title)
        title=html.unescape(title).strip().lower()
        title=re.sub(r'[^\w\s\-\u4e00-\u9fff]','',title,flags=re.UNICODE).replace(' ','-')
        count=seen.get(title,0);seen[title]=count+1
        out.add(title if not count else title+'-'+str(count))
    return out

def main():
    errors=[];checks=[]
    def check(name,items,**facts):
        checks.append({'check':name,'result':'passed-current' if not items else 'failed','errors':items,**facts});errors.extend(items)
    migration=load(ARCHIVE/'migration-manifest.json');baseline=load(RUN/'baseline.json')
    bad=[]
    for row in migration['files']:
        p=(ROOT/row['target']).resolve()
        if ROOT not in p.parents or not p.exists() or sha(p)!=row['sha256']:bad.append(row['source'])
    check('migration-original-hashes',bad,files=len(migration['files']),unique_sources=len({r['source'] for r in migration['files']}))
    before=baseline['protected_files'];after=protected_files()
    authorized_new={}
    archive_record=CURRENT/'verification/openspec-archive.json'
    if archive_record.exists():
        record=load(archive_record)
        assert record['target']=='openspec/changes/archive/2026-10-31-consolidate-design-and-current-ui'
        assert not (ROOT/record['source']).exists()
        for item in record['files']:
            p=(ROOT/record['target']/item['path']).resolve()
            assert (ROOT/record['target']).resolve() in p.parents
            authorized_new[p.relative_to(ROOT).as_posix()]=item['sha256']
    check('protected-production-business-history', [p for p in sorted(set(before)|set(after)|set(authorized_new)) if (before.get(p) if p in before else authorized_new.get(p))!=after.get(p)],files=len(before),authorized_archive_additions=len(authorized_new))
    files=[p for p in CURRENT.rglob('*') if p.suffix in ['.md','.html']]
    files += [ROOT/'README.md',DESIGN/'README.md',ARCHIVE/'README.md']
    files += [ROOT/r['path'] for r in migration['compatibility'] if r['kind']=='redirect']
    bad=[];link_count=0;anchor_count=0;pre_existing_current=[]
    for p in set(files):
        text=p.read_text(encoding='utf-8-sig')
        if p.suffix=='.html':text=re.sub(r'<script\b[^>]*>.*?</script>','',text,flags=re.S|re.I)
        # Embedded JSON contains no navigable HTML; only actual attributes and Markdown links count.
        for value,target,anchor in links(p,text):
            if value.startswith(('tel:','about:')):continue
            link_count+=1
            if not target.exists():
                item={'source':p.relative_to(ROOT).as_posix(),'link':value,'reason':'missing-target'}
                if p==ROOT/'README.md' and value in git('show','HEAD:README.md'):
                    pre_existing_current.append(item)
                else:bad.append(item)
            elif anchor:
                anchor_count+=1
                if unquote(anchor) not in anchors(target):bad.append({'source':p.relative_to(ROOT).as_posix(),'link':value,'reason':'missing-anchor'})
        # Fragment-only anchors skipped by the shared migration scanner.
        for fragment in re.findall(r'\]\(#([^)]+)\)',text):
            anchor_count+=1
            if unquote(fragment) not in anchors(p):bad.append({'source':str(p.relative_to(ROOT)),'link':'#'+fragment,'reason':'missing-anchor'})
    check('current-links-and-anchors',bad,files=len(set(files)),local_links=link_count,anchors=anchor_count,pre_existing_unchanged=pre_existing_current)
    bad=[];immutable_refs=[]
    for ref in load(RUN/'references-before.json'):
        if ref['immutable_source'] and ref['existed']:
            target=ROOT/ref['target'];immutable_refs.append(ref)
            if not target.exists():bad.append(ref)
            elif ref['anchor'] and unquote(ref['anchor']) not in anchors(target):bad.append(ref)
    for row in migration['compatibility']:
        if row['kind']=='evidence-copy' and sha(ROOT/row['path'])!=sha(ROOT/row['original']):bad.append(row)
    check('required-historical-compatibility',bad,entries=len(migration['compatibility']),historical_references=len(immutable_refs))
    manifest=load(CURRENT/'manifest.json');bad=[];seen=set();paths=set()
    for row in manifest['captures']:
        if row['capture_id'] in seen:bad.append('duplicate '+row['capture_id'])
        seen.add(row['capture_id']);paths.add(row['path']);p=(CURRENT/row['path']).resolve()
        if CURRENT not in p.parents or not p.exists():bad.append('invalid path '+row['path']);continue
        raw=p.read_bytes()
        if not raw.startswith(b'\x89PNG\r\n\x1a\n') or sha(p)!=row['sha256']:bad.append('hash/png '+row['path'])
        elif struct.unpack('>II',raw[16:24])!=(row['pixel_width'],row['pixel_height']):bad.append('dimensions '+row['path'])
        if row.get('ui_tree') and not (CURRENT/row['ui_tree']).exists():bad.append('missing tree '+row['capture_id'])
    orphans=[p.relative_to(CURRENT).as_posix() for p in (CURRENT/'screenshots').rglob('*.png') if p.relative_to(CURRENT).as_posix() not in paths]
    check('capture-manifest-and-images',bad+orphans,captures=len(seen),orphan_images=len(orphans))
    required=[f'{p}{n:02}' for p,end in [('P',6),('W',6),('S',4),('X',4),('H',5),('D',16)] for n in range(1,end+1)]
    required += ['C01','C02','C04','C05','D18']+[f'B{n:02}' for n in range(1,21) if n!=16]
    required += ['L01','L02','L03','L04','L05','L06','L08','D15','D16']
    bad=[]
    for screen in set(required):
        actual={(r['language'],r['theme']) for r in manifest['captures'] if r['screen_id']==screen}
        missing={(lang,theme) for lang in ['zh','en'] for theme in ['light','dark']}-actual
        if missing:bad.append({'screen_id':screen,'missing':sorted(missing)})
    check('principal-four-combination-capture-matrix',bad,screen_ids=len(set(required)),scope='Images only; release and widget sources explicit; platform-only states and fault conditions separately scoped')
    bad=[];results=load(CURRENT/'verification/results.json')
    assert results['path_base']=='current-ui'
    for result in results['checks']:
        if result['result']=='passed-current' and not result.get('evidence'):bad.append('no evidence '+result['id'])
        for evidence in result.get('evidence',[]):
            p=(CURRENT/evidence).resolve()
            if ROOT not in p.parents or not p.exists():bad.append('missing evidence '+evidence)
    check('results-evidence',bad,checks=len(results['checks']),path_base=results['path_base'])
    bad=[];sequence_count=0
    for p in (CURRENT/'verification').glob('*-scroll-sequence.json'):
        data=load(p);sequence_count+=1
        if not data['ended_at_scroll_boundary'] or any(frame not in seen for frame in data['frames']):bad.append(p.name)
    check('scroll-sequence-original-frames',bad,sequences=sequence_count,derived_images=0)
    bad=[];brand=CURRENT/'assets/brand'
    for p in [brand/'logo/settrace-symbol-white.svg',brand/'settrace-icon/layers/01-background.svg']:ET.parse(p)
    if 'docs/design/current-ui/assets/brand' not in (ROOT/'tool/generate_android_icons.py').read_text():bad.append('icon-generator-source')
    check('brand-inputs-parse-without-generation',bad,svg_files=2,runtime_resources_regenerated=False)
    build=load(CURRENT/'verification/build.json');bad=[]
    for path,digest in build['source_fingerprint'].items():
        if sha(ROOT/path)!=digest:bad.append(path)
    check('build-source-identity',bad,source_commit=build['source_commit'],apk_sha256=build['apk_sha256'])
    check('single-current-home', [str(p) for p in (ROOT/'work/ui-sketches').rglob('*') if p.is_file() and p.name!='README.md'],home='docs/design/current-ui')
    config=(ROOT/'openspec/config.yaml').read_text(encoding='utf-8');bad=[]
    for p in re.findall(r'docs/design/current-ui/[\w/.-]+',config):
        if not (ROOT/p.rstrip('.')).exists():bad.append(p)
    check('openspec-current-reading-paths',bad)
    bad=[];json_count=0
    for p in CURRENT.rglob('*.json'):
        json_count+=1
        try:load(p)
        except (ValueError,UnicodeError) as error:bad.append({'path':p.relative_to(CURRENT).as_posix(),'error':str(error)})
    check('current-json-syntax',bad,files=json_count)
    report={'created':now(),'baseline_id':manifest['baseline_id'],'result':'passed-current' if not errors else 'failed','checks':checks,
      'historical_policy':'Archived originals are byte-preserved; original relative-link context and pre-existing failures are recorded separately, not asserted repaired.',
      'pre_existing_broken_links':'pre-existing-broken-links.json','errors':len(errors)}
    dump(CURRENT/'verification/documentation-checks.json',report)
    print(json.dumps({'errors':len(errors),'checks':len(checks),'details':errors[:25]},ensure_ascii=False))
    if errors:raise SystemExit(1)

if __name__=='__main__':main()
