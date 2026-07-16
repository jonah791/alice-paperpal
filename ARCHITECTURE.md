# PaperPal Unified Architecture

> 统一架构设计 v1.0 — 融合 MarkItDown (文档转换) + Kori (AI 笔记) + MD Preview (阅读体验)

## 哲学

```
一个入口，万种文档，有灵魂的 AI 伙伴。
```

PaperPal 从"AI 论文阅读伴侣"进化为"AI 文档智能平台"——保持专注的论文阅读核心，同时吸收三个开源项目的精华。

## 吸收的设计理念

| 来源 | 核心理念 | PaperPal 的落地 |
|------|---------|----------------|
| **MarkItDown** | 任意格式→Markdown 的统一转换管道 | `DocConversionService` + Python 桥接 |
| **Kori** | 笔记即写作，模板即效率，多格式渲染 | `TemplateService` + Mermaid 支持 + 文件关联 |
| **MD Preview** | 打开即看的极速体验，离线优先 | `FindInPage` + 实时重载 + 懒加载渲染 |

## 分层架构

```
┌──────────────────────────────────────────────────────────────┐
│                      UI Layer (Flutter)                       │
│                                                              │
│  SearchPage → LibraryPage → ReadPage → NoteEditorPage        │
│       ↑                          ↑              ↑            │
│       │    (MD Preview 风格)      │   (Kori 风格) │            │
│       └──────────────────────────┴──────────────┘            │
│                                                              │
│  新 Widgets: MermaidWidget · FindBar · TemplatePicker        │
│  新页面:    NoteEditorPage · ConvertPage                     │
├──────────────────────────────────────────────────────────────┤
│                      Services Layer (Dart)                    │
│                                                              │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────┐   │
│  │ DocConversion    │  │ PaperService │  │ Template      │   │
│  │ Service (NEW)    │  │ (enhanced)   │  │ Service (NEW) │   │
│  │  ├ MarkItDown   │  │  └ 多格式     │  │  ├ 预置模板   │   │
│  │  │ 桥接 (Python) │  │   导入       │  │  └ 自定义模板 │   │
│  │  ├ MinerU (现有) │  └──────────────┘  └───────────────┘   │
│  │  └ 降级链       │                                        │
│  └─────────────────┘                                        │
├──────────────────────────────────────────────────────────────┤
│                      Rendering Engine                         │
│                                                              │
│  Markdown → RichText · KaTeX → Formula · Mermaid → Diagram   │
│  CodeHighlight → Colored · FindInPage → Highlight            │
│                                                              │
│  (借鉴 MD Preview 的"主渲染先行，重增强延迟"策略)             │
├──────────────────────────────────────────────────────────────┤
│                      AI Pipeline (existing + enhanced)        │
│                                                              │
│  Soul System → Memory → Portrait → LLM (DeepSeek/OpenAI/...) │
├──────────────────────────────────────────────────────────────┤
│                      Platform Layer (existing)                │
│                                                              │
│  Windows · Android · CLI · API Server · (未来 iOS/macOS)     │
└──────────────────────────────────────────────────────────────┘
```

## 核心数据流

### 文档导入流程 (MarkItDown 整合)

```
用户选择文件 (*.pdf, *.docx, *.pptx, *.xlsx, *.epub, *.html, *.md, *.txt)
    │
    ▼
DocConversionService.convertToMarkdown(file)
    │
    ├─ PDF → MinerU API (primary) → Markdown
    │         ↓ fallback
    │       MarkItDown (Python bridge) → Markdown
    │
    ├─ Office (DOCX/PPTX/XLSX) → MarkItDown (Python) → Markdown
    │
    ├─ EPUB → MarkItDown (Python) → Markdown
    │
    ├─ Image/Audio → MarkItDown + LLM Vision → Markdown
    │
    └─ HTML/MD/TXT → 直接读取 → Markdown
            │
            ▼
        PaperService.importMarkdown(markdown, title, sourceType)
            │
            ▼
        缓存 + 索引 + AI 摘要 + 进入文库
```

### 阅读页增强 (MD Preview 整合)

```
ReadPage 打开
    │
    ├─ 加载 Markdown (优先本地缓存)
    │
    ├─ 分块渲染策略:
    │   ├─ 立即: Markdown → RichText (文本 + 标题 + 列表)
    │   ├─ 延迟: KaTeX 公式 (已有)
    │   ├─ 按需: Mermaid 图表 (NEW, 检测到 ```mermaid 时加载)
    │   └─ 按需: 代码高亮 (NEW, 检测到 ``` 时加载)
    │
    ├─ 侧边功能:
    │   ├─ FindInPage: ⌘+F 搜索渲染后文本 (MD Preview 风格)
    │   ├─ 实时重载: 文件变更时自动刷新
    │   └─ 对照模式: 原文/译文/对照 (已有)
    │
    └─ 退出时保存滚动位置 (已有)
```

### 笔记系统增强 (Kori 整合)

```
NoteService (enhanced)
    │
    ├─ 笔记 CRUD (已有)
    │
    ├─ 笔记模板 (NEW):
    │   ├─ "论文总结"模板: # 论文标题 | ## 核心贡献 | ## 方法 | ## 结论
    │   ├─ "阅读笔记"模板: # 日期 | ## 关键点 | ## 疑问 | ## 想法
    │   ├─ "审稿意见"模板: ## Strengths | ## Weaknesses | ## Questions
    │   └─ 自定义模板: 用户创建/编辑/删除
    │
    └─ 文件关联 (NEW):
        ├─ 接受系统 .md/.txt 文件打开
        └─ 作为 Markdown 笔记导入到文库
```

## 新文件清单

```
lib/
├── core/
│   ├── api/
│   │   └── markitdown_bridge.dart   (NEW) Python 子进程桥接
│   ├── models/
│   │   └── document.dart            (NEW) 统一文档模型
│   ├── services/
│   │   ├── doc_conversion_service.dart  (NEW) 统一文档转换
│   │   ├── template_service.dart       (NEW) 笔记模板
│   │   └── mermaid_renderer.dart       (NEW) Mermaid 渲染引擎
│   └── interfaces/
│       └── services.dart             (MODIFIED) 新接口
├── ui/
│   ├── pages/
│   │   └── read_page.dart            (MODIFIED) Mermaid + 搜索 + 高亮
│   └── widgets/
│       ├── mermaid_widget.dart       (NEW) Mermaid 组件
│       ├── find_bar.dart             (NEW) 页面内搜索
│       └── template_picker.dart      (NEW) 模板选择器
└── tool/
    └── markitdown_bridge.py          (NEW) Python 桥接脚本
```

## 依赖追加

```yaml
# pubspec.yaml 追加
dependencies:
  webview_flutter: ^4.10.0        # Mermaid 渲染 (Windows/macOS/Android/iOS)
  webview_flutter_windows: ^0.2.0  # Windows WebView2 支持
  flutter_highlight: ^0.7.0        # 代码语法高亮
  markdown: ^7.2.0                 # 增强 Markdown 解析 (可选替代手动解析)
  path: ^1.9.0                     # 路径处理 (现有)
```

## 设计原则

1. **渐进增强** — 核心阅读体验 0 依赖增加即可工作；Mermaid/高亮等重功能按需加载
2. **离线优先** — 所有渲染资产缓存在本地，MarkItDown 可选，无网时降级链正常工作
3. **统一入口** — 不管什么格式的文件，走同一个导入管道，进同一个文库
4. **保持轻量** — 不引入重型框架，不改变现有代码的 DI 和状态管理模式
