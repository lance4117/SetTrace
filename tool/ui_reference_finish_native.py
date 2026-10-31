"""Finish full-scroll current release references on the owned readonly AVD."""
import json
import os
import time
from ui_reference import ROOT, CURRENT, RUN, load, dump, now
from ui_reference_android import adb, nodes, tap, top, seek, capture, sequence

os.environ['UI_REFERENCE_QUIET']='1'

def labels(language):
    return load(ROOT/f'lib/l10n/app_{language}.arb')

def back():
    adb('shell','input','keyevent','4')
    time.sleep(.8)

if __name__=='__main__':
    # Previous collection ended on choose explanation. Verify before navigating.
    l=labels('zh')
    assert any(l['backupChooseFile'] in (n.get('text','')+n.get('content-desc','')) for n in nodes())
    tap(l['backupChooseFile']);time.sleep(1.5)
    assert any('documentsui' in n.get('package','') for n in nodes())
    capture('B05a','backup','system-picker-stable','zh','dark')
    back();back();back()
    assert any(l['settings'] in (n.get('text','')+n.get('content-desc','')) for n in nodes())
    previous='zh'
    for language,theme in [('en','light'),('en','dark'),('zh','light'),('zh','dark')]:
        top();self_name='English' if language=='en' else '中文'
        seek(self_name);tap(self_name)
        l=labels(language);top()
        tap(l['darkTheme'] if theme=='dark' else l['lightTheme'])
        top();sequence('C01','settings',language,theme)
        # Each sequence needs a unique report; the generic collector overwrites its summary.
        dump(CURRENT/'verification'/f'C01-{language}-{theme}-scroll-sequence.json',load(CURRENT/'verification/C01-scroll-sequence.json'))
        top();seek(l['backupTitle']);tap(l['backupTitle'])
        top();sequence('B01','backup',language,theme)
        dump(CURRENT/'verification'/f'B01-{language}-{theme}-scroll-sequence.json',load(CURRENT/'verification/B01-scroll-sequence.json'))
        top();tap(l['backupCreate']);sequence('B02','backup',language,theme)
        dump(CURRENT/'verification'/f'B02-{language}-{theme}-scroll-sequence.json',load(CURRENT/'verification/B02-scroll-sequence.json'))
        back();back()
    dump(CURRENT/'verification/native-full-scroll.json',{'finished':now(),'combinations':['en-light','en-dark','zh-light','zh-dark'],'pages':['C01','B01','B02'],'method':'original segments; body pixel boundary checked; license detail separate'})
