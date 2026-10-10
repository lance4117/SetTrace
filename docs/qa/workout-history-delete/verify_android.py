"""Reproducible ADB QA on the isolated HistoryDelete AVD only."""
from pathlib import Path
import datetime as dt
import json
import re
import sqlite3
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/qa/workout-history-delete'
TMP = ROOT / '.dart_tool/history-delete-qa'
TMP.mkdir(exist_ok=True)
ADB = r'C:\Users\Lance\AppData\Local\Android\Sdk\platform-tools\adb.exe'
PKG = 'com.settrace.settrace'
TABLES = ['plans', 'plan_exercises', 'workout_sessions', 'session_exercises', 'session_sets']

def adb(*args, check=True):
    result = subprocess.run([ADB, '-s', 'emulator-5554', *args], capture_output=True, check=check, timeout=35)
    return result.stdout

assert b'HistoryDelete' in adb('emu', 'avd', 'name'), 'This script requires the isolated test AVD'

def launch():
    adb('shell', 'am', 'force-stop', PKG)
    adb('shell', 'am', 'start', '-W', '-n', PKG+'/.MainActivity')
    for _ in range(8):
        time.sleep(.5)
        if '设置' in xml():
            return
    raise AssertionError('App home did not become ready')

def xml():
    adb('shell', 'uiautomator', 'dump', '/sdcard/history-delete.xml')
    return adb('exec-out', 'cat', '/sdcard/history-delete.xml').decode('utf-8')

def bounds(node):
    return list(map(int, re.findall(r'\d+', node.attrib['bounds'])))

def find(label, contains=False):
    for _ in range(4):
        nodes = list(ET.fromstring(xml()).iter('node'))
        exact = [n for n in nodes if label in (n.get('text'), n.get('content-desc'))]
        matches = exact or [n for n in nodes if contains and
            any(label in n.get(k, '') for k in ['text','content-desc'])]
        if matches:
            return next((n for n in matches if n.get('clickable')=='true'), matches[-1])
        time.sleep(.5)
    raise AssertionError('UI label absent: '+label+'; '+str([n.get('content-desc') or n.get('text') for n in nodes]))

def tap(label, contains=False):
    n = find(label, contains)
    x1,y1,x2,y2 = bounds(n)
    adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
    time.sleep(.25)
    return bounds(n)

def snap(name):
    (OUT/(name+'.xml')).write_text(xml(),encoding='utf-8')
    (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))

def read_db():
    adb('shell','am','force-stop',PKG)
    target = TMP/'device.db'
    target.write_bytes(adb('exec-out','run-as',PKG,'cat','databases/settrace.db'))
    for suffix in ['-wal','-shm']:
        data = adb('exec-out','run-as',PKG,'cat','databases/settrace.db'+suffix, check=False)
        local = Path(str(target)+suffix)
        if data: local.write_bytes(data)
        elif local.exists(): local.unlink()
    db = sqlite3.connect(target)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    return db

def snapshot(name):
    db=read_db()
    value={table:[dict(row) for row in db.execute('SELECT * FROM '+table+' ORDER BY id')] for table in TABLES}
    assert list(db.execute('PRAGMA foreign_key_check')) == []
    db.close()
    (OUT/(name+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
    return value

def seed():
    db=read_db()
    assert all(db.execute('SELECT count(*) FROM '+t).fetchone()[0] == 0 for t in TABLES), 'QA database must be empty'
    day=dt.date.fromisoformat(adb('shell','date','+%Y-%m-%d').decode().strip())
    old=(day.replace(day=1)-dt.timedelta(days=1)).replace(day=15)
    millis=int(time.time()*1000)
    db.execute('INSERT INTO plans VALUES (901,?,?,?)',('QA_KEEP_PLAN',millis,millis))
    db.execute('INSERT INTO plan_exercises VALUES (901,901,?,1,7,0,0,NULL)',('QA_KEEP_EXERCISE',))
    for sid,name,date,duration,completed,target,active in [
        (901,'QA_DELETE_TARGET',day,1800,6,7,False),
        (902,'QA_KEEP_RECORD',day,600,2,2,False),
        (903,'QA_OLD_RECORD',old,1200,4,5,False),
        (904,'QA_ACTIVE',day,0,0,2,True)]:
        end=millis if sid==901 else millis-3600000 if sid==902 else int(dt.datetime.combine(date,dt.time(12)).timestamp()*1000)
        start=end-duration*1000
        eid=sid*10
        db.execute('INSERT INTO workout_sessions (id,source_plan_id,plan_name_snapshot,started_at,started_local_date,ended_at,duration_seconds,status,current_exercise_order,current_set_number,current_session_exercise_id) VALUES (?,901,?,?,?,?,?,?,1,1,?)',
            (sid,name,start,date.isoformat(),None if active else end,None if active else duration,'in_progress' if active else 'completed',eid))
        db.execute('INSERT INTO session_exercises VALUES (?, ?,901,?,1,?,0,0,NULL)',(eid,sid,'QA_ACTION_'+str(sid),target))
        for n in range(1,target+1):
            db.execute('INSERT INTO session_sets (session_exercise_id,set_number,completed_at,completed_sequence) VALUES (?,?,?,?)',
                (eid,n,end if n<=completed else None,n if n<=completed else None))
    db.commit()
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)')
    db.close()
    adb('push',str(TMP/'device.db'),'/data/local/tmp/history-delete-fixture.db')
    for suffix in ['-wal','-shm']:
        adb('shell','run-as',PKG,'rm','-f','databases/settrace.db'+suffix)
    adb('shell','run-as',PKG,'cp','/data/local/tmp/history-delete-fixture.db','databases/settrace.db')
    launch()
    snapshot('before')
    print(json.dumps({'seeded':True,'date':day.isoformat(),'oldMonth':old.isoformat()}))

def reset_fixture():
    before=json.loads((OUT/'before.json').read_text(encoding='utf-8'))
    db=read_db()
    assert all(str(r['name']).startswith('QA_') for r in db.execute('SELECT name FROM plans'))
    db.execute('DELETE FROM workout_sessions')
    db.execute('DELETE FROM plans')
    for table in TABLES:
        for row in before[table]:
            columns=','.join(row)
            placeholders=','.join('?' for _ in row)
            db.execute('INSERT INTO '+table+' ('+columns+') VALUES ('+placeholders+')',tuple(row.values()))
    db.commit();db.execute('PRAGMA wal_checkpoint(TRUNCATE)');db.close()
    adb('push',str(TMP/'device.db'),'/data/local/tmp/history-delete-fixture.db')
    for suffix in ['-wal','-shm']:
        adb('shell','run-as',PKG,'rm','-f','databases/settrace.db'+suffix)
    adb('shell','run-as',PKG,'cp','/data/local/tmp/history-delete-fixture.db','databases/settrace.db')
    print('Restored isolated QA fixture')

def history():
    launch()
    tap('记录')

def dialog():
    menu=tap('训练记录操作')
    item=tap('删除记录')
    text=xml()
    assert '删除后无法恢复' in text and 'QA_DELETE_TARGET' in text
    button=bounds(find('删除'))
    return {'menu':menu,'item':item,'button':button}

def visual(width,dark):
    density='480' if width==360 else '402'
    adb('shell','wm','density',density)
    adb('shell','settings','put','system','font_scale','1.3')
    launch()
    tap('设置'); tap('深色' if dark else '浅色'); tap('记录')
    tap('QA_DELETE_TARGET',True)
    measured=dialog()
    for b in measured.values():
        x1,y1,x2,y2=b
        # UIAutomator rounds bounds to integer physical pixels.
        minimum=int(48*int(density)/160)
        assert x2-x1>=minimum and y2-y1>=minimum, measured
    name=('dark' if dark else 'light')+'-'+str(width)+'-confirm'
    snap(name)
    tap('取消')
    before=json.loads((OUT/'before.json').read_text(encoding='utf-8'))
    after=snapshot(name+'-cancel')
    assert after==before, 'Cancel must preserve all fields'
    print(json.dumps({'visual':name,'boundsPx':measured,'cancelPreserved':True}))

def deleted_expected(before,sid):
    ids={r['id'] for r in before['session_exercises'] if r['session_id']==sid}
    result={k:list(v) for k,v in before.items()}
    result['workout_sessions']=[r for r in result['workout_sessions'] if r['id']!=sid]
    result['session_exercises']=[r for r in result['session_exercises'] if r['session_id']!=sid]
    result['session_sets']=[r for r in result['session_sets'] if r['session_exercise_id'] not in ids]
    return result

def flow():
    history()
    snap('before-list')
    tap('QA_DELETE_TARGET',True); dialog(); tap('删除')
    text=xml()
    assert 'QA_DELETE_TARGET' not in text and 'QA_KEEP_RECORD' in text
    assert '10 分钟' in text and '最近训练：QA_KEEP_RECORD' in text
    snap('after-delete-list')
    before=json.loads((OUT/'before.json').read_text(encoding='utf-8'))
    after=snapshot('after-delete')
    assert after==deleted_expected(before,901), 'Delete must preserve every unrelated field'
    history(); snap('after-restart-list')
    assert 'QA_DELETE_TARGET' not in xml()
    tap('计划'); assert 'QA_ACTIVE' in xml() and 'QA_KEEP_PLAN' in xml()
    snap('after-restart-plan')
    print(json.dumps({'deleted':901,'exactDatabaseComparison':True,'restart':True,'planAndActivePreserved':True}))

def empty_month():
    history()
    tap('上个月'); tap('QA_OLD_RECORD',True); tap('训练记录操作'); tap('删除记录'); tap('删除')
    text=xml()
    assert '这个月还没有训练记录' in text and '0 分钟' in text and 'QA_KEEP_RECORD' in text
    snap('old-month-empty')
    before=json.loads((OUT/'after-delete.json').read_text(encoding='utf-8'))
    after=snapshot('after-old-delete')
    assert after==deleted_expected(before,903)
    history();tap('QA_KEEP_RECORD',True);tap('训练记录操作');tap('删除记录');tap('删除')
    text=xml()
    assert '最近训练：暂无' in text and '这个月还没有训练记录' in text
    snap('all-history-empty')
    final=snapshot('after-last-delete')
    assert final==deleted_expected(after,902)
    history(); assert '最近训练：暂无' in xml()
    print(json.dumps({'oldMonthEmpty':True,'allHistoryEmpty':True,'activeAndPlanPreserved':True,'restart':True}))

if __name__=='__main__':
    command=sys.argv[1]
    if command=='seed':seed()
    elif command=='reset':reset_fixture()
    elif command=='visual':visual(int(sys.argv[2]),sys.argv[3]=='dark')
    elif command=='flow':flow()
    elif command=='empty':empty_month()
    else:raise ValueError(command)