"""Write REF-01–08 delivery findings after all evidence checks have passed."""
from ui_reference import ROOT,RUN,CURRENT,load,dump,write,mark,now

def main():
    docs=load(CURRENT/'verification/documentation-checks.json')
    browser=load(CURRENT/'verification/browser-qa.json')
    shutdown=load(CURRENT/'verification/emulator-shutdown.json')
    assert docs['result']=='passed-current'
    assert all(c['passed'] for c in browser['checks'])
    assert shutdown['device_absent_after_close'] and shutdown['snapshot_save_disabled']
    checks=[
      ('REF-01','唯一入口与资料层级','根设计入口、项目README及OpenSpec指引已切换到current-ui；历史只留9个必要兼容入口。',['README.md','../README.md','../archive/README.md']),
      ('REF-02','来源保全','633个原文件逐项存在且SHA-256与整理前一致；重复关系保留；旧归档原件未改。',['../archive/migration-manifest.json','verification/documentation-checks.json']),
      ('REF-03','完整状态目录','122个页面／状态条目；120个有图；D19被替代；E04保留具体缺口。入口、条件、操作、返回、失败、实施与验收映射可查。',['screen-inventory.md','manifest.json','verification/coverage.md']),
      ('REF-04','源码、构建与原帧身份','固定306b9bc源码重新构建0.3.1+12 release，独立APK哈希与安装核对；120张Android原帧、476张测试渲染分别标识。',['verification/build.json','manifest.json','verification/capture-registration-corrections.json']),
      ('REF-05','正常画面、四组合与长页','主页面四组合矩阵检查通过；设置／备份四组合与许可正文完整滚动原帧，恢复预览／副本详情有top/bottom；28个适配渲染场景；危险／平台缺口未冒充通过。',['verification/documentation-checks.json','verification/native-full-scroll.json','verification/C05-license-detail-scroll-sequence.json','verification/adaptation-captures.json']),
      ('REF-06','结论有据且范围可读','475项既有回归通过；296项采集测试通过（其中包含字体修正后重采与受控状态，非独立业务总覆盖）；30个现有语义色对计算通过；实际诊断ZIP与通知返回有独立证据；设备／故障待验保留。',['verification/results.json','verification/current-observations.md','verification/visual-measurements.json','verification/discrepancies.md']),
      ('REF-07','离线与路径可达','596张图册本地file URL筛选、详情、Esc与手机宽度通过；图片、哈希、JSON、当前新增链接与历史必需引用通过；母版解析有效且未重新生成。',['verification/browser-qa.json','verification/documentation-checks.json']),
      ('REF-08','范围保护与环境收尾','1302个生产、业务规格、运行资源、历史QA和归档OpenSpec文件哈希未变；只读模拟器已退出且不保存快照；未执行提交、发布或OpenSpec归档。',['verification/documentation-checks.json','verification/emulator-shutdown.json']),
    ]
    data={'created':now(),'baseline_id':'306b9bc-0.3.1+12-2026-10-31','path_base':'current-ui','result':'passed-current','scope':'资料交付通过；不表示所有产品验收、设备条件和故障分支通过。',
          'checks':[{'id':id,'title':title,'result':'passed-current','observed':observed,'evidence':evidence} for id,title,observed,evidence in checks]}
    dump(CURRENT/'verification/ref-report.json',data)
    lines=['# REF-01–08 资料交付报告','','基线 `306b9bc`，应用 `0.3.1+12`，整理日期 2026-10-31。**资料交付检查通过；产品验证按条件分项记录。**','',
      '| ID | 检查 | 本次结果 | 结论 |','| --- | --- | --- | --- |']
    lines += [f'| {id} | {title} | {observed} | passed-current（资料） |' for id,title,observed,_ in checks]
    lines += ['','逐项证据见 [机器可读报告](ref-report.json)、[文档检查](documentation-checks.json) 和 [产品检查结果](results.json)。','',
      '## 保留的差异与未验范围','',
      '- E04：未制造真实磁盘耗尽；当前实现使用通用存储错误，独立空间不足提示未证实。',
      '- 受控故障／瞬时画面只证明呈现，真实回滚、进程中断、存储故障及取消发布竞争不随之通过。',
      '- 活动训练期间诊断导出的完整无干扰设备场景、TalkBack、真机听感／振动、厂商后台、旧API及长期资源继续pending。',
      '- 原项目README的docs/windows-development.md链接在基线已缺失；单列为既有问题，未改写历史原件或冒称修复。','',
      '资料阅读从 [当前UI说明](../README.md) 或 [离线图册](../overview.html) 开始；旧资料从 [归档索引](../../archive/README.md) 追溯。','']
    write(CURRENT/'verification/ref-report.md','\n'.join(lines))
    mark(*[f'5.{n}' for n in range(1,11)],'6.1','6.2','6.3','7.1','7.2','7.3')
    print({'reference_checks':8,'implementation_tasks':'30/30','remaining_product_conditions':'see coverage and discrepancies'})

if __name__=='__main__':main()
