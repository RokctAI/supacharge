# r3_packs/audio

Pre-rendered tutor audio for the Grades R-3 activity packs, one file per
line: `<line key>.mp3` (mono, 24 kHz), where the key is the `R3Line.key`
that `R3SessionEngine.lines` builds (`<pack id>.show`, `<pack id>.hints_0`,
`<pack id>.rounds_2_prompt`, `r3.r3_praise_yes`, ...). The host's
`AssetTutorVoice` plays `assets/r3_packs/audio/<key>.mp3` when the file is
bundled and otherwise shows the line in the speech bubble only.

The files and `r3_manifest.<voice>.json` (per-line scores, seeds, hashes,
and `needs_listen` for phonics lines rendered from a respelling) are written
by the factory voice batch CI (kind `r3`) on a `rokct/` branch and arrive
here by PR. Do not hand-edit them.
