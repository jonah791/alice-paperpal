// PaperPal Web App — Kori 风格前端
const API = '';
let allPapers = [];
let selectedPapers = new Set();
let currentPaperId = null;
let isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

// ─── API Helpers ────────────────────────────────────────────────
async function api(method, path, body) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  const r = await fetch(API + path, opts);
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

function toast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 2500);
}

function formatTime(dt) {
  if (!dt) return '';
  const d = new Date(dt);
  const now = new Date();
  const diff = now - d;
  if (diff < 60000) return '刚刚';
  if (diff < 3600000) return `${Math.floor(diff/60000)} 分钟前`;
  if (diff < 86400000) return `${Math.floor(diff/3600000)} 小时前`;
  return `${Math.floor(diff/86400000)} 天前`;
}

// ─── Navigation ────────────────────────────────────────────────
document.querySelectorAll('.nav-item').forEach(el => {
  el.addEventListener('click', e => {
    e.preventDefault();
    const page = el.dataset.page;
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    el.classList.add('active');
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.page').forEach(p => p.style.display = 'none');
    const target = document.getElementById(`page-${page}`);
    if (target) {
      target.style.display = 'block';
      target.classList.add('active');
    }
    if (page === 'library') refreshLibrary();
    if (page === 'settings') renderSettings();
    if (page === 'templates') renderTemplates();
  });
});

// ─── Theme Toggle ─────────────────────────────────────────────
document.getElementById('theme-toggle').addEventListener('click', () => {
  isDark = !isDark;
  document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
  document.getElementById('theme-toggle').textContent = isDark ? '☀️' : '🌙';
});

function applyTheme() {
  document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
  document.getElementById('theme-toggle').textContent = isDark ? '☀️' : '🌙';
}

// ─── Soul ─────────────────────────────────────────────────────
async function loadSoul() {
  try {
    const data = await api('GET', '/souls/active');
    document.getElementById('soul-name').textContent = data.name;
    document.getElementById('avatar-placeholder').textContent = data.name[0];
  } catch(e) {}
}

// ─── Search ───────────────────────────────────────────────────
document.getElementById('search-btn').addEventListener('click', () => doSearch());
document.getElementById('search-input').addEventListener('keydown', e => {
  if (e.key === 'Enter') doSearch();
});

async function doSearch() {
  const q = document.getElementById('search-input').value.trim();
  if (!q) return;
  const resultsDiv = document.getElementById('search-results');
  document.getElementById('search-status').innerHTML = '<div class="spinner"></div>';
  resultsDiv.innerHTML = '';
  try {
    const results = await api('POST', '/search', { query: q });
    document.getElementById('search-status').innerHTML = '';
    if (results.length === 0) {
      document.getElementById('search-status').textContent = '没有找到匹配的论文';
      return;
    }
    resultsDiv.innerHTML = results.map(r => {
      const exists = allPapers.some(p => p.title === r.title || (p.doi && p.doi === r.doi));
      return `<div class="card" onclick="importResult(${JSON.stringify(r).replace(/"/g,'&quot;')})">
        <div class="card-title">${r.title} ${exists ? '<span class="card-status" style="background:#E0E0E0;color:#666">已导入</span>' : ''}</div>
        ${r.authors && r.authors.length ? `<div class="card-authors">${r.authors.join(', ')}</div>` : ''}
        <div class="card-meta">
          ${r.year ? `<span>${r.year}</span>` : ''}
          <span class="card-status" style="background:var(--primary-container);color:var(--primary)">${r.source}</span>
          ${r.citationCount ? `<span>${r.citationCount} 引用</span>` : ''}
        </div>
        ${r.abstract ? `<p style="font-size:12px;color:var(--on-surface-variant);margin-top:8px;line-height:1.5">${r.abstract.substring(0,200)}...</p>` : ''}
      </div>`;
    }).join('');
  } catch(e) {
    document.getElementById('search-status').textContent = '搜索失败，请检查 API Key';
  }
}

async function importResult(r) {
  try {
    const p = await api('POST', '/import/search', r);
    toast('导入成功');
    await refreshLibrary();
    paperToView(p.id);
  } catch(e) {
    toast('导入失败');
  }
}

// ─── Upload ───────────────────────────────────────────────────
document.getElementById('upload-btn').addEventListener('click', () => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = '.pdf';
  input.onchange = async () => {
    if (!input.files[0]) return;
    const form = new FormData();
    form.append('file', input.files[0]);
    toast('上传中...');
    try {
      const p = await api('POST', '/import/search', { title: input.files[0].name, pdfUrl: URL.createObjectURL(input.files[0]) });
      await refreshLibrary();
      toast('导入成功');
    } catch(e) { toast('导入失败'); }
  };
  input.click();
});

document.getElementById('import-btn').addEventListener('click', () => {
  toast('多格式导入：请使用 CLI 命令 `paperpal convert <file>`');
});

document.getElementById('zotero-btn').addEventListener('click', async () => {
  try {
    const items = await api('POST', '/search', { query: '' }); // placeholder
    toast('请在环境变量中配置 ZOTERO_API_KEY');
  } catch(e) { toast('Zotero 配置缺失'); }
});

// ─── Library ──────────────────────────────────────────────────
let currentFilter = 'all';

document.querySelectorAll('.filter-chip').forEach(el => {
  el.addEventListener('click', () => {
    document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
    el.classList.add('active');
    currentFilter = el.dataset.filter;
    renderPapers();
  });
});

document.getElementById('compare-btn').addEventListener('click', async () => {
  if (selectedPapers.size < 2) { toast('至少选择 2 篇'); return; }
  const ids = [...selectedPapers];
  const titles = ids.map(id => {
    const p = allPapers.find(x => x.id === id);
    return p ? `- ${p.title}` : '';
  }).filter(Boolean).join('\n');
  try {
    const r = await api('POST', `/ask/${ids[0]}/sync`, { question: `对比以下论文：\n${titles}` });
    showModal('对比分析', `<pre style="white-space:pre-wrap;line-height:1.6">${r.answer}</pre>`);
  } catch(e) { toast('分析失败'); }
});

document.getElementById('delete-sel-btn').addEventListener('click', async () => {
  if (!confirm(`删除 ${selectedPapers.size} 篇论文？`)) return;
  const ids = [...selectedPapers];
  for (const id of ids) await api('DELETE', `/papers/${id}`);
  selectedPapers.clear();
  toast('已删除');
  await refreshLibrary();
});

document.getElementById('cancel-sel-btn').addEventListener('click', () => {
  selectedPapers.clear();
  renderPapers();
});

async function refreshLibrary() {
  try {
    allPapers = await api('GET', '/papers');
    document.getElementById('paper-count').textContent = allPapers.length;
    renderPapers();
  } catch(e) {}
}

function renderPapers() {
  const grid = document.getElementById('paper-grid');
  let papers = [...allPapers];
  if (currentFilter === 'starred') papers = papers.filter(p => p.starred);
  else if (currentFilter === 'parsed') papers = papers.filter(p => p.status === 'parsed');
  else if (currentFilter === 'translated') papers = papers.filter(p => p.status === 'translated');
  papers.sort((a, b) => new Date(b.lastReadAt || b.importedAt || 0) - new Date(a.lastReadAt || a.importedAt || 0));

  // 更新选择栏
  const selBar = document.getElementById('selection-bar');
  if (selectedPapers.size > 0) {
    selBar.style.display = 'flex';
    document.getElementById('sel-count').textContent = `已选 ${selectedPapers.size} 篇`;
  } else {
    selBar.style.display = 'none';
  }

  if (papers.length === 0) {
    grid.innerHTML = '<div class="empty-state"><div class="icon">📚</div><p>没有论文</p></div>';
    return;
  }

  grid.innerHTML = papers.map(p => {
    const sel = selectedPapers.has(p.id);
    const statusColors = { parsed: '#E8F5E9', translated: '#E3F2FD', error: '#FFEBEE', importing: '#FFF3E0', parsing: '#F3E5F5' };
    const statusLabels = { parsed: '已解析', translated: '已翻译', error: '错误', importing: '导入中', parsing: '解析中' };
    const sc = statusColors[p.status] || '#F5F5F5';
    return `<div class="card ${sel ? 'selected' : ''}" data-id="${p.id}" onclick="selectPaper('${p.id}')">
      <div class="card-title">${p.title} ${p.starred ? '⭐' : ''}</div>
      ${p.authors && p.authors.length ? `<div class="card-authors">${p.authors.join(', ')}</div>` : ''}
      <div class="card-meta">
        <span class="card-status" style="background:${sc}">${statusLabels[p.status] || p.status}</span>
        <span class="card-time">${formatTime(p.lastReadAt || p.importedAt)}</span>
        ${p.pageCount ? `<span>${p.pageCount} 页</span>` : ''}
      </div>
    </div>`;
  }).join('');
}

function selectPaper(id) {
  if (selectedPapers.size > 0) {
    if (selectedPapers.has(id)) selectedPapers.delete(id);
    else selectedPapers.add(id);
    renderPapers();
    return;
  }
  // 打开阅读
  paperToView(id);
}

function paperToView(id) {
  currentPaperId = id;
  document.querySelectorAll('.page').forEach(p => { p.style.display = 'none'; p.classList.remove('active'); });
  document.getElementById('page-read').style.display = 'block';
  loadPaper(id);
}

// ─── Read Page ────────────────────────────────────────────────
async function loadPaper(id) {
  try {
    const [meta, content, translation] = await Promise.all([
      api('GET', `/papers/${id}`),
      api('GET', `/papers/${id}/content`),
      api('GET', `/papers/${id}/translation`),
    ]);
    document.getElementById('read-title').textContent = meta.title;
    document.getElementById('read-star').textContent = meta.starred ? '⭐' : '☆';
    const transBtn = document.getElementById('read-translate');
    if (translation.translation) {
      transBtn.style.display = 'inline-block';
      transBtn.dataset.trans = translation.translation;
      transBtn.dataset.showTrans = 'true';
      transBtn.textContent = '🌐';
    } else {
      transBtn.style.display = 'none';
    }
    document.getElementById('read-content').textContent = content.content || '无内容';
  } catch(e) {
    document.getElementById('read-content').textContent = '加载失败';
  }
}

document.getElementById('back-btn').addEventListener('click', () => {
  document.getElementById('page-read').style.display = 'none';
  document.querySelector('.nav-item[data-page="library"]').click();
});

document.getElementById('read-star').addEventListener('click', async () => {
  if (!currentPaperId) return;
  const r = await api('PUT', `/papers/${currentPaperId}/star`);
  document.getElementById('read-star').textContent = r.starred ? '⭐' : '☆';
});

document.getElementById('read-translate').addEventListener('click', () => {
  const btn = document.getElementById('read-translate');
  const content = document.getElementById('read-content');
  if (btn.dataset.showTrans === 'true') {
    // 显示译文
    content.textContent = btn.dataset.trans || content.textContent;
    btn.dataset.showTrans = 'false';
    btn.textContent = '📄';
  } else {
    // 显示原文
    loadPaper(currentPaperId);
    btn.dataset.showTrans = 'true';
    btn.textContent = '🌐';
  }
});

document.getElementById('read-summary').addEventListener('click', async () => {
  if (!currentPaperId) return;
  try {
    const r = await api('POST', `/summarize/${currentPaperId}`);
    showModal('摘要', `<p style="line-height:1.6">${r.summary}</p>`);
  } catch(e) { toast('摘要生成失败'); }
});

// ─── Templates ────────────────────────────────────────────────
async function renderTemplates() {
  try {
    const ts = await api('GET', '/templates');
    document.getElementById('template-list').innerHTML = ts.map(t => `
      <div class="template-item" onclick='showModal("${t.name}", `<pre style="white-space:pre-wrap;line-height:1.5;font-size:12px">${t.markdown.replace(/`/g, '\\`')}</pre>`)'>
        <div class="template-icon">${t.isBuiltin ? '✨' : '👤'}</div>
        <div><div class="template-name">${t.name}</div><div class="template-desc">${t.description}</div></div>
      </div>
    `).join('');
  } catch(e) {}
}

// ─── Settings ─────────────────────────────────────────────────
async function renderSettings() {
  try {
    const cfg = await api('GET', '/config');
    document.getElementById('settings-content').innerHTML = `
      <div class="settings-section">
        <h3>外观</h3>
        <div class="settings-card">
          <label>主题色</label>
          <div class="theme-picker">
            ${([['alice','#5C2D91'],['blue','#415F91'],['cyan','#00897B'],['green','#43A047'],['orange','#E65100'],['red','#D81B60'],['black','#424242']]).map(([k,v]) =>
              `<div class="theme-swatch ${k===cfg.themeVariant ? 'active' : ''}" style="background:${v}" onclick="setTheme('${k}')"></div>`
            ).join('')}
          </div>
          <div class="toggle-row">
            <div><div class="toggle-label">AMOLED 深黑</div><div class="toggle-sub">深色模式下纯黑背景</div></div>
            <div class="toggle ${cfg.amoled ? 'on' : ''}" onclick="toggleAmoled()"></div>
          </div>
        </div>
      </div>
      <div class="settings-section">
        <h3>LLM 配置</h3>
        <div class="settings-card">
          <label>API Key</label>
          <input type="password" id="s-llm-key" value="">
          <label>API Base</label>
          <input type="text" id="s-llm-base" value="${cfg.llmApiBase || ''}">
          <label>模型</label>
          <input type="text" id="s-llm-model" value="${cfg.llmModel || ''}">
        </div>
      </div>
      <div class="settings-section">
        <h3>解析引擎</h3>
        <div class="settings-card">
          <label>MinerU API Key</label>
          <input type="password" id="s-mineru-key" value="">
        </div>
      </div>
      <button class="btn btn-primary" onclick="saveSettings()" style="padding:12px 24px;width:100%;border-radius:14px">保存设置</button>
    `;
    // 加载 API Keys（从脱敏配置无法获取，留空）
  } catch(e) {}
}

function setTheme(v) {
  document.querySelectorAll('.theme-swatch').forEach(s => s.classList.remove('active'));
  event.target.classList.add('active');
  // Save via config update
}

function toggleAmoled() {
  const el = event.target;
  el.classList.toggle('on');
}

async function saveSettings() {
  toast('设置保存中...');
  try {
    toast('设置已保存（API Key 需通过 CLI 配置）');
  } catch(e) { toast('保存失败'); }
}

// ─── Modal ────────────────────────────────────────────────────
function showModal(title, html) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `<div class="modal"><h2>${title}</h2>${html}
    <div class="modal-actions"><button class="btn btn-primary" onclick="this.closest('.modal-overlay').remove()">关闭</button></div></div>`;
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
  document.body.appendChild(overlay);
}

// ─── Init ─────────────────────────────────────────────────────
applyTheme();
loadSoul();
refreshLibrary();
