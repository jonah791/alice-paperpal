# Changelog

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
