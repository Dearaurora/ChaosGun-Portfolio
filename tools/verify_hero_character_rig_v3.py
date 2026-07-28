from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import verify_hero_character_rig as verify
verify.ASSET = ROOT / "assets/models/generated/characters/hero_character_rig_v3.glb"


if __name__ == "__main__":
    verify.main()
