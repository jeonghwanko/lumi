# Flow review mode

This development project enables `lumi/review_mode=true` in project.godot. The first/repeated cafe-button review puzzle has yellow goal3 and18 moves. Opening seed2 has no pre-existing matches, and its first hint at (3,0)->(3,1) clears through the normal swap/resolution pipeline. There is no automatic win or reward fixture. First reward100 and repeat35 use the existing attempt ledger.

Normal data/levels.json and all8 levels are preserved byte-for-byte. Set the flag false to return to normal difficulty and the latest unlocked cafe puzzle. Review and normal saves use separate file prefixes (`review-`), including session checkpoints, cafe progression and puzzle progress. Do not toggle the flag during an active scene; restart the application. Existing saves are not rewritten.

Normal regression suites explicitly disable the review profile. Additional review checks cover a deterministic valid swap, exact resume and idempotent/repeat rewards. Final facility animation sets, signed APK/IPA and physical device checks remain incomplete.
