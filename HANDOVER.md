# ALICE PaperPal — 项目交接文档

**项目名：** ALICE PaperPal  
**版本：** v0.2.0  
**仓库：** https://github.com/jonah791/alice-paperpal  
**技术栈：** Flutter (Dart) 桌面端 Windows EXE + CLI 命令行工具  
**构建状态：** CI 自动构建 → Release 发布

---

## 一、项目概述

PaperPal 是一款基于 MinerU + DeepSeek V4 的论文辅助阅读桌面工具。支持搜索论文、导入 PDF、自动解析、自动翻译、AI 问答与摘要。核心特色是「AI 生命感系统」——灵魂、记忆、画像、头像让 AI 伙伴像真人一样陪伴用户阅读论文。

v0.1.4 新增 **CLI 命令行工具**（`tool/paperpal.dart`），纯 Dart 入口，覆盖全部产品功能，可在非 Flutter 环境下端到端测试。

### 核心能力一览

| 能力 | 技术方案 |
|---|---|
| PDF 解析 | MinerU v4 API（异步提交 → 轮询 → 下载 ZIP） |
| AI 对话 | DeepSeek V4 Flash / OpenAI / Claude |
| 论文搜索 | arXiv API + Semantic Scholar API |
| 本地存储 | Local 文件系统 + SharedPreferences |
| API Key 加密 | Windows DPAPI（`dart:ffi` 调用 `crypt32.dll` + `kernel32.dll`） |
| 桌面框架 | Flutter Windows（原生 C++ runner） |
| CLI 工具 | 纯 Dart，`dart run tool/paperpal.dart`（无 Flutter 依赖） |
| CI/CD | GitHub Actions（analyze → test → build → release） |

---

## 二、项目结构

```
paperpal/
├── lib/
│   ├── main.dart                          # 入口 + Dependencies DI
│   │
│   ├── core/                              # 纯 Dart（无 Flutter 依赖）
│   │   ├── api/                           # 外部 API 客户端（5 文件）
│   │   │   ├── arxiv_api.dart             # arXiv 搜索
│   │   │   ├── dio_client.dart            # 共享 Dio 工厂（HTTPS + 重试）
│   │   │   ├── llm_provider.dart          # LLM 提供者（流式/非流式）
│   │   │   ├── mineru_api.dart            # MinerU PDF 解析
│   │   │   └── s2_api.dart                # Semantic Scholar 搜索
│   │   │
│   │   ├── models/                        # 数据模型（8 文件）
│   │   │   ├── app_error.dart
│   │   │   ├── config.dart                # AppConfig（纯 Dart，Flutter extension 移至 ui/）
│   │   │   ├── note.dart                  # 笔记
│   │   │   ├── paper.dart                 # 论文（含 toJson/fromJson）
│   │   │   ├── parse_result.dart
│   │   │   ├── search_result.dart
│   │   │   ├── soul.dart                  # 灵魂定义
│   │   │   └── soul_presets.dart          # 灵魂预设定义（纯 Dart，独立文件）
│   │   │
│   │   ├── services/                      # 业务服务（13 文件）
│   │   │   ├── avatar_service.dart        # 头像管理（纯 Dart，Widget 移至 ui/）
│   │   │   ├── cache_service.dart         # 论文缓存
│   │   │   ├── config_service.dart        # 配置 + Key 加密存储
│   │   │   ├── export_service.dart        # 导出 Markdown/BibTeX
│   │   │   ├── memory_service.dart        # 对话记忆
│   │   │   ├── network_service.dart       # 网络状态检测
│   │   │   ├── note_service.dart          # 笔记 CRUD
│   │   │   ├── paper_service.dart         # 核心编排（最重要）
│   │   │   ├── parse_service.dart         # PDF 分批解析
│   │   │   ├── portrait_service.dart      # 用户画像
│   │   │   ├── search_service.dart        # 搜索编排
│   │   │   ├── soul_service.dart          # 灵魂管理（引用 soul_presets.dart）
│   │   │   └── translation_service.dart   # 语言检测 + 翻译
│   │   │
│   │   └── utils/                         # 工具（4 文件）
│   │       ├── logger.dart                # 日志（脱敏 + 轮转）
│   │       ├── page_counter.dart          # PDF 页数检测
│   │       ├── retry_interceptor.dart     # Dio 重试拦截器
│   │       └── windows_encryption.dart    # DPAPI 加密
│   │
│   └── ui/
│       ├── pages/                         # 页面（6 文件）
│       │   ├── comparison_page.dart       # 多论文对比
│       │   ├── library_page.dart          # 论文库
│       │   ├── read_page.dart             # 阅读页（核心）
│       │   ├── search_page.dart           # 搜索页
│       │   ├── settings_page.dart         # 设置页
│       │   └── welcome_page.dart          # 欢迎页
│       │
│       ├── widgets/                       # 组件（4 文件）
│       │   ├── avatar_helpers.dart        # 默认头像构建（Flutter Widget）
│       │   ├── avatar_picker.dart         # 头像选择器（内联 ImagePicker）
│       │   ├── explain_dialog.dart        # 公式/表格解释
│       │   └── soul_selector.dart         # 灵魂选择器
│       │
│       └── theme/
│           ├── app_theme.dart             # 亮/暗主题 + AppThemeModeX extension
│           └── (config.dart extension 已移入此文件)
│
├── test/                                  # 测试（15 文件，320 个测试）
│   ├── core/
│   │   ├── models_test.dart               # Paper/Soul/Note/MemoryItem 等序列化（48 测试）
│   │   ├── services_test.dart             # ExportService/MergeService/PortraitService/SoulService（29 测试）
│   │   ├── config_test.dart               # ConfigService SharedPreferences 流程（12 测试）
│   │   ├── translation_test.dart          # TranslationService 多语种检测（18 测试）
│   │   ├── api_test.dart                  # DioClient + ArxivApi XML 解析（24 测试）
│   │   ├── mineru_test.dart               # MinerUApi 状态解析 + MineruTask（8 测试）
│   │   ├── utils_test.dart                # RetryInterceptor/Logger 脱敏（20 测试）
│   │   ├── llm_provider_test.dart         # LLMProvider body/endpoint/extractContent（48 测试，新增）
│   │   ├── parse_service_test.dart        # MergeService + buildPageRanges（21 测试，新增）
│   │   ├── search_service_test.dart       # SearchService dedup 去重逻辑（18 测试，新增）
│   │   ├── mineru_edge_test.dart          # MinerU extractZip + parseState（22 测试，新增）
│   │   ├── export_service_test.dart       # BibTeX 边界（15 测试，新增）
│   │   ├── models_edge_test.dart          # 模型边界 case（43 测试，新增）
│   │   ├── services_edge_test.dart        # 服务边界 + soul 结构校验（21 测试，新增）
│   │   └── translation_edge_test.dart     # validateLatex + CJK 边界（30 测试，新增）
│   └── widget_test.dart                   # AppTheme smoke test（1 测试）
│
├── tool/                                  # CLI 命令行工具（v0.1.4 新增）
│   ├── paperpal.dart                      # 入口，路由到子命令
│   ├── cli_state.dart                     # JSON 文件状态管理（config/index/记忆/画像）
│   ├── cli_context.dart                   # 灵魂+画像+记忆上下文装配
│   ├── cli_helpers.dart                   # 格式化输出、ANSI 颜色、--json
│   └── commands/
│       ├── config_command.dart
│       ├── search_command.dart
│       ├── import_command.dart
│       ├── paper_command.dart
│       ├── ask_command.dart
│       ├── summarize_command.dart
│       ├── translate_command.dart
│       ├── export_command.dart
│       ├── soul_command.dart
│       ├── note_command.dart
│       ├── memory_command.dart
│       └── portrait_command.dart
│
├── windows/                               # Flutter Windows 原生代码
│   ├── runner/main.cpp                    # 入口（含文件关联参数传递）
│   ├── install_assoc.bat                  # PDF 文件关联注册
│   └── uninstall_assoc.bat                # PDF 文件关联卸载
│
├── .github/workflows/build.yml            # CI/CD
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
├── API.md                                 # 外部 API 契约
└── THIRD_PARTY_NOTICES.md                 # 第三方许可
```

---

## 三、核心架构

### 3.1 依赖注入

所有服务在 `main()` 中初始化，通过 `Dependencies` InheritedWidget 注入到 widget 树：

```dart
// main.dart
final soulService = SoulService();
final memoryService = MemoryService();
final paperService = PaperService(
  llmProvider: llmProvider,
  soulService: soulService,
  memoryService: memoryService,
  portraitService: portraitService,
  // ...
);
// ...
runApp(PaperPalApp(/* 11 services */));

// 任意 widget 中访问：
final deps = Dependencies.of(context);
deps.paperService.askQuestionStream(...);
deps.soulService.getActiveOrDefault();
```

注册的 11 个服务：ConfigService, CacheService, LLMProvider, SoulService, MemoryService, PortraitService, AvatarService, SearchService, PaperService, NetworkService, NoteService。

### 3.2 AI 对话数据流

```
用户提问
    │
    ▼
PaperService.askQuestionStream()
    │
    ├── 1. 灵魂 systemPrompt（人格风格）
    ├── 2. 元灵魂规则（生命底层行为）
    ├── 3. 用户画像摘要（兴趣/偏好）
    ├── 4. 最近 10 条记忆（历史上下文）
    ├── 5. 论文全文
    ├── 6. 用户问题
    │
    ▼
LLMProvider.chatStream() → SSE 流式返回
    │
    ▼
前端逐 token 显示
    │
    ▼
流式完成后，后台：
    ├── PortraitService.updateFromConversation()  ← 更新画像
    └── MemoryService.addMemory()                ← 追加记忆
```

### 3.3 Prompt 组装逻辑（`PaperService._buildPersonaPrompt()`）

```dart
最终 System Prompt =
  [灵魂.systemPrompt]  // 人格设定
  + [灵魂.speechPattern] // 口头禅
  + [元灵魂规则]       // 底层行为（引用方式、不确定性表达、情绪）
```

### 3.4 CLI 测试工具架构

CLI 工具（`tool/paperpal.dart`）复用 `lib/core/` 中的纯 Dart 代码，绕过 Flutter 依赖：

```
dart run tool/paperpal.dart
    │
    ├── cli_state.dart        ～/.paperwise/ 目录 JSON 文件（替代 path_provider + SharedPreferences）
    ├── cli_context.dart      灵魂 + 画像 + 记忆上下文装配
    │
    └── commands/             12 个子命令
        ├── config_command    → 直接读写 JSON
        ├── search_command    → ArxivApi + S2Api
        ├── import_command    → MineruApi + ParseService + ArxivApi（元数据）
        ├── paper_command     → CLI 状态管理
        ├── ask_command       → LLMProvider + cli_context
        ├── summarize_command → LLMProvider + cli_context
        ├── translate_command → TranslationService + LLMProvider
        ├── export_command    → 内联 BibTeX + YAML frontmatter
        ├── soul_command      → soul_presets.dart + JSON
        ├── note_command      → JSON CRUD
        ├── memory_command    → JSON CRUD
        └── portrait_command  → JSON 读取
```

---

## 四、模块详解

### 4.1 灵魂系统（Soul）

| 文件 | 说明 |
|---|---|
| `lib/core/models/soul.dart` | 灵魂数据模型 |
| `lib/core/models/soul_presets.dart` | 灵魂预设定义（纯 Dart，独立提取） |
| `lib/core/services/soul_service.dart` | 预置 4 个 + 自定义 + 元灵魂（引用 soul_presets.dart） |

预置灵魂：

| ID | 名称 | 定位 |
|---|---|---|
| `academic_mentor` | 学术导师 | 严谨专业，耐心解释 |
| `code_expert` | 代码专家 | 技术务实，关注实现 |
| `paper_reviewer` | 论文审稿人 | 批判性分析 |
| `science_communicator` | 科普达人 | 通俗类比，生动表达 |

**自定义灵魂流程：**
1. 用户输入名字 + 自然语言描述
2. 调用 LLM 生成完整灵魂 JSON
3. 存入 `~/.paperwise/souls/custom/{uuid}.json`

**元灵魂（Meta-Soul）：**
硬编码在 `soul_service.dart` 中，约 80 tokens。定义了连续性（记忆引用方式）、人性化（不确定性/情绪/自我纠正）、禁用语。用户不可见不可改，灵魂未定义时兜底。

### 4.2 记忆系统（Memory）

| 存储 | `~/.paperwise/memory.json` |
|---|---|
| 格式 | JSON 数组，每项带 id/summary/paperId/timestamp |
| 上限 | 最近 100 条 |
| 清理 | 超过 30 天自动归档 |
| 隔离 | 不隔离，所有灵魂共享（连续生命感） |

### 4.3 用户画像（Portrait）

| 存储 | `~/.paperwise/portrait.json` |
|---|---|
| 更新方式 | 每次对话流式完成后，后台异步调用 LLM 判断是否需要更新 |
| 用户感知 | 完全无感，不可见不可操作 |
| Schema | 不固定，LLM 可动态扩展字段 |

### 4.4 头像（Avatar）

| 默认头像 | 程序生成（首字母 + 固定色块） |
|---|---|
| 自定义 | `image_picker` 从相册选择，缩放至 256x256 |
| 存储 | `~/.paperwise/avatars/current.png` |
| 注意 | `buildDefaultAvatar` 移至 `lib/ui/widgets/avatar_helpers.dart`，`core/services/avatar_service.dart` 为纯 Dart |

### 4.5 加密（Windows DPAPI）

```dart
// windows_encryption.dart
// 通过 dart:ffi 直接调用 crypt32.dll 的 CryptProtectData
// 加密后的密文 base64 编码后存入 SharedPreferences
// 解密失败时自动回退到明文（兼容旧版本）
```

**仅在 Windows 上可用。** 后续如果适配 Android，需要替换为 Android Keystore。

### 4.6 外部 API

| API | 端点 | 用途 | 限频 |
|---|---|---|---|
| MinerU | `POST /api/v4/extract/task`（异步提交）<br>`GET /api/v4/extract/task/{task_id}`（轮询） | PDF 解析 | 取决于套餐 |
| DeepSeek | `POST /v1/chat/completions` | LLM 问答 | 500 RPM（免费用户） |
| arXiv | `GET http://export.arxiv.org/api/query` | 论文搜索 | 1 req/3s |
| Semantic Scholar | `GET https://api.semanticscholar.org/graph/v1/paper/search` | 论文搜索 | 100 req/5min |

详见 `API.md`。

---

## 五、构建与发布

### 5.1 本地构建 — 桌面版

```bash
git clone https://github.com/jonah791/alice-paperpal.git
cd alice-paperpal
flutter pub get
flutter build windows --release
```

产物：`build/windows/x64/runner/Release/paperpal.exe` + DLL 文件

### 5.2 运行 CLI 工具（无需 Flutter）

```bash
dart run tool/paperpal.dart help
dart run tool/paperpal.dart config set llm-api-key <key>
dart run tool/paperpal.dart search "attention mechanism"
```

### 5.3 CI/CD 自动构建

文件：`.github/workflows/build.yml`

触发条件：推送 tag `v*`

流程：

```
analyze（flutter analyze --no-fatal-warnings --no-fatal-infos）
  → test（flutter test）
  → build（flutter build windows --release）
  → Package（Compress-Archive 打包 ZIP）
  → Release（上传 ZIP 到 GitHub Releases）
```

**注意：** Release 需要 `permissions: contents: write` 权限，已经在 workflow 中配置。

### 5.4 发布新版

```bash
# 更新 CHANGELOG.md 中的版本
# 修改 pubspec.yaml 中的 version
git commit -m "release: v0.1.x"
git tag -a v0.1.x -m "v0.1.x"
git push origin v0.1.x
# CI 自动构建并发布到 GitHub Releases
```

### 5.5 构建环境要求

| 环境 | 要求 | 备注 |
|---|---|---|
| Windows | Windows 10/11 | 开发机 |
| Flutter SDK | >= 3.41.9 | 通过 `flutter upgrade` 更新 |
| Visual Studio | Build Tools 2022 | 需含 C++ 工作负载（CI 上预装） |
| Android | 不需要 | 当前仅桌面端 |
| Dart SDK | Dart 3.11+ | CLI 工具需要 |

---

## 六、测试覆盖

**当前 320+ 个测试，覆盖全部纯逻辑层 + AppTheme widget smoke test：**

### 原始测试（161 个）

| 测试文件 | 测试数 | 覆盖范围 |
|---|---|---|
| `test/core/models_test.dart` | 48 | Paper/Soul/Note/MemoryItem/ParseResult/SearchResult/AppConfig/AppError 完整序列化 + 边界 |
| `test/core/services_test.dart` | 29 | ExportService BibTeX(6), MergeService(6), PortraitService deepMerge(8), SoulService presets(8) |
| `test/core/config_test.dart` | 12 | ConfigService SharedPreferences 完整流程 + v4 新字段 |
| `test/core/translation_test.dart` | 18 | detectLanguage 全部 5 语种 + needsTranslation + 边界 |
| `test/core/api_test.dart` | 24 | DioClient/LLMConfig + ArxivApi XML 解析(15) + SearchResult 映射 |
| `test/core/mineru_test.dart` | 8 | MineruApi parseState(7状态) + MineruTask 终端判定 |
| `test/core/utils_test.dart` | 20 | RetryInterceptor isRetryable(11) + Logger sanitize(8) |
| `test/widget_test.dart` | 1 | AppTheme smoke test |

### 新增测试（159 个，v0.1.3）

| 测试文件 | 测试数 | 覆盖范围 |
|---|---|---|
| `test/core/llm_provider_test.dart` | 48 | LLMProvider buildClaudeBody/extractContent/endpoint/body, HttpsInterceptor, DioHttpsInterceptor, LLMConfig |
| `test/core/translation_edge_test.dart` | 30 | detectLanguage CJK 边界/Unicode/截断, needsTranslation 边界, validateLatex |
| `test/core/parse_service_test.dart` | 21 | MergeService unicode/边界, ParseService buildPageRanges(1~500页拆分) |
| `test/core/search_service_test.dart` | 18 | SearchService dedup 去重（DOI/标题/来源排序） |
| `test/core/mineru_edge_test.dart` | 22 | parseState 全状态, extractZip(ZIP解压/md/image/隐藏文件/空ZIP) |
| `test/core/export_service_test.dart` | 15 | generateBibtex 逗号作者/多分隔符DOI/单字/LaTeX括号 |
| `test/core/models_edge_test.dart` | 43 | Paper/AppConfig/Note/SearchResult/MemoryItem/Soul/ParseResult/AppError 边界 |
| `test/core/services_edge_test.dart` | 21 | PortraitService deepMerge, SoulService 全预设校验, ExportService titleKey |

**未覆盖领域：**
- UI 组件（SoulSelector / AvatarPicker / ExplainDialog）— 需 widget test
- 页面（SearchPage / ReadPage / SettingsPage / LibraryPage）
- MemoryService/NoteService I/O 路径 — 需文件系统 mock
- PaperService 集成路径 — 需 mock MinerU API + DeepSeek API

---

## 七、已知问题与注意事项

| 问题 | 说明 |
|---|---|
| API Key 存 SharedPreferences | 加密后存 SharedPreferences，加密依赖 Windows DPAPI（v0.1.2 已修复 GetProcessHeap 从错误 DLL 查找的 bug） |
| MinerU API 定价 | 云端 MinerU API 日限额 1000 页，超出后优先级降低；需付费或自部署 |
| MinerU API 连接 | 部分网络环境下代理/VPN 可能拦截对 `mineru.net` 的 HTTPS 请求，导致 SocketException。CLI 工具可通过 `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` 环境变量控制 |
| 小语种检测 | 语言检测仅支持中/日/韩/英/俄，其他语言统一判断为英文 |
| 翻译后格式校验 | 仅校验 `$$` 成对性，复杂 LaTeX 结构可能被 LLM 破坏 |
| 记忆注入上限 | 每次对话最多注入最近 10 条记忆，超出部分被忽略 |
| CLI 自动翻译 | `translates` 命令绕过语言检测直接调用 LLM，与 Flutter UI 的 `TranslationService.translate()` 一致（含 validateLatex） |
| CLI summarize 401 | 某些端点（如 OpenCode Go）对包含 `## ` markdown 格式的 system prompt 返回 401，已在 CLI 中修复为简单格式 |
| CLI 搜索代理 | 本地代理（`HTTP_PROXY`）可能阻止 arXiv/S2 API 访问，设置 `HTTP_PROXY=""` 可绕过 |
| `windows/runner/main.cpp` | 文件关联的 env var `PAPERPAL_PDF_PATH` 仅在 C++ runner 中设置 |
| S2 API 429 限频 | Semantic Scholar 免费 API 100 req/5min，超出后搜索结果缺失，不影响 arXiv 结果 |

---

## 八、未来规划

| 阶段 | 内容 | 预估 |
|---|---|---|
| Phase 3 | APK 移动端（Android） | 5-6 天 |
| Phase 3+ | iOS 适配 | 待定 |
| Phase 3+ | PDF 标注/高亮 | 待定 |
| — | 更多 LLM Provider（本地 Ollama） | 1 天 |
| — | Zotero 集成 | 2-3 天 |
| — | 引用网络可视化 | 待定 |
| — | MinerU Agent 轻量 API 兜底 | 1 天 |

### v0.2.0 已完成功能 — Alice in Wonderland UI Redesign

- **Alice 主题双系统**：深紫+暖金暗色 / 暖白+金日间主题，一键切换
- **动感渐变背景**：3 点径向渐变 + 花色暗纹叠加
- **全新图标**：256×256 爱丽丝主题应用图标（♠♥♦♣）
- **Inno Setup 安装包**：`windows/installer.iss`，CI 自动构建 .exe 安装程序
- **字体系统**：Playfair Display（标题）、Inter（UI）、Noto Serif SC（中文阅读）
- **动画系统**：页面过渡、错列入场、扑克牌花色加载、骨架屏
- **页面美化**：6 个页面全部重新设计（欢迎页/搜索页/文库/阅读/对话/设置）
- **自定义组件**：animated_background, card_spinner, skeleton_loader, progress_bar, page_transition
- **App 图标重新设计**

### v0.1.5 已完成功能

### v0.1.4 已完成功能

- **CLI 测试工具** — `tool/paperpal.dart`，12 个命令覆盖搜索/导入/解析/AI 问答/摘要/翻译/导出/灵魂/笔记/记忆/画像
- **lib/core/ 纯 Dart 化** — `avatar_service.dart` 和 `config.dart` 剥离 Flutter 依赖，`soul_presets.dart` 独立提取
- **BibTeX 元数据增强** — `import url` 自动调用 arXiv API 补全论文元数据
- **`papers show` 新增** — 查看论文 markdown 或翻译内容
- **`import search` 已实现** — 从搜索结果直接下载并解析
- **YAML frontmatter** — `export markdown` 输出添加标题/作者/年份/DOI 头
- **全方位测试** — 161 → 320 测试，新增 8 个测试文件
- **全链路 CLI 测试** — 对真实 arXiv PDF 完成 12 个命令测试，搜索/解析/AI 问答/摘要/翻译/导出/笔记 均正常

### v0.1.3 已完成功能

- **全方位测试扩展** — 161 → 320 测试
- **APIs 公开化** — 多个私有方法改为公开便于测试
- **extractContent 空列表崩溃修复**

### v0.1.2 已完成功能

- **MinerU API v4 迁移** — 从已废弃的 v2 同步接口迁移至 v4 异步任务架构
- **论文库管理** — 按状态筛选 + 单篇/批量删除 + 错误详情展示
- **下载进度** — 搜索页实时百分比 + PDF 文件头校验 + User-Agent 头
- **设置页扩展** — MinerU 模型版本选择 + 公式/表格开关
- **全方位测试** — 27 → 161 测试
- **Bug修复** — DPAPI DLL 查找修正、下载 RangeError、SettingsPage initState 崩溃、MinerU 错误消息改进

---

## 九、联系方式

**仓库：** https://github.com/jonah791/alice-paperpal  
**作者：** @jonah791  

如有问题，请在 GitHub 仓库提交 Issue。
