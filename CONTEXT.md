# MT-Fast-Logic

MT-Fast-Logic adds high-speed logic tooling and a successor multitool experience for Scrap Mechanic players building and debugging logic creations.

## Language

**NewTool**:
The successor to the MTMultitool, focused on improving the player experience for logic-building workflows.
_Avoid_: New multitool, next multitool

**MTMultitool**:
The existing multitool whose capabilities and UX are being replaced or reworked by the NewTool.
_Avoid_: Old tool, legacy tool

**Workflow Hub**:
The NewTool's main menu role: an entry point organized around player goals rather than a flat list of modes.
_Avoid_: Mode list, main menu

**Goal Verb**:
A top-level hub category named after the player's intent. The default v1 order is Connect, Build, Convert, Modify, Inspect, Manage.
_Avoid_: Mode family, tool category

**World Hologram**:
A menu surface rendered spatially in the game world rather than as a conventional flat interface panel. The v1 hologram uses ImRend icons for spatial targets and interaction text for focused names and descriptions.
_Avoid_: GUI screen, 2D panel

**Yaw-Anchored Hologram**:
A World Hologram that follows the player's position while using the player's horizontal facing direction, not camera pitch, for its opening orientation.
_Avoid_: Camera-pitched menu, sky/floor menu

**Look-and-Click Selection**:
A hologram interaction style where the camera aim highlights an item and primary use confirms it. While the hub is open, secondary use closes the hub, short-tap ForceBuild closes the hub, and held ForceBuild is ignored; while a Tool Workflow is active outside the hub, secondary use cancels that workflow.
_Avoid_: Mouse cursor, release-to-confirm

**Focused Preview**:
The explanatory feedback for the currently highlighted Goal Verb or action; in the v1 ImRend-only hub this is shown through interaction text rather than a rendered text panel.
_Avoid_: Tooltip spam, action list

**Side Panel Actions**:
A hub navigation pattern where Goal Verbs remain visible while the selected Goal Verb's available actions are shown beside them.
_Avoid_: Drill-down replacement, inline expansion

**Selected Goal Verb**:
The Goal Verb whose Side Panel Actions are currently visible; the Workflow Hub opens with the first manifest Goal Verb selected.
_Avoid_: Hover category, pinned category

**Visible Action Set**:
The small set of actions shown for a Selected Goal Verb; overflow is treated as a category design problem rather than a scrolling or pagination problem.
_Avoid_: Scroll list, paged list

**Pinned Tool**:
A Tool Workflow assigned to a radial menu slot for quick access.
_Avoid_: Favorite tool, selected goal

**Dummy Tool Workflow**:
A placeholder Tool Workflow that proves menu selection and in-tool completion without porting the real MTMultitool behavior yet. Selecting one closes the Workflow Hub; primary use completes it and clears the active workflow.
_Avoid_: Ported mode, real tool implementation

**Active Workflow Indicator**:
The player-facing hint that names the active Tool Workflow and shows how to complete or cancel it; the prototype uses interaction text plus debug prints.
_Avoid_: Hidden mode, print-only state

**Sleeping Tool Workflow**:
An active Tool Workflow that remains active while the NewTool is unequipped; its state and visuals are kept and it resumes when the NewTool is equipped again.
_Avoid_: Unequip cancellation, hidden reset

**Radial Override Slot**:
A future radial slot that a Tool Workflow may temporarily use for its own settings or actions while relevant.
_Avoid_: Tool-owned radial menu

**Data-Driven Tool Model**:
A NewTool design where menus, categories, actions, and bindings are declared as data instead of being embedded in mode-specific control flow.
_Avoid_: Hardcoded mode list, mode router

**Action Registry**:
The catalog of NewTool actions, where each action has an identity, presentation metadata, placement metadata, and an execution handler.
_Avoid_: Mode router, if-chain dispatch

**Menu Manifest**:
A data declaration that describes menu structure by referencing registered actions and categories.
_Avoid_: Hardcoded menu, embedded layout

**Command**:
A registered action that completes immediately when selected and declares how it affects any active Tool Workflow.
_Avoid_: Instant mode

**Tool Workflow**:
A registered action that activates a stateful interaction flow after selection.
_Avoid_: Mode

**Submenu**:
A registered action that navigates to another menu within the Workflow Hub.
_Avoid_: Menu mode
