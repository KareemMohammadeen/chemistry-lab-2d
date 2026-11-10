class_name LabColors
extends RefCounted
## Colour tokens for the whole application (dark slate scientific look). Scenes, views and the
## theme use these names, never raw colour values, so a theme change is a one-file edit.

# ---- application chrome
const BACKGROUND := Color("#0F151B")
const PANEL := Color("#17202A")
const PANEL_RAISED := Color("#1E2935")
const PANEL_SUNKEN := Color("#121A22")
const PANEL_BORDER := Color("#2B3948")
const PANEL_BORDER_STRONG := Color("#3A4C5E")

# ---- text
const TEXT_PRIMARY := Color("#E8EEF3")
const TEXT_SECONDARY := Color("#9DAEBD")
const TEXT_MUTED := Color("#6F8294")
const TEXT_ON_DARK := Color("#EEF2F5")
## Dark text for light surfaces such as the paper labels on bottles and amber chips.
const INK := Color("#17212B")

# ---- accents and status
const ACCENT := Color("#2BB7AA")
const ACCENT_STRONG := Color("#1F958A")
const CYAN := Color("#46C6E4")
const SECONDARY := Color("#8B86F0")
const INFO := Color("#4C93E6")
const HEAT := Color("#F2A03B")
const WARNING := Color("#F2B53B")
const DANGER := Color("#E5584F")
const SUCCESS := Color("#4DB37A")

# ---- laboratory stage
const WALL_TOP := Color("#222E3A")
const WALL_BOTTOM := Color("#18222C")
const WALL_LINE := Color("#2A3846")
const WALL_LIGHT := Color("#7FB8C8")
const BENCH_TOP := Color("#43566A")
const BENCH_GRID := Color(1.0, 1.0, 1.0, 0.05)
const BENCH_EDGE := Color("#8FA7BA")
const BENCH_APRON := Color("#1B252F")
const SHELF_BOARD := Color("#52667A")
const SHELF_EDGE := Color("#8FA7BA")
const GLASS_EDGE := Color(0.62, 0.80, 0.88, 0.95)
const GLASS_FILL := Color(1.0, 1.0, 1.0, 0.12)
const GLASS_HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.55)
const SHADOW := Color(0.0, 0.0, 0.0, 0.38)
const METAL := Color("#5A6876")
const RUBBER := Color("#8A3F3F")
const LIQUID_THERMOMETER := Color("#E5584F")
