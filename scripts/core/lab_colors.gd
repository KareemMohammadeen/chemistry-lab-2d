class_name LabColors
extends RefCounted
## Colour tokens for the whole application (modern dark glass look). Scenes, views and the
## theme use these names, never raw colour values, so a theme change is a one-file edit.

# ---- application chrome
const BACKGROUND := Color("#07111B")
const BACKGROUND_ALT := Color("#0C1722")
const PANEL := Color("#13202D")
const PANEL_RAISED := Color("#1A2A39")
const PANEL_SUNKEN := Color("#0E1720")
const PANEL_BORDER := Color("#253647")
const PANEL_BORDER_STRONG := Color("#385067")

# ---- text
const TEXT_PRIMARY := Color("#EEF4F8")
const TEXT_SECONDARY := Color("#A9BACA")
const TEXT_MUTED := Color("#708394")
const TEXT_ON_DARK := Color("#F4F7FA")
## Dark text for light surfaces such as the paper labels on bottles and amber chips.
const INK := Color("#16212B")

# ---- accents and status
const ACCENT := Color("#40D0C0")
const ACCENT_STRONG := Color("#1FA79A")
const CYAN := Color("#63D5F0")
const SECONDARY := Color("#8C87FF")
const INFO := Color("#5EA2FF")
const HEAT := Color("#FFB14A")
const WARNING := Color("#F4C34D")
const DANGER := Color("#EF6B63")
const SUCCESS := Color("#59C88A")

# ---- laboratory stage
const WALL_TOP := Color("#1F2D3B")
const WALL_BOTTOM := Color("#121B24")
const WALL_LINE := Color("#2A3B4C")
const WALL_LIGHT := Color("#8ED1DF")
const BENCH_TOP := Color("#40546A")
const BENCH_GRID := Color(1.0, 1.0, 1.0, 0.05)
const BENCH_EDGE := Color("#96ADC0")
const BENCH_APRON := Color("#18222D")
const SHELF_BOARD := Color("#4D6477")
const SHELF_EDGE := Color("#94AFC2")
const GLASS_EDGE := Color(0.70, 0.88, 0.96, 0.95)
const GLASS_FILL := Color(1.0, 1.0, 1.0, 0.12)
const GLASS_HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.58)
const SHADOW := Color(0.0, 0.0, 0.0, 0.38)
const METAL := Color("#5A6876")
const RUBBER := Color("#8D4A4A")
const LIQUID_THERMOMETER := Color("#EF6B63")
