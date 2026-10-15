# Style Directions

Use this with `semantic-icon-design.md` when no owned source artwork exists, or when loose taste references must become a stable Icon Composer package. These are SVG-convertible style directions, not visual templates for copying third-party icons.

Each direction must produce a `semantic_icon_design` first. Image generation and direct authoring both consume that same design.

## Selection Rules

1. Pick one primary direction from the table.
2. Prefer `high` convertibility unless the user's brief truly needs a lower-convertibility direction.
3. Default to one background plus 1-4 foreground/accent layers. Allow 5-7 foreground groups only for directions that explicitly need separable sticker or pane parts, and only when every group is named, bounded, and independently drawable.
4. Choose shape models before colors: single path, compound path, mirrored shapes, ribbon/loop, plates, or simple silhouette. Then choose a coherent palette that fits the app tone.
5. Keep gradients subordinate to the subject: low-to-medium contrast, smooth adjacent hues or monochrome ramps, no rainbow or high-contrast corner-to-corner clashes.
6. Do not select a direction that requires unstructured shadow, dirty glow, noisy blur, or detailed rendering to be recognizable. Controlled translucency, broad gradients, and low-frequency highlights are allowed only when each effect belongs to a named layer and has an SVG or clean PNG fallback route.

When a direction rejects "holes" or asks for opaque overlays, read that as image-generation and design-contract guidance. Conversion-time compound-path exceptions are handled in `semantic-authoring.md`.

## Quick Selection

| Direction | Convertibility | Use for | Default layer model | Avoid |
| --- | --- | --- | --- | --- |
| `black-stage-mark` | high | premium tools, security, finance, developer products | solid dark fill, pure-white geometric mark, one clean vivid accent | bevel, glow, fake glass |
| `black-stage-continuous-loop` | high | fitness, membership, website builders, premium utilities, identity marks, private handoff | solid dark or high-saturation single-hue stage, one thick pure-white rounded connected glyph, overlay-created gaps, optional accent on dark stages | infinity symbol, chain link, exact brand loop, thin outline, real holes, muddy accent |
| `connected-flow` | medium | AI, automation, sync, collaboration, data flow | compact topology-first connector, preferably one foreground SVG path | copied reference silhouette, three-node arch lock-in, shadowed holes, tiny circuit diagrams |
| `kinetic-pop` | medium | fitness, sports, mobility, events, fast actions | solid or same-hue gradient fill plus one pure-white diagonal symbol | motion blur, speed-line clutter, multi-hue gradient, pale low-contrast background |
| `connected-flow-silver` | medium | premium workflow, sync, handoff, and automation apps | satin silver fill plus one compact foreground connector | dirty gray background, oversized foreground, inner shadow |
| `blue-field-cutout-badge` | high | utilities, route tools, security, health notes, productivity | saturated solid fill, one white geometric badge, one same-color action cut | copied badge, document tab, letter, complex zigzag, gradients |
| `silver-field-black-mask` | high | premium companion, focus, privacy, calm helper, identity marks | silver-white fill, one large black abstract mask, 1-2 white overlay features | fur, mouth, whiskers, outlines, shadows, bevel |
| `outlined-friendly-action-mark` | high | reminders, plant care, creative actions, communication, consumer utilities | warm off-white fill, one heavy near-black base, saturated inset, 2-4 rounded accents | black corners, thin stroke, face, sticker border, gradients |
| `single-hue-gradient-outlined-mascot` | high | playful mascot, avatar, pet, customization, consumer identity | restrained single-hue gradient, black backing silhouette, white inset mascot, black overlay details | neon gradient, rainbow, two-color split, stroke-only outline, anatomy detail |
| `single-hue-gradient-soft-white-symbol` | high | warm consumer apps, streaks, mood, wellness, lightweight utilities, friendly identity marks | restrained single-hue gradient, one soft white rounded symbol, optional background-colored overlay details | black outline, sticker border, shadow, bevel, plastic shine, true holes |
| `single-hue-gradient-cropped-silhouette` | high | bold companion, night, privacy, focus, pet, identity, mysterious utility icons | restrained single-hue gradient, oversized cropped near-black silhouette, optional rear echo, one white overlay feature | complete portrait, fur, anatomy, outline, shadow, bevel |
| `dark-gradient-pale-orbit-cluster` | high | calm wellness, plant-care, sleep, focus, habit, or cyclical utility icons | solid or same-hue gradient field, 5-7 independent pure black/white capsule/seed layers, optional background-colored center overlay | literal flower illustration, stem, center pollen, glow, blur, shadow, true holes, cream foreground |
| `organic-blob-mark` | high | lightweight identity marks, mapping, ideas, soft utilities | solid or same-hue field plus one pure black/white organic path and optional dot | splatter, paw print, thin connectors, tinted foreground |
| `souvenir-decal-stickers` | medium | playful collection, cafe, music, maker, travel, memory, and tag/pin apps | pale gray-blue surface plus 2-3 small die-cut sticker groups | fixed travel subjects, oversized sticker collage, handle/title text |
| `flat-color-rounded-pane-cluster` | medium | camera, video, filter, music, creative tools | black stage plus 6-7 separable smooth rounded slender curved solid-color panes | waveform, equalizer, stacked waves, triangular tiles, hard clipped terminals, internal seams, borders, glow, plastic shine |

Lower-convertibility directions are allowed only when the semantic layer plan is still explicit and bounded. If the prompt needs more than 5-7 foreground groups or relies on baked shadow to read, reject it before generation.

For copyable style-family prompts and example JSON conversion contracts, use `examples/semantic-image-prompts/README.md`. Fill the template slots from the app; do not reuse an example subject, seed, bounds, or layer names as defaults. This file stays focused on selection rules and design constraints.

## Direction Details

### `black-stage-mark`

Use when the app needs a crisp premium mark with strong contrast.

- Semantic design bias: solid near-black background, high-contrast pure-white geometric mark, one clean palette-harmonized vivid accent.
- Shape models: `mirrored shapes`, `compound path`, `single filled path`, `small accent polygon`.
- Good metaphors: protected signal, vault, tool mark, focused workspace, premium utility.
- Image generation constraint: keep the black stage flat; no rim light, glow, bevel, or texture.
- SVG risk: low when the accent remains a simple filled shape.

### `black-stage-continuous-loop`

Use when the icon should feel like a premium thick rounded connected glyph without copying a known brand. This direction is suitable when the app can be represented by paired handles, membership links, connected services, building, controlled handoff, or a custom monoline slab mark.

- Semantic design bias: solid near-black background by default, but not fixed. Use a high-saturation single-hue stage when it strengthens the app identity: cobalt blue, vivid red, saturated green, hot pink, orange, or another app-specific solid/same-hue gradient. Foreground remains pure white or very pale. Internal gaps, counters, and terminal separations are background-colored overlay layers. Optional small accents are mainly for black/dark stages; vivid stages usually should not need an accent. For vivid blue stages, a Composer-level Liquid Glass handoff can work well: keep the SVG foreground flat, then use a two-stop same-hue `icon.json.fill` plus group `blur-material`, `refractivity`, `translucency`, and neutral `shadow` settings.
- Shape models: `single filled thick rounded connected glyph path`, `paired bracket glyph`, `mirrored handle glyph`, `single-piece double-counter connector`, `soft capsule bridge glyph`, `background-colored gap overlay`, `small accent rounded rect`.
- Line control: specify ribbon thickness as a canvas percentage or bounds-derived range, usually 12-20% of canvas width. Do not let the generator turn the mark into a thin stroke.
- Good metaphors: workout handles, membership link, site connector, builder glyph, private handoff, route connector, premium custom monoline mark.
- Image generation constraint: use the matching prompt template so the submitted model prompt is square source artwork rather than a rounded finished app-mask render. Reject infinity symbols, two separate chain links, hearts, readable letters, exact third-party brand loops, transparent holes, bevels, tube highlights, and generic logo marks. Keep colored stages single-hue and high-saturation, not rainbow, not multicolor sports gradients, and not pale low-contrast fields. The generated/source SVG must stay flat; any glass, refraction, shadow, or gradient depth belongs to Icon Composer settings, not baked foreground geometry.
- SVG risk: low when gaps are overlays and the glyph is one filled path.

### `connected-flow`

Use when the product is about connection, automation, sync, handoff, or structured flow.

- Semantic design bias: choose a connection topology, not a copied silhouette. Use one clear loop, branch, handoff path, linked capsule chain, folded connector, or 2-3 node ribbon with named flow order. Choose a composition anchor: `center`, `lower-left`, or `lower-right`; lower anchors work when the icon needs large quiet negative space or directional handoff. Choose a coherent app-appropriate palette; accents are optional and must belong to that palette.
- Shape models: `continuous ribbon`, `compound loop`, `asymmetric branch`, `handoff path`, `linked capsules`, `folded connector`, `node-ribbon`.
- Scale and layer bias: keep the connector compact by default, usually about 32-48% canvas width and 22-36% canvas height. Prefer one flat foreground SVG path over multiple pieces; add a second foreground layer only for a necessary same-palette accent or flat cutout.
- Silver route: for the premium gray variant, express silver through a broad two- or three-stop low-saturation gradient only. Do not use noise, texture, rim light, glass, bevel, cast shadow, or contact shadow to create the silver feel.
- Good metaphors: loop, chain, branch, merge, route, handoff, hub.
- Image generation constraint: keep topology simple and readable, but vary the outer silhouette by app semantics. Do not copy a taste reference's exact topology or default to a three-node arch. Avoid hollow grooves, shadowed cutouts, inner shadows, and separate dots unless the JSON explicitly asks for a flat same-palette layer.
- SVG risk: medium when overlaps or holes must be preserved; lower when the design stays one compact filled path over a simple fill or gradient background.

### `connected-flow-silver`

Use when the source taste points to a premium gray/silver field with a compact flow symbol, especially for workflow, sync, or automation apps.

- Semantic design bias: satin silver background from a low-saturation monochrome gradient, compact foreground symbol, large quiet negative space.
- Shape models: `single filled connector path`, `folded handoff path`, `node-ribbon`.
- Composition anchors: `center`, `lower-left`, or `lower-right`; lower anchors are useful when the symbol should feel tucked into a quiet field.
- Good metaphors: handoff, relay, merge, branch, sync.
- Image generation constraint: silver comes from broad smooth gradient only. Do not request rim light, shadowed grooves, glass, bevel, noise, or contact shadow.
- SVG risk: medium; keep the foreground flat and avoid true holes.

### `blue-field-cutout-badge`

Use when a simple utility can be recognized as one centered white badge crossed by a single action gesture on a saturated field.

- Semantic design bias: saturated solid field, one large white shield/plate/marker-like badge, and one diagonal same-field-color check, route, fold, pulse, or action overlay.
- Shape models: `single filled badge path`, `same-color overlay path`, or a conversion-time `compound badge path` when the selected cut reaches the edge and remains cleaner as negative space.
- Good metaphors: protected route, confirmed action, secure utility, health note, travel/place tool, developer task.
- Image generation constraint: preserve a strict two-color flat grammar. Reject copied contours, letters, document tabs, page folds, complex zigzags, gradients, shadows, bevels, glass, and tiny secondary symbols.
- SVG risk: low when the cut is an opaque same-color overlay; allow a clean compound-path exception only after inspecting the selected geometry.

### `outlined-friendly-action-mark`

Use when an approachable consumer utility needs one cheerful flat action object with a heavy rounded near-black contour on a quiet warm field.

- Semantic design bias: full-square warm off-white solid fill, one heavy near-black base/contour, one saturated inset object, optional near-black interior detail, and 2-4 short rounded attention marks.
- Shape models: `filled contour base`, `filled inset path`, `opaque interior detail`, `separate rounded accent paths`.
- Good metaphors: reminder cue, sprout, leaf, spark, note, cursor, chat bubble, play tab, or simple creative tool.
- Image generation constraint: the background reaches every canvas edge. Reject black mask corners, floating cards, thin stroked outlines, faces, sticker borders, gradients, shadows, bevels, glow, and dense UI detail.
- SVG risk: low when the outline is a backing fill rather than a stroke and every detail remains an independent opaque path.

### `silver-field-black-mask`

Use when the app should feel premium, quiet, guarded, companion-like, or identity-led through a large black abstract mask on a silver-white field.

- Semantic design bias: white-to-silver monochrome background with subtle lower charcoal darkening, one large flat near-black app-specific mask silhouette, and 0-2 white overlay features. Choose the mask topology from semantics before drawing; cat-like ears and V-shaped valleys are example-specific, not defaults.
- Shape models: `single filled rounded mask path`, `white visor or half-oval overlays`, `low-contrast monochrome background gradient`.
- Good metaphors: quiet companion, private focus, guarded workspace, calm assistant, minimal identity badge.
- Image generation constraint: keep the black mask large and flat. Use white features as opaque overlays, not holes. Avoid whiskers, mouth, nose, fur, outlines, shadow, bevel, sticker border, plastic shine, and 3D material.
- SVG risk: low when the background is a simple gradient and the mask/eyes stay as filled paths.

### `single-hue-gradient-outlined-mascot`

Use when the app should feel playful, bold, and graphic through a mascot or badge with a thick black backing outline on a restrained single-hue gradient field.

- Semantic design bias: one restrained single-color-family gradient background, one black filled backing silhouette, one white inset mascot face or badge, and 1-3 black overlay details. Treat the black outline as a backing layer, not a stroke.
- Shape models: `single filled backing silhouette`, `single filled inset face path`, `black oval overlays`, `small filled detail mark`.
- Variant axes: hue family (`purple`, `orange`, `teal`, `blue`, `green`, `red`), gradient direction (`upper-left-to-lower-right`, `top-to-bottom`, `left-to-right`), mascot family (`app-specific mascot badge`, `dog-mask badge`, `fox badge`, `bear head`, `ghost badge`, `creature badge`, `cat-skull badge`). Do not reuse cat ears, skull cheeks, or zigzag marks unless the chosen app metaphor needs them.
- Good metaphors: avatar, theme, pet, playful helper, customization, badge identity, consumer companion.
- Image generation constraint: say `restrained single-color-family {hue} gradient`; do not say `vibrant purple-to-magenta` unless the user explicitly wants neon. Avoid rainbow, two-color split, radial glow, wallpaper texture, shadows, bevels, glossy material, stroke-only outlines, realistic anatomy, teeth rows, fur, and whiskers.
- SVG risk: low when every visible part is an opaque filled shape and the background remains a simple single-hue gradient.

### `single-hue-gradient-soft-white-symbol`

Use when the app should feel warm, clean, friendly, and instantly readable through a soft white rounded symbol on a vivid but restrained single-hue gradient field.

- Semantic design bias: one single-color-family gradient background, one centered soft white app-specific symbol, and optional internal details expressed as background-colored opaque overlays.
- Shape models: `single filled rounded organic symbol path`, `bean-shaped overlay`, `oval counter overlay`, `capsule notch overlay`.
- Variant axes: hue family (`rose`, `coral`, `orange`, `blue`, `teal`, `green`, `violet`), gradient direction (`lower-left-to-upper-right`, `top-to-bottom`, `left-to-right`), symbol family (`flame-ghost`, `droplet`, `leaf`, `cloud`, `spark`, `pet-face`, `app-specific rounded mark`), internal overlay count (`none`, `one`, `two`, `three`).
- Good metaphors: daily spark, calm check-in, mood companion, lightweight streak, soft helper, friendly utility, simple consumer identity.
- Image generation constraint: the foreground should be a soft white filled shape, not a black-outlined mascot. Internal eyes, counters, notches, or gaps must be background-colored overlay layers. Use one concrete subject noun when the icon must be literal; avoid hybrid nouns that can drift into another symbol. Avoid black outline, sticker border, shadow, bevel, glow, rim light, glossy plastic highlight, 3D render, realistic fire, narrow slots, and true transparent holes.
- SVG risk: low when the white symbol and overlays stay as filled paths and the background is a simple single-hue gradient. Use PNG fallback only for a strict custom foreground gradient or renderer artifact.

### `single-hue-gradient-cropped-silhouette`

Use when the app should feel bold, mysterious, premium, or quietly iconic through an oversized near-black silhouette intentionally cropped by the app icon canvas.

- Semantic design bias: one restrained single-color-family gradient background, one huge near-black silhouette cropped by 1-3 canvas edges, optional crisp same-hue translucent rear silhouette, and one simple white overlay feature.
- Shape models: `single filled cropped side-profile silhouette path`, `translucent rear echo path`, `white oval overlay`, `capsule overlay`.
- Variant axes: hue family (`violet`, `blue-violet`, `teal`, `green`, `red`), crop edges (`left-and-bottom`, `bottom-and-right`, `left-bottom-right`), silhouette family (`rabbit side-profile`, `fox side-profile`, `owl silhouette`, `bat silhouette`, `pet profile`, `signal-mask`, `app-specific creature mark`), rear echo (`none`, `second ear`, `wing echo`, `back plate`, `antenna echo`), white feature (`oval eye`, `tilted eye`, `capsule signal`, `moon dot`).
- Good metaphors: night companion, private watcher, quiet focus, pet identity, hidden signal, calm routine, mysterious helper, bold consumer avatar.
- Image generation constraint: the silhouette must be oversized and visibly cropped; do not allow a complete centered animal portrait. For non-rabbit variants, explicitly forbid long rabbit ears or other nearby animal drift. Keep rear echoes crisp and separable, not blurred shadows. Use the white feature as an opaque overlay layer, not a cutout. Avoid fur, whiskers, muzzle detail, mouth, paws, feathers, outlines, sticker borders, shadows, bevels, glow, glossy material, and 3D render.
- Conversion constraint: author the rear echo/second ear as a smooth semantic same-hue shape. Do not trace it from the background gradient, source shadow, or semi-transparent renderer region; that failure imports the right-side field as foreground and can create jagged/glitch edges in Icon Composer exports.
- SVG risk: low when the silhouette remains a few filled paths and the background stays a simple single-hue gradient. Medium if the rear translucent layer needs exact renderer fidelity; use PNG fallback only for a controlled translucent layer or strict custom gradient.

### `dark-gradient-pale-orbit-cluster`

Use when the app should feel calm, organic, cyclical, or quietly premium through a sparse orbit of pure black/white capsule marks on a solid or same-hue field. This direction is suitable for wellness, plant-care, sleep, focus, habit, and gentle reminder apps.

- Semantic design bias: solid color or same-hue monochrome gradient background, 5-7 independent pure-white or pure-black capsule/seed layers chosen by contrast, and an optional small center gap expressed as a background-colored opaque overlay layer.
- Shape models: `elongated rounded capsule path`, `seed oval`, `organic bean marker`, `background-colored center gap overlay`.
- Variant axes: background family (`solid deep moss`, `monochrome pine`, `monochrome charcoal`, `monochrome umber`, `monochrome plum`), capsule count (`5`, `6`, `7`), capsule semantics (`breath markers`, `seed cycle`, `sleep rhythm`, `focus intervals`, `care cycle`, `app-specific rounded markers`), foreground contrast (`pure white on dark fields`, `pure black on light fields`), and cluster geometry (`asymmetric orbit`, `incomplete cycle`, `compact wreath`, `off-center swirl`).
- Good metaphors: breathing rhythm, care cycle, recurring habit, sleep markers, focus intervals, gentle growth, quiet orbit.
- Image generation constraint: keep the capsule pieces large, sparse, independently drawable, and pure black or pure white. The source-like flower reading is allowed only as abstract style grammar; do not add tinted cream/mint/ivory foreground, a stem, center pollen, leaf veins, botanical illustration detail, face, clock hands, glow, shadow, blur, glass, bevel, texture, or true transparent center hole. If the app semantic may drift, explicitly say `not a daisy`, `not a face`, `not a clock`, or `not a complete flower illustration`.
- SVG risk: low when each capsule is a filled SVG path and the background is a solid fill or same-hue gradient. Medium if the selected image relies on soft pixel edges or a rounded-square rim highlight; those effects should be simplified or kept out of foreground assets.

### `kinetic-pop`

Use for energetic products where motion is part of the promise.

- Semantic design bias: bright solid or same-hue low-to-medium contrast gradient background, one diagonal pure-white high-contrast foreground symbol.
- Shape models: `filled bolt`, `arrow wedge`, `flame silhouette`, `sweeping curve`.
- Good metaphors: sprint, bolt, flame, play, wave, arrow, track, burst.
- Gradient constraint: keep energetic color in one hue family, either a solid field or a same-hue ramp such as orange-to-deeper-orange, red-to-deeper-red, blue-to-deeper-blue, or teal-to-deeper-teal. The background must be deep or vivid enough for the pure-white foreground to read. Avoid pale low-contrast backgrounds, adjacent multi-hue gradients, rainbow palettes, triadic blue-green-yellow, deep-blue-to-bright-yellow jumps, and any high-contrast gradient that competes with the foreground.
- Image generation constraint: imply motion through silhouette and angle, not blur or many speed lines. Do not apply a default subject-size limit; let the app-specific metaphor and safe area set the foreground mass.
- SVG risk: medium; keep the foreground as one clean filled shape.

### `organic-blob-mark`

Use when the icon should feel soft, clever, minimal, or identity-like without a literal object.

- Semantic design bias: solid color or same-hue subtle gradient field, one pure black or pure white filled organic path chosen by contrast, optional same-color separate dot.
- Shape models: `single filled organic Bezier path`, `circle`.
- Good metaphors: fused ideas, soft map, living connection, flexible workspace.
- Image generation constraint: keep the blob as positive filled geometry. Do not add strokes, nodes, graph lines, shadows, or extra dots unless the JSON names them.
- SVG risk: high when the contour is simple and crisp.

### `souvenir-decal-stickers`

Use when the app should feel playful, collectible, or personal through a small set of sticker-like symbols, without becoming a generic sticker pack or copying a specific fridge/travel icon.

- Semantic design bias: source-like pale gray-blue rounded surface, subtle low-contrast edge/bottom darkening, and 2-3 small die-cut sticker groups occupying about 30-40% of the canvas. The subject content changes by app; the style grammar stays fixed.
- Shape models: `rounded surface fill`, `die-cut sticker border path`, `simple sticker interior path`, `abstract label-block overlay`.
- Content slots: choose app-specific high-recognition motifs such as cafe cup/pastry/receipt, record/ticket/pick, wrench/bolt/blueprint, landmark/taxi/bus, or other 2-3 subject sets. Treat these as slots, not fixed template content.
- Good metaphors: saved memories, local favorites, collections, pins, tags, kits, playlists, cafes, maker tools.
- Image generation constraint: preserve the small decal scale and quiet background. Do not add a handle, title word, appliance hardware, readable labels, or fixed travel subjects unless the app calls for them. Use abstract block marks where a sticker would otherwise contain text.
- Conversion risk: medium. Each sticker group must remain independently redrawable; use SVG for border/interior shapes and reserve PNG fallback only for a user-accepted sticker that is too dense to redraw cleanly.

### `flat-color-rounded-pane-cluster`

Use for creative tools where a black stage and separated colorful smooth rounded slender curved flat color-panel panes can carry the identity without a literal camera or video glyph.

- Semantic design bias: flat black stage, one large pale smooth rounded slender curved pane, 5-6 colored smooth rounded slender curved panes, all separated by visible black gaps. Each pane is one continuous solid flat fill with no visible internal boundary and soft rounded tapered ends.
- Shape models: `smooth rounded slender curved leaf pane`, `boomerang pane`, `tapered crescent pane with rounded ends`, `curved wedge pane with no hard-clipped terminals`, `loose prism cluster`.
- Good metaphors: filter panes, color grading fragments, creative lens panes, media prism panes, layered visual effects.
- Image generation constraint: choose the pane arrangement from app semantics; do not default to a waveform, audio-band stack, equalizer, continuous rainbow ribbon, broad triangular/kite/trapezoid tiles, or copied source arrangement. Do not allow hard clipped terminals, flat chopped ends, straight cut corners, angular polygon cuts, internal seams, internal bands, curved interior divisions, two-tone sections, borders, outlines, rims, sidewalls, long white shine streaks, plastic shine, gel bevel, glow, blur, tiny confetti, or lens simulation.
- SVG risk: medium because of layer count; keep each pane simple, separated, solid-filled, borderless, smoothly rounded, and independently drawable. Use PNG fallback only for a user-approved strict-fidelity flat pane with clean edges and no visible internal seam or band.

## Style-To-Design Rule

After selecting a direction, write a `semantic_icon_design` with:

- exact background type and colors, with layer fills chosen as a coherent palette
- a `background.gradient_policy` for any gradient, including contrast level, hue relationship, and explicit color-clash rejects
- target layer count
- one `shape_model` per layer
- a `layering_policy` that declares cutout-like details as separate opaque overlay layers
- subject scale constraints when the mark must stay compact or intentionally oversized
- for taste-reference-derived directions, a topology choice that preserves the semantic cue without copying the reference silhouette
- a `composition_anchor` and matching safe area/layer bounds when the subject is intentionally centered, lower-left, or lower-right
- bottom-to-top layer order
- explicit `must_preserve` and `must_not_add`
- material restrictions for every SVG target

Do not generate an image from the direction alone. Generate from a short creative prompt derived from the completed JSON design and the matching style family's variant axes, then use the matching style file's `Template Conversion Flow` plus an adapted JSON as the conversion contract.
