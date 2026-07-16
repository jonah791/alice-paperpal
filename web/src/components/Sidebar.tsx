import type { Paper } from '../api'

interface Props { page: string; papers: Paper[]; onNavigate: (p: string) => void; isDark: boolean; onToggleDark: () => void }

export default function Sidebar({ page, papers, onNavigate, isDark, onToggleDark }: Props) {
  const items = [
    { key: 'search', icon: '🔍', label: '搜索', count: undefined },
    { key: 'library', icon: '📚', label: '文库', count: papers.length },
    { key: 'templates', icon: '📝', label: '模板', count: undefined },
    { key: 'settings', icon: '⚙️', label: '设置', count: undefined },
  ];

  return (
    <aside className="w-[280px] bg-[var(--sidebar)] flex flex-col shrink-0 border-r border-[var(--outline-variant)]">
      <div className="h-14 px-4 flex items-center gap-3">
        <div className="w-8 h-8 rounded-full bg-[var(--primary-light)] flex items-center justify-center text-sm font-bold text-[var(--primary)]">P</div>
        <span className="flex-1 text-base font-semibold">PaperPal</span>
        <button onClick={onToggleDark} className="text-lg p-1 rounded hover:bg-[var(--surface-container)] cursor-pointer" title="切换主题">
          {isDark ? '☀️' : '🌙'}
        </button>
      </div>
      <nav className="px-2 flex flex-col gap-1">
        {items.map(item => (
          <button key={item.key} onClick={() => onNavigate(item.key)}
            className={`h-[52px] px-4 flex items-center gap-3 rounded-xl text-sm font-medium cursor-pointer transition-colors
              ${page === item.key ? 'bg-[var(--primary-light)] text-[var(--primary)] font-semibold' : 'hover:bg-[var(--surface-container)]'}`}>
            <span className="text-xl w-6 text-center">{item.icon}</span>
            <span>{item.label}</span>
            {item.count !== undefined && item.count > 0 &&
              <span className="ml-auto bg-[var(--primary-light)] text-[var(--primary)] px-2 py-0.5 rounded-full text-[11px] font-semibold">{item.count}</span>}
          </button>
        ))}
      </nav>
      <div className="mt-auto p-4 text-[10px] text-[var(--on-surface-variant)] opacity-50">PaperPal v0.5.0</div>
    </aside>
  );
}
