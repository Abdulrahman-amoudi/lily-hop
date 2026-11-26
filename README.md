# 🐸 Lily Hop

A juicy pixel-art frog-hopping game. Hold to charge, release to hop, catch bugs and don't sink.

**Play:** https://abdulrahman-amoudi.github.io/lily-hop/

## Controls
- **Hold Space / tap**: charge. **Release**: hop.
- **← / →** (or tap the arrows): change skin on the menu.
- **M**: mute.

## Features
- Lily pads that sink after you land, and get faster and start moving as levels go up
- Fireflies (+3), dragonflies (+5), gold fireflies (+10), rainbow beetles (+25 and FEVER x2), lotus pads (+5)
- Perfect-landing combos, a "NEW RECORD!" reward (crown + fever + Royal skin)
- 6 skins unlocked by level: Classic, Poison Dart, Tomato, Ninja, Ghost, Royal
- WebGL post-processing: bloom, water refraction, chromatic hits, scanlines
- Real recorded CC0 sound effects, no music

## Files
- `index.html`: the playable game (single file, sounds embedded)
- `index.src.html` + `sfx/` + `build.py`: source; run `python3 build.py` to rebuild `index.html`
- `godot/`: Godot 4.3 port (v1 gameplay), open `godot/project.godot` in Godot
