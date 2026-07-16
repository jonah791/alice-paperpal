import { useState, useEffect } from 'react'
import { api, type Paper } from './api'
import Sidebar from './components/Sidebar'
import SearchPage from './pages/SearchPage'
import LibraryPage from './pages/LibraryPage'
import ReadPage from './pages/ReadPage'
import TemplatesPage from './pages/TemplatesPage'
import SettingsPage from './pages/SettingsPage'

type Page = 'library' | 'search' | 'read' | 'templates' | 'settings'

export default function App() {
  const [page, setPage] = useState<Page>('library')
  const [papers, setPapers] = useState<Paper[]>([])
  const [currentPaperId, setCurrentPaperId] = useState<string | null>(null)
  const [isDark, setIsDark] = useState(() => matchMedia('(prefers-color-scheme: dark)').matches)

  useEffect(() => { document.documentElement.classList.toggle('dark', isDark) }, [isDark])
  useEffect(() => { api.listPapers().then(setPapers).catch(() => {}) }, [])

  const refreshPapers = () => api.listPapers().then(setPapers).catch(() => {})

  const goTo = (p: string, paperId?: string) => {
    setPage(p as Page)
    if (paperId) setCurrentPaperId(paperId)
  }

  if (page === 'read' && currentPaperId) {
    return (
      <div className="flex h-screen">
        <Sidebar page={page} papers={papers} onNavigate={goTo} isDark={isDark} onToggleDark={() => setIsDark(!isDark)} />
        <ReadPage paperId={currentPaperId} onBack={() => goTo('library')} />
      </div>
    )
  }

  return (
    <div className="flex h-screen">
      <Sidebar page={page} papers={papers} onNavigate={goTo} isDark={isDark} onToggleDark={() => setIsDark(!isDark)} />
      <main className="flex-1 overflow-y-auto">
        {page === 'search' && <SearchPage onImport={() => { goTo('library'); refreshPapers() }} />}
        {page === 'library' && <LibraryPage papers={papers} onRead={(id) => goTo('read', id)} onRefresh={refreshPapers} />}
        {page === 'templates' && <TemplatesPage />}
        {page === 'settings' && <SettingsPage />}
      </main>
    </div>
  )
}
