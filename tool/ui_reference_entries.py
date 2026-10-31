"""Switch current documentation entry points without rewriting historical sources."""
from ui_reference import ROOT, CURRENT, DESIGN, write, original, mark

def main():
    write(DESIGN/'README.md', '''# SetTrace 设计资料

当前 UI 参考以源码 **306b9bc**、应用 **0.3.1+12** 的重新构建与采集为依据，整理日期为 2026-10-31。

- [当前 UI 参考与使用说明](current-ui/README.md)
- [离线 UI 图册](current-ui/overview.html)：实际 Android 原帧与测试渲染分开标记。
- [页面／状态目录](current-ui/screen-inventory.md)、[视觉与组件规范](current-ui/specs/visual-and-components.md)、[交互规范](current-ui/specs/interaction-spec.md)
- [验收标准](current-ui/specs/acceptance-checklist.md)、[覆盖与待验](current-ui/verification/coverage.md)、[差异](current-ui/verification/discrepancies.md)
- [正式品牌资源](current-ui/assets/brand/README.md)
- [历史归档与迁移清单](archive/README.md)

业务含义以 OpenSpec 主规格为准，当前实现与画面以已标识源码／APK 为准。截图只证明各自的采集条件；真机、TalkBack 和故障恢复等验证范围须查阅结果。

旧路径仅为历史引用保留兼容入口，旧原型与工作稿均已归档；不再作为当前设计主版本。[整理前设计首页原件](archive/2026-10-31-design-history/docs/design/README.md)仍可追溯。此处不改变任何后续工作授权边界。
''')
    p=ROOT/'README.md';text=p.read_text(encoding='utf-8')
    text=text.replace('docs/design/settrace-brand-final/settrace-icon/settrace-icon.preview.png','docs/design/current-ui/assets/brand/settrace-icon/settrace-icon.preview.png')
    start=text.index('- [当前设计入口：')
    end=text.index('- [计划导入导出验收记录]',start)
    text=text[:start]+'''- [当前设计入口](docs/design/README.md)、[离线 UI 图册](docs/design/current-ui/overview.html)
- [视觉与组件规范](docs/design/current-ui/specs/visual-and-components.md)、[页面与状态](docs/design/current-ui/screen-inventory.md)、[交互规范](docs/design/current-ui/specs/interaction-spec.md)、[验收标准](docs/design/current-ui/specs/acceptance-checklist.md)
- [正式 Logo 与图标母版](docs/design/current-ui/assets/brand/README.md)；`tool/generate_android_icons.py` 读取该目录，重新生成需 Python 3 与 Pillow。
- [构建身份与截图清单](docs/design/current-ui/manifest.json)、[覆盖与待验](docs/design/current-ui/verification/coverage.md)
- [旧设计、模拟原型与工作稿归档](docs/design/archive/README.md)
'''+text[end:]
    start=text.index('当前设计基线为 `focus-a-2026-10-14`')
    end=text.index('## 当前范围',start)
    text=text[:start]+'''当前参考对应源码 `306b9bc`、应用 `0.3.1+12` 的独立 release 构建，整合 `focus-a-2026-10-14` 与后续已实施增量。图册明确区分 Android 模拟器原帧、受控 Widget 测试渲染和未验条件；历史 HTML／SVG 仅为来源，不代表当前实装。业务规格与运行资源保持原样。

本次资料整理已获得用户授权。Git 提交、发布及 OpenSpec 归档仍需各自授权；设计文档或已有 change 目录本身不代表新增工作授权。

'''+text[end:]
    write(p,text)
    p=ROOT/'openspec/config.yaml';text=p.read_text(encoding='utf-8')
    text=text.replace('当前设计基线为 focus-a-2026-10-14（A · 专注工具），覆盖应用 0.1.3+5 / da18d62 的全部既有功能。',
       '当前 UI 参考集中在 docs/design/current-ui，源码基线 306b9bc、应用 0.3.1+12；独立构建身份与截图来源见 manifest.json 和 verification/build.json。视觉沿用 focus-a-2026-10-14（A · 专注工具）与后续已实施增量。')
    text=text.replace('docs/design/SetTrace_UI_Design_System_and_Flutter_Spec.md','docs/design/current-ui/specs/visual-and-components.md')
    text=text.replace('docs/design/screens-and-states.md','docs/design/current-ui/screen-inventory.md')
    text=text.replace('docs/design/interaction-spec.md','docs/design/current-ui/specs/interaction-spec.md')
    text=text.replace('docs/design/acceptance-checklist.md','docs/design/current-ui/specs/acceptance-checklist.md')
    text=text.replace('INT-01 至 INT-10','INT-01 至 INT-13')
    text=text.replace('目标视觉与呈现以当前设计 Markdown 为准；docs/design/prototype/SetTrace-Focus.html、previews、exports 是对照资料。',
       '目标视觉与呈现以当前设计 Markdown 为准；docs/design/current-ui/overview.html 为离线当前 UI 图册，verification/coverage.md 说明实际覆盖和待验。旧 prototype、previews、exports 及工作稿已移至 docs/design/archive，仅供历史追溯。')
    write(p,text)
    brand=CURRENT/'assets/brand'
    write(brand/'README.md','''# 正式品牌资源

沿用 2026-10-15 确认的深墨绿三线方案；本次仅集中原有资源，未重新生成应用运行图标。

- [设计与使用规范](design-guide.md)
- [独立标记和字标母版](logo/)
- [通用图标 SVG](settrace-icon/settrace-icon.svg)、[PNG](settrace-icon/settrace-icon.png)、[圆角预览](settrace-icon/settrace-icon.preview.png)
- [分层可编辑源文件](settrace-icon/layers/)、[通用导出](exports/)
- [迁移与原始哈希](../../../archive/migration-manifest.json)
- [历史品牌展示与验证原件](../../../archive/2026-10-31-design-history/docs/design/settrace-brand-final/README.md)

`tool/generate_android_icons.py` 从本目录读取既有 SVG／PNG 母版。Flutter `assets/brand` 与 Android 运行资源是应用产物，保持原样。
''')
    guide=original('docs/design/settrace-brand-final/design-guide.md').read_text(encoding='utf-8-sig').split('## 文件入口')[0]
    guide+='''## 当前文件入口

母版、分层和导出见 [品牌入口](README.md)。原始制作过程、比较图、旧展示包及工具副本均在[历史原件](../../../archive/2026-10-31-design-history/docs/design/settrace-brand-final/design-guide.md)中追溯；原文件内容与哈希保持。
'''
    write(brand/'design-guide.md',guide)
    mark('7.1')

if __name__=='__main__':main()
