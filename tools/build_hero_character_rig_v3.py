from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_hero_character_rig_v2 as rig
import hero_character_v3_geometry as geometry

rig.SOURCE = ROOT / "assets/source/characters/hero_character_rig_v3.blend"
rig.RUNTIME = ROOT / "assets/models/generated/characters/hero_character_rig_v3.glb"
rig.OUT_NEUTRAL = ROOT / "reports/hero_character_rig_v3_neutral.png"
rig.OUT_TURNAROUND = {
    "front": ROOT / "reports/hero_character_rig_v3_front.png",
    "side": ROOT / "reports/hero_character_rig_v3_side.png",
    "back": ROOT / "reports/hero_character_rig_v3_back.png",
    "three_quarter": ROOT / "reports/hero_character_rig_v3_three_quarter.png",
}
rig.OUT_POSES = {
    "pistol": ROOT / "reports/hero_character_rig_v3_pistol.png",
    "smg": ROOT / "reports/hero_character_rig_v3_smg.png",
    "ak_rifle": ROOT / "reports/hero_character_rig_v3_ak.png",
    "sniper": ROOT / "reports/hero_character_rig_v3_sniper.png",
    "shotgun": ROOT / "reports/hero_character_rig_v3_shotgun.png",
    "gatling": ROOT / "reports/hero_character_rig_v3_gatling.png",
}
rig.p29_geometry = geometry
rig.import_character = geometry.build_character


if __name__ == "__main__":
    rig.main()
    print("HERO_CHARACTER_RIG_V3_EXPORTED", rig.RUNTIME)
