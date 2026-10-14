"""Collect screenshots from the isolated QA emulator before Flutter uninstalls
its integration APK. Never targets a physical or personal device."""
import argparse, io, json, re, subprocess, tarfile, time
import xml.etree.ElementTree as ET
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument("--serial",default="emulator-5580")
parser.add_argument("--label",required=True)
parser.add_argument("--log",required=True)
parser.add_argument("--keyboard",action="store_true")
parser.add_argument("--legacy",action="store_true")
parser.add_argument("--journey",action="store_true")
parser.add_argument("--watch-log",action="store_true")
parser.add_argument("--scenes",default="")
args=parser.parse_args()
assert re.fullmatch(r"emulator-\d+",args.serial)
assert re.fullmatch(r"[a-z0-9-]+",args.label)
root=Path(__file__).resolve().parent.parent
destination=root/"docs/qa/focus-a-redesign-evidence"/args.label
destination.mkdir(parents=True,exist_ok=True)
log=Path(args.log)
adb="C:/Users/Lance/AppData/Local/Android/sdk/platform-tools/adb.exe"
folder="focus-a-journey" if args.journey else "focus-a-legacy" if args.legacy else "focus-a-accessibility" if args.keyboard else "focus-a-evidence"
process=None
if not args.watch_log:
    target="integration_test/localization_android_test.dart" if args.journey else "integration_test/localization_legacy_test.dart" if args.legacy else "integration_test/focus_a_keyboard_test.dart" if args.keyboard else "integration_test/focus_a_redesign_test.dart"
    command=["C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe","C:/dev/flutter/bin/cache/flutter_tools.snapshot",
             "--no-version-check","test",target,"-d",args.serial,"--no-pub","--reporter","expanded",
             "--dart-define=FOCUS_EXPORT_WAIT=true"]
    if args.scenes:
        assert re.fullmatch(r"[A-Z0-9,]+",args.scenes)
        command+=["--dart-define=FOCUS_SCENES="+args.scenes]
    output=log.open("wb")
    process=subprocess.Popen(command,cwd=root,stdout=output,stderr=subprocess.STDOUT,
                             creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))

actions=set()
def adb_command(*command):
    return subprocess.run([adb,"-s",args.serial,*command],capture_output=True)
def system_nodes():
    result=adb_command("shell","uiautomator","dump","/sdcard/focus-qa.xml")
    if result.returncode: return []
    result=adb_command("exec-out","cat","/sdcard/focus-qa.xml")
    try:return list(ET.fromstring(result.stdout).iter("node"))
    except ET.ParseError:return []
def click_node(node,stage):
    bounds=re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",node.get("bounds",""))
    if not bounds:return False
    x1,y1,x2,y2=map(int,bounds.groups())
    adb_command("shell","screencap","-p","/sdcard/focus-system.png")
    result=adb_command("exec-out","cat","/sdcard/focus-system.png")
    if result.stdout.startswith(b"\x89PNG"):(destination/(stage+".png")).write_bytes(result.stdout)
    adb_command("shell","input","tap",str((x1+x2)//2),str((y1+y2)//2))
    return True
def legacy_actions(text):
    for marker,suffix in [("LEGACY_QA_DENY","permission_deny_button"),("LEGACY_QA_ALLOW","permission_allow_button")]:
        if marker in text and marker not in actions:
            for node in system_nodes():
                if node.get("resource-id","").endswith("/"+suffix) and click_node(node,marker.lower()):
                    actions.add(marker);break
    if "LEGACY_QA_CANCEL" in text and "cancel" not in actions:
        nodes=system_nodes()
        if any("documentsui" in n.get("package","") for n in nodes):
            adb_command("shell","input","keyevent","4");actions.add("cancel")
    if "LEGACY_QA_PICK_OLD" in text and "old" not in actions:
        nodes=system_nodes()
        node=next((n for n in nodes if n.get("text","").startswith("SetTrace-plans-")),None)
        if node is not None:
            if click_node(node,"legacy-selected-backup"):actions.add("old")
        else:
            node=next((n for n in nodes if n.get("text","") in ["Downloads","Download"]),None)
            if node is None:
                node=next((n for n in nodes if n.get("content-desc","") in ["Show roots","Open navigation drawer"]),None)
            if node is not None:click_node(node,"legacy-file-browser")
    (destination/"native-actions.json").write_text(json.dumps(sorted(actions)),encoding="utf-8")
saved=set()
last_count=0
exported=False
started=time.monotonic()
while time.monotonic()-started<1200:
    text=log.read_text(encoding="utf-8",errors="replace") if log.exists() else ""
    names=set(re.findall(r"FOCUS_SCENE ([A-Z]\d{2}-(?:en|zh)-(?:dark|light)-\d+) OK",text))
    ready="FOCUS_EXPORT_READY" in text
    if args.legacy:legacy_actions(text)
    should_collect=(ready and not exported) or (args.watch_log and len(names)>last_count)
    if should_collect:
        r=subprocess.run([adb,"-s",args.serial,"exec-out","run-as","com.settrace.settrace",
                          "tar","-cf","-","code_cache/"+folder],capture_output=True)
        try:
            with tarfile.open(fileobj=io.BytesIO(r.stdout)) as archive:
                for member in archive.getmembers():
                    if not member.isfile():
                        continue
                    name=Path(member.name).name
                    if not re.fullmatch(r"[A-Za-z0-9_.-]+",name):
                        raise ValueError(name)
                    if name.endswith(".png") and (ready or name[:-4] in names):
                        (destination/name).write_bytes(archive.extractfile(member).read())
                        saved.add(name)
                    if name=="results.json" and ready:
                        data=archive.extractfile(member).read()
                        json.loads(data)
                        (destination/name).write_bytes(data)
            last_count=len(names)
            if ready:
                subprocess.run([adb,"-s",args.serial,"shell","run-as","com.settrace.settrace",
                                "touch","code_cache/"+folder+"/export.done"],check=True,capture_output=True)
                exported=True
        except tarfile.ReadError:
            pass
    ended=process.poll() is not None if process else ("All tests passed!" in text or "Some tests failed." in text)
    if ended:
        if process:
            output.close()
        successful="All tests passed!" in text
        print(json.dumps({"screenshots":len(saved),"destination":str(destination),
                          "testsPassed":successful,"exported":exported}))
        if not successful or (not args.watch_log and not exported):
            raise SystemExit(1)
        break
    time.sleep(.4 if args.watch_log else 1)
else:
    if process:
        process.terminate()
    raise TimeoutError("Android evidence collection timed out")
