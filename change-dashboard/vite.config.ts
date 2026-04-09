import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
/** Diaryapp repo root (parent of `change-dashboard/`) */
const REPO_ROOT = path.resolve(__dirname, '..');
const CHANGE_BUILDING_ABS = path.join(REPO_ROOT, 'CHANGE-ACTIONS', 'change-building');

function saveChangeBuildingPlugin() {
  return {
    name: 'save-change-building',
    configureServer(server: { middlewares: { use: (fn: unknown) => void } }) {
      server.middlewares.use((req: { url?: string; method?: string; on: typeof import('node:events')['prototype']['on'] }, res: {
        statusCode: number;
        setHeader: (k: string, v: string) => void;
        end: (b?: string) => void;
      }, next: () => void) => {
        if (req.url !== '/__save-change-building' || req.method !== 'POST') {
          next();
          return;
        }
        let body = '';
        req.on('data', (c: Buffer | string) => {
          body += typeof c === 'string' ? c : c.toString();
        });
        req.on('end', () => {
          try {
            const parsed = JSON.parse(body) as { filename?: string; markdown?: string };
            const filename = parsed.filename;
            const markdown = parsed.markdown;
            if (typeof filename !== 'string' || typeof markdown !== 'string') {
              res.statusCode = 400;
              res.end('Expected JSON { filename, markdown }');
              return;
            }
            const base = path.basename(filename);
            if (!/^[A-Za-z0-9_-]+-change-building\.md$/.test(base)) {
              res.statusCode = 400;
              res.end('Invalid filename');
              return;
            }
            fs.mkdirSync(CHANGE_BUILDING_ABS, { recursive: true });
            const full = path.join(CHANGE_BUILDING_ABS, base);
            fs.writeFileSync(full, markdown, 'utf8');
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ ok: true, path: `CHANGE-ACTIONS/change-building/${base}` }));
          } catch (e) {
            res.statusCode = 500;
            res.end(e instanceof Error ? e.message : 'Write failed');
          }
        });
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), saveChangeBuildingPlugin()],
  server: { port: 5174 },
});
