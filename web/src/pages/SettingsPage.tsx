import { useState, useEffect } from 'react'
import { api } from '../api'

const themes = [
  { id: 'alice', color: '#5C2D91', label: '爱丽丝' },
  { id: 'blue', color: '#415F91', label: '蓝色' },
  { id: 'cyan', color: '#00897B', label: '青色' },
  { id: 'green', color: '#43A047', label: '绿色' },
  { id: 'orange', color: '#E65100', label: '橙色' },
  { id: 'red', color: '#D81B60', label: '红色' },
  { id: 'black', color: '#424242', label: '黑色' },
]

export default function SettingsPage() {
  const [cfg, setCfg] = useState<any>(null)

  useEffect(() => { api.getConfig().then(setCfg).catch(() => {}) }, [])

  return (
    <div className="p-8 max-w-3xl">
      <h1 className="text-3xl font-bold mb-6">设置</h1>

      {/* 外观 */}
      <Section title="外观">
        <label className="text-xs text-[var(--on-surface-variant)] mb-2 block">主题色</label>
        <div className="flex gap-3 flex-wrap mb-4">
          {themes.map(t => (
            <div key={t.id}
              className="w-12 h-12 rounded-xl cursor-pointer border-2 transition-all"
              style={{ background: t.color, borderColor: cfg?.themeVariant === t.id ? 'var(--primary)' : 'transparent' }}
              onClick={() => api.getConfig().then(() => {})} />
          ))}
        </div>
      </Section>

      {/* LLM 配置 */}
      <Section title="LLM 配置">
        <p className="text-xs text-[var(--on-surface-variant)] mb-3">支持 OpenAI 兼容 API</p>
        <label className="text-xs text-[var(--on-surface-variant)]">API Key</label>
        <input type="password" className="w-full p-2.5 rounded-lg border border-[var(--outline)] bg-[var(--surface)] text-sm mb-3" placeholder="在 CLI 中配置" />
        <label className="text-xs text-[var(--on-surface-variant)]">API Base</label>
        <input type="text" className="w-full p-2.5 rounded-lg border border-[var(--outline)] bg-[var(--surface)] text-sm mb-3"
          defaultValue={cfg?.llmApiBase || 'https://api.deepseek.com'} />
      </Section>

      {/* 关于 */}
      <Section title="关于">
        <p className="text-sm">PaperPal v0.5.0</p>
        <p className="text-xs text-[var(--on-surface-variant)] mt-1">基于 Kori 设计 · AI 论文阅读伴侣</p>
      </Section>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mb-6">
      <h3 className="text-[11px] tracking-wider font-semibold text-[var(--primary)] mb-2 uppercase">{title}</h3>
      <div className="bg-[var(--card-bg)] rounded-2xl p-5">{children}</div>
    </div>
  )
}
