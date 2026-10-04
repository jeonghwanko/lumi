# Approved-screen art layers

Source: user-approved four-screen mockups, 2026-10-04. The user explicitly asked to build this design. These files were generated as independent production-use **static layers** through the existing image-generation workflow. Original mockup PNGs are not packaged as playable screens.

- `title-background.png`: text-free brand/cafe garden background. Decorative title-scene cats do not represent owned game facilities
- `completion-background.png`: text-free celebration cat/coffee background. Stars, title, level, actual reward and CTA are native Controls and are absent from this image
- `garden-empty-background.png`: garden ground/path/fence/foliage only. No owned facility, cat, prospective plot, currency or button is baked in
- `f19-bell-entrance-jongjong.png`: transparent static entrance and exactly one Jongjong. A single owned facility node displays it, and the separate-cat node is suppressed. Runtime AtlasTexture trims transparent bounds without editing the original image

Images were visually inspected as individual layers before integration. Their widths/heights are not used as UI coordinates; Godot fits artwork separately behind safe-area content.

The static entrance is not a final animation atlas. All 36 original catalog atlas fields remain null, with their temporary status intact. Other missing facilities/decorations use clearly labeled native placeholders. No unauthorized third-party or paid sprite-generation service ran.
