"""Standard-library preflight checks; does not replace Xcode compilation."""
import json
import pathlib
import plistlib
import struct
import re

root = pathlib.Path(__file__).resolve().parent.parent
with (root / "FitLife/Info.plist").open("rb") as f:
    info = plistlib.load(f)
for key in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleShortVersionString", "CFBundleVersion", "UILaunchScreen"):
    assert key in info, f"Missing Info.plist key: {key}"
with (root / "FitLife/FitLife.entitlements").open("rb") as f:
    assert plistlib.load(f) == {}, "No private entitlements are required"
for file in (root / "FitLife/Assets.xcassets").rglob("*.json"):
    json.loads(file.read_text(encoding="utf-8"))
png = (root / "FitLife/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()
assert png[:8] == b"\x89PNG\r\n\x1a\n"
width, height, bit_depth, color_type = struct.unpack(">IIBB", png[16:26])
assert (width, height) == (1024, 1024), (width, height)
assert color_type in (0, 2), "App icon must not contain alpha"
sources = list((root / "FitLife").rglob("*.swift"))
assert sum("@main" in f.read_text(encoding="utf-8") for f in sources) == 1
for file in sources:
    text = file.read_text(encoding="utf-8")
    assert "ContentUnavailableView" not in text, "iOS 17 API incompatible with iOS 16"
    # Remove ordinary Swift strings/comments for a basic delimiter check.
    scrubbed = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/', '', text, flags=re.S)
    stack = []
    pairs = {')': '(', ']': '[', '}': '{'}
    for character in scrubbed:
        if character in '([{':
            stack.append(character)
        elif character in ')]}':
            assert stack and stack.pop() == pairs[character], f"Delimiter mismatch: {file}"
    assert not stack, f"Unclosed delimiter: {file}"
spec = (root / "project.yml").read_text(encoding="utf-8")
assert "com.example.fatloss28" in spec, "V3 Bundle ID must be preserved"
assert 'IPHONEOS_DEPLOYMENT_TARGET: "16.0"' in spec
assert (root / ".github/workflows/build-tipa.yml").is_file()
print(f"PASS: {len(sources)} Swift sources, plist/JSON/icon/project preflight")
