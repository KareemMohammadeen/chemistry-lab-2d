#!/usr/bin/env python3
"""Static project validator for Chemistry Lab (no Godot binary required).

Run from the project root:  python3 tests/validate_project.py

Checks:
  1. Every res:// path referenced anywhere exists.
  2. File and folder names are snake_case (root docs excepted).
  3. .tscn files: ext_resource ids are declared and used, sub_resource ids are
     declared and used, node parents exist, NodePath exports resolve.
  4. .gd files: consistent tab indentation, balanced brackets, unique class_name,
     and no class_name that shadows an autoload singleton.
  5. Autoload scripts exist; JSON data files parse.
Exit code is non-zero if any check fails.
"""
import json
import posixpath
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROOT_DOC_FILES = {"README.md", "PROJECT_CONTEXT.md", "TODO.md", "CHANGELOG.md", "NEXT_SESSION.md"}
SKIP_DIRS = {".godot", ".git", ".github"}
SNAKE = re.compile(r"^[a-z0-9_]+(\.[a-z0-9_]+)*$")
ENGINE_NAMES = {"FontVariation",
    "Array", "AudioStream", "AudioStreamPlayer", "AudioStreamWAV", "Button", "ButtonGroup", "CanvasLayer", "CenterContainer", "Color", "ColorRect", "Container", "Control",
    "Dictionary", "FileAccess", "FileDialog", "GridContainer", "HSeparator", "HBoxContainer", "HSplitContainer", "Input", "InputEvent",
    "InputEventKey", "InputEventJoypadButton", "InputEventJoypadMotion", "InputEventMouseButton", "InputEventMouseMotion", "InputMap", "ItemList",
    "JSON", "Label", "MarginContainer", "MenuButton", "Node", "Node2D", "Object",
    "OS", "PackedColorArray", "PopupMenu", "PackedScene", "PackedStringArray", "PackedVector2Array", "PanelContainer", "Rect2",
    "RichTextLabel", "TabContainer",
    "RefCounted", "ScrollContainer", "SceneTree", "SpinBox", "StringName", "StyleBoxFlat", "TextServer", "ThemeDB",
    "Time", "ResourceLoader", "StyleBoxEmpty", "Texture2D", "Theme", "StyleBox", "VBoxContainer", "Vector2", "Viewport", "Key", "MouseButton", "JoyButton", "JoyAxis", "String", "Variant",
    "Callable", "NodePath", "DirAccess", "ProjectSettings", "Engine", "Tween", "Timer", "Window", "Font",
}
errors: list[str] = []
warnings: list[str] = []


def files(*suffixes):
    for p in sorted(ROOT.rglob("*")):
        if p.is_file() and not (set(p.relative_to(ROOT).parts) & SKIP_DIRS) and p.suffix in suffixes:
            yield p


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def check_res_paths():
    pattern = re.compile(r'res://[A-Za-z0-9_./-]+\.[A-Za-z0-9]+')
    for p in files(".gd", ".tscn", ".tres", ".json", ".godot"):
        for m in pattern.findall(p.read_text(encoding="utf-8")):
            if not (ROOT / m[len("res://"):]).exists():
                errors.append(f"{rel(p)}: missing resource {m}")


def check_names():
    for p in sorted(ROOT.rglob("*")):
        parts = set(p.relative_to(ROOT).parts)
        if parts & SKIP_DIRS:
            continue
        name = p.name
        if p.is_dir():
            if not SNAKE.match(name):
                errors.append(f"{rel(p)}: folder name is not snake_case")
        elif name in ROOT_DOC_FILES or name.startswith(".") or name in {"icon.svg", "project.godot"}:
            continue
        elif p.parent == ROOT / "docs" and re.match(r"^[A-Z0-9_]+\.md$", name):
            continue  # docs/ uses UPPER_SNAKE_CASE.md by convention
        elif not SNAKE.match(name):
            errors.append(f"{rel(p)}: file name is not snake_case")


def check_scene(p: Path):
    text = p.read_text(encoding="utf-8")
    ext_ids = re.findall(r'^\[ext_resource [^\]]*\bid="([^"]+)"', text, re.M)
    sub_ids = re.findall(r'^\[sub_resource [^\]]*\bid="([^"]+)"', text, re.M)
    used_ext = set(re.findall(r'ExtResource\("([^"]+)"\)', text))
    used_sub = set(re.findall(r'SubResource\("([^"]+)"\)', text))
    for i in used_ext - set(ext_ids):
        errors.append(f"{rel(p)}: ExtResource '{i}' used but not declared")
    for i in set(ext_ids) - used_ext:
        errors.append(f"{rel(p)}: ext_resource '{i}' declared but unused")
    for i in used_sub - set(sub_ids):
        errors.append(f"{rel(p)}: SubResource '{i}' used but not declared")
    for i in set(sub_ids) - used_sub:
        errors.append(f"{rel(p)}: sub_resource '{i}' declared but unused")

    # Node tree
    nodes: dict[str, dict] = {}
    current = None
    root_seen = False
    for line in text.splitlines():
        m = re.match(r'^\[node name="([^"]+)"(.*)\]$', line)
        if m:
            name, rest = m.group(1), m.group(2)
            parent = re.search(r'parent="([^"]*)"', rest)
            if parent is None:
                if root_seen:
                    errors.append(f"{rel(p)}: multiple root nodes")
                root_seen = True
                path = "."
            else:
                par = parent.group(1)
                if par != "." and par not in nodes:
                    errors.append(f"{rel(p)}: node '{name}' has unknown parent '{par}'")
                path = name if par == "." else f"{par}/{name}"
            nodes[path] = {"props": {}, "node_paths": re.findall(r'"([^"]+)"', (re.search(r'node_paths=PackedStringArray\(([^)]*)\)', rest) or [None, ""])[1])}
            current = path
        elif line.startswith("["):
            current = None
        elif current and " = " in line:
            k, v = line.split(" = ", 1)
            nodes[current]["props"][k.strip()] = v.strip()

    for path, info in nodes.items():
        for prop in info["node_paths"]:
            value = info["props"].get(prop, "")
            m = re.match(r'NodePath\("([^"]*)"\)', value)
            if not m:
                errors.append(f"{rel(p)}: node '{path}' lists node_path '{prop}' but has no NodePath value")
                continue
            base = "" if path == "." else path
            target = posixpath.normpath(posixpath.join(base, m.group(1)))
            if target == ".":
                continue
            if target in nodes:
                continue
            # A path may legitimately continue into an instanced scene's children.
            parts = target.split("/")
            if any("/".join(parts[:i]) in nodes for i in range(1, len(parts))):
                warnings.append(f"{rel(p)}: '{prop}' -> '{m.group(1)}' points inside an instanced scene (verify manually)")
            else:
                errors.append(f"{rel(p)}: node '{path}' property '{prop}' -> '{m.group(1)}' does not resolve")
        for prop, value in info["props"].items():
            if prop not in info["node_paths"] and value.startswith('NodePath("') and prop != "script":
                errors.append(f"{rel(p)}: node '{path}' sets NodePath '{prop}' but it is missing from node_paths=")


def strip_gd(line: str) -> str:
    line = re.sub(r'"(\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(\\.|[^'\\])*'", "''", line)
    line = re.sub(r'&""', '""', line)
    return line.split("#", 1)[0]


def check_scripts():
    autoloads = {}
    for line in (ROOT / "project.godot").read_text().splitlines():
        m = re.match(r'^(\w+)="\*res://(.+)"$', line)
        if m:
            autoloads[m.group(1)] = m.group(2)
    for name, path in autoloads.items():
        if not (ROOT / path).exists():
            errors.append(f"project.godot: autoload {name} -> {path} missing")

    class_names: dict[str, str] = {}
    for p in files(".gd"):
        text = p.read_text(encoding="utf-8")
        for n, line in enumerate(text.splitlines(), 1):
            indent = re.match(r"^[ \t]*", line).group(0)
            if " " in indent and line.strip():
                errors.append(f"{rel(p)}:{n}: space indentation (use tabs)")
        stack, pairs = [], {")": "(", "]": "[", "}": "{"}
        for n, line in enumerate(text.splitlines(), 1):
            for ch in strip_gd(line):
                if ch in "([{":
                    stack.append((ch, n))
                elif ch in pairs:
                    if not stack or stack.pop()[0] != pairs[ch]:
                        errors.append(f"{rel(p)}:{n}: unbalanced '{ch}'")
        if stack:
            errors.append(f"{rel(p)}: unclosed '{stack[-1][0]}' opened on line {stack[-1][1]}")
        m = re.search(r"^class_name (\w+)", text, re.M)
        is_autoload = rel(p) in autoloads.values()
        if m:
            if m.group(1) in class_names:
                errors.append(f"{rel(p)}: duplicate class_name {m.group(1)} (also {class_names[m.group(1)]})")
            class_names[m.group(1)] = rel(p)
            if m.group(1) in autoloads:
                errors.append(f"{rel(p)}: class_name {m.group(1)} shadows autoload")
            if is_autoload:
                errors.append(f"{rel(p)}: autoload scripts must not declare class_name")
        if not text.endswith("\n"):
            errors.append(f"{rel(p)}: missing final newline")
    # Every CamelCase identifier used as a type or static call must be a project class, an
    # autoload or a known engine class. Unknown names are reported as warnings to eyeball.
    known = set(autoloads) | set(class_names) | ENGINE_NAMES
    # Enums declared inside a project script (e.g. LibraryIcon.Kind) are valid type names too.
    for p in files(".gd"):
        known |= set(re.findall(r"^enum (\w+)", p.read_text(encoding="utf-8"), re.M))
    for p in files(".gd"):
        text = p.read_text(encoding="utf-8")
        for ref in set(re.findall(r"\b(EventBus|InputManager|GameManager|SettingsManager|AudioManager)\b", text)):
            if ref not in autoloads:
                errors.append(f"{rel(p)}: uses undefined autoload {ref}")
        code = "\n".join(strip_gd(line) for line in text.splitlines())
        for ref in set(re.findall(r"(?:\bas |:\s*|->\s*|\bis |\b)([A-Z][A-Za-z0-9]+)(?=\.new\(|\.[a-z_]+\(|\s*=|\s*$|\s*:|\s*\)|\s*,)", code)):
            if ref not in known and not ref.isupper():
                warnings.append(f"{rel(p)}: unknown type or class '{ref}' (check spelling)")


def check_variant_inference():
    """`var x := dict[...]` or `:= something.get(...)` cannot infer a type in GDScript 4."""
    risky = re.compile(r":=\s*(?!.*\b(?:float|int|str|bool|String|Vector2|Color|StringName)\()(?!.*\bas\b).*(?:\.get\(.*\)|\[[\"'a-z_]+[\"']?\])\s*$")
    for p in files(".gd"):
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            code = strip_gd(line)
            if ":=" in code and risky.search(code):
                warnings.append(f"{rel(p)}:{n}: ':=' from a Variant expression may fail to infer a type: {line.strip()}")


def check_scene_exports():
    """Every node-typed @export of a script must be assigned in the scene that uses the script."""
    plain = {"int", "float", "String", "bool", "Color", "Vector2", "PackedScene", "Texture2D", "StringName"}
    for scene in files(".tscn"):
        text = scene.read_text(encoding="utf-8")
        script_ids = dict((i, path) for path, i in re.findall(r'\[ext_resource type="Script" path="res://([^"]+)" id="([^"]+)"', text))
        for block in re.split(r"(?m)^(?=\[node )", text):
            m = re.match(r'\[node name="([^"]+)"', block)
            sm = re.search(r'^script = ExtResource\("([^"]+)"\)', block, re.M)
            if not m or not sm or sm.group(1) not in script_ids:
                continue
            gd = ROOT / script_ids[sm.group(1)]
            if not gd.exists():
                continue
            for name, typ in re.findall(r"^@export var (\w+): ([A-Za-z0-9_]+)", gd.read_text(encoding="utf-8"), re.M):
                if re.search(rf"^{name} = ", block, re.M) is None:
                    errors.append(f"{rel(scene)}: node '{m.group(1)}' does not assign @export {name}: {typ}")


def _load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def check_json():
    for p in files(".json"):
        try:
            json.loads(p.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{rel(p)}: invalid JSON ({e})")
    bindings = _load("data/input/default_bindings.json")["actions"]
    for action in ("undo", "redo", "deselect", "toggle_pause"):
        if action not in bindings:
            errors.append(f"input action '{action}' has no binding")
    interactions = {e["id"] for e in _load("data/interaction/interaction_types.json")["interactions"]}
    chemicals = {f.stem: _load(rel(f)) for f in (ROOT / "data/chemicals").glob("*.json")}
    equipment = {f.stem: _load(rel(f)) for f in (ROOT / "data/equipment").glob("*.json")}
    reactions = {f.stem: _load(rel(f)) for f in (ROOT / "data/reactions").glob("*.json")}
    for stem, c in chemicals.items():
        if c["id"] != stem:
            errors.append(f"data/chemicals/{stem}.json: id '{c['id']}' does not match the file name")
        if len(c.get("color", [])) != 4:
            errors.append(f"data/chemicals/{stem}.json: color must be RGBA")
        for key in ("name", "state", "density_g_ml", "safety", "display"):
            if key not in c:
                errors.append(f"data/chemicals/{stem}.json: missing '{key}'")
    for stem, e in equipment.items():
        if e["id"] != stem:
            errors.append(f"data/equipment/{stem}.json: id does not match the file name")
        for i in e.get("interactions", []):
            if i not in interactions:
                errors.append(f"data/equipment/{stem}.json: unknown interaction '{i}'")
        profile = e.get("visual", {}).get("profile", [])
        heights = [p[0] for p in profile]
        if heights != sorted(heights):
            errors.append(f"data/equipment/{stem}.json: profile heights must ascend")
        if e.get("category") == "vessel" and not profile:
            errors.append(f"data/equipment/{stem}.json: vessel without a visual profile")
        for point in ("base", "opening", "pour_lip"):
            if e.get("category") == "vessel" and point not in e.get("interaction_points", {}):
                errors.append(f"data/equipment/{stem}.json: missing interaction point '{point}'")
    for stem, r in reactions.items():
        for key in ("solute", "solvent"):
            if key in r and r[key] not in chemicals:
                errors.append(f"data/reactions/{stem}.json: unknown chemical '{r[key]}'")
    for f in (ROOT / "data/setups").glob("*.json"):
        for o in _load(rel(f))["objects"]:
            if o["equipment"] not in equipment:
                errors.append(f"{rel(f)}: unknown equipment '{o['equipment']}'")
            contents = o.get("contents", {})
            for kind in ("liquids", "solids"):
                for cid in contents.get(kind, {}):
                    if cid not in chemicals:
                        errors.append(f"{rel(f)}: unknown chemical '{cid}'")
    # Reference data: elements and compounds.
    elements = _load("data/elements/elements.json")["elements"]
    if [e["atomic_number"] for e in elements] != list(range(1, 119)):
        errors.append("data/elements/elements.json: atomic numbers must run 1..118 without gaps")
    if len({e["symbol"] for e in elements}) != 118:
        errors.append("data/elements/elements.json: symbols are not unique")
    by_symbol = {e["symbol"]: e for e in elements}
    for e in elements:
        for key in ("atomic_mass_u", "melting_c", "boiling_c", "density_g_cm3", "electronegativity_pauling"):
            entry = e.get(key)
            if entry is not None and entry.get("status") not in ("unverified_reference", "reference", "derived", "placeholder"):
                errors.append(f"element {e['symbol']}.{key}: missing provenance status")
        if e.get("melting_c") and e.get("boiling_c") and e["melting_c"]["value"] > e["boiling_c"]["value"] \
                and "ublimation" not in e["boiling_c"].get("note", ""):
            errors.append(f"element {e['symbol']}: melting point above boiling point")
        if sum(e["electrons_per_shell"]) != e["atomic_number"]:
            errors.append(f"element {e['symbol']}: electrons per shell do not add up to Z")
    for f in sorted((ROOT / "data/compounds").glob("*.json")):
        c = _load(rel(f))
        if c["id"] != f.stem:
            errors.append(f"{rel(f)}: id does not match the file name")
        mass = sum(by_symbol[s]["atomic_mass_u"]["value"] * n for s, n in c["composition"].items())
        if abs(mass - c["molar_mass_g_mol"]["value"]) > 0.01:
            errors.append(f"{rel(f)}: molar mass {c['molar_mass_g_mol']['value']} does not match its composition ({mass:.3f})")
        sim = c["simulation"]["chemical_id"]
        if sim and sim not in chemicals:
            errors.append(f"{rel(f)}: unknown simulation chemical '{sim}'")
        for key in ("hazards", "storage", "educational_notes"):
            if not c.get(key):
                errors.append(f"{rel(f)}: missing {key}")
    # Provenance: how much of the data is still a placeholder (informational).
    count = sum(json.dumps(x).count('"placeholder"') for x in list(chemicals.values()) + list(equipment.values()))
    warnings.append(f"data: {count} placeholder value(s) still need a reviewed source (see docs/CHEMISTRY_REQUIREMENTS.md)")


def check_element_visual_coverage():
    """Ensure all 118 catalogue elements receive a safe visual representation."""
    visual_path = ROOT / "scripts/ui/element_visual.gd"
    specimen_path = ROOT / "scripts/ui/element_specimen.gd"
    card_path = ROOT / "scripts/ui/element_reference_card.gd"
    for path in (visual_path, specimen_path, card_path):
        if not path.exists():
            errors.append(f"element visuals: required file {path.relative_to(ROOT)} is missing")
    if not visual_path.exists() or not specimen_path.exists() or not card_path.exists():
        return

    visual = visual_path.read_text(encoding="utf-8")
    specimen = specimen_path.read_text(encoding="utf-8")
    card = card_path.read_text(encoding="utf-8")
    required_modes = {"solid_metal", "solid_crystal", "liquid", "gas_molecule", "gas_atom", "unknown_atom"}
    for mode in required_modes:
        if f'"{mode}"' not in visual:
            errors.append(f"element visuals: missing renderer for {mode}")
    for marker in ("static func profile_for", "state_at_stp", "radioactive", "hazards", "_draw_sealed_display_frame"):
        if marker not in visual:
            errors.append(f"element visuals: missing coverage/safety marker {marker}")
    if "ElementVisual.new()" not in specimen:
        errors.append("element visuals: dropped specimen does not instantiate ElementVisual")
    if '"simulation_reagent": false' not in card:
        errors.append("element visuals: periodic-table payload must remain non-reactive")
    drag_function = re.search(
        r"(?ms)^func _get_drag_data[^\n]*:\n(?P<body>.*?)(?=^func |\Z)",
        card,
    )
    if drag_function is None:
        errors.append("element visuals: periodic-table card has no _get_drag_data implementation")
    else:
        drag_body = drag_function.group("body")
        if "\tvar payload: Dictionary = {" not in drag_body:
            errors.append("element visuals: drag payload must be declared at the function scope")
        if "\t\tvar payload" in drag_body:
            errors.append("element visuals: drag payload must not be nested inside the null guard")
        if "\tset_drag_preview(preview)" not in drag_body:
            errors.append("element visuals: drag preview is not assigned by _get_drag_data")
        if "\treturn payload" not in drag_body:
            errors.append("element visuals: _get_drag_data must return its payload at function scope")

    elements = _load("data/elements/elements.json")["elements"]
    if len(elements) != 118:
        errors.append(f"element visuals: expected 118 element entries, got {len(elements)}")
        return
    covered = set()
    for element in elements:
        symbol = element.get("symbol", "")
        state_entry = element.get("state_at_stp")
        state = state_entry.get("value", "") if isinstance(state_entry, dict) else ""
        category = str(element.get("category", "")).lower()
        if state == "gas":
            covered.add("gas_atom" if category == "noble gas" or symbol in {"He", "Ne", "Ar", "Kr", "Xe", "Rn"} else "gas_molecule")
        elif state == "liquid":
            covered.add("liquid")
        elif state == "solid":
            is_metal = ("metal" in category and category not in {"nonmetal", "metalloid"}) or category in {"lanthanoid", "actinoid"}
            covered.add("solid_metal" if is_metal else "solid_crystal")
        else:
            covered.add("unknown_atom")
    missing = covered - required_modes
    if missing:
        errors.append(f"element visuals: catalogue states have no renderer: {sorted(missing)}")
    if "SEALED VIRTUAL SPECIMEN" not in specimen or "NOT A REAGENT" not in specimen:
        errors.append("element visuals: specimen UI must clearly state virtual-only/non-reagent status")


def main():
    check_res_paths()
    check_names()
    for p in files(".tscn"):
        check_scene(p)
    check_scripts()
    check_variant_inference()
    check_scene_exports()
    check_json()
    check_element_visual_coverage()
    for w in warnings:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print(f"\n{len(list(files('.gd')))} scripts, {len(list(files('.tscn')))} scenes, "
          f"{len(list(files('.json')))} data files checked: {len(errors)} error(s), {len(warnings)} warning(s)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
