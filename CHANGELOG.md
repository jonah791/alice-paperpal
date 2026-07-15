# Changelog

## [0.4.3] - 2026-07-15

### Added

- **REST API 服务器** — `lib/server_main.dart`，全功能 HTTP 接口。运行：`flutter run -t lib/server_main.dart --dart-define=PORT=4090`
- **API 端点**：`/health`、`/papers`、`/papers/:id/content`、`/papers/:id/translation`、`/search`、`/import/search`、`/ask/:id`（SSE 流式）、`/summarize/:id`、`/notes` CRUD

### Changed

- **重构**：QA 面板和笔记面板从 `read_page.dart` 拆分为独立 Widget（`qa_panel.dart` 177 行、`notes_panel.dart` 245 行），ReadPage 从 1000 行降至 575 行

### Fixed

- **错误详情可见**：导入/搜索失败时显示具体原因（网络断开/超时/401/500 等），而非泛化提示
- **QA 面板 dispose 后 setState**：流式响应添加 `mounted` 守卫，防止页面退出后崩溃
- **`use_build_context_synchronously`**：18 处 async 后 context 引用全部修复，lib/ 分析归零

### Changed

- **AnimatedBackground**：包裹 `RepaintBoundary` 隔离重绘区域 + 降低 `_GradientPainter` 每帧分配量
- **Deep link**：`paperpal://arxiv/XXXX.XXXX` 协议支持，C++ runner + Dart 解析 + Inno Setup 注册
- **CI 安装包**：新增 `paperpal://` 协议注册

## [0.4.2] - 2026-07-15

### Added

- **划词问答** — 浮动 Ask 按钮 + 选中文本智能问答（读剪贴板 → 底部面板输入问题 → LLM 回答）
- **文库排序** — 最近阅读/最新导入/标题 A-Z 三模式，默认最近阅读
- **库内搜索** — 按标题+作者实时过滤
- **批量导入 PDF** — 多选文件，逐篇导入+状态提示
- **系统托盘增强** — 右键「快速搜索」「导入 arXiv 链接」，自动切到搜索页
- **深色模式一键切换** — 导航栏底部 🌙/☀️ 按钮
- **搜索「已导入」标识** — 已导入 Chip + 直达读页

### Fixed

- **库筛选索引偏移** — 「全部」错误显示 importing 论文；「导入中」错误显示 downloading。改为 `_filterStatus == 0 → all`
- **QA dispose crash** — `setState()` after dispose（stream 后置操作），加 `mounted` 守卫
- **10 处 `$e` 暴露给用户** — 所有用户可见错误消息替换为友好文案，原始异常保留日志
- **search_page 2 处不可达 null 检查** — `importPdf` 恒不为 null，移除多余分支
- **`_lastImportedPaper` 未设置** — URL 导入和结果卡片导入后无「查看」按钮
- **`touchPaper` 时机过早** — 在内容加载之前标记已读，改为内容加载成功后调用
- **settings `fontSize: 9` 硬编码** — 违反 DesignTokens，改为 `DesignTokens.fsXxs`
- **settings API Key 无可见性切换** — 加 👁️ suffixIcon
- **CLI 帮助不完整** — soul/note/translate 子命令缺失

### UI Polish

- **QA 面板动态高度** — 按消息量自动扩展，最大 40% 屏幕，可收起
- **QA 输入框快捷键** — Enter 发送，Shift+Enter 换行，`maxLines: 4`
- **笔记选中文本捕获** — 读剪贴板作为笔记上下文、删除按钮、类型徽章
- **文库长按提示** — 列表底部「长按卡片可多选」
- **导入后「查看」按钮** — 三种导入路径均显示直达读页按钮
- **回退解析论文「重新解析」** — ReadPage 菜单一键调用 MinerU 替换内容

## [0.4.1] - 2026-07-14

### Added

- **MinerU fallback 轻量解析管线** — MinerU 不可用时自动降级：poppler pdftotext → flutter_pdf 逐页提取 → 仅元数据，三层兜底
- **`sourceType` 字段** — ParseResult/Paper 记录解析来源（`mineru`/`fallback_text`/`fallback_raw`），UI 显示对应横幅
- **359 测试** — 含 19 个 PdfFallbackService 新测（提取标题、section 拆分、header 识别、flutter_pdf 集成）

### Fixed

- **chatStream 错误吞掉** — stream 静默终止时 UI 死等。改为 yield 用户可读的错误消息（API Key 无效/限频/超时/服务端错误）
- **JSON 损坏静默丢失文库** — `cache_service.loadAllPapers()` 在 index.json 损坏时自动备份文件再返回空，而非直接清空
- **4 个 ReadPage 方法吞错误** — `_summarize`、`_exportMarkdown`、`_exportBibtex`、`_openOriginalPdf` 失败时添加 SnackBar 反馈
- **6 个 UI catch 块无日志** — search_page、library_page、settings_page 的 catch 添加 `_log.warning`
- **`_activeComment()` 空 catch** — LLM 评论生成失败时记录日志而非静默
- **`_loadSettings()` 吞错误** — 配置损坏时记录日志

### UI

- **SearchPage 搜索条去重** — 宽窄屏共享 TextField builder，按钮布局更紧凑
- **LibraryPage filter 修复** — `PaperStatus.values.length` 索引偏移修正，间距 token 化

## [0.4.0] - 2026-07-14

### Refactor

- **ServiceLocator** (`lib/core/di/service_locator.dart`) — 轻量 DI 容器，消除 131 行 main() 工厂。新服务只需注册 1 处
- **Dependencies 简化** — 11 个具名字段 → 1 个 `locator` 字段；新增 `ServiceX` 扩展（`context.paperService` 替代 `Dependencies.of(context).paperService`）
- **共享 AppInitializer** (`lib/core/init.dart`) — CLI 和 Flutter 共用 `createLocator()` 初始化逻辑
- **PaperService 接口化** — 所有内部依赖改为接口类型（`ICacheService`, `ISearchService` 等）
- **DesignTokens 系统** (`lib/core/tokens/design_tokens.dart`) — 4px 网格间距、圆角、字号、不透明度、断点的单一数据源。200+ 硬编码值替换为 token 引用
- **app_theme.dart 重构** — 全量驱动于 DesignTokens，移除所有硬编码色值/间距/圆角
- **8 个页面/组件**更新：search_page、read_page、library_page、settings_page、soul_selector、explain_dialog、avatar_picker、welcome_page 改用 token 和 context.XXX 模式

### Fixed

- **ReadPage initState crash** — `_loadContent()` 调用 `Dependencies.of(context)` 时 InheritedWidget 未挂载，改为 `addPostFrameCallback`
- **MockPaperService 空标题** — `importPdf` 传入的 title 正确映射到 paper title
- **MockConfigService 平台缺失** — 添加 `_MockPlatform` 使 widget test 可用
- **ATL 依赖修复** — `flutter_secure_storage_windows` 插件依赖 ATL 库，改为内联 CA2W/CW2A 实现

### Added

- **340 测试套件**（+20 新测试）：
  - 8 个 SearchPage widget test：空状态、搜索结果、错误、离线、导入、URL
  - 7 个 ReadPage widget test：内容渲染、译文切换、问答、字体
  - 5 个端到端测试：真实 PDF 验证、缓存管线、导入管线、BibTeX 导出、ReadPage 渲染
- **test/helpers/mock_services.dart** — 11 个 mock 服务实现，即插即用
- **Windows 便携包** — `build/ALICE-PaperPal-v0.4.0-portable.zip`

## [0.3.2] - 2026-05-12

### Fixed

- **灰屏崩溃**：`read_page.dart` 中 `build()` 内 `addPostFrameCallback` → `setState` 无限循环导致 Flutter 框架灰屏。将 BottomSheet 展示逻辑移至专用方法 `_toggleNotesPanel()`
- **异步安全**：7 个文件共 12 处 async 方法添加 try/catch + mounted 检查，防止未处理异常导致的崩溃（`_search()`、`_uploadPdf()`、`_deleteSelected()`、`_confirmDelete()`、`_loadSettings()`、`_saveSettings()`、avatar picker、soul selector）

### Changed

- **暗色模式适配**：`PaperStatus.color` 改为接收 `BuildContext` 参数，使用 `ColorScheme` 语义色替代硬编码 `Colors.*`

### Cleanup

- **无用 import**：移除 `explain_dialog.dart` 中未使用的 `paper_service.dart` 导入

## [0.3.1] - 2026-05-12

### Refactor

- **Dependencies 解耦**：`Dependencies` InheritedWidget 从 `main.dart` 提取到 `lib/core/di/dependencies.dart`，消除 8 个页面直接引用入口文件的架构耦合
- **CLI search 命令重写**：复用 `SearchService` 代替直接调用 `ArxivApi`/`S2Api`，消除 30 行重复去重逻辑

### Fixed

- **笔记残留 Bug**：删除论文时从未调用 NoteService，笔记变成孤立数据。修复：`NoteService` 注入 `PaperService`，`deletePaper()` 末尾自动调用 `deleteNotesForPaper()`
- **搜索错误不可见**：`SearchService.search()` 静默吞掉所有异常，用户无法区分"无结果"和"网络断开"。修复：返回 `(List, String?)` tuple，`SearchPage` 显示具体错误信息

### Added

- **网络状态检查**：`SearchPage._search()` 在发起 API 请求前检查 `NetworkService.isOnline`，离线时直接提示"网络不可用"
- **笔记批量删除**：`NoteService.deleteNotesForPaper(String paperId)` 新方法

## [0.3.0] - 2026-05-11

### Added — Android Mobile Support

- **Platform abstraction layer**: `PlatformService` with `DesktopPlatformService` and `AndroidPlatformService` implementations
- **Android Keystore encryption**: API keys secured via `flutter_secure_storage` on Android (replaces Windows DPAPI)
- **Adaptive navigation**: Mobile uses `NavigationBar` (bottom tabs), desktop retains `NavigationRail` (side rail), auto-switches based on screen width (600dp threshold)
- **Read page mobile adaptations**: Notes panel opens as `DraggableScrollableSheet` BottomSheet, side-by-side mode hidden on mobile, AppBar overflow menu for secondary actions
- **Mobile PDF opening**: Uses `open_filex` package to open PDFs via Android intents
- **Search page responsive**: Button row wraps to next line on narrow screens
- **Explain dialog width**: Fixed 560px changed to `maxWidth: 560` for narrow screens
- **Android project scaffold**: `android/` directory with `AndroidManifest.xml` (INTERNET + ACCESS_NETWORK_STATE permissions)
- **CI/CD Android build**: GitHub Actions builds `app-release.apk` on Ubuntu, uploaded to Releases alongside Windows artifacts

### Changed

- `ConfigService` now requires `PlatformService` constructor argument
- `main()` detects platform and conditionally initializes `window_manager`/`tray_manager` (skipped on Android)
- `Dependencies` includes `configService.platform` for widget-level platform checks

### Added — Alice in Wonderland UI Redesign

- **Complete theme rewrite** — Dark (deep purple + gold #E8B84B) and light (warm cream + gold #C28A2C) dual theme with explicit ColorScheme
- **Custom typography** — Playfair Display (headings), Inter (UI), Noto Serif SC (Chinese reading) via Google Fonts
- **Animated gradient background** — 3-point radial gradients slowly drifting across screen, with card suit pattern overlay
- **Card suit decorations** — ♠♥♦♣ markers on paper library cards, floating suit decorations on welcome page
- **Custom page transitions** — Slide-in curtain effect with cubic bezier curve on all page navigation
- **Scroll progress bar** — 3px gold gradient bar tracking reading progress on read page
- **Card spinner loading** — Animated ♠♥♦♣ staggered loading indicator replacing CircularProgressIndicator
- **Skeleton loader** — Breathing opacity placeholder while content loads
- **Staggered list animations** — Cards fade+slide up on search results and library pages
- **Gold gradient text** — Welcome page title "PaperPal" with three-tone gold linear gradient
- **Highlight markup style** — Gold underline highlight (18% opacity background) for key terms in reading content
- **Styled equation blocks** — Gold-tinted container with border for LaTeX equations
- **Styled note cards** — Gold left border accent, elevated surface, italic content text
- **Chat bubble redesign** — Purple tint user bubble, gold-accented AI bubble with gold circle avatar
- **Soul selector redesign** — Gold active state chip with tint background
- **Settings page polish** — Section headers with gold muted uppercase labels
- **App icon** — New 256×256 Alice-themed app icon with playing card motifs
- **Inno Setup installer** — Professional Windows installer (.exe) with PDF file association

### Changed

- All `CircularProgressIndicator` usages replaced with themed `CardSpinner` or `SkeletonLoader`
- All card styling unified via `CardTheme` (12px radius, gold border)
- All input fields unified via `InputDecorationTheme` (dark surface, gold focus)
- All buttons unified via `ElevatedButtonTheme` (gold pill shape)

## [0.1.5] - 2026-05-11

### Fixed

- **CI 构建失败修复**：`read_page.dart` 和 `soul_selector.dart` 仍引用已移除的 `AvatarService.buildDefaultAvatar()`，改为调用 `avatar_helpers.dart` 中的 `buildDefaultAvatar()` 独立函数

## [0.1.4] - 2026-05-11

### Added

- **CLI 测试工具**：`tool/paperpal.dart` — 纯 Dart 命令行入口，12 个命令覆盖全部产品功能
- **lib/core/ 纯 Dart 化**：`avatar_service.dart` 剥离 flutter/material 和 image_picker，`config.dart` 剥离 flutter extension，`lib/core/` 成为纯 Dart 模块
- **`papers show <id>` 命令**：查看论文 markdown 或翻译内容（`--translated`）
- **元数据获取**：`import url` 自动调用 arXiv API 补全论文的作者/年份/DOI
- **`import search <index>` 命令**：从搜索结果直接导入论文
- **YAML frontmatter**：`export markdown` 输出添加 title/authors/year/doi/source 头

### Changed

- **数据目录统一**：CLI 与应用共享 `~/.paperwise/`（原 test_harness 使用 `~/.paperpal/`）
- **Soul 预设独立**：`soulPresetDefinitions` 从 `soul_service.dart` 提取为独立纯 Dart 文件 `soul_presets.dart`
- **BibTeX 导出增强**：不再使用 `{Anonymous}`，优先使用 arXiv API 获取的作者元数据
- **README 更新**：新增 CLI 工具文档、测试数更新至 320

## [0.1.3] - 2026-05-10

### Added

- **全方位测试扩展**：从 161 增至 320 测试，新增 8 个测试文件覆盖 LLMProvider（body/Claude 消息/endpoint/extractContent）、ParseService（页范围拆分边界）、SearchService（dedup 去重逻辑）、MineruApi（ZIP 解压）、ExportService（BibTeX 边界）、TranslationService（validateLatex）、模型边界、服务边界
- **APIs 公开化**：`endpoint`、`buildBody`、`buildClaudeBody`、`extractContent`、`validateLatex`、`extractZip`、`buildPageRanges`、`HttpsInterceptor`/`DioHttpsInterceptor` 从私有改为公开，便于单元测试

### Fixed

- **extractContent 空列表崩溃**：`choices: []` 或 `content: []` 时 `.first` 抛异常，替换为安全路径导航 `_safeExtract`
- **测试质量改进**：占位 widget test 替换为真实 AppTheme 验证；死测试（PortraitService 无断言）修复；SOulService 预设测试从硬编码文本改为结构性校验；往返测试补全遗漏字段；enum 顺序脆弱性修复

## [0.1.2] - 2026-05-11

### Fixed

- **DPAPI 加密修复**：`GetProcessHeap` 和 `HeapFree` 从错误的 `crypt32.dll` 改为 `kernel32.dll`，Windows 加密功能现在可用
- **下载 RangeError**：文件名清理后截取使用清理前长度导致越界，改为使用清理后长度
- **错误消息改进**：MinerU API 失败时显示底层 `SocketException` 详情，不再显示 `null (null)`
- **解析错误可见**：`Paper` 模型新增 `errorMessage` 字段，解析失败时存入具体原因供用户查看
- **MinerU API 健壮性**：`_submitFileUpload` 和 `_pollBatch` 增加 `DioException` 捕获和重试
- **DPAPI 日志静默**：加密不可用时不再输出 WARNING 日志

### Changed

- **测试框架重写**：从 27 个松散测试重构为 161 个结构化测试，覆盖模型序列化 / API 逻辑 / 服务纯逻辑
- **ArxivApi 解析方法公开化**：`_parseXml`、`_extractTag` 等 5 个纯函数改为 package-visible，便于单元测试
- **MineruApi 状态解析公开化**：`_parseState` 改为 package-visible

### Added

- **论文库筛选**：按状态（全部/已解析/已翻译/错误）过滤
- **论文库删除**：支持单篇（右键菜单）和多选批量删除
- **下载进度**：搜索页展示实时下载百分比
- **设置页扩展**：MinerU 模型版本选择器（VLM/Pipeline/MinerU-HTML）+ 公式/表格识别开关
- **配置文件扩展**：`AppConfig` 新增 `mineruModelVersion`、`enableFormula`、`enableTable`

## [0.1.1] - 2026-05-11

### Changed

- **MinerU API v4 迁移**：从已废弃的 v2 `/file_parse` 同步接口迁移至 v4 异步任务架构（`/api/v4/extract/task` 提交 → 轮询 → 下载 ZIP），支持 URL 提交和本地文件预签名上传两种模式
- **ParseService 重构**：移除手动分批逻辑，改为 API 原生 `page_ranges` 参数；`batchSize` 配置项移除
- **配置模型扩展**：`AppConfig` 新增 `mineruModelVersion`、`enableFormula`、`enableTable` 字段

### Added

- **论文库删除**：支持单篇删除（右键菜单）和多选批量删除
- **论文库筛选**：顶部 `FilterChip` 栏按状态（全部/已解析/已翻译/错误）过滤
- **下载进度**：`SearchService.downloadPdf()` 支持 `onProgress` 回调，搜索页展示实时下载百分比
- **设置页扩展**：模型版本选择器（VLM/Pipeline/MinerU-HTML）+ 公式/表格识别开关
- **全方位测试**：测试数从 27 提升至 131，覆盖 AppError、ExportService BibTeX、MergeService、PortraitService deepMerge、SoulService presetDefinitions、RetryInterceptor isRetryable、Logger sanitize、多语种检测、DioClient、MergeService 等

### Fixed

- **设置页**：提示 URL 从 `api/v2` 改为 `api/v4`
- **默认 Base URL**：`paper_service.dart` 从 `https://mineru.net/api/v2` 修正为 `https://mineru.net`
- **ReadPage 内存泄漏**：新增 `_noteController.dispose()`
- **WelcomePage**：应用名从 "PaperWise" 统一为 "PaperPal"
- **未使用 imports 清理**：soul_selector、explain_dialog
- **API.md / HANDOVER.md**：更新为 v4 契约

## [0.2.0] - 2026-05-10

### Added

- **灵魂系统**：4 个预置灵魂（学术导师/代码专家/论文审稿人/科普达人）+ 零代码创建向导（LLM 从自然语言生成灵魂定义）
- **元灵魂（Meta-Soul）**：底层生命规则，定义主动性、连续性、人性化行为
- **用户画像**：LLM 自动维护用户兴趣/偏好画像，对话后异步更新，用户无感
- **对话记忆**：自动积累对话摘要，跨 session 注入，所有灵魂共享（连续生命感）
- **头像系统**：内置默认头像（首字母+色块）+ image_picker 从相册选择
- **流式响应**：SSE 流式输出，Q&A 逐字显示
- **主动事件**：启动问候（引用最近记忆）、解析完成后主动评论
- **Windows DPAPI 加密**：通过 dart:ffi 调用 CryptProtectData 加密 API Key
- **共享 Dio 客户端**：统一 HTTPS 强制 + 重试拦截器
- **重试逻辑**：RetryInterceptor（3 次重试，指数退避）
- **网络状态检测**：connectivity_plus + NavigationRail 底部状态图标
- **导出功能**：Markdown / BibTeX 导出
- **PDF 原始视图**：系统默认 PDF 阅读器打开
- **多论文对比**：长按多选 → AI 对比分析
- **公式/表格解释**：选中公式/表格 → AI 解读
- **标注/笔记**：侧栏笔记面板，持久化存储
- **URL 导入**：粘贴 arXiv 链接或 PDF 直链
- **PDF 文件关联**：install_assoc.bat 注册 Windows 文件关联
- **单元测试**：18 个测试覆盖 models + translation + services

## [0.1.0] - 2026-05-09

### Added

- 初始版本
- 论文搜索 (arXiv + Semantic Scholar)
- PDF 本地上传
- MinerU API 解析（含自动分批）
- 自动翻译（语言检测 → 翻译 → 后校验 → 缓存）
- AI 问答与摘要
- Markdown + LaTeX 阅读视图
- 原文/译文/对照三模式
- 论文库本地缓存 + 持久化（JSON 索引）
- 系统托盘 + 窗口管理
- 暗黑模式
- 字体大小调整
- 欢迎页 + 首次引导
- 设置页（API Key 配置）
- 键盘快捷键（Ctrl+S/L/P/Q）
- 日志系统（脱敏 + 文件轮转）
