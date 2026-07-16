import { useState } from 'react'
import { api, type Paper } from '../api'

interface Props { papers: Paper[]; onRead: (id: string) => void; onRefresh: () => void }

const statusColors: Record<string,string> = { parsed: '#E8F5E9', translated: '#E3F2FD', error: '#FFEBEE', importing: '#FFF3E0', parsing: '#F3E5F5' };
const statusLabels: Record<string,string> = { parsed: '已解析', translated: '已翻译', error: '错误', importing: '导入中', parsing: '解析中' };

export default function LibraryPage({ papers, onRead, onRefresh }: Props) {
  const [filter, setFilter] = useState('all')
  const [selected, setSelected] = useState<Set<string>>(new Set())

  const toggle = (id: string) => {
    if (selected.size > 0) {
      const next = new Set(selected)
      if (next.has(id)) next.delete(id); else next.add(id)
      setSelected(next)
      return
    }
    onRead(id)
  }

  const filtered = filter === 'all' ? papers :
    filter === 'starred' ? papers.filter(p => p.starred) :
    papers.filter(p => p.status === filter)

  const sorted = [...filtered].sort((a,b) =>
    new Date(b.lastReadAt || b.importedAt || 0).getTime() - new Date(a.lastReadAt || a.importedAt || 0).getTime())

  const deleteSelected = async () => {
    for (const id of [...selected]) await api.deletePaper(id)
    setSelected(new Set())
    onRefresh()
  }

  return (
    <div className="p-8 max-w-3xl">
      <div className="flex items-center gap-4 mb-5">
        <h1 className="text-3xl font-bold">论文库</h1>
        {selected.size >= 2 && (
          <div className="flex items-center gap-2 px-4 py-2 rounded-xl bg-[var(--primary-light)] text-sm">
            <span>已选 {selected.size} 篇</span>
            <button onClick={deleteSelected} className="px-3 py-1 rounded-lg bg-red-100 text-red-700 text-xs cursor-pointer">删除</button>
            <button onClick={() => setSelected(new Set())} className="px-3 py-1 text-xs cursor-pointer">取消</button>
          </div>
        )}
      </div>
      <div className="flex gap-2 mb-4 flex-wrap">
        {['all','starred','parsed','translated'].map(f => (
          <button key={f} onClick={() => { setFilter(f); setSelected(new Set()) }}
            className={`px-3 py-1.5 rounded-full text-xs cursor-pointer border
              ${filter === f ? 'bg-[var(--primary-light)] text-[var(--primary)] border-[var(--primary)]' : 'border-[var(--outline-variant)] text-[var(--on-surface-variant)]'}`}>
            {f === 'all' ? '全部' : f === 'starred' ? '⭐ 星标' : f === 'parsed' ? '已解析' : '已翻译'}
          </button>
        ))}
      </div>
      {sorted.length === 0 && <div className="text-center py-16 text-[var(--on-surface-variant)]">📚<p className="mt-2">没有论文</p></div>}
      {sorted.map(p => {
        const sel = selected.has(p.id)
        return (
          <div key={p.id} onClick={() => toggle(p.id)}
            className={`rounded-xl p-4 mb-2 cursor-pointer transition-all border
              ${sel ? 'bg-[var(--primary-light)] border-[var(--primary)]' : 'bg-[var(--card-bg)] border-transparent hover:shadow-sm hover:border-[var(--outline-variant)]'}`}>
            <div className="font-semibold text-base mb-1 leading-snug">
              {p.title} {p.starred && <span className="text-amber-500">⭐</span>}
            </div>
            {p.authors?.length > 0 && <div className="text-xs text-[var(--on-surface-variant)] mb-2">{p.authors.join(', ')}</div>}
            <div className="flex gap-2 items-center text-[11px]">
              <span className="px-2 py-0.5 rounded text-[11px] font-medium" style={{background: statusColors[p.status] || '#eee'}}>
                {statusLabels[p.status] || p.status}
              </span>
              <span className="text-[var(--on-surface-variant)] opacity-70">{timeAgo(p.lastReadAt || p.importedAt)}</span>
              {p.pageCount > 0 && <span className="text-[var(--on-surface-variant)] opacity-70">{p.pageCount} 页</span>}
            </div>
          </div>
        )
      })}
    </div>
  )
}

function timeAgo(d: string) {
  if (!d) return ''
  const diff = Date.now() - new Date(d).getTime()
  if (diff < 60000) return '刚刚'
  if (diff < 3600000) return `${Math.floor(diff/60000)} 分钟前`
  if (diff < 86400000) return `${Math.floor(diff/3600000)} 小时前`
  return `${Math.floor(diff/86400000)} 天前`
}
