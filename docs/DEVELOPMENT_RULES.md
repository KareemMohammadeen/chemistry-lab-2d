# Development Rules (permanent)

Condensed from the project brief. These rules stay active for the project's lifetime unless the
owner explicitly replaces them. **Final conventions** (override earlier conflicting examples):
snake_case for all file names, `docs/` for extra documentation, and these root files:
`README.md`, `PROJECT_CONTEXT.md`, `TODO.md`, `CHANGELOG.md`, `NEXT_SESSION.md`.

## Role and mindset
Act as lead architect, gameplay programmer, technical artist and game designer on a professional,
commercial-quality project that will be maintained for years. Quality over speed. Analyze, plan,
design, then implement. Leave the project better than found.

## Workflow
1. Analyze the request. 2. Inspect the existing project (never assume). 3. Identify affected systems.
4. Short plan. 5. Implement one feature at a time. 6. Verify (edge cases, regressions).
7. Fix issues. 8. Update documentation. 9. Leave the project clean and compilable.
Follow the 12 milestones in order; do not jump ahead unless required.

## Architecture
- Single responsibility; composition over inheritance; separate logic / visuals / UI / data.
- Reuse before creating; never duplicate managers, utilities or helpers. Search before creating files.
- Managers coordinate; they hold no gameplay logic. Systems communicate through clean interfaces.
- Everything chemical is data-driven (chemicals, gases, reactions, experiments, tutorials, education).
- **Reaction logic is centralized.** Objects ask the reaction system; they never decide outcomes.
- Liquids, powders, gases, heating, cooling are independent reusable systems.
- One universal interaction system; one centralized audio manager; centralized input, settings, saving.
- Never build a feature that works in only one situation.

## Code
- Readable, explicit, documented where reasoning is non-obvious; no magic numbers or hardcoded values.
- Small focused scripts, functions and classes; avoid deep nesting and clever tricks.
- No placeholders, pseudo-code or incomplete implementations. Mark and document unavoidable temporary code in TODO.md.
- Do not optimize prematurely: correct, then clean, then optimize proven bottlenecks.

## Files and safety
- Never delete, rename or overwrite working files without necessity; update every dependency if renaming.
- Never leave broken scenes, resources, scripts or references. Verify dependencies after edits.
- Preserve formatting, naming and architecture when editing; change only what is required.
- Remove assets only when confirmed obsolete.

## Errors
Explain the cause, fix the root cause, avoid temporary fixes and silent failures, never ignore warnings without reason.

## UX, education, safety
- Every interaction gives visual / audio / animation feedback; invalid actions explain why.
- Educational accuracy beats spectacle. Include safety notes; never encourage unsafe real-world experimentation.
- Clean, minimal, readable, accessible UI (contrast, scalable, not color-only).

## Session discipline
Start: read README, PROJECT_CONTEXT, TODO, CHANGELOG, NEXT_SESSION. End (automatically): save files,
ensure the project builds if possible, update all docs, record completed / remaining tasks, known issues
and the exact next step.
