# Table: `change_tasks` (CTASK) — field names and one-line descriptions

| Field name | One-line description |
|------------|----------------------|
| `id` | UUID primary key. |
| `change_id` | FK → `changes.id` (denormalized for dashboard filters). |
| `change_review_id` | FK → `change_reviews.id` (which team raised this CTASK). |
| `ctask_number` | Human-readable id, e.g. `CTASK000001`. |
| `motive` | Why this isolated task exists (scope, blast radius, team-only change). |
| `task` | Detailed instructions to perform this CTASK (steps, files, acceptance criteria). |
| `status` | See **CTASK status** below. |
| `status_remark` | **Required on dashboard save** — audit note for the latest status transition. |
| `created_at` | When the CTASK row was created. |
| `updated_at` | Last update to this row. |

---

## CTASK `status` (values and meaning)

| Value | Meaning |
|-------|--------|
| `pending` | Waiting on dashboard decision (or implementation) for this CTASK. |
| `approved` | You approved this CTASK on the dashboard; proceed per policy. |
| `rejected` | You rejected this CTASK on the dashboard. |
| `skipped` | You reviewed: **no change needed** for this team’s CTASK; treat parent **change_review** as **`approved`** from their side (no work in that team). |
| `cancelled` | No longer active (e.g. parent **change** was cancelled — all CTASKs under that change are set to **`cancelled`** together). |

**Cardinality:** 0..N CTASKs per `change_review`; if none and team has no impact, reviews can go straight to **`approved`** without CTASK rows.
