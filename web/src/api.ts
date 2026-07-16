/// API 客户端 — 对接 PaperPal 后端
const BASE = '';

export interface Paper {
  id: string; title: string; authors: string[]; year: number;
  source: string; doi: string; status: string; starred: boolean;
  pageCount: number; importedAt: string; lastReadAt: string;
}

export interface SearchResult {
  title: string; authors: string[]; year: number;
  abstract: string; pdfUrl: string; source: string; citationCount: number;
}

export interface Note {
  id: string; paperId: string; text: string; createdAt: string; type: string;
}

export interface Soul {
  id: string; name: string; description: string; traits: string[];
  style: string; specialty: string; isBuiltin: boolean;
}

export interface Template {
  id: string; name: string; description: string; markdown: string; isBuiltin: boolean;
}

async function req<T>(method: string, path: string, body?: unknown): Promise<T> {
  const opts: RequestInit = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  const r = await fetch(BASE + path, opts);
  if (!r.ok) { const t = await r.text(); throw new Error(t); }
  return r.json();
}

export const api = {
  // Health
  health: () => req<{status:string}>('GET', '/health'),

  // Papers
  listPapers: () => req<Paper[]>('GET', '/papers'),
  getPaper: (id: string) => req<Paper>('GET', `/papers/${id}`),
  deletePaper: (id: string) => req<{deleted:boolean}>('DELETE', `/papers/${id}`),
  toggleStar: (id: string) => req<{starred:boolean}>('PUT', `/papers/${id}/star`),
  getContent: (id: string) => req<{content:string}>('GET', `/papers/${id}/content`),
  getTranslation: (id: string) => req<{translation:string}>('GET', `/papers/${id}/translation`),

  // Search
  search: (q: string) => req<SearchResult[]>('POST', '/search', { query: q }),
  importSearch: (r: SearchResult) => req<Paper>('POST', '/import/search', r),

  // AI
  summarize: (id: string) => req<{summary:string}>('POST', `/summarize/${id}`),
  ask: (id: string, question: string) => req<{answer:string}>('POST', `/ask/${id}/sync`, { question }),

  // Notes
  listNotes: (paperId: string) => req<Note[]>('GET', `/notes/${paperId}`),
  addNote: (paperId: string, text: string) => req<{created:boolean}>('POST', `/notes/${paperId}`, { text }),
  deleteNote: (noteId: string) => req<{deleted:boolean}>('DELETE', `/notes/${noteId}`),

  // Souls
  listSouls: () => req<{active:Soul;presets:Soul[];custom:Soul[]}>('GET', '/souls'),
  setActiveSoul: (id: string) => req<{active:string}>('PUT', '/souls/active', { id }),

  // Config
  getConfig: () => req<any>('GET', '/config'),

  // Templates
  listTemplates: () => req<Template[]>('GET', '/templates'),
};
