# Table: `change_reviews` — field names and one-line descriptions

| Field name | One-line description |
|------------|----------------------|
| `id` | UUID primary key. |
| `change_id` | FK → `changes.id` (which change this review belongs to). |
| `team_key` | Stable id for the team/feature (e.g. `notifications`; matches `feature-list`). |
| `status` | See **Review status** below. |
| `status_remark` | **Required on dashboard save** — audit note for the latest approver status transition. |
| `impact_summary` | Short: affected areas, risk level, SAFE / NEEDS ATTENTION / BREAKS style. |
| `justification` | Narrative: approve/reject reason, conflicts, blockers, exact reasons when rejecting. |
| `conflict` | Whether this review flags conflict with another team or shared code (boolean). |
| `full_discussion` | Long text or JSON: full report, edge cases, files touched, all discussed details. |
| `doc_updates_suggested` | Optional text/JSON: doc deltas to apply after implementation. |
| `reviewed_at` | When this review row was last submitted or materially updated. |
| `created_at` | When the review row was created. |
| `updated_at` | Last update to this row. |

**Uniqueness (recommended):** one row per `(change_id, team_key)` so each team has a single active review per change.

---

## Review `status` (values and meaning)

### Decision workflow (how we use it)

After the review for a team is done:

| Situation | Set CR status | CTASK |
|-----------|-----------------|--------|
| **Change is needed** in that team’s code | **`requested`** (track follow-up work) | Yes — add **CTASK** row(s) for that review. |
| **No change needed** in that team | **`approved`** | None, or CTASK **`skipped`** if you recorded a task then decided no work. |

Cursor typically inserts the CR as **`requested`** first; you move it to **`approved`** when that team has nothing to do, or keep **`requested`** while CTASKs are open, then **`implementing`** / **`approved`** as you prefer when work finishes. **`rejected`** if that team blocks the change.

---

| Value | Meaning |
|-------|--------|
| `requested` | Work may still be needed for this team; often used together with **CTASK** until resolved. |
| `implementing` | Optional — work in progress for this team’s scope after review. |
| `rejected` | Team rejects the change; align parent **`changes.status`** / process. |
| `approved` | No further change needed from this team (or CTASKs resolved / skipped). |
| `cancelled` | No longer active (e.g. parent **change** was cancelled — all approver rows under that change are set to **`cancelled`** together). |

**Relation to `change_tasks`:** CTASK rows use `change_review_id`; CTASK `status` values are in `change-task-feilds.md`.
