from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/generated/combat"

SFX = ROOT / "assets/audio/sfx"
SCI_FI = ROOT / "assets/audio/scifi-sounds/Audio"
IMPACTS = ROOT / "assets/audio/impact-sounds/Audio"


ASSETS = {
    "shot_pistol_v2.ogg": {
        "inputs": [SFX / "shoot_pistol.ogg", IMPACTS / "impactMetal_light_001.ogg"],
        "filter": (
            "[0:a]aresample=48000,highpass=f=95,volume=0.92,atrim=0:0.24[a];"
            "[1:a]aresample=48000,highpass=f=1500,volume=0.28,atrim=0:0.12,afade=t=out:st=0.06:d=0.06[b];"
            "[a][b]amix=inputs=2:normalize=0,alimiter=limit=0.88,atrim=0:0.25[out]"
        ),
    },
    "shot_smg_v2.ogg": {
        "inputs": [SFX / "shoot_smg.ogg", SCI_FI / "impactMetal_001.ogg"],
        "filter": (
            "[0:a]aresample=48000,highpass=f=130,volume=0.70,atrim=0:0.18,afade=t=out:st=0.12:d=0.06[a];"
            "[1:a]aresample=48000,highpass=f=1900,volume=0.14,atrim=0:0.08,adelay=9|9[b];"
            "[a][b]amix=inputs=2:normalize=0,alimiter=limit=0.80,atrim=0:0.19[out]"
        ),
    },
    "shot_ak_v2.ogg": {
        "inputs": [SFX / "shoot_ak.ogg", IMPACTS / "impactMetal_medium_002.ogg", SCI_FI / "explosionCrunch_003.ogg"],
        "filter": (
            "[0:a]aresample=48000,highpass=f=80,volume=0.84,atrim=0:0.33[a];"
            "[1:a]aresample=48000,highpass=f=900,volume=0.22,adelay=8|8[b];"
            "[2:a]aresample=48000,lowpass=f=360,volume=0.08,atrim=0:0.28[c];"
            "[a][b][c]amix=inputs=3:normalize=0,alimiter=limit=0.88,atrim=0:0.34[out]"
        ),
    },
    "shot_sniper_v2.ogg": {
        "inputs": [SFX / "shoot_sniper.ogg", SCI_FI / "lowFrequency_explosion_000.ogg", IMPACTS / "impactMetal_heavy_002.ogg"],
        "filter": (
            "[0:a]aresample=48000,highpass=f=65,volume=0.92,atrim=0:0.68[a];"
            "[1:a]aresample=48000,lowpass=f=320,volume=0.24,atrim=0:0.72,afade=t=out:st=0.44:d=0.28[b];"
            "[2:a]aresample=48000,highpass=f=620,volume=0.20,atrim=0:0.42,adelay=54|54[c];"
            "[a][b][c]amix=inputs=3:normalize=0,alimiter=limit=0.92,atrim=0:0.82[out]"
        ),
    },
    "shot_gatling_v2.ogg": {
        "inputs": [SFX / "shoot_smg.ogg", IMPACTS / "impactMetal_light_004.ogg"],
        "filter": (
            "[0:a]aresample=48000,asetrate=58560,aresample=48000,highpass=f=180,volume=0.52,atrim=0:0.11,afade=t=out:st=0.065:d=0.045[a];"
            "[1:a]aresample=48000,asetrate=64800,aresample=48000,highpass=f=2100,volume=0.15,atrim=0:0.07[b];"
            "[a][b]amix=inputs=2:normalize=0,alimiter=limit=0.72,atrim=0:0.12[out]"
        ),
    },
    "shot_shotgun_v2.ogg": {
        "inputs": [SFX / "shoot_ak.ogg", SCI_FI / "explosionCrunch_001.ogg", IMPACTS / "impactPunch_heavy_001.ogg"],
        "filter": (
            "[0:a]aresample=48000,asetrate=40320,aresample=48000,highpass=f=55,volume=0.88,atrim=0:0.47[a];"
            "[1:a]aresample=48000,lowpass=f=720,volume=0.25,atrim=0:0.58,afade=t=out:st=0.38:d=0.20[b];"
            "[2:a]aresample=48000,lowpass=f=1450,volume=0.30,atrim=0:0.50,adelay=18|18[c];"
            "[a][b][c]amix=inputs=3:normalize=0,alimiter=limit=0.92,atrim=0:0.60[out]"
        ),
    },
    "impact_light_v2.ogg": {
        "inputs": [SFX / "hit_light.ogg", IMPACTS / "impactPunch_medium_002.ogg"],
        "filter": (
            "[0:a]aresample=48000,volume=0.78,atrim=0:0.28[a];"
            "[1:a]aresample=48000,highpass=f=240,volume=0.25,atrim=0:0.20[b];"
            "[a][b]amix=inputs=2:normalize=0,alimiter=limit=0.82,atrim=0:0.28[out]"
        ),
    },
    "impact_heavy_v2.ogg": {
        "inputs": [SFX / "hit_heavy.ogg", IMPACTS / "impactPunch_heavy_003.ogg", SCI_FI / "lowFrequency_explosion_001.ogg"],
        "filter": (
            "[0:a]aresample=48000,volume=0.86,atrim=0:0.52[a];"
            "[1:a]aresample=48000,lowpass=f=1900,volume=0.36,atrim=0:0.46[b];"
            "[2:a]aresample=48000,lowpass=f=280,volume=0.16,atrim=0:0.55,afade=t=out:st=0.34:d=0.21[c];"
            "[a][b][c]amix=inputs=3:normalize=0,alimiter=limit=0.90,atrim=0:0.56[out]"
        ),
    },
    "ringout_v2.ogg": {
        "inputs": [SFX / "fall_death.ogg", SCI_FI / "forceField_003.ogg", SCI_FI / "lowFrequency_explosion_000.ogg"],
        "filter": (
            "[0:a]aresample=48000,volume=0.82,atrim=0:1.05[a];"
            "[1:a]aresample=48000,asetrate=43200,aresample=48000,highpass=f=260,volume=0.22,atrim=0:0.78[b];"
            "[2:a]aresample=48000,lowpass=f=250,volume=0.17,atrim=0:0.92,afade=t=out:st=0.56:d=0.36[c];"
            "[a][b][c]amix=inputs=3:normalize=0,alimiter=limit=0.90,atrim=0:1.05[out]"
        ),
    },
}


def build_asset(ffmpeg, filename, spec):
    destination = OUT / filename
    command = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y"]
    for source in spec["inputs"]:
        if not source.exists():
            raise FileNotFoundError(source)
        command.extend(["-i", str(source)])
    command.extend(
        [
            "-filter_complex",
            spec["filter"],
            "-map",
            "[out]",
            "-ar",
            "48000",
            "-ac",
            "2",
            "-c:a",
            "libvorbis",
            "-q:a",
            "5",
            str(destination),
        ]
    )
    subprocess.run(command, check=True)
    print("BUILT_COMBAT_AUDIO", destination.relative_to(ROOT))


def main():
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        print("COMBAT_AUDIO_BUILD_FAIL ffmpeg is not available")
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    for filename, spec in ASSETS.items():
        build_asset(ffmpeg, filename, spec)
    print("COMBAT_AUDIO_BUILD_PASS", len(ASSETS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
