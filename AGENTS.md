# AGENTS.md

## Purpose
This file defines how the coding agent must work in this repository.
Follow these rules strictly for the entire session.

---

## Priority Order
When rules conflict, follow this order:

1. Explicit user request in the current session
2. This `AGENTS.md`
3. Existing project conventions already present in the codebase
4. Default tool or model behavior

If something is unclear, do not guess. State the uncertainty explicitly.

---

## Language Rule

Respond in Romanian by default.

Do not switch to English unless the user explicitly asks for English.

Keep technical tokens unchanged:
- code
- identifiers
- file paths
- commands
- logs
- error messages
- API/framework/library names

---

## Core Rules

### 1. Do not make assumptions
If a detail is not clear from the code or from the user's request, say exactly what is unclear and stop inventing missing details.

### 2. Change only what was explicitly requested
Do not add, remove, rename, move, refactor, optimize, clean up, or "improve" anything unless the user explicitly asked for it.

### 3. Do not apply any file change without explicit user approval
Any modification to application code, configuration, assets, scripts, documentation, or other files must first be discussed and proposed as a patch.

Do not apply any change until the user gives explicit approval.

### 4. Keep the change surface minimal
Touch the fewest possible files and modify the smallest possible amount of code needed to satisfy the request.

### 5. Analyze before editing
Before changing code, first identify the exact file or files involved, read the relevant surrounding code, and explain the impact area.

### 6. Respect existing behavior unless told otherwise
Do not change current logic, flows, defaults, validation, UI behavior, architecture, or naming unless the requested task requires it.

### 7. Be explicit about uncertainty
If you are not sure which file, version, branch, symbol, or implementation is the correct one, say so clearly instead of guessing.

### 8. Never hide omitted code
Do not use `...`, summaries, placeholders, partial snippets, or "same as before" when presenting modified code or patch instructions.

### 9. Preserve user intent over agent initiative
If the user's request is narrow, keep your work narrow. Do not broaden the task on your own.

---

## Required Workflow

### 10. First locate the exact target
Identify the exact file path, symbol, widget, function, class, or block that must be changed before proposing edits.

### 11. Read enough context before changing anything
Read the target code and the immediately related code so the change is grounded in actual project context.

### 12. Explain the intended change before applying it
Before editing, state briefly what will change, where it will change, and whether other files are affected.

### 13. Wait for explicit user approval before applying any patch
After analysis and after proposing the patch, stop and wait for explicit user approval before applying any modification.

Do not treat silence, implied agreement, or general discussion as permission to edit files.

### 14. Stop when requirements are ambiguous
If multiple valid implementations exist and the user did not choose one, do not silently pick one and present it as certain.

### 15. After editing, report exactly what changed
State the file paths changed, the exact purpose of each change, and any areas that should be verified manually.

---

## Output Rules

### 15. Prefer precise patch instructions by default
Unless the user explicitly asks for downloadable files, provide changes as exact patch instructions.

### 16. Patch instructions must be concrete
For every change, specify the full file path and use this exact format:
- 2 lines before the target block as anchor
- the exact code to modify or remove
- the exact replacement or inserted code
- 2 lines after the target block as anchor

Do not provide vague instructions, summaries, or abbreviated diffs.

### 17. Present complete modified files only when explicitly requested
If the user asks for the whole modified file, provide the full file with the requested changes already integrated and nothing omitted.

### 18. Never bundle modified files into a zip
If downloadable files are requested, provide each modified file individually.

### 19. Do not add extra commentary inside code deliverables
Keep deliverables clean. Put explanations outside the code or file content.

---

## Code Modification Discipline

### 20. No silent refactors
Do not reorganize code structure, extract methods, rename symbols, change formatting style, or reorder code unless explicitly requested.

### 21. No speculative bug fixes
Do not fix nearby issues just because they look wrong. Fix only the requested issue.

### 22. No hidden dependency changes
Do not add packages, change SDK constraints, update Gradle, alter build files, or modify configuration unless the user explicitly asked for that.

### 23. No destructive edits without clear need
Do not delete code, files, assets, comments, or configuration unless deletion is explicitly part of the requested change.

### 24. Preserve public interfaces unless required
Do not change signatures, routes, APIs, exported names, or externally used behavior unless necessary and explicitly requested.

---

## Flutter / Dart Rules

### 25. Do not start variable names with underscore
Avoid variable names beginning with `_` because they generate warnings in this environment.

### 26. Do not use `BuildContext` across async gaps
Avoid using `BuildContext` after `await`. If unavoidable, guard it with `context.mounted`.

### 27. Do not introduce deprecated `.withOpacity(...)`
When writing new code or changing a line that requires alpha, use `.withValues(alpha: ...)` instead of `.withOpacity(...)`.

### 28. Use the required color expression style
When needed in this codebase, write:
`color: (baseStyle.color ?? Theme.of(ctx).textTheme.bodySmall?.color)`
Do not put `?` after `baseStyle`.

### 29. Keep Flutter changes narrowly scoped
Do not restyle widgets, rename widgets, move logic between files, or restructure state handling unless explicitly requested.

---

## DzVents Rules

### 30. Do not declare boolean variables in DzVents
DzVents in this project must avoid boolean variable declarations.

### 31. Use `set()` to assign a new value to a variable
When a variable value must change in DzVents, use `set()`.

### 32. Use `updateText()` for text devices
When updating a text-type device value, use `updateText()`.

### 33. Compare strings with single quotes
In DzVents, use `'text'`, not `"text"`.

### 34. Treat text variables as strings
Text values must be handled and compared as strings using single quotes.

### 35. Respect existing device equivalences
When the project maps names such as `pompa = dz.devices('Pompa_ON/OFF')`, preserve and respect that equivalence in comparisons and logic.

---

## Project-Specific Safeguards

### 36. `foaie_prestatii_mvp`: treat current project files as source of truth
Base analysis and changes only on the actual current files of the repository being edited, not on old conversations or assumptions.

### 37. Do not flag February 16 as an error by default
In this project, February 16 is a valid special day under the collective labor agreement unless the user explicitly asks for a different rule.

### 38. Do not treat the "Afișare Avansată" work-in-progress area as a bug
If the UI explicitly says that the area is still in progress, treat it as intentional unless the user asks otherwise.

### 39. Verify the no-overlap invariant before claiming overlap bugs
This application is intended to prevent overlapping segments. Check that invariant carefully before reporting overlap-related issues.

---

## Analysis Rules

### 40. Ground conclusions in actual code
When analyzing behavior, cite the exact files, classes, methods, widgets, or logic paths that support the conclusion.

### 41. Distinguish facts from inferences
State clearly what is directly visible in code and what is only inferred from code structure.

### 42. Do not report unverified problems as bugs
If something only looks suspicious but is not confirmed by the code path, label it as uncertainty, not as a bug.

### 43. Check impact radius before proposing changes
Whenever possible, identify callers, dependencies, related widgets, and connected files before recommending a modification.

### 44. Do not edit when the user asked only for analysis
If the user asks for analysis, review, explanation, or impact assessment, do not propose or apply code changes unless explicitly asked.

---

## Communication Rules

### 45. Be direct and technical
Use clear, precise language. Do not pad responses with unnecessary phrasing.

### 46. Do not pretend certainty
Never present guesses as facts.

### 47. Keep explanations tied to the task
Do not drift into unrelated suggestions, optional improvements, or alternative implementations unless the user asks for them.

### 48. When asked for code, provide code-oriented output
Do not replace concrete edits with generic advice when the user asked for an actual change.

---

## Session Start Rule
At the start of each task, first do this:

1. Read this `AGENTS.md`
2. Read the requested target files and nearby context
3. Restate the exact requested change
4. Identify the files affected
5. State any uncertainty
6. Only then propose the patch
7. Apply changes only after explicit user approval

---

## Final Rule
If following user instructions strictly conflicts with your urge to improve unrelated code, ignore the urge.