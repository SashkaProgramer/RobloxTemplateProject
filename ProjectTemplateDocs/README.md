# Project Template Docs

This folder stores reusable documentation and agent-instruction templates for future Roblox projects.

## Files

- `AGENTS.md`
  - Persistent project-level agent rules.
  - Usually safe to reuse with small edits.

- `ProductStrategyPrompt.md`
  - Prompt for product strategy, retention, virality, and monetization reviews.
  - Usually safe to reuse as-is.

- `ProjectOverview.md`
  - Reusable overview template for a new project.
  - Should be filled in and adapted for each new project.

- `TechnicalSpec.md`
  - Reusable technical specification template.
  - Must be filled in and updated for each new project.

## Recommended Reuse Flow

1. Copy `AGENTS.md` into the root of the new repository.
2. Copy `ProductStrategyPrompt.md` into the new project's `Docs/` folder.
3. Use `ProjectOverview.md` as a starting template, then rewrite it for the new game's concept.
4. Use `TechnicalSpec.md` as a starting template, then update architecture, modules, Rojo mapping, and tools.

## Suggested Target Layout

- `AGENTS.md`
- `Docs/ProjectOverview.md`
- `Docs/TechnicalSpec.md`
- `Docs/ProductStrategyPrompt.md`
