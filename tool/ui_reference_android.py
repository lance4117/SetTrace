"""Collect original screenshots from the explicitly selected isolated emulator."""
import argparse
import json
import os
import re
import struct
import sys
import hashlib
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from ui_reference import ROOT, RUN, CURRENT, TZ, now, sha, dump, load, mark

sys.stdout.reconfigure(encoding="utf-8")

ADB = r"D:\ProgramData\Android_SDK\platform-tools\adb.exe"
SERIAL = "emulator-5556"
ENV = dict(os.environ, ANDROID_USER_HOME=r"D:\ProgramData\DevCache\Android",
           ADB_VENDOR_KEYS=r"D:\ProgramData\DevCache\Android\adbkey",
           TEMP=r"D:\ProgramData\DevTemp\settrace-ui-reference",
           TMP=r"D:\ProgramData\DevTemp\settrace-ui-reference")


def adb(*args, check=True):
    result = subprocess.run([ADB, "-s", SERIAL, *args], cwd=ROOT, env=ENV,
                            capture_output=True, timeout=45)
    if check and result.returncode:
        raise RuntimeError(result.stderr.decode(errors="replace"))
    return result.stdout


def nodes():
    adb("shell", "uiautomator", "dump", "/sdcard/ui-reference.xml")
    return list(ET.fromstring(adb("exec-out", "cat", "/sdcard/ui-reference.xml")).iter("node"))


def tap(label):
    candidates = [n for n in nodes() if n.get("text") == label or n.get("content-desc") == label]
    if not candidates:
        candidates = [n for n in nodes() if label in (n.get("text", "") + " " + n.get("content-desc", ""))]
    if not candidates:
        raise ValueError(f"No visible control: {label}")
    node = next((n for n in candidates if n.get("clickable") == "true"), candidates[0])
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds", "")))
    adb("shell", "input", "tap", str((x1+x2)//2), str((y1+y2)//2))
    time.sleep(.5)


def scroll(direction="down"):
    adb("shell", "input", "swipe", "850", "1900" if direction == "down" else "500", "850", "700" if direction == "down" else "2000", "350")
    time.sleep(.25)


def seek(label):
    for _ in range(9):
        if any(label in (n.get("text", "") + n.get("content-desc", "")) for n in nodes()):
            return
        scroll()
    raise ValueError(f"Control not reachable by scrolling: {label}")


def top():
    for _ in range(4): scroll("up")


def matrix(previous_language="en"):
    previous = previous_language
    for language, theme in [("en","light"),("en","dark"),("zh","light"),("zh","dark")]:
        current = json.loads((ROOT/f"lib/l10n/app_{previous}.arb").read_text(encoding="utf-8"))
        tap(current['settings'])
        top()
        self_name = '中文' if language == 'zh' else 'English'
        seek(self_name); tap(self_name)
        l = json.loads((ROOT/f"lib/l10n/app_{language}.arb").read_text(encoding="utf-8"))
        top(); tap(l['darkTheme'] if theme == 'dark' else l['lightTheme'])
        capture('C01','settings','top',language,theme)
        scroll(); capture('C01','settings','reminders',language,theme)
        seek(l['diagTitle']); capture('L00','settings','data-entry',language,theme)
        scroll(); capture('C05','about','about-and-version',language,theme)
        top(); seek(l['diagTitle']); tap(l['diagTitle'])
        capture('L01','diagnostics','normal',language,theme)
        seek(l['diagDetailed']); tap(l['diagDetailed']); capture('L05','diagnostics','detailed-off',language,theme)
        adb('shell','input','keyevent','4'); time.sleep(.4)
        seek(l['diagPrivacy']); tap(l['diagPrivacy']); capture('L08','diagnostics','privacy-top',language,theme)
        scroll(); capture('L08','diagnostics','privacy-bottom',language,theme)
        adb('shell','input','keyevent','4'); time.sleep(.4)
        tap(l['diagExport']); capture('L02','diagnostics','preview',language,theme)
        adb('shell','input','keyevent','4'); time.sleep(.4)
        adb('shell','input','keyevent','4'); time.sleep(.4)
        top(); seek(l['backupTitle']); tap(l['backupTitle']); capture('B01','backup','normal',language,theme)
        tap(l['backupCreate']); capture('B02','backup','preview',language,theme)
        adb('shell','input','keyevent','4'); time.sleep(.4)
        adb('shell','input','keyevent','4'); time.sleep(.4)
        tap(l['historyTab']); capture('H01','history','normal',language,theme)
        tap(l['plansTab']); capture('P01','plans','normal',language,theme)
        previous = language


def capture(screen, group, state="normal", language="zh", theme="light", scale=1):
    hierarchy = nodes()
    app_visible=any(n.get("package") == "com.settrace.settrace" for n in hierarchy)
    system_visible=(screen=='C03' and any(n.get('package')=='com.android.systemui' for n in hierarchy)) or (screen=='B05a' and any('documentsui' in n.get('package','') for n in hierarchy))
    if not app_visible and not system_visible:
        for _ in range(3):
            time.sleep(.7)
            hierarchy=nodes()
            app_visible=any(n.get("package") == "com.settrace.settrace" for n in hierarchy)
            if app_visible: break
        if not app_visible:
            raise RuntimeError("SetTrace is not visible; refusing to register an unrelated frame")
    data = adb("exec-out", "screencap", "-p")
    assert data.startswith(b"\x89PNG\r\n\x1a\n")
    width, height = struct.unpack(">II", data[16:24])
    density_text = adb("shell", "wm", "density").decode()
    density = int(re.findall(r"(?:Physical|Override) density: (\d+)", density_text)[-1])
    key = f"{screen}-{state}-{language}-{theme}-{round(width*160/density)}-s{scale}"
    target = CURRENT / "screenshots" / group / (key + ".png")
    if target.exists():
        key += "-" + str(int(time.time()))
        target = target.with_name(key + ".png")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    xml = ET.tostring(ET.Element("hierarchy"), encoding="unicode")
    texts = [{"text": n.get("text", ""), "description": n.get("content-desc", ""),
              "bounds": n.get("bounds"), "clickable": n.get("clickable"),
              "enabled": n.get("enabled"), "checked": n.get("checked")}
             for n in hierarchy if n.get("text") or n.get("content-desc")]
    dump(CURRENT / "verification/ui-trees" / (key + ".json"), texts)
    row = {"capture_id": key, "screen_id": screen, "state_id": state, "group": group,
           "path": target.relative_to(CURRENT).as_posix(), "sha256": sha(target),
           "baseline_id": "306b9bc-0.3.1+12-2026-10-31", "capture_kind": "release-emulator",
           "language": language, "theme": theme, "theme_color": "teal", "font_scale": scale,
           "pixel_width": width, "pixel_height": height, "density": density,
           "logical_width": width*160/density, "logical_height": height*160/density,
           "orientation": "landscape" if width > height else "portrait", "captured_at": now(),
           "fixture": "isolated read-only AVD; production UI; synthetic QA navigation",
           "ui_tree": "verification/ui-trees/" + key + ".json"}
    row['system_owned']=system_visible and not app_visible
    if row['system_owned']:
        row['theme_scope']='app preference; system window appearance controlled by Android'
    path = RUN / "release-captures.json"
    rows = load(path) if path.exists() else []
    rows.append(row)
    dump(path, rows)
    print(json.dumps({"captured": key, **({"controls":len(texts)} if os.environ.get('UI_REFERENCE_QUIET') else {"text": [t["text"] or t["description"] for t in texts]})}, ensure_ascii=False))


def viewport_digest():
    # Compare body pixels in memory, excluding clock, app bar, gesture bar and
    # transient scrollbar. System.Drawing is already installed with Windows.
    command = r'''Add-Type -AssemblyName System.Drawing; $m=New-Object IO.MemoryStream; [Console]::OpenStandardInput().CopyTo($m);$m.Position=0;$b=New-Object Drawing.Bitmap($m);$r=New-Object Drawing.Rectangle(0,280,($b.Width-36),($b.Height-400));$c=$b.Clone($r,$b.PixelFormat);$o=New-Object IO.MemoryStream;$c.Save($o,[Drawing.Imaging.ImageFormat]::Png);$h=[Security.Cryptography.SHA256]::Create();[Console]::Write([Convert]::ToBase64String($h.ComputeHash($o.ToArray())));$c.Dispose();$b.Dispose();$m.Dispose();$o.Dispose();$h.Dispose()'''
    return subprocess.check_output(['powershell.exe','-NoProfile','-Command',command],input=adb('exec-out','screencap','-p'),cwd=ROOT,env=ENV,timeout=20).decode().strip()


def sequence(screen,group,language,theme):
    os.environ['UI_REFERENCE_QUIET']='1'
    frames=[];previous=None;ended=False
    for index in range(80):
        current=viewport_digest()
        if current==previous:
            ended=True;break
        capture(screen,group,f'full-scroll-{index:02}',language,theme)
        frames.append(load(RUN/'release-captures.json')[-1]['capture_id'])
        previous=current;scroll();time.sleep(.7)
    report={'screen_id':screen,'frames':frames,'ended_at_scroll_boundary':ended,'created':now(),
            'criterion':'body pixel digest unchanged after forward scroll; excludes system bars and scrollbar; original PNGs retained'}
    dump(CURRENT/'verification'/(screen+'-scroll-sequence.json'),report)
    if not ended:raise RuntimeError('Scroll boundary not reached; resume instead of claiming completeness')
    print(json.dumps({'sequence':screen,'frames':len(frames),'boundary_verified':ended}))


def install():
    assert adb("shell", "getprop", "ro.kernel.qemu").strip() == b"1"
    assert adb("shell", "getprop", "sys.boot_completed").strip() == b"1"
    apk = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
    try:
        result = adb("install", "-r", str(apk)).decode()
    except RuntimeError as error:
        if "INSTALL_FAILED_UPDATE_INCOMPATIBLE" not in str(error):
            raise
        assert load(RUN/"emulator.json")["readonly"] is True
        assert SERIAL == "emulator-5556"
        adb("uninstall", "com.settrace.settrace")
        result = adb("install", str(apk)).decode()
    assert "Success" in result, result
    adb("shell", "wm", "size", "1080x2400")
    adb("shell", "wm", "density", "480")
    adb("shell", "settings", "put", "system", "font_scale", "1.0")
    adb("shell", "am", "start", "-n", "com.settrace.settrace/.MainActivity")
    time.sleep(2)
    metadata = {"baseline_id": "306b9bc-0.3.1+12-2026-10-31", "source_commit": load(RUN/"baseline.json")["source_commit"],
                "apk_sha256": sha(apk), "apk_bytes": apk.stat().st_size,
                "source_fingerprint": {k:v for k,v in load(RUN/"baseline.json")["protected_files"].items() if k.startswith(("lib/", "android/", "assets/", "pubspec"))},
                "built_at": now(), "version": "0.3.1+12", "target": "lib/main.dart", "build_kind": "release",
                "command": "tool/ui_reference_dev.ps1 -Tool flutter -ToolArgs build,apk,--release,--no-pub,--target,lib/main.dart",
                "installed_package": adb("shell", "dumpsys", "package", "com.settrace.settrace").decode(errors="replace"),
                "api": adb("shell", "getprop", "ro.build.version.sdk").decode().strip(),
                "abi": adb("shell", "getprop", "ro.product.cpu.abi").decode().strip(),
                "emulator": load(RUN/"emulator.json"), "environment": load(RUN/"environment.json")}
    dump(CURRENT / "verification/build.json", metadata)
    mark("4.1", "4.2")
    print(result)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["install", "capture", "tap", "nodes", "back", "scroll", "input", "matrix", "sequence"])
    parser.add_argument("args", nargs="*")
    args = parser.parse_args()
    if args.command == "install": install()
    elif args.command == "matrix": matrix(*args.args)
    elif args.command == "sequence": sequence(*args.args)
    elif args.command == "capture": capture(*args.args)
    elif args.command == "tap": tap(" ".join(args.args))
    elif args.command == "nodes": print(json.dumps([{k: n.get(k) for k in ["text", "content-desc", "bounds", "clickable"]} for n in nodes() if n.get("text") or n.get("content-desc")], ensure_ascii=False))
    elif args.command == "back": adb("shell", "input", "keyevent", "4")
    elif args.command == "scroll": adb("shell", "input", "swipe", "850", "1900" if args.args != ["up"] else "500", "850", "700" if args.args != ["up"] else "2000", "450")
    elif args.command == "input": adb("shell", "input", "text", " ".join(args.args).replace(" ", "%s"))
