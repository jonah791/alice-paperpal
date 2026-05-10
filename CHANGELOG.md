# Changelog

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
