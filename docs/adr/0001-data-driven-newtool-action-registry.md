# Data-driven NewTool action registry

NewTool will use an Action Registry plus Menu Manifests, declared as Lua tables in v1, instead of MTMultitool-style hardcoded mode lists and mode-routing chains. Registered entries are explicitly typed as Commands, Tool Workflows, or Submenus so the Workflow Hub can stay configurable without pretending every user-facing choice behaves like the same kind of mode.

## Considered Options

- Keep behavior hardcoded and only make the menu prettier.
- Make menu layout data-driven while leaving behavior routed through hardcoded mode conditionals.
- Make all workflows fully declarative.

## Consequences

The v1 configuration boundary is the action registry and explicit menu manifests. Menu layout is intentional and ordered by manifest rather than generated from action categories. User-editable menu layout remains a later extension, not a v1 requirement.
