"""Prepare, migrate and verify the repository's versioned UI reference.

Standard library only. All writes are confined to this D: repository. Archived
source bytes are preserved; this tool never changes application code or QA.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from datetime import datetime, timezone, timedelta
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
DATE = "2026-10-31"
RUN = ROOT / "build/ui-reference" / DATE
DESIGN = ROOT / "docs/design"
CURRENT = DESIGN / "current-ui"
ARCHIVE = DESIGN / "archive"
ACTIVE_CHANGE = ROOT / "openspec/changes/consolidate-design-and-current-ui"
ARCHIVED_CHANGE = ROOT / "openspec/changes/archive/2026-10-31-consolidate-design-and-current-ui"
CHANGE = (ACTIVE_CHANGE if ACTIVE_CHANGE.exists() else ARCHIVED_CHANGE) / "tasks.md"
TZ = timezone(timedelta(hours=8))


def now():
    return datetime.now(TZ).isoformat()


def safe(path):
    path = Path(path).resolve()
    if ROOT not in path.parents or path.drive.lower() != "d:":
        raise ValueError(f"Path outside D: workspace: {path}")
    return path


def relative(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, content):
    path = safe(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def dump(path, data):
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def mark(*ids):
    text = CHANGE.read_text(encoding="utf-8")
    before = text
    for task in ids:
        text = text.replace(f"- [ ] {task} ", f"- [x] {task} ")
    if text != before:
        if CHANGE.parent == ARCHIVED_CHANGE:
            raise RuntimeError("Archived tasks are immutable; do not reopen them through capture tools")
        write(CHANGE, text)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode("utf-8").strip()


def protected_files():
    roots = ["lib", "assets", "android/app/src", "openspec/specs", "docs/qa", "openspec/changes/archive"]
    paths = [p for folder in roots for p in (ROOT / folder).rglob("*") if p.is_file()]
    paths += [ROOT / name for name in ["pubspec.yaml", "pubspec.lock", "android/app/build.gradle.kts"]]
    return {relative(p): sha(p) for p in paths if p.exists()}


def links(path, text):
    for raw in re.findall(r"\]\(([^)]+)\)|(?:href|src)=[\"']([^\"']+)", text):
        value = next((part for part in raw if part), "").split(" \"")[0].strip("<>")
        if not value or value.startswith(("#", "http:", "https:", "mailto:", "data:", "javascript:")):
            continue
        target, _, anchor = value.partition("#")
        candidate = (path.parent / unquote(target)).resolve()
        if candidate == ROOT or ROOT in candidate.parents:
            yield value, candidate, anchor


def prepare():
    if (RUN / "original-files.json").exists():
        raise RuntimeError("Preparation already exists; do not overwrite the original baseline")
    sources = sorted([p for p in DESIGN.rglob("*") if p.is_file()] +
                     [p for p in (ROOT / "work/ui-sketches").rglob("*") if p.is_file()])
    records = []
    hashes = {}
    for p in sources:
        name = relative(p)
        digest = sha(p)
        formal = name.startswith("docs/design/settrace-brand-final/") and "/tmp/" not in name and any(
            name.startswith("docs/design/settrace-brand-final/" + folder) for folder in ["logo/", "exports/", "settrace-icon/"])
        if name.startswith("docs/design/archive/"):
            target, role = name, "existing-archive"
        elif formal:
            target = "docs/design/current-ui/assets/brand/" + name.split("settrace-brand-final/", 1)[1]
            role = "approved-brand-source"
        else:
            topic = "working-sketches" if name.startswith("work/") else "design-history"
            target = f"docs/design/archive/{DATE}-{topic}/{name}"
            role = "archive-original"
        records.append({"source": name, "sha256": digest, "bytes": p.stat().st_size,
                        "target": target, "role": role, "reason": "当前正式母版" if formal else "保留整理前原件及历史来源",
                        "duplicate_of": hashes.get(digest)})
        hashes.setdefault(digest, name)
    refs = []
    for folder in ["docs", "openspec", "tool"]:
        for p in (ROOT / folder).rglob("*"):
            if not p.is_file() or p.suffix not in {".md", ".html", ".json", ".py", ".ps1", ".cjs"}:
                continue
            if "consolidate-design-and-current-ui" in p.parts:
                continue
            text = p.read_text(encoding="utf-8-sig", errors="replace")
            for value, target, anchor in links(p, text):
                if DESIGN == target or DESIGN in target.parents or "work/ui-sketches" in str(target).replace("\\", "/"):
                    refs.append({"source": relative(p), "link": value, "target": relative(target),
                                 "anchor": anchor, "existed": target.exists(),
                                 "immutable_source": relative(p).startswith(("docs/qa/", "openspec/changes/archive/"))})
    baseline = {"created": now(), "source_commit": git("rev-parse", "HEAD"), "initial_status": git("status", "--porcelain"),
                "version": re.search(r"^version:\s*(.+)", (ROOT / "pubspec.yaml").read_text(), re.M)[1],
                "protected_files": protected_files(), "planned_reference_commit": "306b9bc"}
    dump(RUN / "baseline.json", baseline)
    dump(RUN / "original-files.json", records)
    dump(RUN / "references-before.json", refs)
    dump(RUN / "pre-existing-broken-design-links.json", [r for r in refs if not r["existed"]])
    for a, b in [("work/ui-sketches/history-layout.html", "docs/design/history-summary/history-layout.fragment.html"),
                 ("work/ui-sketches/history-recommended-light.png", "docs/design/history-summary/previews/history-light-zh.png"),
                 ("work/ui-sketches/history-recommended-dark.png", "docs/design/history-summary/previews/history-dark-zh.png"),
                 ("work/ui-sketches/preview-check.json", "docs/design/history-summary/verification/preview-check.json")]:
        assert sha(ROOT / a) == sha(ROOT / b), (a, b)
    mark("1.1", "1.2", "1.3")
    print(json.dumps({"files": len(records), "references": len(refs), "protected": len(baseline["protected_files"])}))


def migrate():
    records = load(RUN / "original-files.json")
    refs = load(RUN / "references-before.json")
    targets = [r["target"] for r in records]
    assert len(targets) == len(set(targets)), "Conflicting migration destinations"
    for row in records:
        source, target = safe(ROOT / row["source"]), safe(ROOT / row["target"])
        if source == target:
            continue
        if target.exists():
            assert sha(target) == row["sha256"]
            continue
        assert sha(source) == row["sha256"], row["source"]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(source), str(target))
        assert sha(target) == row["sha256"], row["target"]
    mapping = {r["source"]: r for r in records}
    compat = []
    for ref in refs:
        if not ref["immutable_source"] or not ref["existed"] or ref["target"] not in mapping:
            continue
        row = mapping[ref["target"]]
        old, archived = safe(ROOT / row["source"]), safe(ROOT / row["target"])
        if old == archived or old.exists():
            continue
        old.parent.mkdir(parents=True, exist_ok=True)
        link = os.path.relpath(archived, old.parent).replace("\\", "/")
        current = os.path.relpath(CURRENT / "README.md", old.parent).replace("\\", "/")
        if old.suffix == ".md":
            anchors = sorted({r["anchor"] for r in refs if r["target"] == ref["target"] and r["anchor"]})
            write(old, "# 历史路径兼容入口\n\n此路径仅供原验收／归档引用，不是当前规范。\n\n"
                  f"- [历史原件]({link})\n- [当前 UI 参考]({current})\n\n" +
                  "\n".join(f'<a id="{html.escape(a, quote=True)}"></a>' for a in anchors))
        else:
            shutil.copyfile(archived, old)
        compat.append({"path": relative(old), "original": relative(archived), "kind": "redirect" if old.suffix == ".md" else "evidence-copy"})
    for root in [DESIGN, ROOT / "work/ui-sketches"]:
        for p in sorted(root.rglob("*"), key=lambda x: len(x.parts), reverse=True):
            if p.is_dir() and not any(p.iterdir()):
                p.rmdir()
    dump(ARCHIVE / "migration-manifest.json", {"format_version": 1, "created": now(), "files": records, "compatibility": compat})
    dump(CURRENT / "verification/baseline.json", load(RUN / "baseline.json"))
    dump(CURRENT / "verification/references-before.json", refs)
    dump(CURRENT / "verification/pre-existing-broken-links.json", load(RUN / "pre-existing-broken-design-links.json"))
    rows = ["# 设计历史归档", "", "原件按原路径保留字节和 SHA-256；仅当前 UI 入口指导后续工作。", "",
            "- [当前 UI](../current-ui/README.md)", "- [逐文件迁移与去重来源](migration-manifest.json)", "",
            "归档正文的相对链接以原 source 路径为基准；迁移清单提供目标映射。原报告的历史链接通过最小兼容入口保留。", "",
            "| 原资料 | 归档／有效资源位置 | 内容重复来源 |", "| --- | --- | --- |"]
    for row in records:
        dest = os.path.relpath(ROOT / row["target"], ARCHIVE).replace("\\", "/")
        rows.append(f'| `{row["source"]}` | [原件](<{dest}>) | {row["duplicate_of"] or "—"} |')
    write(ARCHIVE / "README.md", "\n".join(rows) + "\n")
    icon = ROOT / "tool/generate_android_icons.py"
    write(icon, icon.read_text(encoding="utf-8").replace("docs/design/settrace-brand-final", "docs/design/current-ui/assets/brand"))
    assert (CURRENT / "assets/brand/logo/settrace-symbol-white.svg").exists()
    assert (CURRENT / "assets/brand/settrace-icon/layers/01-background.svg").exists()
    mark("2.1", "2.2", "2.3", "2.4")
    print(json.dumps({"migrated": len(records), "compatibility": len(compat)}))


def original(name):
    mapping = {r["source"]: r["target"] for r in load(RUN / "original-files.json")}
    return ROOT / mapping[name]


def canonical_targets():
    return {
        "docs/design/README.md": "docs/design/current-ui/README.md",
        "docs/design/SetTrace_UI_Design_System_and_Flutter_Spec.md": "docs/design/current-ui/specs/visual-and-components.md",
        "docs/design/screens-and-states.md": "docs/design/current-ui/screen-inventory.md",
        "docs/design/interaction-spec.md": "docs/design/current-ui/specs/interaction-spec.md",
        "docs/design/acceptance-checklist.md": "docs/design/current-ui/specs/acceptance-checklist.md",
        "docs/design/backup/README.md": "docs/design/current-ui/specs/features/backup.md",
        "docs/design/backup/backup-ui-spec.md": "docs/design/current-ui/specs/features/backup.md",
        "docs/design/diagnostics/README.md": "docs/design/current-ui/specs/features/diagnostics.md",
        "docs/design/diagnostics/ui-spec.md": "docs/design/current-ui/specs/features/diagnostics.md",
        "docs/design/history-summary/README.md": "docs/design/current-ui/specs/features/history-summary.md",
    }


def rewrite(text, old, target):
    mapping = {r["source"]: r["target"] for r in load(RUN / "original-files.json")}
    mapping.update(canonical_targets())
    def convert(match):
        label, value = match[1], match[2].strip("<>")
        if value.startswith(("http:", "https:", "mailto:", "#")):
            return match[0]
        value, separator, anchor = value.partition("#")
        resolved = (ROOT / old).parent.joinpath(unquote(value)).resolve()
        if ROOT not in resolved.parents:
            return match[0]
        key = relative(resolved)
        dest = ROOT / mapping.get(key, key)
        result = os.path.relpath(dest, target.parent).replace("\\", "/")
        if separator:
            result += "#" + anchor
        return f"[{label}](<{result}>)"
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", convert, text)


def specs():
    docs = {
        "docs/design/SetTrace_UI_Design_System_and_Flutter_Spec.md": CURRENT / "specs/visual-and-components.md",
        "docs/design/interaction-spec.md": CURRENT / "specs/interaction-spec.md",
        "docs/design/acceptance-checklist.md": CURRENT / "specs/acceptance-checklist.md",
        "docs/design/backup/backup-ui-spec.md": CURRENT / "specs/features/backup.md",
        "docs/design/diagnostics/ui-spec.md": CURRENT / "specs/features/diagnostics.md",
        "docs/design/history-summary/README.md": CURRENT / "specs/features/history-summary.md",
    }
    for source, target in docs.items():
        text = original(source).read_text(encoding="utf-8-sig")
        text = text.replace("UI 已确认，待实现", "已实现，验证按当前证据分项记录")
        text = text.replace("设计已确认，实施待验", "已实现，实施验证分项记录")
        text = text.replace("UI已确认与草图核查不代表日志功能或Android导出已经实现", "草图核查不代表功能通过；实现已接入，运行结果按当前验证清单记录")
        text = text.replace("应用尚未实现", "应用已实现，覆盖范围见当前验证清单")
        text = text.replace("尚未实现", "对应状态需按实现及证据核对") if source.endswith("interaction-spec.md") else text
        if "诊断与日志验收" in text:
            text = text.replace("当前均未进行应用运行验收", "历史应用运行验收已建立，本次逐项复验状态见 verification/results.json")
        banner = ("\n> 当前参考整理：2026-10-31。沿用 focus-a 及已实施增量；当前应用基线和验证结论以 manifest.json、verification/results.json 为准。"
                  "文中链接到的旧 HTML、草图、旧日期报告仅为来源追溯，不是当前构建截图。发现要求与实现差异时登记，不修改业务规则。\n\n")
        first, _, rest = text.partition("\n")
        text = first + "\n" + banner + rest
        write(target, rewrite(text, source, target))
    inventory_source = "docs/design/screens-and-states.md"
    text = original(inventory_source).read_text(encoding="utf-8-sig")
    text = text.replace("UI 已确认，待实现", "已实现，验证状态分项记录").replace("本轮仅文档接入，尚无新页面运行证据", "历史运行证据已建立，本次实际采集与验证见 manifest.json 及 verification/results.json")
    target = CURRENT / "screen-inventory.md"
    intro = "# 当前 UI 页面与状态目录\n\n入口、条件、返回与错误以本文及 specs/interaction-spec.md、专项规范对应 ID 为准。\n\n当前采集情况由图册、manifest.json 和 verification/coverage.md 自动汇总；未采集状态保持 pending。\n\n"
    text = intro + rewrite(text, inventory_source, target)
    for source in ["docs/design/backup/backup-ui-spec.md", "docs/design/diagnostics/ui-spec.md"]:
        raw = original(source).read_text(encoding="utf-8-sig")
        rows = [line for line in raw.splitlines() if re.match(r"\|\s*(?:B\d{2}|E\d{2}|L\d{2}|LD\d{2}|LE\d{2})", line)]
        text += "\n\n## 专项状态完整索引：" + ("备份" if "/backup/" in source else "诊断") + "\n\n| ID | 状态／条件 | 内容与操作 |\n| --- | --- | --- |\n" + "\n".join(rows) + "\n"
    text += "\n## 补充子页面\n\n| ID | 状态 | 实现及行为 |\n| --- | --- | --- |\n| C05-license-summary | 主要许可摘要 | licenses_page.dart；点击项目进入详情，返回保持列表 |\n| C05-license-all | 全部许可 | 完整离线列表，非空／空／失败分别表达 |\n| C05-license-detail | 许可正文 | 原文可选择、滚动，返回到来路 |\n| C01-sound | 系统声音 | 读取中／允许／受限／未知／读取失败／试听／停止／设置失败 |\n\nD19 仅保留历史编号，三音面板已替代，当前使用 C01-sound。所有条目共用 VIS-01–06、ADAPT-01–07；状态级证据按 ID 查询清单。\n"
    write(target, text)
    mark("3.1", "3.2", "3.3")
    print("Current specifications integrated")


def reference_contract():
    guide = """# 验证证据与结果解释

当前参考复用 focus-a 与后续增量的要求；版本、构建和采集信息见 [构建记录](build.json) 与 [清单](../manifest.json)。

实现与验证是两个维度：implemented/planned/unknown 描述实现；passed-current、passed-historical、pending、failed、not-implemented、not-applicable 描述某个环境下的检查结果。

- passed-current 必须有当前源码／构建、预期、观察、环境及落盘证据。
- 旧报告仅能记为 passed-historical。代码存在或页面截图不能证明事务、文件写入、失败恢复或全部适配通过。
- release-emulator 是新 release APK 的实际 Android 原帧；widget-test 是当前生产组件在隔离 SQLite／平台夹具下的测试渲染。Windows 字体回退与 Android 字体存在差异。
- 正常、空、加载／提交、禁用、失败、未知和取消分别记录。预览不是文件保存成功，停止提醒不是完成训练，通知请求不证明真人听见。
- TalkBack、真实听感／振动、小米后台、系统迁移、旧 API 和长时资源条件需独立证据；未执行即 pending。
- 长页面以分段原帧为参考，首屏与末尾均保留；若日后生成拼接图必须列出原帧，不将其称为原始系统截图。

结果字段：screen_id/state_id、criteria、expected、observed、implementation、test、evidence、baseline_id、environment、method、result。当前执行与历史结果分别保存，未取得证据不自动升级。

资料交付 REF-01–08：入口唯一、来源保全、状态索引完整、构建可追溯、截图与适配范围清晰、验证有据、离线及链接有效、业务与历史未被改变。资料可完成而产品人工待验仍存在；必需截图缺失时对应任务不完成。
"""
    write(CURRENT / "verification/README.md", guide)
    text = (CURRENT / "specs/acceptance-checklist.md").read_text(encoding="utf-8")
    design = (CHANGE.parent / "design.md").read_text(encoding="utf-8")
    rows = [line for line in design.splitlines() if line.startswith("| REF-")]
    text += "\n\n## 当前资料交付检查\n\n| ID | 完成条件 | 既有依据 |\n| --- | --- | --- |\n" + "\n".join(rows) + "\n"
    write(CURRENT / "specs/acceptance-checklist.md", text)
    for p in [CURRENT/"specs/features/diagnostics.md"]:
        write(p, p.read_text(encoding="utf-8").replace("未自动同步主规格", "已于2026-10-25同步主规格并归档；未验设备与人工条件继续保留"))
    write(CURRENT / "verification/discrepancies.md", "# 差异与待验记录\n\n1. 旧入口的诊断待实现描述已由当前实现及历史实施报告纠正。\n2. D19 三音面板已被系统声音控件替代；历史兼容枚举不作为当前声音选择 UI。\n3. 旧历史总览未包含当前通栏月度汇总，保留为历史原型。\n4. 相同版本号的 APK 不等同；本次新构建具有独立哈希，原报告按原构建展示。\n5. Widget 截图使用 Windows 测试字体与受控平台，不能代表 Android 文件／声音操作已通过。\n6. 真机听感、振动、TalkBack、厂商后台与完整旧 API 矩阵本次仍待独立验证。\n\n新发现的问题按页面、构建、预期、实际、复现和证据追加；不在资料整理中修改生产实现。\n")
    mark("3.4")
    print("Verification contract written")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "migrate", "specs", "contract"])
    args = parser.parse_args()
    {"prepare": prepare, "migrate": migrate, "specs": specs, "contract": reference_contract}[args.command]()
