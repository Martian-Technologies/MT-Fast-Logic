# NewTool TODO

Goal: make NewTool a full replacement for MTMultitool while keeping both tools independent.

## Rules

- NewTool must own its tool logic.
- MTMultitool is a behavior reference only. NewTool must not call or load its code.
- Flight is the only shared tool feature.
- Stable mod-wide APIs may still be used.
- Keep MTMultitool working until NewTool passes the final parity check.

## Implementation order

### 1. Complete the NewTool foundation

- [x] Forward all required controls to the active mode, including reload, rotate, and crouch.
- [ ] Handle equip, unequip, cancel, undo, commit, and invalid selections consistently.
- [x] Add a NewTool-owned client/server operation flow for safe mutations and large jobs.
- [ ] Add backup support before destructive operations.
- [ ] Add localization and NewTool-owned settings storage.
- [ ] Support a one-time import of existing MTMultitool settings without creating a runtime dependency.

### 2. Complete connection support

- [ ] Add connect and disconnect modes.
- [ ] Add directional previews, preview limits, commit feedback, and safe batching.
- [x] Finish Parallel Connect.
- [x] Add Series Connect.
- [ ] Add N-to-N Connect.
- [ ] Add Multipoint selection with all-to-all and index-paired operations.
- [ ] Add Decoder Maker.

### 3. Add the remaining selection types

- [ ] Select a body or full creation.
- [ ] Select inside and outside cuboid volumes.
- [ ] Select arbitrary shapes and groups with undo support.
- [ ] Select vectors and discrete ranges.

### 4. Add creation editing tools

- [ ] Convert full creations between vanilla and Fast Logic.
- [ ] Delete all shapes in a selected volume.
- [ ] Place volumes of vanilla or Fast Logic gates.
- [ ] Change gate modes in a selected volume.
- [ ] Merge selected gates by linking their inputs to their outputs.
- [ ] Convert selected regions between Fast Logic and Silicon.
- [ ] Color blocks or Fast Logic connection dots, including match and invert modes.

### 5. Add advanced tools

- [ ] Add Tensor Connect with matching source and destination dimensions.
- [ ] Support large tensor jobs without requiring a full preview.
- [ ] Add Copy/Paste with grouped selection, repeat vectors, preserved state, and external connection policies.

### 6. Add inspection tools

- [ ] Add Connection Shower for vanilla, Fast Logic, and Silicon connections.
- [ ] Show interactable state and power where supported.
- [ ] Add the Fast Logic performance heatmap.

### 7. Complete settings and utilities

- [ ] Add settings profiles and action visibility controls.
- [ ] Add the connection preview limit and inspection toggles.
- [ ] Add the one-tick hammer toggle.
- [ ] Add blueprint import.
- [ ] Add the backup browser and restore flow.
- [ ] Show and control flight from the settings UI.

### 8. Verify parity and replace MTMultitool

- [ ] Verify every user-facing MTMultitool workflow in NewTool.
- [ ] Test lifted, non-lifted, and multi-body creations.
- [ ] Test multiplayer, cancellation, undo, large operations, backups, settings migration, and supported languages.
- [ ] Remove all placeholder actions.
- [ ] Confirm NewTool has no dependency on MTMultitool code other than the flight exception.
- [ ] Retire MTMultitool only after all checks pass.
