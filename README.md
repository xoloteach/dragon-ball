# Solar Ascendant: Skybreak Arena

An original 3D anime arena fighter built with Godot 4.7.2 and Blender 5.2.2. Inspired by the supplied hand drawing: immense golden hair, a luminous halo, dark martial gi, cobalt accents, and a golden energy aura.

## Run

Open `project.godot` in Godot 4.7.2 or newer and press Play. Run from a terminal with `godot --path .`.

The current playable slice includes Solar Ascendant, the Solar Nova form, Dusk Rival, one generated arena, airborne AI, a complete fight flow, Blender authored animation clips, cel shading, touch controls, procedural energy effects, and synthesized combat audio.

## Controls

| Action | Keyboard/mouse | Touch |
| --- | --- | --- |
| Move | WASD | left virtual stick |
| Look | Mouse drag | drag right side |
| Jump / rise | Space | ↑ |
| Descend | C | ↓ |
| Dash / evade | Shift | DASH |
| Lock on | Tab | LOCK |
| Light combo | J / left click | HIT |
| Heavy / launcher | K | HEAVY |
| Ki blast | L | BLAST |
| Blast volley | X | VOLLEY |
| Charged sphere | Z | SPHERE |
| Guard / counter | Q | GUARD |
| Charge ki | E | CHARGE |
| Beam | R | BEAM |
| Ultimate | F | ULT |
| Transform Solar → Nova | T (75 Ki) | FORM |
| Vanish behind opponent | V | VANISH |
| Pause | Esc | pause button |

## Rebuild assets

Run `blender -b -t 4 --python blender/generate_assets.py` from the project root. This replaces the fighter, form, rival LOD, and arena GLB exports with deterministic procedural assets and 14 Blender animation clips per fighter. Blender source is the Python script; no manual `.blend` edits are needed.

Run `python3 audio/generate_sfx.py` to recreate the original sound effects. Run `godot --headless --path . --script scripts/smoke_test.gd` to check the combat flow. Run `tools/build_linux.sh` to export and package a Linux x86_64 build after installing Godot 4.7.2 export templates.

For rendered selection portraits, run `SOLAR_CAPTURE=portrait xvfb-run -a godot --path .`, then repeat with `portrait_nova` and `portrait_dusk`; import the resulting files with `godot --headless --path . --editor --import --quit`.

The desktop controls are designed for an arena fight; touchscreen controls are rendered automatically when touch events are detected. The game uses the Godot GL Compatibility renderer for a broad range of devices.
