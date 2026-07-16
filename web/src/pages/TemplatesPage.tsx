import { useState, useEffect } from 'react'
import { api, type Template } from '../api'

export default function TemplatesPage() {
  const [templates, setTemplates] = useState<Template[]>([])

  useEffect(() => { api.listTemplates().then(setTemplates).catch(() => {}) }, [])

  return (
    <div className="p-8 max-w-3xl">
      <h1 className="text-3xl font-bold mb-6">笔记模板</h1>
      {templates.map(t => (
        <div key={t.id} onClick={() => alert(t.markdown)}
          className="flex items-center gap-3 bg-[var(--card-bg)] rounded-xl p-4 mb-2 cursor-pointer hover:shadow-sm transition-shadow">
          <span className="text-2xl w-10 text-center">{t.isBuiltin ? '✨' : '👤'}</span>
          <div>
            <div className="font-semibold text-sm">{t.name}</div>
            <div className="text-xs text-[var(--on-surface-variant)]">{t.description}</div>
          </div>
        </div>
      ))}
    </div>
  )
}
