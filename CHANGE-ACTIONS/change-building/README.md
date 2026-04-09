# change-building

Planning markdown exports for **change control**, written from the dashboard during **`changes.status` = `new`**.

## Repo location (permanent)

```
CHANGE-ACTIONS/change-building/{change_id}-change-building.md
```

Example: `CHG0000042-change-building.md`

## How files get here

1. **Local dev (recommended):** from `change-dashboard/`, run `npm run dev`. On **Save planning report**, Vite saves the file **directly into this folder** (see `change-dashboard/vite.config.ts` — `__save-change-building` middleware).

2. **Production / static hosting:** the app cannot write to your disk. The browser opens a **Save** dialog (File System Access API) or falls back to a normal **download**.

## Contents

See the generated file header and `change-dashboard/src/lib/changeBuildingReport.ts` — planning export is **only** the `changes` row + Cursor chat instructions.
