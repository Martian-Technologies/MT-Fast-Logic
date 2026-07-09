# NewTool Workflow Hub v1 Prototype

The v1 prototype validates the NewTool Workflow Hub without porting MTMultitool behavior.

## Controls

- Short-tap ForceBuild opens the Workflow Hub.
- While the hub is open:
  - Aim at an icon to focus it.
  - Primary use selects the focused icon.
  - Secondary use closes the hub.
  - Short-tap ForceBuild closes the hub.
  - Holding ForceBuild is ignored; the radial menu does not nest inside the hub.
- While a Tool Workflow is active outside the hub:
  - Primary use completes the dummy workflow.
  - Secondary use cancels it.
  - Short-tap ForceBuild opens the hub without cancelling the workflow.
  - Holding ForceBuild opens the radial menu.

## Hub Layout

The hub is a yaw-anchored world hologram rendered with ImRend icons. It follows the player's position but keeps the opening horizontal orientation rather than following camera pitch.

The left stack contains Goal Verbs in this order:

1. Connect
2. Build
3. Convert
4. Modify
5. Inspect
6. Manage

The hub opens with Connect selected. Selecting a different Goal Verb changes the side-panel actions. Action overflow is not handled in v1; overflow means the categories need to be redesigned.

Focused names and descriptions are shown through interaction text until a NewTool text renderer exists.

## Dummy Action Mapping

All old MTMultitool modes are represented as dummy Tool Workflows:

- Connect
  - Single Connect
  - Series Connect
  - N-to-N Connect
  - Parallel Connect
  - Tensor Connect
- Build
  - Volume Placer
  - Decoder Maker
- Convert
  - Logic Converter
  - Silicon Converter
  - Merger
- Modify
  - Mode Changer
  - Volume Deleter
  - Colorizer
  - Copy Paste
- Inspect
  - Heatmap
- Manage
  - Settings

Selecting a dummy Tool Workflow closes the hub, prints activation, and shows interaction text. Primary use completes it and clears it; secondary use cancels it.

## Radial Defaults

The radial menu keeps Toggle Flight and adds these default Pinned Tools:

- Single Connect
- Series Connect
- Parallel Connect
- Tensor Connect

Selecting a Pinned Tool cancels/restarts the active Tool Workflow before activating the selected workflow.
