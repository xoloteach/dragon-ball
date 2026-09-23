# Solar Ascendant: Skybreak Arena

An original 3D anime arena fighter built with Godot 4.7.2 and Blender 5.2.2. Inspired by the supplied hand drawing: immense golden hair, a luminous halo, dark martial gi, cobalt accents, and a golden energy aura.

## Run

Open `project.godot` in Godot 4.7.2 or newer and press Play. Run from a terminal with `godot --path .`.

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
| Guard / counter | Q | GUARD |
| Charge ki | E | CHARGE |
| Beam | R | BEAM |
| Ultimate | F | ULT |
| Pause | Esc | pause button |

## Rebuild assets

Run `blender -b -t 4 --python blender/generate_assets.py` from the project root. This replaces both GLB exports with deterministic procedural assets. Blender source is the Python script; no manual `.blend` edits are needed.

The desktop controls are designed for an arena fight; touchscreen controls are rendered automatically when touch events are detected. The game uses the Godot GL Compatibility renderer for a broad range of devices.

