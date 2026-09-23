# Rendered visual review

The supplied drawing at `assets/reference/3996.jpg` guided the first fighter: tall sharp golden hair, a tilted halo, stern face, muscular arms, dark sleeveless gi, cobalt trim, and a golden aura. The Blender generator translates these into 3D volumes for side and rear gameplay views rather than tracing the flat image.

These captures came from the running Godot GL Compatibility renderer under Xvfb, after importing the latest Blender GLBs:

- [Solar portrait](../assets/portraits/solar.png) shows the front silhouette, face, costume, halo, and aura.
- [Character selection](screenshots/select.png) shows the three selectable variants and the designed UI.
- [Combat](screenshots/combat.png) shows both fighters against the rocky arena with the game HUD.
- [Close attack](screenshots/action.png) shows the revised side camera, with both fighters and the lock marker visible during a heavy strike.
- [Ultimate](screenshots/ultimate.png) shows the staged energy attack, its translucent patterned sphere, and the attacker pose.
- [Touch layout](screenshots/touch.png) shows the movement, flight, attack, guard, ki, and form controls in the rendered arena.

Three independent visual critics reviewed the portrait, selection, combat, and attack captures over several passes. Their recurring concerns were a radial hair silhouette, the rear mane hiding the torso and opponent at close range, dark hair surfaces viewed from behind, bright ground clutter, and unreadable strike framing. The revisions swept and lowered the mane on one side, made its rear planes gold, cleared the center of the arena, strengthened the character selection art, aligned Blender attack playback with combat timings, and moved the close combat camera sideways and farther back. The latest close attack capture keeps the target visible, though the heavy strike pose still needs more readable staging. The ultimate capture shows a much clearer attacker pose and target. Touch controls were captured in Godot but have not been tested on a physical phone or tablet.
