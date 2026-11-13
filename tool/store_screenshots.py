#!/usr/bin/env python3
"""Mağaza ekran görüntülerini iOS simülatöründen çeker.

Kullanım: python3 tool/store_screenshots.py <simülatör-udid>
integration_test/store_screenshots_test.dart'ı çalıştırır; test her
"STORE_SHOT <ad>" satırı bastığında simülatör ekranını build/screenshots/
altına kaydeder (durum çubuğu dahil).
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
udid = sys.argv[1]
out = ROOT / "build/screenshots"
out.mkdir(parents=True, exist_ok=True)

subprocess.run(["xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41",
                "--batteryLevel", "100", "--batteryState", "charged"], check=False)
proc = subprocess.Popen(
    ["flutter", "drive", "--driver=test_driver/integration_test.dart",
     "--target=integration_test/store_screenshots_test.dart",
     "--dart-define=STORE_SCREENSHOTS=true", "-d", udid],
    cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
for line in proc.stdout:
    if "STORE_SHOT " in line:
        name = line.split("STORE_SHOT ", 1)[1].strip()
        # Simülatör servisi harici diske (SSD) doğrudan yazamıyor; önce /tmp.
        tmp = pathlib.Path(tempfile.gettempdir()) / f"{name}.png"
        subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(tmp)],
                       check=True, capture_output=True)
        shutil.move(tmp, out / f"{name}.png")
        print(f"✓ {name}")
    elif "All tests passed" in line or "Some tests failed" in line or "Exception" in line:
        print(line.rstrip())
sys.exit(proc.wait())
