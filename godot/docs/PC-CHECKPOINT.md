# Native PC checkpoint — 2026-10-04

Separate checkout based on web commit `709d50eeef29b8701cb6eff8e1f9db9050fb21a8`. Original dirty checkout and web sources preserved.

Godot 4.6.3 stable official, Windows Compatibility renderer on NVIDIA RTX 3050. Actual native viewport captures show title, puzzle, earned completion and cafe. Navigation captures emit native Button signals; puzzle uses native Control touch events. These are software input emulation, not physical touch or mobile-device QA.

Review mode defaults to yellow3/moves18, seed2. One ordinary valid swap wins. No automatic win/reward fixture; first100, repeat35 and duplicate suppression are tested. Review saves use separate filenames. Turn off `lumi/review_mode` to restore original eight levels and yellow12 first goal.

Current effects: selection lift, rejected swap return, squash/pop with bounded color particles, per-column fall delay and landing, cascade label, final settled-board pulse. Input locks during presentation; pause suspends tweens and sequence; cancellation replaces stale ownership. Effects-off/reduced-motion skip board presentation. Sound-off retains existing settings behavior. Goal absorption, refined sound rhythm and new expression drawings are future work.

Design timings (not input-latency measurements): selection100ms, reject200ms, swap140ms, clear160ms (low100ms), fall230ms plus40ms settle allowance; fall columns stagger9ms, landing35ms, victory pulse240ms. Rendering/movie averages are recorded separately and do not prove mobile performance or p95 frame stability.

Regression results: cafe1578, puzzle7494/40seededgames, session1967, garden183, screens1247, UI1182, review31 checks; all zero failures. UI cases cover repeated input, focus loss, pause, title/resume, relaunch/restart, reward idempotence and 320/360/390 layout matrix. Feedback45 checks, zero failures, separately checks rollback, paused transforms, bounded particle cleanup over20 cycles and selection motion off.

Four actual screenshots saved to Library: title `libfile_6a67ddd75d0081918748eaf10cd1e74d`, puzzle `libfile_67b0e8af43408191b30f4e8c50d1d8ed`, completion `libfile_a18592c441788191ac14f8c0b926d10b`, cafe `libfile_1c0d8b28ece08191b716c05ffdfb8556`.

Native portrait rendering uses390 logical width; a320px physical window scales this canvas. Exact320 logical layouts are covered by the regression matrix. The approved v5 red/orange atlas has not been materialized locally and is not applied. Other four v4 tiles remain unchanged. f19 is static approved art; remaining facility animation packages, APK/IPA builds, signing, installs and store publication remain incomplete.

Native Godot Movie Maker recording: 164 frames at30fps, 5.47s, Library `libfile_7ee7560166bc8191aeef8e5407b782a9`. Movie run averages CPU render2.60ms/frame and GPU1.65ms/frame; encoding11.41ms/frame. Recording ran at35% real-time speed, so these figures are capture diagnostics, not gameplay frame-rate or mobile performance guarantees.

Native Godot Movie Maker recording: 164 frames at30fps, 5.47s, Library `libfile_7ee7560166bc8191aeef8e5407b782a9`. Movie run averages CPU render2.60ms/frame and GPU1.65ms/frame; encoding11.41ms/frame. Recording ran at35% real-time speed, so these figures are capture diagnostics, not gameplay frame-rate or mobile performance guarantees.
