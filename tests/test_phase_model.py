#!/usr/bin/env python3
"""Reference model for the Phase 1 phase-change maths, checked against the real data files.

This is an independent re-implementation of scripts/chemistry/melt_equilibrium.gd,
scripts/chemistry/binary_melt_system.gd and the vapour-equilibrium step of
scripts/simulation/phase_change_system.gd. It validates the DESIGN of the algorithm
(energy conservation, plateaus, lever rule, equilibrium) using the project's own data.
It does NOT execute the GDScript, so it does not prove the GDScript port is correct; that is
covered by tests/run_phase_change_tests.gd, which needs Godot 4.7.x to run.

Run: python3 tests/test_phase_model.py
"""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
R = 8.314462618
failures = 0
checks = 0


def check(condition: bool, label: str) -> None:
    global failures, checks
    checks += 1
    if not condition:
        failures += 1
        print(f"FAIL: {label}")


def near(a: float, b: float, tolerance: float, label: str) -> None:
    check(abs(a - b) <= tolerance, f"{label} (got {a}, expected {b} +/- {tolerance})")


def value(entry):
    return entry["value"] if isinstance(entry, dict) else entry


def chemical(name: str) -> dict:
    return json.loads((ROOT / f"data/chemicals/{name}.json").read_text(encoding="utf-8"))


# ------------------------------------------------------------------ solver (mirror of GDScript)

class Entry:
    def __init__(self, latent, jump, liquid, f_jump=1.0, continuous=None, fraction=0.0):
        self.latent, self.jump, self.liquid = latent, jump, liquid
        self.f_jump, self.continuous, self.fraction = f_jump, continuous, fraction

    def f_above_open(self, t):
        if t >= self.liquid:
            return 1.0
        if self.continuous:
            return min(max(self.continuous(t), self.f_jump), 1.0)
        return self.f_jump

    def f_below(self, t):
        return 0.0 if t <= self.jump else self.f_above_open(t)

    def f_above(self, t):
        if t < self.jump:
            return 0.0
        if t == self.jump:
            return self.f_jump
        return self.f_above_open(t)


def enthalpy(entries, c, t):
    return c * t + sum(e.latent * e.fraction for e in entries)


def phi(entries, c, t, which):
    f = {"below": Entry.f_below, "above": Entry.f_above, "open": lambda e, x: e.f_above_open(x)}[which]
    return c * t + sum(e.latent * f(e, t) for e in entries)


def solve(entries, c, h):
    points = sorted({p for e in entries for p in (e.jump, e.liquid)})
    if not points:
        return h / c
    if h <= phi(entries, c, points[0], "below"):
        for e in entries:
            e.fraction = 0.0
        return h / c
    for i, p in enumerate(points):
        low, high = phi(entries, c, p, "below"), phi(entries, c, p, "above")
        if low <= h <= high:
            remaining = h - low
            for e in entries:
                base = e.f_below(p)
                e.fraction = base
                if e.jump == p and e.latent > 0:
                    room = e.latent * (e.f_above(p) - base)
                    used = min(remaining, room)
                    e.fraction = base + used / e.latent
                    remaining -= used
            return p
        nxt = points[i + 1] if i + 1 < len(points) else math.inf
        next_low = math.inf if math.isinf(nxt) else phi(entries, c, nxt, "below")
        if high < h < next_low:
            if math.isinf(nxt):
                t = (h - (high - c * p)) / c
            else:
                lo, hi = p, nxt
                for _ in range(80):
                    mid = 0.5 * (lo + hi)
                    if phi(entries, c, mid, "open") < h:
                        lo = mid
                    else:
                        hi = mid
                t = 0.5 * (lo + hi)
            for e in entries:
                e.fraction = e.f_above_open(t) if t > e.jump else 0.0
            return t
    raise AssertionError("solver fell through")


class Eutectic:
    def __init__(self, data, a, b):
        self.ta = value(a["melting_point_c"]); self.tb = value(b["melting_point_c"])
        self.la = value(a["thermal"]["enthalpy_fusion_j_per_g"]); self.lb = value(b["thermal"]["enthalpy_fusion_j_per_g"])
        self.te = value(data["eutectic_temperature_c"]); self.xe = value(data["eutectic_mass_fraction_b"])

    def liquidus(self, x):
        if x <= self.xe:
            return self.ta + (self.te - self.ta) * x / self.xe
        return self.te + (self.tb - self.te) * (x - self.xe) / (1 - self.xe)

    def liquid_x(self, x, t):
        if t <= self.te:
            return self.xe
        if x <= self.xe:
            return self.xe * (self.ta - t) / (self.ta - self.te)
        return 1 - (1 - self.xe) * (self.tb - t) / (self.tb - self.te)

    def fraction(self, x, t):
        if t >= self.liquidus(x):
            return 1.0
        lx = self.liquid_x(x, t)
        f = x / lx if x <= self.xe else (1 - x) / (1 - lx)
        return min(max(f, 0.0), 1.0)

    def latent_per_g(self, x):
        return (1 - x) * self.la + x * self.lb

    def entry(self, mass, x, fraction=0.0):
        return Entry(mass * self.latent_per_g(x), self.te, self.liquidus(x), self.fraction(x, self.te),
                     lambda t: self.fraction(x, t), fraction)


# ------------------------------------------------------------------ tests

def test_pure_melting_plateau():
    water = chemical("water")
    latent = value(water["thermal"]["enthalpy_fusion_j_per_g"])
    cp_ice = value(water["thermal"]["specific_heat_solid_j_per_g_k"])
    mass, power, dt = 100.0, 100.0, 1.0
    c = mass * cp_ice
    entry = Entry(mass * latent, 0.0, 0.0, 1.0, None, 0.0)
    t, h, seconds, plateau = -10.0, 0.0, 0.0, 0.0
    h = enthalpy([entry], c, t)
    while entry.fraction < 1.0 and seconds < 5000:
        h += power * dt
        t = solve([entry], c, h)
        seconds += dt
        if abs(t) < 1e-9 and 0.0 < entry.fraction < 1.0:
            plateau += dt
    expected = (-(-10.0) * c + mass * latent) / power
    near(seconds, expected, 1.5, "100 g of ice at -10 degC takes the latent-heat time to melt at 100 W")
    near(plateau, mass * latent / power, 2.0, "the temperature holds at 0 degC for the whole melt")


def test_energy_conservation_random():
    sn, bi = chemical("tin"), chemical("bismuth")
    system = json.loads((ROOT / "data/materials/binary_systems.json").read_text(encoding="utf-8"))["systems"][0]
    model = Eutectic(system, sn, bi)
    rng = random.Random(1234)
    worst = 0.0
    for _ in range(4000):
        mass = rng.uniform(1, 200)
        x = rng.uniform(0.02, 0.98)
        c = rng.uniform(40, 700)
        t0 = rng.uniform(20, 320)
        f0 = rng.random() if rng.random() < 0.5 else (0.0 if t0 < model.te else 1.0)
        entry = model.entry(mass, x, f0)
        h = enthalpy([entry], c, t0)
        t1 = solve([entry], c, h)
        worst = max(worst, abs(enthalpy([entry], c, t1) - h) / max(abs(h), 1.0))
    check(worst < 1e-9, f"binary melting conserves enthalpy (worst relative error {worst:.2e})")


def test_eutectic_composition_isothermal():
    sn, bi = chemical("tin"), chemical("bismuth")
    system = json.loads((ROOT / "data/materials/binary_systems.json").read_text(encoding="utf-8"))["systems"][0]
    model = Eutectic(system, sn, bi)
    x, mass = model.xe, 50.0
    entry = model.entry(mass, x, 0.0)
    c = 200.0
    h = enthalpy([entry], c, 100.0)
    temperatures = []
    for _ in range(400):
        h += 50.0
        temperatures.append(solve([entry], c, h))
        if entry.fraction >= 1.0:
            break
    held = [t for t in temperatures if abs(t - model.te) < 1e-9]
    check(len(held) > 5, "the eutectic composition melts at one fixed temperature")
    check(all(b >= a - 1e-9 for a, b in zip(temperatures, temperatures[1:])), "heating never lowers the temperature")
    near(entry.fraction, 1.0, 1e-9, "the eutectic composition ends fully liquid")


def test_off_eutectic_melting_range():
    sn, bi = chemical("tin"), chemical("bismuth")
    system = json.loads((ROOT / "data/materials/binary_systems.json").read_text(encoding="utf-8"))["systems"][0]
    model = Eutectic(system, sn, bi)
    x = 0.2  # tin-rich
    entry = model.entry(80.0, x, 0.0)
    c = 150.0
    h = enthalpy([entry], c, 100.0)
    seen_range, last = [], None
    for _ in range(3000):
        h += 25.0
        t = solve([entry], c, h)
        if 0.0 < entry.fraction < 1.0 and t > model.te + 1e-6:
            seen_range.append((t, entry.fraction))
        last = t
        if entry.fraction >= 1.0:
            break
    check(len(seen_range) > 10, "an off-eutectic mixture melts over a temperature range above the eutectic")
    check(all(b[1] >= a[1] - 1e-9 for a, b in zip(seen_range, seen_range[1:])), "liquid fraction rises with temperature")
    near(last, model.liquidus(x), 20.0, "the melt is complete near the liquidus (sensible heat added afterwards)")
    check(model.te < model.liquidus(x) < model.ta, "the liquidus lies between the eutectic and the melting point of tin")


def test_freezing_is_reverse_of_melting():
    sn, bi = chemical("tin"), chemical("bismuth")
    system = json.loads((ROOT / "data/materials/binary_systems.json").read_text(encoding="utf-8"))["systems"][0]
    model = Eutectic(system, sn, bi)
    x, mass, c = 0.3, 60.0, 180.0
    entry = model.entry(mass, x, 1.0)
    h = enthalpy([entry], c, 260.0)
    t_final = None
    while True:
        h -= 20.0
        t = solve([entry], c, h)
        if entry.fraction <= 0.0 and t < model.te - 20:
            t_final = t
            break
        if h < -1e6:
            break
    check(t_final is not None and entry.fraction == 0.0, "cooling a melt below the eutectic freezes it completely")


def test_two_substances_share_energy():
    water = chemical("water")
    ice_l = value(water["thermal"]["enthalpy_fusion_j_per_g"])
    # ice (melts at 0) and a second substance that melts at 50 degC in the same vessel
    a = Entry(100.0 * ice_l, 0.0, 0.0, 1.0, None, 0.0)
    b = Entry(20.0 * 200.0, 50.0, 50.0, 1.0, None, 0.0)
    c = 600.0
    entries = [a, b]
    h = enthalpy(entries, c, -5.0)
    for _ in range(4000):
        h += 200.0
        solve(entries, c, h)
        if a.fraction >= 1.0 and b.fraction >= 1.0:
            break
    check(a.fraction == 1.0 and b.fraction == 1.0, "two melting substances both finish melting")
    # the substance with the lower melting point must finish first
    h = enthalpy(entries, c, -5.0)
    for e in entries:
        e.fraction = 0.0
    h = enthalpy(entries, c, -5.0)
    order = []
    for _ in range(4000):
        h += 200.0
        solve(entries, c, h)
        for name, e in (("ice", a), ("other", b)):
            if e.fraction >= 1.0 and name not in order:
                order.append(name)
    check(order == ["ice", "other"], f"substances finish melting in melting-point order (got {order})")


def antoine_kpa(profile, t_c):
    a = profile["vapor_pressure"]
    return 10 ** (a["a"] - a["b"] / (t_c + 273.15 + a["c"])) * 100.0


def vapour_pressure(profile, molar_mass, boiling_c, t_c):
    vp = profile.get("vapor_pressure")
    k = t_c + 273.15
    if vp and vp["t_min_k"] <= k <= vp["t_max_k"]:
        return antoine_kpa(profile, t_c)
    molar_heat = value(profile["enthalpy_vaporization_j_per_g"]) * molar_mass
    return 101.325 * math.exp(-(molar_heat / R) * (1 / k - 1 / (boiling_c + 273.15)))


def test_antoine_and_clausius_clapeyron_water():
    water = chemical("water")
    thermal = water["thermal"]
    p25 = antoine_kpa(thermal, 25.0)
    near(p25, 3.17, 0.1, "water vapour pressure at 25 degC is about 3.17 kPa (Antoine fit)")
    p100 = antoine_kpa(thermal, 99.9)
    near(p100, 101.325, 3.0, "water vapour pressure at 100 degC is about one atmosphere (Antoine fit)")
    cc25 = vapour_pressure({"enthalpy_vaporization_j_per_g": thermal["enthalpy_vaporization_j_per_g"]}, 18.015, 100.0, 25.0)
    near(cc25, 3.17, 0.8, "Clausius-Clapeyron fallback is within about 25 % of the Antoine value at 25 degC")
    cc_ethanol = vapour_pressure(chemical("ethanol")["thermal"], 46.069, 78.4, 78.4)
    near(cc_ethanol, 101.325, 1e-6, "the fallback reproduces one atmosphere at the normal boiling point")


def test_closed_equilibrium_conserves_energy_and_mass():
    water = chemical("water")["thermal"]
    latent_mol = value(water["enthalpy_vaporization_j_per_g"]) * 18.015
    liquid_g, c, head_l, t0 = 50.0, 300.0, 0.2, 80.0
    gas0 = 0.0

    def balance(dn):
        t = t0 - dn * latent_mol / c
        k = t + 273.15
        return gas0 + dn - antoine_kpa(water, t) * head_l / (R * k)

    lo, hi = -gas0, liquid_g / 18.015
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if balance(mid) < 0:
            lo = mid
        else:
            hi = mid
    dn = 0.5 * (lo + hi)
    t1 = t0 - dn * latent_mol / c
    check(dn > 0, "a hot sealed vessel with liquid water evaporates until saturated")
    near(gas0 + dn, antoine_kpa(water, t1) * head_l / (R * (t1 + 273.15)), 1e-9, "vapour amount equals the saturation amount at the new temperature")
    near(c * (t0 - t1), dn * latent_mol, 1e-6, "the heat taken equals the latent heat of the vapour formed")
    check(t1 < t0, "evaporation cools the liquid")


def main() -> int:
    for test in (test_pure_melting_plateau, test_energy_conservation_random, test_eutectic_composition_isothermal,
                 test_off_eutectic_melting_range, test_freezing_is_reverse_of_melting, test_two_substances_share_energy,
                 test_antoine_and_clausius_clapeyron_water, test_closed_equilibrium_conserves_energy_and_mass):
        print("--", test.__name__)
        test()
    print(f"\n{checks} check(s), {failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
