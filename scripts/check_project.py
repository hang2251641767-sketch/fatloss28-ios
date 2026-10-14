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

catalog = json.loads((root / "FitLife/Resources/TrainingPrograms.json").read_text(encoding="utf-8"))
fixture = json.loads((root / "Tests/LegacyTrainingFixture.json").read_text(encoding="utf-8"))
assert len(catalog) == 10
assert len({p["id"] for p in catalog}) == len(catalog)
original = next(p for p in catalog if p["id"] == "legacy-v3-28day")
assert [[e["prescription"] for e in d["exercises"]] for d in original["days"]] == fixture
assert {"初级", "中级"} <= {p["level"] for p in catalog}
assert {"增肌", "减脂", "基础体能", "恢复"} <= {p["goal"] for p in catalog}
for program in catalog:
    assert 1 <= program["weeks"] <= 52
    assert len({d["offset"] for d in program["days"]}) == len(program["days"])
    for day in program["days"]:
        assert 0 <= day["offset"] <= 6
        for exercise in day["exercises"]:
            assert exercise["sets"] > 0
            assert exercise.get("reps", 0) > 0 or exercise.get("durationSeconds", 0) > 0
print("PASS: 10 offline programs, 25 original V3 prescriptions, goal/level coverage")

meals = json.loads((root / "FitLife/Resources/MealGuide.json").read_text(encoding="utf-8"))
assert len(meals) == 7
for day in meals:
    assert len(day["meals"]) == 4
    assert len({m["id"] for m in day["meals"]}) == 4
    for meal in day["meals"]:
        assert len({f["id"] for f in meal["ingredients"]}) == len(meal["ingredients"])
        assert all(f["grams"] > 0 and f["basis"] for f in meal["ingredients"])
for asset in ["CourseHome", "CourseStrength", "NutritionCover"]:
    folder = root / ("FitLife/Assets.xcassets/" + asset + ".imageset")
    assert (folder / "cover.png").is_file()
    assert (folder / "cover.png").stat().st_size > 10000
print("PASS: 7 daily meal menus, explicit portions, 3 offline photographic covers")
