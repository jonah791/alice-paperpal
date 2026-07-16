import { useState, useEffect, useRef } from 'react'
import { api } from '../api'
import { marked } from 'marked'

interface Props { paperId: string; onBack: () => void }

export default function ReadPage({ paperId, onBack }: Props) {
  const [title, setTitle] = useState('')
  const [content, setContent] = useState('')
  const [translation, setTranslation] = useState<string | null>(null)
  const [showTrans, setShowTrans] = useState(true)
  const [starred, setStarred] = useState(false)
  const [html, setHtml] = useState('')
  const contentRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    api.getPaper(paperId).then(p => { setTitle(p.title); setStarred(p.starred) })
    api.getContent(paperId).then(r => setContent(r.content || ''))
    api.getTranslation(paperId).then(r => { if (r.translation) setTranslation(r.translation) })
  }, [paperId])

  useEffect(() => {
    const text = showTrans ? (translation || content) : content
    if (text) {
      Promise.resolve(marked.parse(text, { breaks: true })).then(h => setHtml(h))
    }
  }, [content, translation, showTrans])

  return (
    <main className="flex-1 overflow-y-auto">
      <div className="max-w-3xl mx-auto px-8 py-6">
        <button onClick={onBack} className="text-sm text-[var(--primary)] mb-4 cursor-pointer hover:underline">← 返回文库</button>
        <div className="flex items-center gap-3 mb-6">
          <h1 className="flex-1 text-xl font-semibold">{title}</h1>
          <button onClick={async () => { const r = await api.toggleStar(paperId); setStarred(r.starred) }}
            className="text-lg cursor-pointer bg-none border-none">{starred ? '⭐' : '☆'}</button>
          {translation && (
            <button onClick={() => setShowTrans(!showTrans)}
              className="px-3 py-1 rounded-full text-xs bg-[var(--primary-light)] text-[var(--primary)] cursor-pointer border-none">
              {showTrans ? '原文' : '🌐 译文'}
            </button>
          )}
          <button onClick={async () => {
            try { const r = await api.summarize(paperId); alert(r.summary) }
            catch { alert('摘要生成失败') }
          }} className="px-3 py-1 rounded-full text-xs bg-[var(--primary-light)] text-[var(--primary)] cursor-pointer border-none">📋 摘要</button>
        </div>
        <div ref={contentRef} className="leading-[1.8] text-base"
          dangerouslySetInnerHTML={{ __html: html }} />
      </div>
    </main>
  )
}
