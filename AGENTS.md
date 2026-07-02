# AGENTS.md

This file contains repository-level guidance for Codex and other coding agents.

## Before changing code

- Read the relevant implementation and tests before editing.
- Preserve user changes and unrelated worktree modifications.
- Game DLLs under `lib/` are local artifacts copied from the user's installation;
  never commit or redistribute them.
- Treat the current `sts2.dll` as the source of truth for game APIs. When an API
  differs across game builds, prefer a narrowly scoped compatibility adapter.

## Build and validation

Windows PowerShell:

```powershell
.\setup.ps1 -ValidateOnly
dotnet build .\src\Sts2Headless\Sts2Headless.csproj
python -m pytest .\tests
```

macOS/Linux:

```bash
./setup.sh --validate-only /path/to/game
dotnet build src/Sts2Headless/Sts2Headless.csproj
python -m pytest tests
```

For gameplay changes, run focused deterministic JSON-protocol reproductions in
addition to unit tests. Before a release, run batch games for every character:

```bash
for char in Ironclad Silent Defect Regent Necrobinder; do
  python scripts/play_full_run.py 5 "$char"
done
```

Expected result: `Completed: 5/5` for every character, with no crashes or stuck
decision points. If local dependencies prevent a validation step, report exactly
which step was not run.

## Architecture

- `src/Sts2Headless/RunSimulator.cs`: game lifecycle, actions, decision-point
  detection, reward state, and state serialization.
- `src/Sts2Headless/Program.cs`: stdin/stdout JSON command router.
- `src/Sts2Patcher/`: the single shared IL patcher used by all setup paths.
- `src/GodotStubs/`: no-op replacement for GodotSharp.
- `scripts/play.py`: interactive terminal client.
- `scripts/play_full_run.py`: batch simulation client.
- `tests/`: protocol-level integration tests.
- `localization_eng/`, `localization_zhs/`: official localization data.

## Localization

- Use official strings from `localization_eng/` and `localization_zhs/`.
- Do not invent Chinese translations when an official entry exists.
- Python user-facing strings must use `t(en, zh)`.
- Resolve template variables such as `{Damage}`, `{Block}`, and `{MaxHp}` before
  display.

## Decision-point invariants

- Every interactive decision must include a `player` summary containing HP,
  gold, potions, relics, and deck data.
- Read-only commands such as `deck`, `map`, `draw`, and `discard` must not mutate
  the active decision.
- Rewards remain pending until explicitly claimed or skipped. Potion rewards
  remain available when potion slots are full.
- Nested `RewardsSet` instances must suspend and later restore their parent
  reward context without leaving an in-progress lock.

## Async conventions

- Event completion should normally trust `localEvent.IsFinished`. Ancient events
  are single-shot and use their `Done()` transition after all nested selections
  and rewards resolve.
- Effects that can open `card_select`, `card_reward`, `bundle_select`, or
  `reward_select` must not synchronously block the JSON command loop.
- When waiting for an engine task, return immediately once a pending decision
  appears. Do not add fixed animation sleeps unless a deterministic engine state
  requires one and a regression test demonstrates it.
- Always consume redirected child-process stdout and stderr to prevent pipe
  backpressure deadlocks.

## Card and combat conventions

- `card_select` uses the `cards` field and the `select_cards` action with
  comma-separated `indices`.
- `AnyEnemy` cards and potions require `target_index` when two or more enemies
  are alive; a single living enemy may be selected automatically.
- `UpdateDynamicVarPreview` mutates live cards. Call `ClearPreview` before and
  after preview reads so serialization cannot corrupt later play actions.

## Editing and handoff

- Keep changes focused and add or update regression coverage for fixed bugs.
- Run `git diff --check` before handoff.
- Summarize behavior changes and list the exact validation commands that passed.
