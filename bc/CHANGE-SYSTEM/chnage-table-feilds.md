# Table: `changes` — field names and one-line descriptions

| Field name | One-line description |
|------------|----------------------|
| `id` | UUID primary key (internal). |
| `change_id` | Human-readable id shown on dashboard, e.g. `CHG0000001`. |
| `created_at` | When the change record was created (server timestamp). |
| `updated_at` | Last update to this row (any field or status). |
| `status` | Lifecycle: `new`, `started`, `closed`, `cancelled`, `rollbacked`. |
| `status_remark` | Latest remark for the current or last status transition (short). |
| `status_history` | JSON array of steps: from/to status, remark, timestamp (full audit trail). |
| `type` | Change type: fix, add, remove, refactor, other (align with CR template). |
| `primary_feature` | Main feature or area driving this change (single label). |
| `feature_names` | All features/teams in scope: JSON array of strings or `text[]`. |
| `short_description` | One-line summary for lists and cards. |
| `description` | Full description of the change (what/why). |
| `rollback_plan` | How to revert or mitigate if the change fails. |
| `discussed_details` | Free text or JSON blob for meeting notes, decisions, links, CAB discussion. |
| `created_by` | Who raised the change (user id or email; optional until auth wired). |
| `closed_at` | When terminal success (`closed`) was recorded (nullable). |

**Status notes (serial / terminal):** Use `new` → `started` → work → `closed` on success; use `cancelled` or `rollbacked` as terminal outcomes with remarks in `status_history`.
