import { useState } from 'react'
import { api, type SearchResult } from '../api'

interface Props { onImport: () => void }

export default function SearchPage({ onImport }: Props) {
  const [q, setQ] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')

  const doSearch = async () => {
    if (!q.trim()) return
    setLoading(true); setMsg('')
    try {
      const r = await api.search(q)
      setResults(r)
      if (r.length === 0) setMsg('没有结果')
    } catch { setMsg('搜索失败，请检查 API Key') }
    finally { setLoading(false) }
  }

  const importResult = async (r: SearchResult) => {
    try { await api.importSearch(r); onImport() }
    catch { setMsg('导入失败') }
  }

  return (
    <div className="p-8 max-w-3xl">
      <h1 className="text-3xl font-bold mb-6">搜索论文</h1>
      <div className="flex gap-2 mb-3">
        <input value={q} onChange={e => setQ(e.target.value)} onKeyDown={e => e.key === 'Enter' && doSearch()}
          placeholder="搜索 arXiv + Semantic Scholar..."
          className="flex-1 h-12 px-4 rounded-full border border-[var(--outline)] bg-[var(--surface-container-low)] text-sm outline-none focus:border-[var(--primary)]" />
        <button onClick={doSearch} disabled={loading}
          className="px-6 rounded-full bg-[var(--primary)] text-white text-sm font-medium cursor-pointer disabled:opacity-50">
          {loading ? '...' : '搜索'}
        </button>
      </div>
      {msg && <p className="text-center py-10 text-[var(--on-surface-variant)]">{msg}</p>}
      {results.map((r, i) => (
        <div key={i} onClick={() => importResult(r)}
          className="bg-[var(--card-bg)] rounded-xl p-4 mb-2 cursor-pointer hover:shadow-sm border border-transparent hover:border-[var(--outline-variant)] transition-all">
          <div className="font-semibold text-base mb-1 leading-snug">{r.title}</div>
          {r.authors.length > 0 && <div className="text-xs text-[var(--on-surface-variant)] mb-2">{r.authors.join(', ')}</div>}
          <div className="flex gap-2 items-center text-[11px]">
            {r.year > 0 && <span>{r.year}</span>}
            <span className="px-2 py-0.5 rounded bg-[var(--primary-light)] text-[var(--primary)] text-[11px] font-medium">{r.source}</span>
            {r.citationCount > 0 && <span className="text-[var(--on-surface-variant)]">{r.citationCount} 引用</span>}
          </div>
          {r.abstract && <p className="text-xs text-[var(--on-surface-variant)] mt-2 leading-relaxed line-clamp-3">{r.abstract}</p>}
        </div>
      ))}
    </div>
  )
}
