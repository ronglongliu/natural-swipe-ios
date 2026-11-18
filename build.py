#!/usr/bin/env python3
from pathlib import Path
import hashlib
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
SDK = Path(os.environ.get("IOS_SDK", "/tmp/sdks/iPhoneOS16.5.sdk"))
CLANG = os.environ.get("IOS_CLANG", "clang")
LDID = Path(os.environ.get("IOS_LDID", "/var/minis/shared/iostoolchain/bin/ldid"))
OUT = ROOT / "dist" / "NaturalSwipeUniversal.dylib"
SRC = ROOT / "src"

BASE = [
    CLANG, "-target", "arm64-apple-ios15.0", "-isysroot", str(SDK),
    "-fobjc-arc", "-fblocks", "-O2", "-fuse-ld=lld",
    "-framework", "UIKit", "-framework", "Foundation",
    "-framework", "QuartzCore", "-framework", "CoreFoundation",
    "-framework", "CoreGraphics",
]

def run(args):
    subprocess.run([str(x) for x in args], check=True)

def main():
    if not SDK.exists():
        raise SystemExit(f"SDK not found: {SDK}\nSet IOS_SDK to an iPhoneOS SDK path.")
    if not LDID.exists():
        raise SystemExit(f"ldid not found: {LDID}\nSet IOS_LDID to a compatible signing tool.")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    run(BASE + [
        "-shared", "-Wl,-install_name,@rpath/NaturalSwipeUniversal.dylib",
        SRC / "NSSwipeEngine.m", SRC / "NSController.m", "-o", OUT,
    ])
    signer = Path("/tmp/natural-swipe-universal-ldid")
    shutil.copy2(LDID, signer)
    os.chmod(signer, 0o755)
    run([signer, "-S", OUT])
    print(f"built: {OUT}")
    print(f"sha256: {hashlib.sha256(OUT.read_bytes()).hexdigest()}")

if __name__ == "__main__":
    main()
