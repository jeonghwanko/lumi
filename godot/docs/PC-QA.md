# PC final QA / integration checklist

This source was tested with Godot 4.6.3 official. VM graphics were skipped at the user's request. PC execution evidence and remaining limitations are recorded in PC-CHECKPOINT.md. The checklist includes broader physical/device work that remains pending.

## Safe integration

1. Confirm the PC repository's current branch/working changes and preserve the web title-overlap fix at 709d50eeef29b8701cb6eff8e1f9db9050fb21a8 or later
2. Add only the supplied `godot/` folder. No web source replacement, reset, clean, force-push or deletion is required
3. The VM has not committed or pushed this work. Review changes and make the final commit/push on the PC using the user's existing identity
4. Use an official Godot 4.6.3 editor/console binary. The latest official 4.7.2 was researched but not tested against this source
5. Run the isolated `tools/run_checks.ps1` with the exact Godot console path. It makes a separate copied project name so real saves stay untouched; ordinary project names are rejected by integration tests

## Visual / input checks

- First fresh test launch: title artwork has no baked title/button; actual title, settings and start control are crisp and safe-area aligned
- Start once, double-tap Start: exactly one first puzzle. No login/purchase dialog, cafe gate intact
- First puzzle is an actual 8×8 grid using the approved six-color PNG. Default review goal is yellow3/moves18; normal mode retains yellow12/moves18. Validate a legal swap, illegal swap rollback, edge swipe, tap-pair, hammer and +5 once
- Verify tap input on ordinary Buttons as well as custom board input. Touch emulation must not duplicate board moves or editor undo entries
- Pause during a swap/cascade: displayed board freezes, inputs/boosters cannot spend. Continue retains state. Save→title→immediate resume remains coherent
- Quit during puzzle and completion presentation, reopen: same settled board/RNG/moves/boosters or pending result, no duplicate reward
- First victory: actual earned stars and +100 first reward. Continue to cafe; initial scenery has exactly f19 and one Jongjong, balance100. Subsequent repeat wins use35, not a fixed100 label
- Cafe: live currency, next project f05 Hand-drip Bar80, one main “퍼즐 하기” CTA. Gear exposes workshop, collection, orders, layout, memories/settings. No unowned facility in the garden
- f19 is a static art layer. Additional facilities/decor are explicitly temporary where artwork is missing. Do not claim all36 animations complete
- Change window sizes approximating320×568,360×640,390×844,tablet and landscape. Check real font minimum sizes, transparency/shader atlas corners, top HUD, full board and bottom buttons
- Check editor save/cancel/undo and scrolling on the smallest size. Low-motion and sound settings persist. Floor/path selection visibly updates its temporary native surface layer

## Android/iOS

Read BUILDING.md. Matching templates, configured SDK/JDK and authorized signing are separate from running the native Godot project. APK/IPA signing, device installation and store publication have not been done. Never generate/upload credentials or accept new SDK agreements without the required user authorization.
