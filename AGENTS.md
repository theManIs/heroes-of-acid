# Project Workflow Rules

**Main rule (every repo):** do not work without a plan. Plan → command → do.

Rule scopes:

- **Every repo** — applies everywhere. Copy into other projects only when asked; do not go edit other repos from this chat.
- **Layout and UI** — applies only to tasks that create or change user interfaces.
- **iOS app repos** — this repository and other native iOS apps. Not for PHP/PWA/etc.

Use only the sections relevant to the current repository and task.

---

## Every repo

### Plan → command → work

- Do not start implementation without a plan.
- Order: **plan** → **command** («да», «делай», «ок», or a concrete step) → **do**.
- Short plan first; wait. «Сделай план» is not approval to implement.
- Creating and editing rules or journals does not need a separate «делай».
- Do not choose features, design, or scope for the user.
- Do not guess the next step.
- «Готов?» / «можем?» is not a command to work.

### File

- Single source of truth: this file only.
- Do not duplicate it under `.cursor/rules/` or any other tool-specific folder.
- Copy this file into another project verbatim only when the user explicitly asks to take it there. Do not copy selected fragments or silently adapt it during transfer.
- A copied file remains a rule catalog: apply only the sections relevant to the current repository and current task.
- **Rules:** `AGENTS.md`
- **Tasks:** `TASKS.md`
- **Journals:** `journals/SESSION.md`, `journals/CODELOG.md`

### Communication

- Answer **short**.
- Use numbered lists for review problems and proposals, not as a universal response format.
- A problem's number is its stable identifier throughout the review of that method: never renumber it in follow-up explanations, decisions, implementation updates, or the final summary.
- Ordinary explanations and confirmations that do not enumerate problems should be prose, without artificial numbering.
- For each finding, provide a concrete proposed change that the user can approve or reject; do not leave observations as open-ended commentary.
- If a request looks wrong (contradicts earlier decisions, breaks balance or style, makes no sense resource-wise), say so once, briefly, with the reason and an alternative, before starting. The user decides: after the answer, do as they said without arguing again.
- Do not ask follow-up questions by default.
- Ask only when the request is **genuinely ambiguous**.
- When asking: an **interactive questionnaire**, not a wall of questions.

### One problem at a time

People track **one** problem. Stay inside that frame.

- Do not solve neighbouring problems, neighbouring repos, or the “next” topic.
- Finish the current problem, **commit**, then the next one.

### Task status and acceptance

- Interactive/manual acceptance is performed by the user unless the user explicitly asks the assistant to perform it.

### Workspace

- Work only inside the **current** workspace root.
- Do not read, edit, or run commands on other projects, home dirs, or `../`.
- The one exception: `~/Documents/projects/AGENTS.md` — a copy of this file. After every change to `AGENTS.md`, copy it there so it always holds the latest version.
- If the user names another project: this chat stays here; they open that folder in the editor.

### Journals

- After every assistant response, append to `journals/SESSION.md` (do not rewrite history):

```markdown
### YYYY-MM-DD HH:MM

**User:** one-line summary.

**Assistant:** one-line summary.
```

- Update top sections of `SESSION.md` if scope/architecture/open questions changed.
- Skip a turn only if the user says not to log it.
- Do not log secrets, tokens, or `.env` contents.
- Code changes: `journals/CODELOG.md` (hunks + commands). No fake diff if nothing changed.

### Tasks

- File: `TASKS.md`.
- Every task is a numbered Markdown checkbox: `- [ ] 12. …` or `- [x] 12. …`. The number is stable; new tasks go to the end with the next number.
- Write every planned project task to this file.
- Every task the user gives: add it to `TASKS.md` with its number, then propose it for execution (by number) and wait for the command.
- Check an item as soon as its code is written. Do not wait for manual acceptance. A dropped task is checked too, with a short note why.
- If a side topic appears while we are in another frame: **do not start it**. Add an unchecked task and return to the current problem.
- Update the file on disk when task status changes. Do not paste the task list into chat every turn.

### Chat files: screens, references, assets

The user drops files in chat. Sort and save every time. Names:

- **скрины** → `screens/`
- **референсы** → `references/`
- **ассеты** → the place the project actually uses them

Rules:

- **скрины** — свежий набор экранов в `screens/current/`, постоянные имена по экрану/состоянию. При просьбе пройти приложение и обновить скрины заменять одноимённые файлы, обновлять manifest со временем/версией и отмечать недоступные состояния. Старые файлы не выдавать за свежие. Gitignore. Do not push.
- **референсы** — files we rely on for the current task. Keep in `references/`. Commit them.
- Every reference gets a line in `references/README.md`: what we take from it (one mechanic, style or shape) and what we do not take. Use a reference only for what its line says; never copy the rest of the picture.
- **ассеты** — files used by the product. Put them in the project’s real asset location, not a dump folder.
- If the type is not obvious: interactive questionnaire (скрин / референс / ассет). Do not guess.

### Asset generation in external chats

- When an asset is generated in an external chat (ChatGPT etc.) through the browser, archive every chat opened for that generation once the result is saved.

### Pipelines

- A project may keep step-by-step recipes for recurring jobs in `pipelines/<name>/` (`README.md` + the scripts it uses).
- When a task matches a pipeline, follow it step by step; when the user changes the process, update the pipeline in the same turn.
- A pipeline is project-specific know-how, like a skill but kept in the repo, versioned and readable by any tool.

### Local URLs

- Do not open an in-editor browser.
- Reply with the **URL only** (example: `http://localhost:3000`).

---

## Layout and UI

### Form input

- Phone numbers and other numeric fields use an appropriate numeric keyboard.
- When a value has a known display format, apply an input mask (for example, a phone-number mask).

---

## iOS app repos (not every repo)

This repository is the **Afimall iOS** client. Android and Server are other repos.

Default for **ассеты** from chat: `App/Assets.xcassets` (or the path the user names).

### Xcode

```bash
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
```

- Do not `sudo xcode-select` unless the user asks.

### Device

- Only physical **iPhone (Artem)** (`00008110-00014D69368B801E`). No simulator, ever.
- If the iPhone is unavailable: say so, do not fall back to simulator, wait instead.
- Do not propose a device run for an empty shell, rule tweaks, or non-visual work.
- UI-visible changes: install and launch on the iPhone. Skip the device if the change is not user-visible.

### Tests

- Do not run UI tests unless asked.
- Unit tests on the iPhone when tests are actually needed.
- `swift test` on the Mac is fine for package-level checks.
