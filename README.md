# Death Notebook

A World of Warcraft: Forever addon. Write your enemies into the black book; it marks
their nameplates and counts your kills.

## Features

- A black book of names, opened from the minimap button, a keybind or `/dnb`
- Warns you with a banner and a sound when a written enemy is near
- Marks their nameplates with a skull and the score between you
- Remembers who killed you and who fought you, ready to write down with one click
- Counts killing blows by you or your pet
- Notes, class, level, guild, last sighting and a waypoint to it
- Search, sorting, tooltips and settings; English and German
- Understands first names and surnames: a name written without a surname
  matches every enemy with that first name
- Shares nothing and changes none of your game settings

## Coming from Death Wish

This addon used to be called Death Wish. WoW stores saved data by addon name, so
to keep your names and kills, exit the game and rename `DeathWish.lua` to
`DeathNotebook.lua` in `WTF/Account/<account>/SavedVariables`. Remove the old
`DeathWish` addon folder and set your keybinds again.

## Commands

| Command | Effect |
| --- | --- |
| `/dnb` | Open or close the book |
| `/dnb add [name]` | Add a name, or your target |
| `/dnb remove <name>` | Strike a name from the book |
| `/dnb way <name>` | Waypoint to the last sighting |
| `/dnb mute` | Turn warnings on or off |

`/dn` works too, unless another addon uses it.

On the minimap button, left-click opens the book and right-click adds your
target. Keybinds are in the AddOns section of the keybinding options.

## Development

- `lua5.1 tests/run.lua` runs the tests.
- `python tools/make_art.py` regenerates the textures (numpy + Pillow), `tools/make_logo.py` the logo.

## Releasing

Push a version tag. The tests run, then the addon is packaged, uploaded to
CurseForge and added to GitHub Releases. The version in the TOC comes from the
tag, and the changelog comes from the commits since the previous tag.

```
git tag -a v1.2.0 -m "v1.2.0"
git push origin main v1.2.0
```

When the game version changes, update `## Interface` in
`DeathNotebook/DeathNotebook.toc` first.
