"""Validate the built payload before making it downloadable."""
import pathlib
import plistlib
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None, "ZIP checksum failure"
    plist_path = "Payload/FitLife.app/Info.plist"
    info = plistlib.loads(bundle.read(plist_path))
    assert info["CFBundleIdentifier"] == "com.example.fatloss28"
    assert info["CFBundleShortVersionString"] == "4.0.0"
    assert info["MinimumOSVersion"] == "16.0", info.get("MinimumOSVersion")
    executable = "Payload/FitLife.app/" + info["CFBundleExecutable"]
    binary = bundle.read(executable)
    assert len(binary) > 10000, "Executable is unexpectedly small"
    assert binary[:4] in (b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"), "Not a Mach-O executable"
    assert "Payload/FitLife.app/Assets.car" in bundle.namelist(), "Compiled assets missing"
print(f"PASS: {archive.name}, iOS 16.0, FitLife 4.0.0, executable and assets")
