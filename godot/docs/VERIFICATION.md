# Native migration verification

2026-10-04 · Godot 4.6.3 official · Linux x86_64 · original web source 7c7178db7c64f2870e5e32550a056818cf8e3482.

## Passed against this native source

- Cafe: **33 scenarios / 1,578 assertions**, zero failures
- Puzzle: **7,494 assertions / 40 seeded games**, zero failures. Every game matches the original JavaScript final board, score, moves, goals, ice/crates and win/loss. Includes all special creation/pair/rainbow behavior, boosters, invalid swaps and dead-board reshuffle
- Session: **11 scenarios / 1,967 checks**, zero failures. All eight levels × three seeds preserve board/RNG/counters after reload and subsequent play. Completion is stored before reward, finish-attempt is idempotent, first completion gate waits for acknowledged win
- Native UI: **38 scenarios / 1,182 assertions**, zero failures. Scene routing, real Viewport-routed touch, tap/swipe/multitouch/cancel, 320×568/360×640/390×844/tablet/landscape logical layouts, rotated modal bounds, edit save/cancel/undo, stale revisions, lifecycle, duplicate input and reward, failed checkpoint/restart/reward retry
- Native title/result screens: **1,247 assertions**, including all actual stars/reward values, 24 size/state combinations and duplicate-action locks
- Owned Garden rendering: **183 checks**, including short viewports, exact initial f19/cat19, no duplicate embedded cat, edge positions and null-atlas preservation
- Standard button touches and custom board/garden touch coexist: touch→mouse emulation is enabled for Godot Buttons, and custom touch handlers ignore emulated mouse events
- Editor import and headless native launch
- Resource-only PCK export using the Linux Development preset
- Original JS cafe21 + theme12 tests and engine40 seeded games still pass; no original web source edits
- Catalog deep-equals source: 36 facilities, 6 chapters, 6 zones, 19 decorations, 36 null atlases
- Approved cat PNG equals source byte-for-byte

Use `tools/run_checks.sh` to reproduce on Linux. `tools/run_checks.ps1` prepares an isolated copy on Windows; it is supplied but not yet executed on Windows. Both avoid production saves. The resource PCK is not a standalone executable or APK.

## Verified blockers / not-run stages

Android unsigned export was attempted and correctly failed before producing an APK: missing 4.6.3 Android debug/release templates, unset Java SDK setting, missing Android SDK platform-tools/build-tools/adb/apksigner. Java21 exists on the VM but the export editor path is unset. No signing key or Android SDK license was created/accepted.

iOS export/build was not run. Linux lacks macOS/Xcode and no Apple signing inputs are supplied.

VM graphics inspection was deliberately skipped after the user allowed it. Geometry and input tests are not pixel/GPU/font/shader or actual-device touch evidence. Final PC/phone screen and touch QA is still required. No FPS, battery, low-end-device or app-store readiness claim is made.

The approved four-screen UI uses a 390×844 reference canvas with aspect-aware resizing, actual safe-area conversion and 60-logical-unit button hit targets. Separate text-free art is behind native Controls; no complete UI mockup bitmap is used as a screen. Explicit pause/continue, root exit confirmation, stored mid-animation return and rapid resume are tested. Logical targets are not claimed to equal Android dp/iOS pt on every device. Real density/scale/safe-area and GPU-pixel checks remain open.

## Asset and publication limits

The original cat tile source is approved and reused unchanged. Approved UI artwork is separated into text-free title/completion/empty-garden layers plus one transparent static f19/Jongjong layer. Native labels/buttons/64 tiles/rewards are not baked into those images. Other facilities and final six-state animations are unfinished; no external sprite-generation service ran. Design implementation is complete at the code/headless level, with final PC/device visual review still required.

No push, store submission, signed build, release account, analytics, ads, paid generation, account sync or commercial license expansion occurred. Original PolyForm Noncommercial restrictions remain applicable.
