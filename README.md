# Death Wish

A World of Warcraft: Forever addon. Write your enemies into the book; it marks
their nameplates and counts your kills.

## Features

- A book of names, opened from the minimap button, a keybind or `/dw`
- A pulsing skull and kill counter on the nameplates of written players
- Counts killing blows by you or your pet
- "Write into the book" in the right-click menu of enemy players
- Understands first names and surnames: a name written without a surname
  matches everyone with that first name

## Commands

| Command | Effect |
| --- | --- |
| `/dw` | Open or close the book |
| `/dw add [name]` | Add a name, or your target |
| `/dw remove <name>` | Strike a name from the book |

On the minimap button, left-click opens the book and right-click adds your
target. Keybinds are in the AddOns section of the keybinding options.

## Development

- `lua5.1 tests/run.lua` runs the tests.
- `python tools/make_art.py` regenerates the textures (numpy + Pillow).

## Releasing

Push a version tag. The tests run, then the addon is packaged, uploaded to
CurseForge and added to GitHub Releases. The version in the TOC comes from the
tag, and the changelog comes from the commits since the previous tag.

```
git tag -a v1.2.0 -m "v1.2.0"
git push origin main v1.2.0
```

When the game version changes, update `## Interface` in
`DeathWish/DeathWish.toc` first.
