"""Record code-based visual measurements and bounded current observations."""
import re
from ui_reference import ROOT,RUN,CURRENT,load,dump,write,now

def luminance(color):
    channels=[int(color[i:i+2],16)/255 for i in (2,4,6)]
    values=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in channels]
    return sum(v*w for v,w in zip(values,[.2126,.7152,.0722]))

def ratio(a,b):
    a,b=sorted([luminance(a),luminance(b)])
    return (b+.05)/(a+.05)

def main():
    colors=[]
    source=(ROOT/'lib/app/theme/theme_color_preset.dart').read_text(encoding='utf-8')
    for preset,dark,values in re.findall(r'(teal|blue|violet|graphite)( when dark)?\s*=>\s*\((.*?)\)',source,re.S):
        accent,pressed,soft,on,ons=re.findall(r'0x([0-9A-Fa-f]{8})',values)
        for name,fg,bg in [('primary',on,accent),('primary-pressed',on,pressed),('soft-label',ons,soft)]:
            contrast=ratio(fg,bg)
            colors.append({'preset':preset,'theme':'dark' if dark else 'light','pair':name,'foreground':'#'+fg[2:],'background':'#'+bg[2:],'ratio':round(contrast,3),'threshold':4.5,'passed':contrast>=4.5})
    theme=(ROOT/'lib/app/theme/app_theme.dart').read_text(encoding='utf-8')
    for mode in ['light','dark']:
        body=re.search(rf'static const {mode} = AppColors\((.*?)\n  \);',theme,re.S)[1]
        tokens=dict(re.findall(r'(\w+): Color\(0x([0-9A-Fa-f]{8})\)',body))
        for name,fg,bg,threshold in [('body','textPrimary','background',4.5),('secondary','textSecondary','surface',4.5),('control-border','controlBorder','surface',3)]:
            contrast=ratio(tokens[fg],tokens[bg])
            colors.append({'preset':'shared','theme':mode,'pair':name,'foreground':'#'+tokens[fg][2:],'background':'#'+tokens[bg][2:],'ratio':round(contrast,3),'threshold':threshold,'passed':contrast>=threshold})
    button=(ROOT/'lib/core/widgets/app_button.dart').read_text(encoding='utf-8')
    measurement={'created':now(),'method':'sRGB relative luminance on existing Dart token literals; no application colors changed','source':['lib/app/theme/app_theme.dart','lib/app/theme/theme_color_preset.dart'],
      'pairs':colors,'passed':all(p['passed'] for p in colors),'scope':'Only these opaque semantic color pairs; excludes disabled opacity, every overlay/pixel, system windows and real-device appearance.',
      'touch_review':{'primary_min_height_dp':56,'secondary_min_height_dp':48,'source':'lib/core/widgets/app_button.dart',
        'code_pattern_present':'kind == AppButtonVariant.primary ? 56 : 48' in button,'limits':'Static minimum constraints, not a claim that all hit targets were measured; history month controls have executed 48dp assertions in history_summary_ui_test.'}}
    dump(CURRENT/'verification/visual-measurements.json',measurement)
    write(CURRENT/'verification/current-observations.md','''# 当前观察与检查边界

基线 `306b9bc-0.3.1+12-2026-10-31`。这里记录本轮看到、执行或测量的内容；通过只限所列检查，不将整条 FLOW／BK／LOGUI 自动标为通过。

| 范围 | 本次观察与证据 | 结果边界 |
| --- | --- | --- |
| P01–P06、D01–D04/D10，INT-01/02/07 | 实际 release 建计划、动作、准备；生产组件四组合正常／空／确认；focus_redesign_ui_test 与 step_picker_test 核对数字上限、按钮和 Picker 端点／禁用、取消与默认排序 | 当前画面与所列用例通过；系统 IME 原帧见 A03，全部输入法矩阵未执行 |
| W01–W06、S01–S04、D05–D09/D14 | release 实际完成组、组间休息与结束；两类休息与其余状态有生产组件四组合；换序／跳过测试验证固定部分完成位置、取消不写入、保存仅本次、旧草稿重载与独立撤销 | 当前测试通过；平台重启恢复和厂商后台仍按独立设备报告 |
| D17/D18、C03，INT-12/REM | 自然到期后停止，真实完成数保持1/2；系统通知显示休息结束，点击回同一训练后仍1/2；interval draft cancel/save、返回只收起与防穿透有当前测试 | 本次 API36 观察与受控用例通过；真人听感／振动、长期后台不由此通过 |
| X01–X04、D12，INT-08 | 四组合生产预览；plan_transfer_ui_test 验证默认全选／空选择、双输出、忙状态防重复、文件取消、损坏输入、预览取消不创建、重名与事务失败重试 | 当前受控流程通过；本轮未复验旧 API 文件权限 |
| H01–H05、D13，HIST | 当前统计顺序、月份空与全部空原帧；history_summary_ui_test 验证月份仅影响所选汇总／记录、语言主题缩放保留月份；history_delete_ui_test 验证删除取消、旧请求与刷新失败 | 测试通过；真实 TalkBack 未执行 |
| C01/C02/C04/C05、D15/D16、许可与声音 | 设置四组合完整滚动至本机数据末行；实际版本0.3.1+12；系统声音区与许可实际列表／正文原帧；主题、说明与许可现有测试通过 | Widget 许可正文为夹具，正式许可证以 release 原帧和运行注册表为准；声音状态测试不等于真人试听 |
| B00–B20 与 E 分支 | 四组合正常备份、选择／校验、预览、确认取消、保护、恢复、副本删除取消、撤回及活动训练阻止；短暂／故障画面单列 controlled-view-fixture | 正常测试执行与受控状态呈现分开；真实文件故障／中断／回滚不因故障画面通过。E04 独立缺口见差异 |
| L/LD/LE 与 INT-13 | 实际诊断页、隐私、详细状态、导出预览与成功文件；公共 ZIP 15655 bytes 读取及 CRC 校验；偏好失败、空／受限、清理取消和启动故障用受控夹具 | 当前测试与该实际导出文件通过；活动训练期间导出的无干扰完整场景、真实数据库启动故障和取消发布竞争本轮未做设备复验 |
| A01–A05，VIS/ADAPT | 360/430dp、1.0/1.3/1.6字号、长动作名、740×390横屏、768平板、四主题色与减少动画代表画面；已有回归验证历史末项与月控件可达、主操作和声音区短屏布局 | 28项适配渲染通过；不声称全条件笛卡尔积。颜色计算与48/56dp静态约束见 visual-measurements.json；全部触控与语义巡查未执行 |

完整设置与备份原帧按 `*-scroll-sequence.json` 顺序浏览；滚动边界由正文像素不再变化核对。恢复预览、副本详情、说明弹窗提供 top/bottom 原帧；未生成拼接长图。固定操作区在原帧中保留。

测试渲染使用生产组件、合成样本与受控平台；缺省字体在测试光栅化前补入 Roboto／Microsoft YaHei，保持字符串、字号、字重、颜色和生产代码。与 Android 实际字体／状态栏不同。夹具可能使用合成版本信息，实际安装版本以 build.json 和 release 关于原帧为准。

已有无关断链：项目 README 原先引用的 docs/windows-development.md 在基线中即不存在，未计作本次新增断链；当前资料环境见 environment.json。历史归档相对链接按迁移清单中的原 source 基准解释，原件不改写。
''')
    p=CURRENT/'verification/discrepancies.md';text=p.read_text(encoding='utf-8')
    if 'E04：' not in text:
        text+='''
7. **E04：空间不足的独立提示尚未证实。** 当前 `AndroidBackupFilesPlatform._call` 将除 tooLarge/busy/readFailed 外的平台错误归入 `BackupFailure.storage`，`backupError` 使用通用 `backupStorageFailed`；没有给 E04 构造专门的“磁盘耗尽已通过”画面。此处与专项规范细分原因的要求存在差距；没有填满模拟器磁盘或修改应用来验证，真实触发保持 pending。E05 受控图只能说明通用存储失败的呈现。
8. **受控故障画面不等于真实故障执行。** `controlled-view-fixture` 使用显式内存状态；备份 B08a/B13a、B17/B18 和 E 分支只验证生产页面的对应呈现。真实事务、恢复、回滚和中断另查既有测试及历史报告，未执行的设备场景继续 pending。
9. **本次适配覆盖有明确范围。** 字号／横屏／长文本原帧只覆盖清单中的代表页，所有生产页、系统窗口、TalkBack、输入法及安全区组合没有全部交叉执行。
'''
    write(p,text)
    print({'color_pairs':len(colors),'contrast_failures':sum(not p['passed'] for p in colors)})

if __name__=='__main__':main()
