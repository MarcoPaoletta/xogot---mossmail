# Godot AI 4.3.0: long runtime probes and saved instance edits

Measured while building Shrine Keeper in Godot 4.7.2, 6 October 2026.

## Long runtime probes

The runtime game eval reply guard is about eight seconds. A valid probe that walks a level or waits for a finale can return EVAL_HUNG even while the game continues executing its coroutine. This is not evidence that gameplay froze.

Keep the probe outside that short reply lifetime. Save a development RefCounted driver through the MCP script creation tool. Its start method stores itself in metadata on the current scene, schedules an async method with call_deferred, and immediately returns. The async method runs the input probe, writes its result to a local evidence JSON, stores the result in scene metadata, and releases its retained reference. Read that result through short eval calls. Wait for it before dispatching another mutation or probe.

Use real viewport input events and semantic state getters. The driver and tests are excluded from export. No permanent gameplay nodes are created by the runtime driver.

## Instance children must survive a disk reload

Packing a parent scene can retain changes to an instance root while omitting changes to children owned by the nested source scene. A changed metadata field is not proof that the sprite texture or collider changed.

Edit and save the owning source scene when all instances should change. For a new variant, save a standalone prop source whose children have that source root as owner, then replace the level instance with the new PackedScene. Preserve its name, transform and parent scene owner. Reload the saved scene and assert the actual texture paths, dimensions and collision shapes.

The Shrine Keeper white flower and small stall corrections required this. Root position changes serialized; nested texture and shape edits needed owning source scenes.

## Independent reload audits

Prefer CACHE_MODE_IGNORE_DEEP for an independent saved-scene audit. CACHE_MODE_REPLACE_DEEP updates shared dependencies in place and can invalidate a FontFile still used by an open editor scene, producing temporary TextServer errors. Reloading an independent copy avoids disturbing the editor's visible font resources.

## Scaled UI pivots

Changing a Control pivot moves its visible rectangle when its authored scale is not one. Preserve the base rectangle before introducing a centred pop tween:

    position -= (new_pivot - old_pivot) * (Vector2.ONE - base_scale)

Then assign the new pivot and animate around the authored base scale. Check the runtime rectangle and screenshot, since an audit of saved offsets alone cannot see this displacement.

## Corrupt saves without error spam

Use a JSON instance and its parse return code for untrusted save content. JSON.parse_string logs a parse error for a truncated file even when the caller handles the null result. A guarded decoder can start fresh and preserve the backup while keeping runtime diagnostics clean.

## Detached sprite bounds

Shrine Keeper's woodland budget pass kept reporting the same count after moving detached props. Cached global transforms were stale outside the tree. Compose the current local transforms from the sprite through its ancestor chain for editor authoring audits. Assert that every budget relocation reduces the count before packing. Check runtime bounds separately after loading the saved scene.

## Presentation memory is part of the budget

In Shrine Keeper, more large UI type sizes and a shrine CanvasGroup pushed whole renderer texture memory above 160 MB although the source image payload remained below 100 MiB. Lora MSDF shared one scalable atlas, and a single sprite shader mixed the two aligned original shrine images without the CanvasGroup screen buffer. Final ordinary runtime allocation was 147.73 MiB. Measure the whole renderer after opening all major screens, rather than reporting only imported PNG payload. Verify the crossfade by rendered contact sheet and keep original source images unchanged.

## Verify actual sound requests

An existence check over audio assets missed silent walking. The controller requested footstep_grass_1 and footstep_bridge_1, while the baked files used padded01 names and plank. Verify every gameplay request through the audio resolver and decoded playback pool. Include positional ambience in the Effects setting. Separate score and effects buses, and duck only the score for dialogue and important cues. Boot mute remains the first audio operation.

## Text padding is a content rectangle

Shrine Keeper's wood controls grew their borders with the control height, leaving only 52 px of usable centre inside a 110 px button. Lora at 48 px needed 63 px before padding. Keep ornamental corner scale fixed, stretch only the blank centre and assign actual StyleBox content margins. Runtime menu resizing must preserve those margins. Measure full shaped text and font height, not character count. Wide inventory captions can preserve full names and large type while making room between rows. A control can pass minimum size checks yet place its glyphs on painted borders, so inspect the frame too.

## Complete mutations before saving or signalling

Compound economy and quest operations must update every related field before one save and signal emission. Saving removal before addition can persist payment without its reward if the process stops between calls. Observe trade, blessing, shrine and pickup signals against the disk payload; every observer must see the complete transaction. Validate finite numeric settings before converting untrusted JSON values. Keep a byte exact fixture backup and restore all save generations after corruption tests.


## Embedded screenshots need a fixed capture viewport

Measured in Last Floor Hotel, Godot 4.7.2, 7 October 2026. The editor embedded game kept the rendered window at 1763 by 991 even when a screenshot driver assigned Window.size to 1920 by 1080 and later 1280 by 720. Inspect the PNG dimensions; assigning Window.size is insufficient evidence.

Bake a development SubViewport into the capture scene through the MCP. Use size 1920 by 1080, size_2d_override 1920 by 1080, size_2d_override_stretch true, use_hdr_2d true, update mode Always, and Linear With Mipmaps for its canvas texture filter. Instance the real game inside that viewport and capture its texture. Set only the viewport size to 1280 by 720 for the smaller UI check. This produced exact 1920 by 1080 and 1280 by 720 captures without changing the user's editor window. Disable the hotel's Camera2D while capturing a standalone showcase without a camera, or its inherited framing shrinks the showcase.

## Manual camera input and light independent world UI

Runtime input_mouse motion events may supply position with zero relative displacement. For a left drag camera, remember the press position and subtract successive motion positions. The same implementation works with native mouse input and the MCP probe. Process the camera during pause and test UI button clicks independently.

A world bubble with a white face and dark number was washed out beside the cab arrival light. Assign an Unshaded CanvasItemMaterial to the shared bubble scene root and use_parent_material on every child, including the Label. The whole bubble, its ring and the number then keep their colors under warm and cold light.

For the five independent navigation maps, setting their merge_rasterizer_cell_scale to 0.01 removed the synchronization warnings after rebaking the expanded rooms. Set Camera2D.process_callback to Physics in the saved scene, before it enters the tree, to avoid the startup interpolation override warning. Check the current runtime log after a new launch.
