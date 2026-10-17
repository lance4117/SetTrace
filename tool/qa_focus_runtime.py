"""Observed-UI and database evidence helpers for the two isolated Focus QA AVDs.
Never targets a physical device or an existing personal AVD.
"""
import io
import json
import re
import sqlite3
import subprocess
import tarfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/qa/focus-a-redesign-evidence/runtime"
OUT.mkdir(parents=True, exist_ok=True)
ADB = "D:/ProgramData/Android_SDK/platform-tools/adb.exe"
PACKAGE = "com.settrace.settrace"

class Device:
    def __init__(self, serial="emulator-5580"):
        if serial not in {"emulator-5580", "emulator-5582"}:
            raise ValueError("Only the isolated Focus QA AVDs are allowed")
        self.serial = serial

    def adb(self, *args, data=None):
        return subprocess.run([ADB, "-s", self.serial, *args], input=data,
                              capture_output=True, check=True).stdout

    def shell(self, *args):
        return self.adb("shell", *args).decode("utf-8", errors="replace")

    def nodes(self):
        for _ in range(5):
            self.shell("rm", "-f", "/sdcard/focus-runtime.xml")
            status = self.shell("uiautomator", "dump", "--compressed", "/sdcard/focus-runtime.xml")
            if "dumped to" not in status:
                time.sleep(.3)
                continue
            raw = self.adb("exec-out", "cat", "/sdcard/focus-runtime.xml")
            try:
                return ET.fromstring(raw)
            except ET.ParseError:
                time.sleep(.3)
        raise AssertionError("No UI hierarchy")

    def wait(self, label, *, contains=False):
        for _ in range(8):
            nodes = self.nodes()
            if any(label in (n.get("text", "")+n.get("content-desc", ""))
                   if contains else label in (n.get("text"), n.get("content-desc"))
                   for n in nodes.iter("node")):
                return
            time.sleep(.3)
        raise AssertionError(f"UI did not expose {label!r}")

    def tap(self, label, *, contains=False):
        root = self.nodes()
        matches = [n for n in root.iter("node") if
                   (label in n.get("text", "") or label in n.get("content-desc", ""))
                   if contains or label in (n.get("text"), n.get("content-desc"))]
        if len(matches) != 1:
            raise AssertionError(f"Expected one {label!r}, found {len(matches)}")
        bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", matches[0].get("bounds", ""))
        if not bounds:
            raise AssertionError("Unusable target bounds")
        x1, y1, x2, y2 = map(int, bounds.groups())
        if x2 <= x1 or y2 <= y1:
            raise AssertionError("Target is off screen")
        self.shell("input", "tap", str((x1+x2)//2), str((y1+y2)//2))
        time.sleep(.5)

    def snapshot(self, label):
        if not re.fullmatch(r"[a-z0-9-]+", label):
            raise ValueError(label)
        root = self.nodes()
        (OUT / (label+".xml")).write_bytes(ET.tostring(root, encoding="utf-8"))
        (OUT / (label+".png")).write_bytes(self.adb("exec-out", "screencap", "-p"))
        nodes = [{k:n.get(k) for k in ["text", "content-desc", "class", "focused", "selected", "clickable", "bounds"]}
                 for n in root.iter("node") if n.get("text") or n.get("content-desc")]
        print(json.dumps({"snapshot": label, "accessibleNodes": len(nodes)}))
        return nodes

    def pull_db(self, label):
        # A stopped app has a coherent WAL. Work only with a host copy of its files.
        self.shell("am", "force-stop", PACKAGE)
        data = self.adb("exec-out", "run-as", PACKAGE, "tar", "-cf", "-", "databases")
        folder = OUT / label
        folder.mkdir(exist_ok=True)
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            for item in archive.getmembers():
                if item.isfile() and Path(item.name).name.startswith("settrace.db"):
                    (folder / Path(item.name).name).write_bytes(archive.extractfile(item).read())
        path = folder / "settrace.db"
        db = sqlite3.connect(path)
        try:
            db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        finally:
            db.close()
        return path

    def push_db(self, path):
        path = Path(path).resolve()
        if not path.is_relative_to(OUT.resolve()):
            raise ValueError("Only a Focus QA evidence database copy may be uploaded")
        db = sqlite3.connect(path)
        try:
            db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        finally:
            db.close()
        self.shell("am", "force-stop", PACKAGE)
        # Remove only the two known QA-app WAL files, never a directory.
        self.shell("run-as", PACKAGE, "rm", "-f", "databases/settrace.db-wal", "databases/settrace.db-shm")
        remote = "/data/local/tmp/settrace-focus-qa.db"
        self.adb("push", str(path), remote)
        self.shell("run-as", PACKAGE, "cp", remote, "databases/settrace.db")
        self.shell("rm", "-f", remote)
        uploaded = self.adb("exec-out", "run-as", PACKAGE, "cat", "databases/settrace.db")
        if uploaded != path.read_bytes():
            raise AssertionError("QA database upload was not byte-for-byte complete")

    def launch(self, session=None):
        command = ["am", "start", "-n", PACKAGE+"/.MainActivity"]
        if session is not None:
            command += ["--ei", "rest_session_id", str(session)]
        self.shell(*command)
        time.sleep(1)
