# Change control dashboard

React (Vite) app for the **changes** / **change_reviews** / **change_tasks** tables. Uses Supabase Auth (`anon` key + RLS for `authenticated`).

## Prerequisite: database

1. Apply migrations in order (`008_change_control_tables.sql`, `009_change_tasks_add_task.sql`, `010_change_cancelled_status_and_cr_remark.sql`) via the Supabase SQL Editor or `supabase db push` from the diaryapp repo.
2. In Supabase **Authentication → Users** → **Add user**, create:
   - **Email:** `admin@change.local` (must match `src/config/dashboardAuth.ts`)
   - **Password:** `ravi1`
   - Or change both in `dashboardAuth.ts` and create the matching user in Supabase.

The login screen has **no sign-up** — only a **Sign in** button using those credentials.

### Layout

Left **sidebar**: **Home** (overview stats: changes / CTASKs / reviews / closed counts), **All changes** (list at `/changes`), **Raise change**, and **Sign out**. Main content on the right.

### Audit remarks & cancellation

- **Status remark** is required on status saves: **change** (inline + Edit change), **approver (CR)** page, and **CTASK** page.
- **Status history** on the change detail page aggregates transitions for the change, each approver, and each CTASK (prefixed in the list).
- Setting the **change** to **cancelled** updates every **change_reviews** and **change_tasks** row for that change to **cancelled**, using the same remark. A CTASK **rejected** flow that cancels the parent change does the same cascade.

### Change review status

After review: **change needed in that team** → keep **`requested`** and use **CTASK** (Cursor inserts both as needed). **No change needed** for that team → set **`approved`** on the team’s review page. DB default for new CRs is **`requested`**. You can still use **`implementing`** / **`rejected`** when they fit.

### Change review (per team)

From a change’s **Change reviews** table, click a row to open **`/changes/:id/review/:teamKey`** (team name is URL-encoded). Same boxed layout as the change screen: impact, justification, full discussion, doc updates, meta; **CTASKs** for that team only at the bottom when present. **Approved** reviews still show all stored text from `change_reviews`.

### Edit change

On a change detail page, **Edit change** opens `/changes/:id/edit` to update status, type, primary feature, affected features, short title, description, rollback plan, and **motive / discussed details** (same DB field `discussed_details`). `change_id` is read-only on edit.

Testers can **raise** a minimal change (title + description); you add technical fields later via **Edit change**.

### Change reviews & CTASKs

On a change **detail** page, **CTASK numbers** link to **`/changes/:id/ctask/:taskId`** where you can edit **`task`** (detailed instructions), **status** (default `pending`), and **status remark**. Saving updates `change_tasks` in Supabase.

**Rejecting a CTASK** (`status: rejected`) also sets the parent **change review** to `rejected` and, if the change is not already terminal, sets **`changes.status`** to `cancelled` with an appended **`status_history`** entry (CR + change stay in sync in the DB).

After saving a CTASK, that team’s **`change_reviews.status`** is set to **`implementing`** only when **every** CTASK for that review is **`approved`** or **`skipped`** (no **`pending`** left). Not applied if the CR is already **`rejected`**, **`approved`**, or **`cancelled`**.

Other CTASK fields and new rows remain **insert/update via Cursor / Supabase** as needed. You can still **update the parent change status** and remarks on the change detail page.

### Feature names (Raise change form)

Primary and affected features use the same catalog as `FEATURES CONTROL/feature-list.md`, duplicated in `src/data/appFeatures.ts`. When you add or rename features in the markdown, update that file too.

## Configure

```bash
cd change-dashboard
copy .env.example .env
```

Edit `.env`: set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` from **Project Settings → API** (same values as Flutter’s `SUPABASE_URL` / `SUPABASE_ANON_KEY`, but names **must** start with `VITE_`).

**Restart** `npm run dev` after creating or editing `.env` — Vite loads env only at startup.

## Run

```bash
npm install
npm run dev
```

Open **http://localhost:5174** (port set in `vite.config.ts`).

## Troubleshooting

### `401` on `/rest/v1/changes` (or `change_reviews` / `change_tasks`)

PostgREST returns **401** when the request is not authorized as an **authenticated** Supabase user:

1. **Sign in** on `/login` (dashboard uses fixed admin credentials; user must exist under **Authentication → Users** in the **same** project as `.env`).
2. **`change-dashboard/.env`** must use **`VITE_SUPABASE_URL`** and **`VITE_SUPABASE_ANON_KEY`** from **Project Settings → API** for **this** project (`…supabase.co`). Use the **anon** **public** key, not **service_role**. Values must match your Flutter `.env` project if you share one database.
3. **Restart** `npm run dev` after any `.env` change (Vite reads env only at startup).
4. **Migrations**: if tables are missing you may see different errors; apply `008`, `009`, `010` (see [Prerequisite: database](#prerequisite-database)).

### `404` in Network tab

Browsers often request **`/favicon.ico`**; the app uses an empty data-URI favicon to avoid that noise. Other 404s usually mean a wrong URL or a missing static file.

## Security

- Do **not** put the **service_role** key in this app.
- RLS on the three tables allows **authenticated** users full access; only your account should exist for a solo dashboard.

## Copy outside the Flutter repo

Copy the whole `change-dashboard` folder elsewhere if you prefer; keep `.env` local and never commit it.
