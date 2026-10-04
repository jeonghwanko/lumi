# Mobile build and PC handoff

Verified 2026-10-04. This is a build-preparation document, not an APK/IPA release claim.

## Runtime versions

- VM: Godot **4.6.3.stable.official.7d41c59c4** is installed and was used for native execution/tests
- Official latest stable listed on the [Godot Linux download page](https://godotengine.org/download/linux/): **4.7.2**, released 2026-08-18
- For reproducible continuation, install the official **4.6.3** editor and matching **4.6.3** export templates on the PC. Upgrading to 4.7.2 requires rerunning every test and device check; a newer editor has not yet been verified here
- No unofficial installer, third-party generator, paid art service, or plugin was executed

## Android

Current VM evidence: Java 21 is present; `adb`/Android SDK and Godot export templates were not found in the checked locations. The PC reportedly already has Android SDK/ADB and Android Studio Java 21.0.9, while its default Java is 8. This PC fact was supplied by the coordinating task and must be verified by the PC executor before export.

1. Install the matching official Godot editor/templates
2. Configure Godot Editor Settings → Export → Android with the Android SDK path and the Android Studio JDK 21 path, **not default Java 8**. Godot's official guide recommends JDK17 and supports higher versions
3. Verify installed SDK packages against the version's [official Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). The current guide lists Platform35, Build Tools35.0.1, Platform Tools35+, NDK28.1.13356709 and CMake3.10.2.4988404
4. Any newly required Android SDK agreement must be disclosed and accepted before installation. Do not silently accept licenses or new permissions
5. `export_presets.cfg` contains Android arm64 with signing explicitly off. `com.example.catsandcoffee` is a placeholder, not a confirmed publishing identifier
6. Do not create/store/transmit a signing keystore or account token. The unsigned setup is suitable only for verifying packaging prerequisites; device installation requires an explicitly approved signing workflow
7. Google Play release requires an AAB/Gradle configuration and release signing. Neither is done here. No store account, payment, advertising, analytics, or Internet permission is added

## iOS

The [official iOS export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) requires macOS, Xcode and matching templates. The Linux VM cannot complete this stage. A valid Team ID, chosen bundle identifier and signing/provisioning workflow are not supplied. The iOS preset intentionally leaves Team ID empty.

The Compatibility renderer is selected for this 2D game and supported by the iOS simulator; test on a Mac and physical target device before any performance claim. No Apple developer account, signing identity, certificate, provisioning profile, or legal agreement is created/accepted here.

## Verification levels

- Passed: editor import, headless native launch, GDScript suites, deterministic original JS parity, resource-only PCK package
- UI functional: native Control layout geometry, routed InputEventScreenTouch, multi-touch/cancel, portrait/landscape logical sizes, scene transitions, save failure and resume
- Not checked: GPU pixels/font/shader appearance, actual Android/iOS touch, notch behavior on devices, device performance/thermal/battery, APK/IPA signing/install, store compliance
- User chose to skip VM graphical validation; approved mockups are now applied as native Controls; final screen/touch review remains on the PC/device
- No VM push. Copy/apply only this `godot/` folder onto the PC's latest branch, preserving the separate web title-overlap fix at 709d50eeef29b8701cb6eff8e1f9db9050fb21a8

## Native asset boundary

`assets/cats/colored-cat-tokens-v4.png` is an unchanged approved source image. GDScript extracts the original six documented frame regions; no replacement image generation was used.

Facility catalog data retains `artStatus: temporary` and all 36 `atlas: null` entries. The final facility animation contract remains six states: idle, work, rare variation, tap response, arrival, stable return. Final assets must preserve canvas, floor/contact anchors, stable character identity and tool contacts. The garden now uses approved text-free scenery and a separate f19/Jongjong static cutout. All other unavailable facility art remains labeled temporary. This is not a final six-state facility animation package.

## License gate

The existing repository is PolyForm Noncommercial 1.0.0. Godot's MIT license does not grant commercial rights to the original game. Obtain/verify appropriate original-code rights before advertising, paid distribution, in-app purchases, commercial release or other prohibited commercial use.
