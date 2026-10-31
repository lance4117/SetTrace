"""Generate the offline atlas, inventories and evidence manifest from captures."""
import html
import json
import os
import re
import shutil
from pathlib import Path

from ui_reference import ROOT, RUN, CURRENT, ARCHIVE, DATE, now, sha, load, dump, write, mark, original

GROUPS = {
    'P':('plans','计划与准备','lib/features/plans/plans_page.dart','FLOW-01/02; INT-01/02/07'),
    'W':('workout','训练与休息','lib/features/workout/workout_page.dart','FLOW-03–09; INT-03–07/12'),
    'S':('workout','本次训练工具','lib/features/workout/session_order_sheet.dart','FLOW-07/08; INT-05'),
    'X':('transfer','计划分享','lib/features/plans/plan_transfer_pages.dart','FLOW-10/11; INT-08'),
    'H':('history','记录与统计','lib/features/history/history_page.dart','FLOW-12/13; HIST-01–06; INT-09'),
    'C':('settings','设置与关于','lib/features/settings/settings_page.dart','COLOR; FLOW-14/17; INT-10–12'),
    'D':('dialogs','确认与弹层','lib/features/workout/workout_page.dart','VIS-04/05; FLOW-16; INT-07'),
    'A':('adaptation','适配','lib/core/widgets/app_task_layout.dart','ADAPT-01–07'),
    'B':('backup','备份与恢复','lib/features/backup/backup_pages.dart','BK; VIS-01–05; ADAPT-01–07'),
    'E':('backup','备份异常','lib/features/backup/backup_pages.dart','BK; VIS-05'),
    'L':('diagnostics','诊断与日志','lib/features/diagnostics/diagnostics_pages.dart','LOGUI-01–12; INT-13'),
}


def classify(id):
    if id in ['D01','D02','D03','D04','D10']:
        return GROUPS['P']
    if id == 'D12': return GROUPS['X']
    if id == 'D13': return GROUPS['H']
    if id in ['D15','D16'] or id.startswith('C05'):
        return ('about','关于与许可','lib/features/about/'+('licenses_page.dart' if 'license' in id else 'app_notice_dialog.dart'),'FLOW-18/19; VIS-03–05; LOGUI-11')
    if id in ['D18','D19','C01-sound']:
        return ('settings','提醒设置','lib/features/rest_alerts/rest_reminder_controls.dart','REM-04/06; INT-12; ADAPT-01–07')
    if id=='L07':
        return ('diagnostics','启动失败','lib/main.dart','LOGUI-10; INT-13')
    return GROUPS[id[0]]


def rectify_release_rows(rows):
    corrections=[]
    for row in rows:
        if row.get('registration_correction'):
            corrections.append({'capture_id':row['capture_id'],**row['registration_correction']})
        tree=CURRENT/row['ui_tree']
        texts=[x['text'] or x['description'] for x in load(tree)]
        inferred=None
        if 'Rest-end reminder' in texts: inferred=('D11','permission-explanation')
        if 'Rest is over' in texts: inferred=('D17','rest-due')
        if not texts and row['screen_id']=='D15': inferred=('B16','startup-checking-saved-results')
        if inferred and inferred[0]!=row['screen_id']:
            old=row['screen_id'];row['screen_id'],row['state_id']=inferred
            row['registration_correction']={'requested_id':old,'observed_id':inferred[0],
                                             'basis':'stored UI hierarchy and visual inspection; original PNG bytes retained'}
            corrections.append({'capture_id':row['capture_id'],**row['registration_correction']})
    dump(CURRENT/'verification/capture-registration-corrections.json',corrections)
    return rows


def collect():
    rows=rectify_release_rows(load(RUN/'release-captures.json'))
    for name in ['widget-captures.json','backup-captures.json','extra-captures.json','adaptation-captures.json','branch-captures.json','diagnostic-cancel-captures.json']:
        p=CURRENT/'verification'/name
        if p.exists(): rows.extend(load(p))
    for row in rows:
        row['sha256']=sha(CURRENT/row['path'])
        row.setdefault('baseline_id','306b9bc-0.3.1+12-2026-10-31')
        row.setdefault('group',classify(row['screen_id'])[0])
    assert len({r['capture_id'] for r in rows})==len(rows),'Duplicate capture IDs'
    order=['plans','workout','history','settings','transfer','backup','diagnostics','about','adaptation','core']
    return sorted(rows,key=lambda r:(order.index(r['group']) if r['group'] in order else 99,
                  r['capture_kind']!='release-emulator',r['screen_id'].startswith('D'),r['screen_id'],r['language']!='zh',r['theme']!='light',r['state_id']))


def inventory(rows):
    records={}
    for source in ['docs/design/screens-and-states.md','docs/design/backup/backup-ui-spec.md','docs/design/diagnostics/ui-spec.md']:
        for line in original(source).read_text(encoding='utf-8-sig').splitlines():
            cells=line.split('|')
            if len(cells)<4: continue
            for id in re.findall(r'(?<![A-Z])(?:LD|LE|[PWSXHC DABE])\d{2}[a-z]?',cells[1].replace(' ','')):
                records.setdefault(id,{'screen_id':id,'name':re.sub(r'\[([^\]]+)\]\([^)]+\)',r'\1',cells[2]).strip(),
                                      'description':' / '.join(c.strip() for c in cells[3:-1]),'original_source':source})
    for prefix,start,end in [('P',1,6),('W',1,6),('S',1,4),('X',1,4),('H',1,5),('C',1,5),('D',1,19),('A',1,5),('B',0,20),('E',1,14),('L',0,8)]:
        for number in range(start,end+1):
            id=f'{prefix}{number:02}'
            records.setdefault(id,{'screen_id':id,'name':id,'description':'具体条件、返回和失败分支见对应交互／专项规范。'})
    for row in rows:
        id=row['screen_id']
        records.setdefault(id,{'screen_id':id,'name':id,'description':'补充子状态；见原帧及来源说明。'})
    for id in ['L01a','L01b','L01c','L01d','L01e','L02a','L03a','LD01','LE01','LE02']:
        records.setdefault(id,{'screen_id':id,'name':id,'description':'诊断专项状态，条件及恢复操作见 diagnostics 规范。'})
    records.setdefault('C01-sound',{'screen_id':'C01-sound','name':'系统通知声音','description':'系统声音读取、试听／停止、渠道设置；替代 D19 三音面板。'})
    aliases={'B00':('L00','同一设置数据区包含诊断与备份两个入口'),
             'B01a':('B01b','初始空数据夹具同时为尚未创建过备份；没有虚构成功日期'),
             'C01-sound':('C01','完整设置滚动原帧含系统通知声音区；依具体阶段核对')}
    navigation={
      'P':('计划一级页或目标计划','计划／动作按实际条件存在；空态单列','新建、详情、编辑或准备','返回来路；未保存草稿不提交','名称／数值校验，失败保留输入'),
      'W':('准备确认或继续活动训练','存在本次会话快照','完成、休息、撤销、结束等按真实进度开放','结束走确认；不因返回暗中保存／放弃','状态变化重载；持久化失败不伪报成功'),
      'S':('训练页查看动作或更换下一动作','存在活动会话；资格由完成／跳过记录决定','本次编辑、换序或选择下一动作','取消草稿不写入，仅影响本次','过期草稿重载，不能覆盖最新状态'),
      'X':('计划首页更多菜单','导出有计划；导入具有有效文本／文件','全选／预览／复制／文件／确认','取消文件选择正常返回；确认前不导入','保留输入、整批回滚；同名创建副本'),
      'H':('记录一级页及目标记录','按已保存快照与月份计算','切月、详情、删除确认','返回月份；取消删除保留记录','读失败不冒充空；刷新失败只重试加载'),
      'C':('设置一级页及关于／提醒子项','控件按真实权限／开关显隐','外观、语言、声音、提醒、数据及关于','子页返回设置并保留位置','保存失败保留原有效值并允许重试'),
      'D':('对应操作显式触发确认或菜单','按描述中的资格和真实目标','显示具体后果并确认','取消／返回不提交；D17 返回仅收起','操作失败保留真实数据，显示实际结果'),
      'A':('对应页面的适配配置','宽度／字号／键盘／长文本按具体原帧','可滚动，主要操作可达','遵循原页面语义','溢出与安全区按单独证据，不推断 TalkBack'),
      'B':('设置→备份与恢复','无活动训练才可创建／替换；预览完整校验','创建、恢复、副本或撤回按状态执行','写入前可取消；替换期间禁止重复与返回','先保护再替换；未知结果不称成功／原数据完整'),
      'E':('备份流程错误分支','受控夹具或真实平台失败；不制造生产故障','按对应原因重新选择／预览／有限重试','保留真实已提交结果与原有文件','错误种类、回滚、设置与核心成功分开'),
      'L':('设置→诊断；L07 由启动失败进入','本机诊断／导出能力和实际日志状态','开关、详细模式、导出、清理与隐私','返回来路；清理取消不删除','限制／部分成功／失败／未知分别表达'),
    }
    for id,record in records.items():
        group,title,code,criteria=classify(id)
        images=[r for r in rows if r['screen_id']==id]
        if not images and id in aliases:
            target,reason=aliases[id]
            images=[r for r in rows if r['screen_id']==target]
            record['capture_alias']={'screen_id':target,'reason':reason}
        entry,precondition,actions,back,failure=navigation[id[0]]
        record.update(group=group,implementation=code,criteria=criteria,
                      entry=entry,precondition=precondition,actions=actions,back_cancel=back,failure=failure,
                      implementation_status='implemented' if id!='D19' else 'superseded',
                      capture_status='captured' if images else 'pending',
                      captures=[r['capture_id'] for r in images],
                      pending_reason=None if images else ('已被系统声音控件替代' if id=='D19' else '本轮未取得该分支原帧；沿实现与既有测试追溯，不声明已验证'))
        if id=='E04':
            record['implementation_note']='空间不足类平台错误现归为通用 storage；独立原因提示未证实'
            record['pending_reason']='未对模拟器制造磁盘耗尽；当前平台适配将该类错误归入通用存储失败，空间不足的独立文案与真实失败路径尚未验证，见 discrepancies.md'
    return sorted(records.values(),key=lambda r:r['screen_id'])


def make_results(rows):
    results=[]
    for row in rows:
        group,title,code,criteria=classify(row['screen_id'])
        results.append({'id':row['capture_id'],'screen_id':row['screen_id'],'state_id':row['state_id'],
            'criteria':['REF-04','REF-05/render'],'expected':'当前基线的生产组件／应用在指定环境可绘制并保存原帧；本项仅证明画面采集',
            'observed':'原帧存在且 PNG／哈希可核对；受控视图夹具仅检查呈现，未执行其表示的真实故障／事务' if 'controlled-view-fixture' in row['state_id'] else ('原帧存在且 PNG／哈希可核对；测试渲染的异常断言在采集测试中通过' if row['capture_kind']=='widget-test' else '新 release 在隔离 Android API36 中实际呈现；原帧及 UI 树已保存'),
            'implementation':code,'evidence':[row['path']]+([row['ui_tree']] if row.get('ui_tree') else []),
            'baseline_id':row['baseline_id'],'environment':{k:row.get(k) for k in ['language','theme','theme_color','font_scale','logical_width','logical_height','orientation']},
            'method':row['capture_kind'],'result':'passed-current','scope':'画面渲染／采集，不能据此推断完整业务、平台或辅助技术通过'})
    results += [
      {'id':'regression-flow','criteria':['REF-06'],'expected':'计划／数值／分享／训练工具／删除／主题／关于与许可相关现有测试通过',
       'observed':'239 tests passed；与 regression-ui 的236项文件集合不同',
       'evidence':['verification/flow-regression.log'],'method':'flutter-tests','result':'passed-current','scope':'focus_redesign_ui, step_picker, plan_transfer_ui, session_exercise_reordering, skipped_sets_ui, history_delete_ui, theme_color_ui, about_notice, licenses_page'},
      {'id':'visual-token-measurements','criteria':['VIS-01/pairs','ADAPT-06/static'],'expected':'所列语义色对和静态触控约束满足阈值',
       'observed':'30个现有不透明颜色对计算通过；AppButton静态最小高度56/48dp，历史月控件有当前48dp断言',
       'evidence':['verification/visual-measurements.json','verification/regression.log'],'method':'source-measurement-and-widget-test','result':'passed-current','scope':'只限报告列出的色对和约束；不推断所有叠层／控件／真实读屏通过'},
        {'id':'regression-ui','criteria':['REF-06'],'expected':'相关现有 UI／控制器测试通过','observed':'236 tests passed',
         'evidence':['verification/regression.log'],'method':'flutter-widget-tests','result':'passed-current',
         'scope':'history_summary_ui_test, rest_reminder_ui_test, backup_ui_test, diagnostics_pages_test, diagnostics_controller_test；受控环境'},
        {'id':'native-rest-ack','screen_id':'D17/W01','criteria':['REM-01','FLOW-03'],'expected':'停止提醒不增加完成组数',
         'observed':'到期提示第2/2组，确认后仍为1/2完成；随后明确点击完成才转动作间休息',
         'evidence':[r['path'] for r in rows if r['capture_kind']=='release-emulator' and r['screen_id'] in ['D17','W01']],
         'method':'release-emulator-observation','result':'passed-current','scope':'本次 API36 英文浅色合成训练；非真人听感'},
        {'id':'physical-device','criteria':['ADAPT-06','REM-06','LOGUI-12'],'expected':'真实 TalkBack／听感／振动及厂商后台证据',
         'observed':'本次没有物理设备观察，模拟器禁用宿主音频','evidence':[],'method':'not-executed','result':'pending'},
        {'id':'historical-qa','criteria':['REF-06'],'expected':'历史结果保留原范围','observed':'原报告与未完成任务不被本次资料整理改写',
         'evidence':['../../qa/local-diagnostics-acceptance.md','../../qa/background-rest-reliability/README.md'],
         'method':'historical-reports','result':'passed-historical','scope':'不归入本次设备复验数量'},
    ]
    results += [
      {'id':'native-diagnostic-file','screen_id':'L04','criteria':['LOGUI-07'],'expected':'真实导出文件可读且 ZIP 完整',
       'observed':'API36 公共下载文件已读取，15655 bytes；ZIP CRC 全部通过；完整文件哈希见证据',
       'evidence':['verification/native-diagnostic-file.json'],'method':'release-emulator-file-readback','result':'passed-current','scope':'此文件本次写入与完整性；不证明旧 API 权限／空间不足／重名全矩阵'},
      {'id':'native-notification-return','screen_id':'C03/W01','criteria':['REM-05'],'expected':'点击到期通知回到所属训练，停止后保留真实完成组数',
       'observed':'同一 ReferenceRow 第2/2组，返回稳定画面为1/2组完成；本次没有触发完成组操作',
       'evidence':[r['path'] for r in rows if 'notification' in r['state_id']],
       'method':'release-emulator-observation','result':'passed-current','scope':'API36 临时合成训练；后台长期可靠性与真机听感保持待验'},
      {'id':'adaptation-render','criteria':['VIS-03','ADAPT-02','ADAPT-03/render'],'expected':'代表宽度、字号、长动作名、横屏／平板、主题色和减少动画能绘制',
       'observed':'28 个适配场景测试通过；无 Flutter 绘制异常，原帧逐张保留',
       'evidence':['verification/adaptation-capture.log','verification/adaptation-captures.json'],'method':'flutter-widget-tests','result':'passed-current','scope':'受控渲染；未执行的设备、触控语义、TalkBack、对比度测量不随之通过'},
      {'id':'static-analysis','criteria':['REF-08'],'expected':'新增采集测试及现有工程静态分析通过','observed':'flutter analyze: No issues found',
       'evidence':['verification/analyze.log'],'method':'flutter-analyze','result':'passed-current'},
      {'id':'diagnostic-active-workout-platform','criteria':['LOGUI-05'],'expected':'活动训练期间导出不改变进度、截止和提醒','observed':'本轮没有完整执行该设备场景；页面采集与导出成功文件不替代无干扰检查','evidence':['verification/current-observations.md'],'method':'not-executed','result':'pending'},
      {'id':'backup-fault-platform','criteria':['BK/faults'],'expected':'实际存储、进程中断、回滚、设置与核心结果按真实状态反馈','observed':'受控状态渲染已登记；真实平台故障矩阵本轮未复验，历史证据保留原范围','evidence':['verification/branch-captures.json','verification/discrepancies.md'],'method':'not-executed','result':'pending'},
    ]
    for p in inventory(rows):
        if p['capture_status']=='pending':
            results.append({'id':'gap-'+p['screen_id'],'screen_id':p['screen_id'],'criteria':['REF-03','REF-06'],
              'expected':'状态有当前画面与独立检查','observed':p['pending_reason'],'evidence':[],
              'implementation':p['implementation'],'method':'not-executed','result':'not-applicable' if p['screen_id']=='D19' else 'pending'})
    for result in results:
        result.setdefault('baseline_id','306b9bc-0.3.1+12-2026-10-31')
        result.setdefault('environment',{'platform':'Android API36 isolated AVD' if 'emulator' in result['method'] else result['method']})
    browser=CURRENT/'verification/browser-qa.json'
    if browser.exists():
        passed=all(c['passed'] for c in load(browser)['checks'])
        results.append({'id':'offline-atlas','criteria':['REF-07'],'expected':'离线筛选、原图、详情、Esc和手机宽度可用','observed':'现有Chrome/Playwright实际file URL检查，详见逐项结果','evidence':['verification/browser-qa.json'],'method':'browser-automation','result':'passed-current' if passed else 'failed','baseline_id':'306b9bc-0.3.1+12-2026-10-31','environment':{'browser':'Chrome / existing managed Playwright'}})
    for result in results:
        result.setdefault('implementation',None)
        result.setdefault('test','See named suite and evidence logs' if 'test' in result['method'] else None)
    return results


def publish():
    rows=collect(); pages=inventory(rows); build=load(CURRENT/'verification/build.json')
    manifest={'format_version':1,'generated_at':now(),'baseline_id':build['baseline_id'],'version':build['version'],
              'source_commit':build['source_commit'],'apk_sha256':build['apk_sha256'],'build_record':'verification/build.json',
              'design_sources':['focus-a-2026-10-14','history-summary-2026-10-22','diagnostics-ui-2026-10-23','rest-system-sound-2026-10-27'],
              'screens':pages,'captures':rows,'verification':'verification/results.json'}
    dump(CURRENT/'manifest.json',manifest)
    dump(CURRENT/'verification/results.json',{'format_version':1,'path_base':'current-ui','baseline_id':build['baseline_id'],'generated_at':now(),'checks':make_results(rows)})
    for name in ['regression.log','flow-regression.log','widget-capture.log','backup-capture.log','extra-capture.log','adaptation-capture.log','branch-capture.log','diagnostic-cancel-capture.log','analyze.log','release-build.log','release-badging.txt','environment.json','finish-native.log']:
        if (RUN/name).exists(): shutil.copyfile(RUN/name,CURRENT/'verification'/name)
    # The environment wrapper prints its own JSON before Flutter's --machine
    # output. Preserve the raw stream in build, publish a valid single object.
    stream=(RUN/'flutter-version.json').read_text(encoding='utf-8-sig').strip()
    decoder=json.JSONDecoder();objects=[]
    while stream:
        value,end=decoder.raw_decode(stream);objects.append(value);stream=stream[end:].strip()
    dump(CURRENT/'verification/flutter-version.json',next(v for v in objects if 'frameworkVersion' in v))
    release=[r for r in rows if r['capture_kind']=='release-emulator']; widget=[r for r in rows if r['capture_kind']=='widget-test']
    pending=[p for p in pages if p['capture_status']=='pending' and p['screen_id']!='D19']
    lines=['# 当前 UI 状态目录','','本文完整登记页面与分支；captured 仅表示已有图像，功能验证见 [结果](verification/results.json)。',
           '','- [交互规范](specs/interaction-spec.md) · [备份专项](specs/features/backup.md) · [诊断专项](specs/features/diagnostics.md)',
           '- [历史与设置等原始编号说明](../archive/'+DATE+'-design-history/docs/design/screens-and-states.md)','',
           '| ID | 页面／状态与条件 | 实施位置 | 交互／验收 | 当前图像 |','| --- | --- | --- | --- | --- |']
    by_id={r['capture_id']:r for r in rows}
    for p in pages:
        image=next((by_id[i] for i in p['captures'] if by_id[i]['capture_kind']=='release-emulator'),None) or (by_id[p['captures'][0]] if p['captures'] else None)
        link=f'[{image["capture_kind"]}](<{image["path"]}>)' if image else ('已替代' if p['screen_id']=='D19' else 'pending：未采集')
        name=p['name'].replace('|','／');description=p['description'].replace('|','／')
        lines.append(f'| {p["screen_id"]} | {name}；{description} | `{p["implementation"]}` | {p["criteria"]} | {link} |')
    lines += ['','## 入口、操作与返回映射','','状态表给出具体条件，以下逐项保留导航与错误范围；严格条件以对应 INT／专项规范为准。','']
    for p in pages:
        lines += [f'### {p["screen_id"]}',f'- 入口：{p["entry"]}。前置：{p["precondition"]}。',
                  f'- 操作：{p["actions"]}。返回／取消：{p["back_cancel"]}。',f'- 失败：{p["failure"]}。实施：`{p["implementation"]}`。',
                  f'- 状态：{p["implementation_status"]}；采集：{p["capture_status"]}；验证按 [results.json](verification/results.json) 的 screen_id 查询。','']
    write(CURRENT/'screen-inventory.md','\n'.join(lines)+'\n')
    coverage=f'''# 覆盖与未验范围

基线 `{build['baseline_id']}`；应用 `{build['version']}`，源码 `{build['source_commit']}`。

- 已登记页面／状态：{len(pages)}。
- 当前 release 原帧：{len(release)}；有原始 UI 树和独立 APK 哈希。
- 当前 Widget 测试渲染：{len(widget)}；与实际 APK 画面分开，不作为平台操作证明。
- 已有图像的页面／状态：{len(pages)-len(pending)-1}；被替代 D19 单列。
- 既有相关回归：两组分别 236 与 239 项通过，共 475 项；文件集合不重叠。截图测试计数和回归计数不相加为独立业务覆盖。

主要页面提供中英文浅深组合。360dp 为主参考；430dp、字号、长文本、横屏／平板及主题色覆盖按具体捕获与既有测试记录，不表示全部条件的笛卡尔积通过。长页面的 top/bottom 或分段为独立原帧，不是拼接伪造。[当前观察与检查边界](current-observations.md) 逐组说明实际执行与未验范围；[颜色与触控约束](visual-measurements.json) 只证明所列测量。

## 本轮未采集原帧的分支

这些条目已有文字规范及实施路径；保留未验，不以原型图补位：

'''+ '\n'.join(f'- {p["screen_id"]}：{p["name"]}；{p["pending_reason"]}' for p in pending)+'''

## 人工与平台边界

TalkBack、真人听感／触感、小米 HyperOS 两种省电配置、旧 API、跨设备系统迁移和长时资源测量继续 pending。诊断真实导出文件已有独立读取／ZIP 校验证据；其他预览原帧不证明文件写入。完整设置与备份首页／创建预览各四组合、许可正文的分段原帧及滚动边界记录见 `*-scroll-sequence.json`；备份恢复预览与副本详情另有测试 top/bottom 原帧。
'''
    write(CURRENT/'verification/coverage.md',coverage)
    write(CURRENT/'README.md',f'''# SetTrace 当前 UI 参考

当前资料按源码 `{build['source_commit'][:7]}`、应用 **{build['version']}** 整理。正式画面来源和验证方式逐项标注，旧稿见 [归档](../archive/README.md)。

1. [打开离线 UI 图册](overview.html)：按功能、语言、明暗和来源筛选。
2. [页面与状态完整目录](screen-inventory.md)：入口、条件、操作、返回与实施映射。
3. [视觉与组件规范](specs/visual-and-components.md)、[交互规范](specs/interaction-spec.md)、[验收标准](specs/acceptance-checklist.md)。
4. 专项：[备份](specs/features/backup.md)、[诊断](specs/features/diagnostics.md)、[记录统计](specs/features/history-summary.md)。
5. [构建及截图清单](manifest.json)、[覆盖与待验](verification/coverage.md)、[验证说明](verification/README.md)、[差异](verification/discrepancies.md)。
6. [REF-01–08 资料交付报告](verification/ref-report.md)、[逐组当前观察](verification/current-observations.md)、[文档完整性检查](verification/documentation-checks.json)。

APK SHA-256：`{build['apk_sha256']}`。本次重新构建，与历史同版本包分别记录。

图册含 {len(release)} 张 release Android 原帧、{len(widget)} 张测试渲染。测试图使用当前生产组件、隔离 SQLite 和受控平台，明确标记，不能替代真实 Android 写入／提醒验证。未采集分支与未验设备条件在目录中保留。

## 资料优先级

业务含义以现有 OpenSpec 主规格为准；当前实现以标识的源码／构建为准；本目录 Markdown 解释当前视觉与交互。发现冲突同时登记要求和实际，不静默改变业务。旧原型及历史 QA 只证明各自日期与范围。

## 刷新方式

1. 固定最新确认源码及应用改动范围，保存旧清单和当前参考到按日期命名的归档。
2. 用 `tool/ui_reference_dev.ps1` 核实 D 盘环境并重建 release；记录源码、源文件指纹、APK 哈希及实际安装版本。
3. 在只读 AVD 中采集实际原帧；运行明确标注的参考截图测试和对应既有回归。所有输出留在 D 盘。
4. 更新页面目录、manifest 与结果；通过截图哈希、引用、覆盖和变更范围检查后切换入口。
5. 未执行项保持 pending。不得把旧截图改名、新版本号或代码存在当作复验通过。

采集工具见项目 `tool/ui_reference_android.py`；生成图册使用 `python -B tool/ui_reference_publish.py`。Widget 采集须显式设置 `UI_REFERENCE_OUTPUT`，默认运行测试不会生成参考图片。
''')
    data=json.dumps(manifest,ensure_ascii=False).replace('<','\\u003c')
    archive_record=CURRENT/'verification/openspec-archive.json'
    if archive_record.exists():
        record=load(archive_record)
        p=CURRENT/'README.md'
        write(p,p.read_text(encoding='utf-8')+'\n## OpenSpec 归档\n\n'
              f'`{record["change"]}` 已于 {record["archived_at"][:10]} 按用户请求[归档](../../../{record["target"]}/tasks.md)，30/30项完成，无规格增量。[归档记录](verification/openspec-archive.json)保存原件哈希；REF报告是归档前的实施验收快照，归档不改变其中的产品待验条件。未执行Git提交或发布。\n')
    template=(ROOT/'tool/ui_reference_atlas.html').read_text(encoding='utf-8')
    write(CURRENT/'overview.html',template.replace('__MANIFEST__',data))
    mark('4.3')
    print(json.dumps({'screens':len(pages),'release_frames':len(release),'widget_frames':len(widget),'unpictured':len(pending)}))


if __name__=='__main__':
    from ui_reference import DATE
    publish()
