# Change building — open change export (`new`)

> **Save in repo:** `CHANGE-ACTIONS/change-building/CHG0000011-change-building.md`
> **Download filename:** `CHG0000011-change-building.md`

| Meta | Value |
| --- | --- |
| Generated at (UTC) | 2026-04-07T21:06:58.631Z |
| `changes.id` (UUID) | `783c6a4e-4cec-477f-ba3d-da191c514d4e` |
| `change_id` | `CHG0000011` |
| **Status** | **new** — export includes **full `changes` row**, **discussion journal** (time order), **status audit timeline**, **approvers**, **CTASKs**. |
| **Discussion notes** | 0 entries in `discussion_log` |

---

## Discussion journal (`discussion_log`)

*No `discussion_log` entries yet. Add them from the change **detail** page → **Discussion** → **Append note** (newest at top in the UI; this export lists **oldest first**).*

> **Why 0 entries?** You have text in `discussed_details` (see **Current row** below), but **`discussion_log`** is still empty. They are different columns: threaded notes come only from the change **detail** page → **Discussion** → **Append note**. **Edit change** updates `discussed_details`, not `discussion_log`.



---

## Status & audit timeline (oldest → newest)

**Status transitions** from `status_history` on the change, approvers, and CTASKs — merged by `at`. Does **not** repeat `discussion_log` (see **Discussion journal**).

---

### 1. 2026-04-07T20:58:31.123Z

**[Record]** Change row created (`change_id` = `CHG0000011`).

_`2026-04-07T20:58:31.123736+00:00`_


---

## Supabase table: `public.changes` (schema reference)

All columns on the change row. Check constraints in migrations `008`+.

| Column | Type / notes |
| --- | --- |
| `id` | UUID PK |
| `change_id` | text, unique human id (e.g. CHG…) |
| `status` | Allowed: `new`, `started`, `closed`, `cancelled`, `rollbacked`, `rejected` |
| `type` | Allowed: `fix`, `add`, `remove`, `refactor`, `other` |
| `primary_feature` | text, nullable |
| `feature_names` | jsonb array of strings |
| `short_description` | text |
| `description` | text |
| `rollback_plan` | text, nullable |
| `discussed_details` | text, nullable |
| `discussion_log` | jsonb — thread `{ at, body, author? }` (dashboard stores **newest first**) |
| `status_remark` | text, nullable |
| `status_history` | jsonb audit array |
| `final_state_note` | text — required when status is terminal |
| `created_by` | text, nullable |
| `created_at` / `updated_at` / `closed_at` | timestamptz |

### What can be updated (and where)

| Column | How to update |
| --- | --- |
| `id`, `change_id` | **Do not change** — identity (human `change_id` is read-only on **Edit change**). |
| `created_at`, `created_by` | Set at insert; normally **read-only**. |
| `updated_at` | **DB trigger** on update. |
| `type`, `primary_feature`, `feature_names`, `short_description`, `description`, `rollback_plan`, `discussed_details` | Dashboard **Edit change** (or SQL / MCP). |
| `discussion_log` | Dashboard **Discussion** on change detail (append note); or SQL with full JSON array. |
| `status`, `status_remark`, `status_history`, `final_state_note`, `closed_at` | Dashboard **Update change status** on detail — follows workflow rules (remarks, terminal notes). |

Related tables: `change_reviews` (approvers), `change_tasks` (CTASKs) — full snapshots below when you export from this page.

---

## Feature docs (check in chat before expanding scope)

- Catalog: `FEATURES CONTROL/feature-list.md`
- Per-feature: `bc/CHANGE-SYSTEM/features-docs/`

**Primary** and **possibly affected** features may be *(empty / unknown)* until you agree in chat.

---

## Primary feature (user intent)

**Bottom Navigation**

---

## Possibly affected features (`feature_names`)

*(empty / unknown — discuss in chat)*

---

## Current row — all `changes` values (snapshot)

| Column | Value |
| --- | --- |
| `id` | `783c6a4e-4cec-477f-ba3d-da191c514d4e` |
| `change_id` | CHG0000011 |
| `status` | new |
| `type` | refactor |
| `primary_feature` | Bottom Navigation |
| `created_at` | 2026-04-07T20:58:31.123736+00:00 |
| `updated_at` | 2026-04-07T21:03:07.881933+00:00 |
| `created_by` | admin@change.local |
| `closed_at` | *(empty / unknown)* |
| `status_remark` | *(empty / unknown)* |
| `final_state_note` | *(empty / unknown)* |
| `discussion_log` | 0 note(s) — see **Discussion journal** for time-ordered text; JSON below for exact storage. |

### `short_description`

```text
I need one more button for premium feature in bottom nav bar
```


### `description`

```text
I need one more button for premium feature in bottom nav barI need one more button for premium feature in bottom nav barI need one more button for premium feature in bottom nav bar
```


### `rollback_plan`

```text
*(empty / unknown)*
```


### `discussed_details`

```text
I need one more button for premium feature in bottom nav bar
```


**`discussion_log` (JSON, as stored — newest first in array)**

```json
[]
```

**`discussion_log` (JSON, chronological — oldest first; same data, sorted for reading)**

```json
[]
```

**`feature_names` (JSON)**

```json
[]
```

**`status_history` (JSON)**

```json
[]
```

---

## Approvers (`change_reviews`) — full detail

*No approver rows loaded (empty in dashboard / not created yet).*

---

## CTASKs (`change_tasks`) — full detail

*No CTASK rows loaded.*

---

## Cursor — workflow prompt (read this file @-tagged)

**Ground rules:** Do not invent DB columns or skip RLS. Prefer updating via the change dashboard when possible.

### Phase 1 — Discuss the change first (required detail)

1. Read **Discussion journal** and **Status & audit timeline** for context already captured.
2. With the user, confirm **scope**, **risk**, **rollback** (align with `rollback_plan` and `description`), and what “done” means.
3. If anything is unclear, ask before proposing schema or code changes.

### Phase 2 — Primary feature & affected features

1. Using `FEATURES CONTROL/feature-list.md` and `bc/CHANGE-SYSTEM/features-docs/`, propose the **single best** `primary_feature` for this change.
2. List **every feature** that might be touched (UI, data, edge functions, notifications, etc.) as `feature_names` — be inclusive; narrow later if needed.
3. If you are **unsure** which owning teams or boundaries apply, say so explicitly: **we will run change review (CR)** once **approver teams** exist on this change — do not pretend scope is settled.

### Phase 3 — After approver teams / CR rows exist

1. When `change_reviews` (and CTASKs) are added, treat CR outcomes as authoritative for multi-team alignment.
2. **Update the discussion journal:** add a short `discussion_log` note summarizing decisions (who agreed, what changed, links to CR/CTASK). Keeps this export self-contained next time.

### Phase 4 — Persist

1. Update `changes` for `id` = `783c6a4e-4cec-477f-ba3d-da191c514d4e` (or **Edit change** / **Discussion** / status UI). See **What can be updated** above.
2. Approver and CTASK sections in this file reflect what was loaded at export time — refresh the export after major updates.

### File convention

- Repo: **`CHANGE-ACTIONS/change-building/CHG0000011-change-building.md`**
- Name: **`CHG0000011-change-building.md`**

---

*End of open change export.*
