# ALICE PaperPal — 项目交接文档

**项目名：** ALICE PaperPal  
**版本：** v0.3.1  
**仓库：** https://github.com/jonah791/alice-paperpal  
**技术栈：** Flutter (Dart) 桌面端 Windows EXE + Android APK + CLI 命令行工具  
**构建状态：** CI 自动构建 → Release 发布（ZIP 便携版 + Setup.exe 安装包 + split APK）

---

## 一、项目概述

### 产品定位

PaperPal 是一款面向科研人员、研究生和 AI 从业者的**论文辅助阅读工具**。核心价值主张是 **「AI 生命感系统」** —— 不只是工具，而是一位有灵魂、有记忆、有性格的 AI 伙伴，陪伴用户完成从论文搜索到深度理解的完整阅读流程。

### 目标用户
- 需要大量阅读论文的研究生和博士生
- 跨领域研究时快速上手陌生方向的科研人员
- 非英语母语者需要论文翻译辅助
- AI/ML 从业者追踪前沿进展

### 关键里程碑

| 版本 | 日期 | 核心交付 |
|---|---|---|
| v0.1.0 | 2026-05-09 | 初始版本：搜索/解析/翻译/问答 |
| v0.1.4 | 2026-05-11 | CLI 工具 + 纯 Dart 核心层 |
| v0.2.0 | 2026-05-11 | Alice in Wonderland UI 重设计 |
| v0.3.0 | 2026-05-11 | Android 移动端支持 + 跨平台架构 |

### 核心能力一览

### 核心能力一览

| 能力 | 技术方案 |
|---|---|
| PDF 解析 | MinerU v4 API（异步提交 → 轮询 → 下载 ZIP） |
| AI 对话 | DeepSeek V4 Flash / OpenAI / Claude |
| 论文搜索 | arXiv API + Semantic Scholar API |
| 本地存储 | Local 文件系统 + SharedPreferences |
| API Key 加密 | Windows DPAPI（`dart:ffi` 调用 `crypt32.dll` + `kernel32.dll`）<br>Android Keystore（`flutter_secure_storage`） |
| 桌面框架 | Flutter Windows（原生 C++ runner） |
| 移动框架 | Flutter Android（Kotlin runner，Android 7.0+） |
| CLI 工具 | 纯 Dart，`dart run tool/paperpal.dart`（无 Flutter 依赖） |
| UI 主题 | 自定义双主题 ColorScheme（深紫#07050D + 暖金#E8B84B / 暖白#FFFBF3 + 金#C28A2C） |
| UI 字体 | Google Fonts：Playfair Display（标题）、Inter（UI）、Noto Serif SC（中文阅读） |
| 打包分发 | 桌面：ZIP 便携版 + Inno Setup 安装包<br>Android：APK（CI 构建） |
| CI/CD | GitHub Actions（analyze → test → build → package → release） |

---

## 二、项目结构

```
paperpal/
├── lib/
│   ├── main.dart                          # 入口 + Dependencies DI + AnimatedBackground 包裹
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
│   │   ├── services/                      # 业务服务（14 文件，v0.3.0 新增平台抽象层）
│   │   │   ├── avatar_service.dart        # 头像管理（纯 Dart，Widget 移至 ui/）
│   │   │   ├── cache_service.dart         # 论文缓存
│   │   │   ├── config_service.dart        # 配置 + Key 加密存储
│   │   │   ├── export_service.dart        # 导出 Markdown/BibTeX
│   │   │   ├── memory_service.dart        # 对话记忆
│   │   │   ├── network_service.dart       # 网络状态检测
│   │   │   ├── note_service.dart          # 笔记 CRUD
│   │   │   ├── paper_service.dart         # 核心编排（最重要）
│   │   │   ├── parse_service.dart         # PDF 分批解析
│   │   │   ├── platform_service.dart      # [v0.3.0] 平台抽象层（加密/文件打开/路径）
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
│   └── ui/                                # Flutter UI 层
│       ├── pages/                         # 页面（7 文件）
│       │   ├── comparison_page.dart       # 多论文对比
│       │   ├── library_page.dart          # 论文库（含花色标记、金色装饰线、错列入场） 
│       │   ├── read_page.dart             # 阅读页（含 progress bar、高亮标记、styled eqblocks、笔记卡片、对话区）
│       │   ├── search_page.dart           # 搜索页（含错列入场动画、CardSpinner）
│       │   ├── settings_page.dart         # 设置页（金色 muted 标签、主题化输入框）
│       │   └── welcome_page.dart          # 欢迎页（金色渐变标题、花色装饰）
│       │
│       ├── widgets/                       # 组件（10 文件）
│       │   ├── animated_background.dart   # [v0.2.0] 动感渐变背景（Canvas 3 点径向漂移 + 花色暗纹）
│       │   ├── avatar_helpers.dart        # 默认头像构建（Flutter Widget）
│       │   ├── avatar_picker.dart         # 头像选择器（内联 ImagePicker）
│       │   ├── card_spinner.dart          # [v0.2.0] 扑克牌花色加载动画（8 花色错位淡入）
│       │   ├── explain_dialog.dart        # 公式/表格解释
│       │   ├── page_transition.dart       # [v0.2.0] 自定义页面过渡（cubic 贝塞尔滑入）
│       │   ├── progress_bar.dart          # [v0.2.0] 阅读进度条（3px 金色渐变）
│       │   ├── skeleton_loader.dart       # [v0.2.0] 骨架屏（呼吸闪烁占位）
│       │   └── soul_selector.dart         # 灵魂选择器（金色选中态）
│       │
│       └── theme/
│           └── app_theme.dart             # [v0.2.0 重写] 完整双主题 ColorScheme + 自字义 TextTheme/CardTheme/InputTheme/ButtonTheme
│
├── test/                                  # 测试（15+ 文件，320+ 测试）
│   ├── core/
│   │   ├── models_test.dart               # Paper/Soul/Note/MemoryItem 等序列化（48 测试）
│   │   ├── services_test.dart             # ExportService/MergeService/PortraitService/SoulService（29 测试）
│   │   ├── config_test.dart               # ConfigService SharedPreferences 流程（12 测试）
│   │   ├── translation_test.dart          # TranslationService 多语种检测（18 测试）
│   │   ├── api_test.dart                  # DioClient + ArxivApi XML 解析（24 测试）
│   │   ├── mineru_test.dart               # MinerUApi 状态解析 + MineruTask（8 测试）
│   │   ├── utils_test.dart                # RetryInterceptor/Logger 脱敏（20 测试）
│   │   ├── llm_provider_test.dart         # LLMProvider body/endpoint/extractContent（48 测试）
│   │   ├── parse_service_test.dart        # MergeService + buildPageRanges（21 测试）
│   │   ├── search_service_test.dart       # SearchService dedup 去重逻辑（18 测试）
│   │   ├── mineru_edge_test.dart          # MinerU extractZip + parseState（22 测试）
│   │   ├── export_service_test.dart       # BibTeX 边界（15 测试）
│   │   ├── models_edge_test.dart          # 模型边界 case（43 测试）
│   │   ├── services_edge_test.dart        # 服务边界 + soul 结构校验（21 测试）
│   │   └── translation_edge_test.dart     # validateLatex + CJK 边界（30 测试）
│   └── widget_test.dart                   # AppTheme smoke test（1 测试）
│
├── tool/                                  # CLI 命令行工具（12 命令）
│   ├── paperpal.dart                      # 入口，路由到子命令
│   ├── cli_state.dart                     # JSON 文件状态管理
│   ├── cli_context.dart                   # 灵魂+画像+记忆上下文装配
│   ├── cli_helpers.dart                   # 格式化输出、ANSI 颜色、--json
│   └── commands/                          # 12 个子命令文件
│
├── android/                             # Android 工程（v0.3.0 新增）
│   ├── app/src/main/AndroidManifest.xml  # 权限：INTERNET + ACCESS_NETWORK_STATE
│   └── app/build.gradle.kts              # minSdk 21, targetSdk 34
│
├── windows/                              # Windows 平台文件
│   ├── runner/main.cpp                    # 入口（含文件关联参数传递）
│   ├── runner/resources/app_icon.ico      # [v0.2.0] 256×256 爱丽丝主题图标
│   ├── installer.iss                      # [v0.2.0] Inno Setup 安装包脚本
│   ├── install_assoc.bat                  # PDF 文件关联注册
│   └── uninstall_assoc.bat                # PDF 文件关联卸载
│
├── docs/superpowers/                      # 设计文档与实施计划
│   ├── specs/                             # UI 设计文档
│   └── plans/                             # 实施计划
│
├── .github/workflows/build.yml            # CI/CD（含 Inno Setup 打包）
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
├── HANDOVER.md
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

### 3.3 Prompt 组装逻辑

```dart
最终 System Prompt =
  [灵魂.systemPrompt]    // 人格设定
  + [灵魂.speechPattern]  // 口头禅
  + [元灵魂规则]          // 底层行为（引用方式、不确定性表达、情绪）
```

### 3.4 CLI 测试工具架构

CLI 工具（`tool/paperpal.dart`）复用 `lib/core/` 中的纯 Dart 代码，绕过 Flutter 依赖：

```
dart run tool/paperpal.dart
    │
    ├── cli_state.dart        ~/.paperwise/ 目录 JSON 文件（替代 path_provider + SharedPreferences）
    ├── cli_context.dart      灵魂 + 画像 + 记忆上下文装配
    │
    └── commands/             12 个子命令
        ├── config            → 直接读写 JSON
        ├── search            → ArxivApi + S2Api
        ├── import            → MineruApi + ParseService + ArxivApi（元数据）
        ├── papers            → CLI 状态管理
        ├── ask               → LLMProvider + cli_context
        ├── summarize         → LLMProvider + cli_context
        ├── translate         → TranslationService + LLMProvider
        ├── export            → 内联 BibTeX + YAML frontmatter
        ├── soul              → soul_presets.dart + JSON
        ├── note              → JSON CRUD
        ├── memory            → JSON CRUD
        └── portrait          → JSON 读取
```

### 3.5 UI 渲染流水线（v0.2.0 新增）

```
main.dart: MaterialApp
    │
    ├── ThemeData            ← app_theme.dart（双主题 ColorScheme）
    ├── PageTransitionsTheme ← page_transition.dart（cubic 贝塞尔过渡）
    │
    └── _AppShellState.build()
        │
        ├── NavigationRail    ← 底部导航
        │
        └── AnimatedBackground    ← animated_background.dart（渐变层 + 花色暗纹）
            │
            └── IndexedStack
                ├── SearchPage     ← search_page.dart（错列入场 + CardSpinner）
                ├── LibraryPage    ← library_page.dart（花色标记 + 金色装饰线）
                ├── ReadPage       ← read_page.dart（progress bar + 高亮 + equation + note + chat）
                ├── ComparisonPage ← comparison_page.dart
                └── SettingsPage   ← settings_page.dart（金色 label + 主题输入框）
```

---

## 四、模块详解

### 4.1 主题系统（v0.2.0 重写）

| 文件 | 说明 |
|---|---|
| `lib/ui/theme/app_theme.dart` | 完整双主题，从 40 行扩展为 236 行 |

**暗色主题：** 灵感来自爱丽丝童话的「神秘花园」
| Token | 色值 | 用途 |
|---|---|---|
| `--bg` | `#07050D` | 场景背景（近乎纯黑带一丝紫） |
| `--surface` | `#120C1F` | 卡片/面板表面 |
| `--elevated` | `#1B1332` | 悬停/升高表面 |
| `primary` | `#9B6DF7` | 紫色品牌色 |
| `secondary` | `#E8B84B` | 金色强调色 |

**日间主题：** 暖白基底 + 紫色品牌色
| Token | 色值 | 用途 |
|---|---|---|
| `--bg` | `#FFFBF3` | 暖奶油背景 |
| `--surface` | `#FFFFFF` | 白色表面 |
| `--elevated` | `#FFF6E5` | 暖金色升高表面 |
| `primary` | `#6D28D9` | 深紫色品牌色 |
| `secondary` | `#C28A2C` | 温润金色 |

**字体系统：**
- `GoogleFonts.playfairDisplay()` — 标题、大字号展示（32-36px）
- `GoogleFonts.inter()` — UI 文字、正文（14-16px）、标签（11-12px）
- `Noto Serif SC` — 中文阅读（body 通过 system font fallback）

**组件主题覆盖：**
- `CardTheme` — 12px 圆角、金色边框（10% alpha）、0 elevation
- `InputDecorationTheme` — 深色填充、金色 focus 边框（1.5px）、8px 圆角
- `ElevatedButtonTheme` — 金色填充、50px 药丸圆角、Inter 字体 13px
- `DividerTheme` — 金色 8% alpha、1px 高
- `AppBarTheme` — 透明背景、0 elevation、Playfair Display 标题

### 4.2 灵魂系统（Soul）

| 文件 | 说明 |
|---|---|
| `lib/core/models/soul.dart` | 灵魂数据模型 |
| `lib/core/models/soul_presets.dart` | 灵魂预设定义（纯 Dart，独立提取） |
| `lib/core/services/soul_service.dart` | 预置 4 个 + 自定义 + 元灵魂（引用 soul_presets.dart） |

预置灵魂：

| ID | 名称 | 定位 | UI 标识 |
|---|---|---|---|
| `academic_mentor` | 学术导师 | 严谨专业，耐心解释 | 金色 A |
| `code_expert` | 代码专家 | 技术务实，关注实现 | 金色 C |
| `paper_reviewer` | 论文审稿人 | 批判性分析 | 金色 R |
| `science_communicator` | 科普达人 | 通俗类比，生动表达 | 金色 S |

**自定义灵魂流程：**
1. 用户输入名字 + 自然语言描述
2. 调用 LLM 生成完整灵魂 JSON
3. 存入 `~/.paperwise/souls/custom/{uuid}.json`

**元灵魂（Meta-Soul）：**
硬编码在 `soul_service.dart` 中，约 80 tokens。定义了连续性（记忆引用方式）、人性化（不确定性/情绪/自我纠正）、禁用语。用户不可见不可改，灵魂未定义时兜底。

### 4.3 记忆系统（Memory）

| 存储 | `~/.paperwise/memory.json` |
|---|---|
| 格式 | JSON 数组，每项带 id/summary/paperId/timestamp |
| 上限 | 最近 100 条 |
| 清理 | 超过 30 天自动归档 |
| 隔离 | 不隔离，所有灵魂共享（连续生命感） |

### 4.4 用户画像（Portrait）

| 存储 | `~/.paperwise/portrait.json` |
|---|---|
| 更新方式 | 每次对话流式完成后，后台异步调用 LLM 判断是否需要更新 |
| 用户感知 | 完全无感，不可见不可操作 |
| Schema | 不固定，LLM 可动态扩展字段 |

### 4.5 头像（Avatar）

| 默认头像 | 程序生成（首字母 + 固定色块） |
|---|---|
| 自定义 | `image_picker` 从相册选择，缩放至 256x256 |
| 存储 | `~/.paperwise/avatars/current.png` |
| 注意 | `buildDefaultAvatar` 移至 `lib/ui/widgets/avatar_helpers.dart`，`core/services/avatar_service.dart` 为纯 Dart |

### 4.6 UI 自定义组件（v0.2.0 新增）

#### AnimatedBackground（`lib/ui/widgets/animated_background.dart`）
- 使用 `AnimationController`（30s 循环）+ `CustomPainter`
- 两层 Canvas：_GradientPainter（3 组径向渐变，sin/cos 缓慢漂移） + _SuitPatternPainter（花色 Unicode 字符暗纹网格）
- 颜色自动适配当前主题色：secondary（金）和 primary（紫），4-6% 透明度
- 在 `main.dart` 的 `_AppShellState.build()` 中包裹 `IndexedStack`

#### PageTransition（`lib/ui/widgets/page_transition.dart`）
- 实现 `PageTransitionsBuilder` 接口
- Forward：从右侧滑入（`Offset(1.0,0) → Offset.zero`）
- Reverse：从左侧滑出（`Offset.zero → Offset(-1.0,0)`）
- 曲线：`Cubic(0.77, 0.0, 0.18, 1.0)`
- 注册给 Windows/Android/iOS 平台

#### ScrollProgressBar（`lib/ui/widgets/progress_bar.dart`）
- 监听 `ScrollController`，计算 `pixels / maxScrollExtent`
- `FractionallySizedBox` + `Container`（金色渐变 + 3px 高度 + 发光阴影）
- 在 `read_page.dart` 中通过 Stack 叠在内容上方

#### CardSpinner（`lib/ui/widgets/card_spinner.dart`）
- 8 个花色字符（♠♥♦♣ 各两轮）水平排列
- 每轮 3s 循环：淡入(15%) → 保持(35%) → 淡出(35%) → 消失(15%)
- 花色错位 0.125s，形成流水效果
- 使用 `AnimatedBuilder` + `AnimationController`（3s repeat）
- 替代 search_page 和 library_page 中的 `CircularProgressIndicator`

#### SkeletonLoader（`lib/ui/widgets/skeleton_loader.dart`）
- 呼吸闪烁动画（2s reverse repeat，alpha 6-10%）
- 接受 width/height/borderRadius 参数
- 在 library_page 加载时展示 5 个骨架卡片

### 4.7 页面 UI 变更（v0.2.0）

| 页面 | 变更 |
|---|---|
| **WelcomePage** | 金色渐变 Playfair Display 标题、花色浮动装饰、"掉进兔子洞" italic tagline、"进入奇妙世界" 按钮 |
| **SearchPage** | CardTheme 统一卡片样式、CardSpinner 替代加载指示器、TweenAnimationBuilder 错列入场动画 |
| **LibraryPage** | 花色标记（♠♥♦♣ 基于 paper.id.hashCode）、金色 3px 左侧装饰线、错列入场动画、骨架屏 |
| **ReadPage** | 金色高亮标记（18% bg Paint）、equation 金色容器（5% bg + 10% border）、笔记金色左框 + italic + metadata、阅读进度条 |
| **Chat/QA** | 用户气泡 primaryContainer 紫、AI 气泡 surfaceContainerHighest 金、AI 头像金色 CircleAvatar + 字母、打字指示器 gold |
| **SettingsPage** | 配置段标签改金色 muted uppercase（9px letter-spacing 2）、主题 CardTheme+InputTheme 自动生效 |
| **SoulSelector** | active chip：secondaryContainer bg + secondary text+border；inactive：transparent + outline border |

### 4.8 加密（Windows DPAPI）

```dart
// windows_encryption.dart
// 通过 dart:ffi 直接调用 crypt32.dll 的 CryptProtectData
// 加密后的密文 base64 编码后存入 SharedPreferences
// 解密失败时自动回退到明文（兼容旧版本）
```

**仅在 Windows 上可用。** 后续如果适配 Android，需要替换为 Android Keystore。

v0.3.0 已通过 `PlatformService` 抽象层实现了跨平台加密：桌面端使用 DPAPI，Android 端使用 `flutter_secure_storage`（Android Keystore）。

### 4.9 外部 API

| API | 端点 | 用途 | 限频 |
|---|---|---|---|
| MinerU | 标准：`POST /api/v4/extract/task`（URL提交）<br>`POST /api/v4/file-urls/batch` + `PUT`（文件上传）<br>Agent（免 Key）：`POST /api/v1/agent/parse/file`（≤10MB/20页） | PDF 解析 | 标准：1000 页/天高优先级<br>Agent：IP 限频 |
| DeepSeek | `POST /v1/chat/completions` | LLM 问答 | 500 RPM（免费用户） |
| arXiv | `GET http://export.arxiv.org/api/query` | 论文搜索 | 1 req/3s |
| Semantic Scholar | `GET https://api.semanticscholar.org/graph/v1/paper/search` | 论文搜索 | 100 req/5min |

详见 `API.md`。

### 4.10 依赖清单

| 包名 | 版本 (pubspec.lock) | 用途 | 平台限制 |
|---|---|---|---|
| `flutter` | SDK | 框架 | 跨平台 |
| `dio` | any | HTTP 客户端（MinerU/LLM/arXiv 请求） | 跨平台 |
| `shared_preferences` | any | 配置持久化 | 跨平台 |
| `path_provider` | any | 应用数据目录 | 跨平台 |
| `archive` | any | ZIP 解压（MinerU 解析结果） | 跨平台 |
| `flutter_math_fork` | any | LaTeX 公式渲染 | 跨平台 |
| `logging` | any | 结构化日志 | 跨平台 |
| `uuid` | any | 唯一 ID 生成 | 跨平台 |
| `synchronized` | any | 异步锁 | 跨平台 |
| `syncfusion_flutter_pdf` | any | PDF 页数检测 | 跨平台 |
| `connectivity_plus` | any | 网络状态监听 | 跨平台 |
| `image_picker` | any | 头像选择（相册/相机） | 跨平台 |
| `file_picker` | any | 论文文件选择 | 跨平台 |
| `ffi` | any | FFI 支持（DPAPI 底层） | 所有平台，但仅 Windows 使用 |
| `google_fonts` | any | Playfair Display/Inter/Noto Serif SC | 跨平台（首次需网络） |
| `flutter_secure_storage` | any | Android Keystore 加密 | 跨平台 |
| `open_filex` | any | Android 打开 PDF | 跨平台 |
| `window_manager` | any | 桌面窗口管理 | **仅 Windows** |
| `tray_manager` | any | 系统托盘 | **仅 Windows** |
| `flutter_test` | SDK | 测试框架 | 跨平台 |
| `flutter_lints` | any | Lint 规则 | — |

---

## 五、关键服务详解

### 5.1 PaperService — 核心编排（`lib/core/services/paper_service.dart`）

这是项目中**最复杂、最重要的服务**。它负责论文的完整生命周期，是 AI 问答、导入、解析、翻译的核心调度者。

| 方法 | 职责 | 涉及的外部依赖 |
|---|---|---|
| `importPdf(File)` | 本地 PDF 导入 → 保存到缓存 | `CacheService`, `MineruApi` |
| `importUrl(String)` | URL 论文导入 → 自动下载 PDF | `CacheService`, `MineruApi`, `ArxivApi`（补全元数据） |
| `importSearchResult(SearchResult, String)` | 搜索结果导入 → 下载 PDF | `SearchService`, `CacheService` |
| `parsePaper(String)` | 触发 MinerU 解析 → 轮询 → 获取结果 | `MineruApi`, `ParseService` |
| `askQuestionStream(String, String)` | AI 问答（流式） | `LLMProvider`, `SoulService`, `MemoryService`, `PortraitService` |
| `summarizePaper(String)` | 论文摘要 | `LLMProvider` |
| `translatePaper(String)` | 全论| AI 译文 | `TranslationService`, `LLMProvider` |

**AI 问答数据流：**（含灵魂+画像+记忆上下文装配流程如上文 3.2 节所示）

_Prompt 组装权重：灵魂人格 ~45% + 论文上下文 ~35% + 记忆 ~10% + 画像 ~10%_

### 5.2 PlatformService — 平台抽象层（`lib/core/services/platform_service.dart`）

v0.3.0 新增，解决桌面/移动端平台差异。所有平台特定逻辑集中于此，**业务代码不直接感知平台**。

```dart
abstract class PlatformService {
  Future<String> encrypt(String plainText);     // DPAPI (desktop) / Keystore (Android)
  Future<String?> decrypt(String cipherText);   // DPAPI (desktop) / Keystore (Android)
  Future<void> openFile(String path);           // Process.run (desktop) / open_filex (Android)
  Future<String> get dataPath;                  // path_provider (共通)
  bool get isDesktop;                           // Platform.isWindows
  bool get isAndroid;                           // Platform.isAndroid
}
```

通过 `createPlatformService()` 工厂方法在 `main()` 入口处创建一次，注入 `Dependencies`。`ConfigService` 通过构造参数接收 `PlatformService` 实例，替换原有的直接 `dpapi.encrypt()` 调用。

---

## 六、构建与发布

### 5.1 本地构建

**Windows 桌面版：**

```bash
git clone https://github.com/jonah791/alice-paperpal.git
cd alice-paperpal
flutter pub get
flutter build windows --release
```

产物：`build/windows/x64/runner/Release/paperpal.exe` + DLL 文件

**Android APK：**

```bash
flutter build apk --release --split-per-abi
```

产物：
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` — **ARM64**（主流手机，约 30MB，推荐下载）
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` — 32 位（老旧设备）
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` — 模拟器

> `--split-per-abi` 按 CPU 架构分别打包，每个 APK 只包含一套原生库。配合 `isMinifyEnabled=false` + `isShrinkResources=false` 避免 R8 压缩导致的 `play-core` 依赖冲突。

### 5.2 构建 Inno Setup 安装包（本地）

```bash
# 需要安装 Inno Setup: https://jrsoftware.org/isdl.php
iscc windows\installer.iss
```

产物：`build/installer/ALICE-PaperPal-{version}-Setup.exe`

### 5.3 运行 CLI 工具（无需 Flutter）

```bash
dart run tool/paperpal.dart help
dart run tool/paperpal.dart config set llm-api-key <key>
dart run tool/paperpal.dart search "attention mechanism"
```

### 5.4 CI/CD 自动构建

**文件：** `.github/workflows/build.yml`

**触发条件：** 推送 tag `v*`

**流程：**

```
                     ┌── analyze (flutter analyze)
                     │
master push / tag v* ── test (flutter test)
                     │
                     ├── deploy-windows ──────────────────────
                     │   ├── flutter build windows --release   │
                     │   ├── Package ZIP                          │
                     │   ├── Build installer (iscc)               │──→ GitHub Release
                     │   └── Upload via gh release create         │
                     │                                            │
                     └── deploy-android ─────────────────────     │
                         ├── flutter build apk --release           │
                         └── Upload via gh release upload ────────┘
```

**构建产物：**
- `ALICE-PaperPal-v{version}.zip` — Windows 便携版，解压即用
- `ALICE-PaperPal-v{version}-Setup.exe` — Windows 安装包，含 PDF 文件关联
- `paperpal-v{version}-app-arm64-v8a-release.apk` — Android ARM64（主流手机，约 30MB）
- `paperpal-v{version}-app-armeabi-v7a-release.apk` — Android 32 位（老旧设备）
- `paperpal-v{version}-app-x86_64-release.apk` — Android 模拟器

**注意：** Release 需要 `permissions: contents: write` 权限，已经在 workflow 中配置。

### 5.5 发布新版

```bash
# 1. 更新 CHANGELOG.md、pubspec.yaml 版本号
# 2. 提交并打 tag
git commit -m "release: v0.x.x"
git tag -a v0.x.x -m "v0.x.x"
git push origin v0.x.x
# 3. CI 自动构建并发布到 GitHub Releases
```

### 5.6 构建环境要求

| 环境 | 要求 | 备注 |
|---|---|---|
| Windows | Windows 10/11 | 开发机 |
| Flutter SDK | >= 3.41.9 | 通过 `flutter upgrade` 更新 |
| Visual Studio | Build Tools 2022 | 需含 C++ 工作负载（CI 上预装） |
| Android SDK | API 34+ | Android 构建需要（CI 上预装） |
| Java / Kotlin | JDK 17+ | Android 构建需要 |
| Inno Setup | 6.x（可选） | 仅本地构建安装包时需要 |

---

## 六、测试覆盖

**当前 320+ 个测试，覆盖全部纯逻辑层 + AppTheme widget smoke test：**

### 核心测试（161 个，v0.1.1-0.1.2）

| 测试文件 | 测试数 | 覆盖范围 |
|---|---|---|
| `test/core/models_test.dart` | 48 | Paper/Soul/Note/MemoryItem/ParseResult/SearchResult/AppConfig/AppError |
| `test/core/services_test.dart` | 29 | ExportService BibTeX(6), MergeService(6), PortraitService deepMerge(8), SoulService presets(8) |
| `test/core/config_test.dart` | 12 | ConfigService SharedPreferences 完整流程 + v4 新字段 |
| `test/core/translation_test.dart` | 18 | detectLanguage 全部 5 语种 + needsTranslation + 边界 |
| `test/core/api_test.dart` | 24 | DioClient/LLMConfig + ArxivApi XML 解析(15) + SearchResult 映射 |
| `test/core/mineru_test.dart` | 8 | MineruApi parseState(7状态) + MineruTask 终端判定 |
| `test/core/utils_test.dart` | 20 | RetryInterceptor isRetryable(11) + Logger sanitize(8) |
| `test/widget_test.dart` | 1 | AppTheme light/dark 有效性 |

### 扩展测试（159 个，v0.1.3）

| 测试文件 | 测试数 | 覆盖范围 |
|---|---|---|
| `test/core/llm_provider_test.dart` | 48 | buildClaudeBody/extractContent/endpoint/body/HttpsInterceptor |
| `test/core/translation_edge_test.dart` | 30 | CJK 边界/Unicode/截断/validateLatex |
| `test/core/parse_service_test.dart` | 21 | MergeService unicode/边界/buildPageRanges(1~500页) |
| `test/core/search_service_test.dart` | 18 | dedup 去重（DOI/标题/来源排序） |
| `test/core/mineru_edge_test.dart` | 22 | parseState 全状态/extractZip(ZIP/隐藏/空) |
| `test/core/export_service_test.dart` | 15 | BibTeX 逗号作者/多分隔符DOI/单字/LaTeX括号 |
| `test/core/models_edge_test.dart` | 43 | 全部模型边界 case |
| `test/core/services_edge_test.dart` | 21 | deepMerge/预设校验/titleKey |

**未覆盖领域：**
- UI 组件（SoulSelector / AvatarPicker / ExplainDialog）— 需 widget test
- 页面（SearchPage / ReadPage / SettingsPage / LibraryPage）
- MemoryService/NoteService I/O 路径 — 需文件系统 mock
- PaperService 集成路径 — 需 mock MinerU API + DeepSeek API

---

## 七、已知问题与注意事项

| 编号 | 问题 | 说明 |
|---|---|---|
| 1 | API Key 存 SharedPreferences | 加密后存 SharedPreferences，加密依赖 Windows DPAPI（v0.1.2 已修复 GetProcessHeap 从错误 DLL 查找的 bug） |
| 2 | MinerU API 定价 | 云端 MinerU API 日限额 1000 页，超出后优先级降低；需付费或自部署 |
| 3 | MinerU API 连接 | 部分网络环境下代理/VPN 可能拦截对 `mineru.net` 的 HTTPS 请求，导致 SocketException。CLI 工具可通过 `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` 环境变量控制 |
| 4 | 小语种检测 | 语言检测仅支持中/日/韩/英/俄，其他语言统一判断为英文 |
| 5 | 翻译后格式校验 | 仅校验 `$$` 成对性，复杂 LaTeX 结构可能被 LLM 破坏 |
| 6 | 记忆注入上限 | 每次对话最多注入最近 10 条记忆，超出部分被忽略 |
| 7 | CLI 自动翻译 | `translates` 命令绕过语言检测直接调用 LLM，与 Flutter UI 的 `TranslationService.translate()` 一致（含 validateLatex） |
| 8 | CLI summarize 401 | 某些端点（如 OpenCode Go）对包含 `## ` markdown 格式的 system prompt 返回 401，已在 CLI 中修复为简单格式 |
| 9 | CLI 搜索代理 | 本地代理（`HTTP_PROXY`）可能阻止 arXiv/S2 API 访问，设置 `HTTP_PROXY=""` 可绕过 |
| 10 | `windows/runner/main.cpp` | 文件关联的 env var `PAPERPAL_PDF_PATH` 仅在 C++ runner 中设置 |
| 11 | S2 API 429 限频 | Semantic Scholar 免费 API 100 req/5min，超出后搜索结果缺失，不影响 arXiv 结果 |
| 12 | AnimatedBackground 性能 | Canvas CustomPainter 每帧重绘，在低配机器上可能增加 CPU 占用。如遇性能问题可考虑降低帧率或禁用（用 `Opacity` 控制） |
| 13 | Google Fonts 加载 | 首次启动需要网络加载字体文件，之后缓存。无网络时回退到系统字体 |
| 14 | Android 文件选择 | `file_picker` 使用 SAF（Storage Access Framework），无需 `READ_EXTERNAL_STORAGE` 权限。Android 11+ 上用户可选择"授予全部文件访问权限" |
| 15 | Android 导航栏 | 自适应 `NavigationBar` 在 <360dp 宽设备上文字可能截断，考虑缩小图标/文字间距 |
| 16 | Android 返回键 | 当前未拦截系统返回键（返回即退出应用）。如需返回上一页/确认退出，需在 `MaterialApp` 中处理 `PopScope` |
| 17 | APK 未签名 | CI 构建的 APK 是 debug-unsigned。正式分发需配置 Android 签名（`key.properties` + `signingConfigs`） |
| 18 | R8 + Play Core 冲突 | `flutter build apk --release` 默认启用 R8，但 R8 会剥离 `play-core` 的 `SplitCompatApplication`。当前通过 `isMinifyEnabled=false` 跳过。如需 R8 压缩，需在 `proguard-rules.pro` 中添加 `play-core` 的 keep rules |
| 19 | MinerU 文件上传 403 | OSS 预签名上传 URL 的签名不包含 `Content-Type` 字段。Dio PUT 时若设置 `Content-Type` 头会导致签名校验失败返回 403。修复：PUT 时不设置 `Content-Type` 头（Dio 默认不发送该头即可） |
| 20 | MinerU 标准 API 文件上传依赖代理 | 通过 `/api/v4/file-urls/batch` 获取预签名 URL 后，PUT 上传文件到 OSS 时会受本地代理配置影响。如遇 `SocketException: Connection reset`，需清空 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量 |
| 21 | MinerU Agent API 备选 | MinerU 提供免 Token 的 Agent 轻量 API（`/api/v1/agent/parse/file`），限制 10MB/20 页，仅输出 Markdown。可作为标准 API 的 fallback，但当前 CLI 未实现自动降级 |

---

## 八、开发者快速指南

### 8.1 本地开发流程

```bash
# 1. 克隆
git clone https://github.com/jonah791/alice-paperpal.git
cd alice-paperpal

# 2. 安装依赖
flutter pub get

# 3. 运行测试（确保现有功能不受影响）
flutter test

# 4. 运行桌面版（热重载调试）
flutter run -d windows

# 5. 运行 Android 版（需连接设备或模拟器）
flutter run -d android

# 6. 构建 Release
flutter build windows --release   # → paperpal.exe
flutter build apk --release       # → app-release.apk
```

### 8.2 常见问题排查

| 症状 | 可能原因 | 解决 |
|---|---|---|
| `flutter build windows` 失败 `error RC2176` | ICO 文件格式不兼容 | 用 Python 重新生成：所有尺寸用 PNG 格式而非 BMP。见 `windows/runner/resources/app_icon.ico` |
| Android 构建报 `Deprecated Gradle` | Gradle 版本与 Flutter SDK 不匹配 | `flutter upgrade` 或调整 `android/gradle-wrapper.properties` 中的 Gradle 版本 |
| `windowManager.ensureInitialized()` 崩溃 | 在 Android 上运行（桌面插件不可用） | `PlatformService` 已在 `main()` 中做条件判断。确认 `!platform.isAndroid` 包裹了所有 `windowManager` 调用 |
| `dpapi.encrypt()` 返回 null | 在 Linux/测试环境运行（无 DPAPI） | `DesktopPlatformService.encrypt()` 已做 null → plaintext 回退。`ConfigService` 测试使用 `_TestPlatform` mock |
| CI Release 缺少 Windows 文件 | Release job 的 `download-artifact` 路径不匹配 | 改为每个 build job 直接用 `gh release upload` 上传，见 `.github/workflows/build.yml` |
| CLI 命令报 `401` | 某些 LLM 端点不支持 Markdown system prompt | 已在 `cli_helpers.dart` 中修复为纯文本格式 |
| `import pdf` 报 403 | OSS 预签名 URL 签名与请求头不匹配 | 移除 PUT 请求中的 `Content-Type` 头。详见 `mineru_api.dart` 中 `_submitFileUpload` 的 `_downloadDio.put()` 调用 |
| Google Fonts 不显示 | 网络不通或字体缓存未生效 | 检查网络连接，或在本地预下载字体文件 |

### 8.3 代码规范

- **命名风格**: Dart 标准（camelCase 变量/方法，PascalCase 类，lowercase_with_underscores 文件）
- **主题色引用**: 所有颜色从 `Theme.of(context).colorScheme` 获取，禁止硬编码色值
- **平台判断**: 通过 `configService.platform.isAndroid` / `.isDesktop`，不使用 `Platform.isXxx`
- **测试**: 核心逻辑必须写测试，UI 层至少保证编译通过
- **Commit 风格**: `type(scope): message` — `feat(ui):`, `fix(ci):`, `docs:`, `refactor(core):`

---

## 九、已知问题与注意事项

### 为什么选择 Alice in Wonderland 主题？
- 产品名称 "ALICE" 天然关联爱丽丝梦游仙境
- 项目已有的「灵魂/记忆/画像」系统已有拟人化设定，童话主题强化了这一印象
- 深紫+暖金色调在论文阅读场景中兼顾专业感与品牌辨识度
- 扑克牌花色（♠♥♦♣）作为装饰元素贯穿全 UI，建立了统一的视觉语言

### 为什么使用 Google Fonts 而非本地字体？
- 减少仓库体积（Playfair Display + Inter ≈ 300KB 字体文件）
- `google_fonts` 包自动缓存，首次加载后离线可用
- 方便未来更换字体而无需重新构建

### 为什么重写 ColorScheme 而不使用 colorSchemeSeed？
- `colorSchemeSeed` 生成的 palette 不可控，暗色模式下紫色/金色搭配不稳定
- 显式 ColorScheme 确保跨版本 Flutter 的一致性
- 精确控制每个语义色（primaryContainer、surfaceContainerHighest 等）的色值和透明度

### 为什么用 CustomPainter 而非静态图片做背景？
- 动效可以随主题切换自动变色
- 花色暗纹可编程控制密度/透明度
- 无额外图片资源体积
- 渐变位置缓动产生呼吸感

---

## 十、设计决策记录

### 为什么选择 Alice in Wonderland 主题？
- 产品名称 "ALICE" 天然关联爱丽丝梦游仙境
- 项目已有的「灵魂/记忆/画像」系统已有拟人化设定，童话主题强化了这一印象
- 深紫+暖金色调在论文阅读场景中兼顾专业感与品牌辨识度
- 扑克牌花色（♠♥♦♣）作为装饰元素贯穿全 UI，建立了统一的视觉语言

### 为什么使用 Google Fonts 而非本地字体？
- 减少仓库体积（Playfair Display + Inter ≈ 300KB 字体文件）
- `google_fonts` 包自动缓存，首次加载后离线可用
- 方便未来更换字体而无需重新构建

### 为什么重写 ColorScheme 而不使用 colorSchemeSeed？
- `colorSchemeSeed` 生成的 palette 不可控，暗色模式下紫色/金色搭配不稳定
- 显式 ColorScheme 确保跨版本 Flutter 的一致性
- 精确控制每个语义色（primaryContainer、surfaceContainerHighest 等）的色值和透明度

### 为什么用 CustomPainter 而非静态图片做背景？
- 动效可以随主题切换自动变色
- 花色暗纹可编程控制密度/透明度
- 无额外图片资源体积
- 渐变位置缓动产生呼吸感

### 为什么用 PlatformService 而非条件编译？
- 单 entry point 减少维护成本（不需要两个 main.dart）
- 平台差异对业务代码透明（业务层只调 `platform.openFile()`，不管底层实现）
- 新增平台支持只需添加新的 `PlatformService` 实现类
- 测试可以用 `_TestPlatform` 模拟任意平台

### 为什么 Android 用 BottomNavigationBar 而非 Drawer？
- BottomNavigationBar 是 Material 3 推荐的主导航方式，拇指操作友好
- 3 个 Tab 刚好匹配桌面 NavigationRail 的结构，`_currentIndex` 完全复用
- Drawer 适合更多导航项的场景（5+ 项）

---

## 十一、未来规划

| 阶段 | 内容 | 预估 |
|---|---|---|
| Phase 3+ | iOS 适配 | 待定 |
| Phase 3+ | PDF 标注/高亮 | 待定 |
| — | 更多 LLM Provider（本地 Ollama） | 1 天 |
| — | Zotero 集成 | 2-3 天 |
| — | 引用网络可视化 | 待定 |
| — | MinerU Agent 轻量 API 兜底 | 1 天 |
| — | AnimatedBackground 性能优化 | 1 天 |
| — | UI widget test 覆盖 | 2 天 |
| — | Deep link（arxiv.org 链接直接打开） | 1 天 |
| — | Android 自适应横屏布局 | 1 天 |
| — | 自动 APK 签名配置 | 1 天 |

---

## 十二、版本历史

### v0.3.1（2026-05-12）— 架构清理与 Bug 修复

**架构改进：**
- `Dependencies` 从 `main.dart` 提取到 `lib/core/di/dependencies.dart`，消除页面直接引用入口文件的耦合
- CLI `search` 命令复用 `SearchService`，消除重复的去重逻辑

**Bug 修复：**
- 笔记残留：`NoteService` 注入 `PaperService`，删论文时自动删除关联笔记
- 搜索错误可见：`SearchService.search()` 返回 `(List<SearchResult>, String?)` tuple，UI 层可区分网络错误与空结果
- 搜索前检查网络状态：离线时直接提示而非静默失败

### v0.3.0（2026-05-11）— Android Mobile Support

**跨平台架构：**
- `PlatformService` 抽象层：`DesktopPlatformService` + `AndroidPlatformService`
- 桌面：DPAPI 加密 + `Process.run` 打开 PDF
- Android：`flutter_secure_storage`（Keystore）+ `open_filex`
- `main()` 中条件初始化 `window_manager`/`tray_manager`（Android 跳过）
- 单 entry point，单代码库，桌面/移动端共享 90%+ 代码

**自适应导航：**
- `LayoutBuilder` + 600dp 阈值：手机 → `NavigationBar`（底部），桌面 → `NavigationRail`（侧栏）
- 两端共享 `IndexedStack` + page list，`_currentIndex` 完全复用

**页面适配：**
- 阅读页笔记：280px 侧栏 → `DraggableScrollableSheet` BottomSheet
- 阅读页对照：Android 隐藏 side-by-side，仅原文/译文切换
- 阅读页 AppBar：5 个图标按钮 → `PopupMenuButton` 溢出菜单
- 搜索页：按钮 `Row` → `Wrap`，窄屏自动换行
- ExplainDialog：`SizedBox(560)` → `ConstrainedBox(maxWidth: 560)`

**Android 工程：**
- `flutter create --platforms=android`
- `AndroidManifest.xml`：INTERNET + ACCESS_NETWORK_STATE
- `build.gradle.kts`：minSdk 21, targetSdk 34
- 桌面包（window_manager/tray_manager）保留但条件跳过

**CI/CD：**
- 新增 `deploy-android` job（ubuntu-latest）
- `deploy-windows` 创建 Release 并上传 Windows 产物
- `deploy-android` 上传 APK 到同一 Release
- 修复：ICO 全 PNG 格式、choco --force、中文语言包移除

**APK 体积优化：**
- 启用 `--split-per-abi` 按 CPU 架构拆分，APK 从 59.8MB 降至 ~30MB（arm64-v8a）
- 禁用 R8 代码压缩（`isMinifyEnabled=false`）和资源压缩（`isShrinkResources=false`）
  - R8 因 `play-core` 依赖（`SplitCompatApplication`）缺少 keep rules 而失败
  - 30MB 已足够小，R8 收益有限，暂不启用
- CI 构建 3 个 ABIs：arm64-v8a / armeabi-v7a / x86_64

**Bug 修复：**
- MinerU 文件上传 403：OSS 预签名 URL 的签名不含 `Content-Type`，移除 PUT 请求中的 `Content-Type: application/octet-stream` 头解决

### v0.2.0（2026-05-11）— Alice in Wonderland UI Redesign

**主题系统：**
- 完整双主题 ColorScheme（深紫+暖金暗色 / 暖白+金日间）
- Playfair Display（标题）+ Inter（UI）+ Noto Serif SC（中文）字体系统
- CardTheme/InputDecorationTheme/ElevatedButtonTheme/DividerTheme/AppBarTheme

**UI 动效：**
- AnimatedBackground — 3 点径向渐变缓慢漂移 + 花色暗纹叠加
- PageTransition — cubic-bezier 滑入过渡
- ScrollProgressBar — 3px 金色渐变阅读进度条
- CardSpinner — 8 花色错位加载动画

**页面改造（6 页）：**
- WelcomePage — 金色渐变标题、花色装饰、爱丽丝 tagline
- SearchPage — 错列入场动画、CardSpinner 替代加载器
- LibraryPage — 花色标记、金色左侧装饰线、骨架屏
- ReadPage — 金色高亮、equation 容器、笔记金色左框、progress bar
- Chat/QA — 紫色气泡、金色气泡、金色头像、typing indicator
- SettingsPage — 金色 muted 标签、主题化输入

**自定义组件（5 新文件）：**
- animated_background.dart、page_transition.dart、progress_bar.dart、card_spinner.dart、skeleton_loader.dart

**其他：**
- 256×256 爱丽丝主题应用图标
- Inno Setup 安装包（windows/installer.iss）
- build.yml CI 新增 Inno Setup 打包步骤
- .gitignore 新增 .superpowers/

### v0.1.5（2026-05-11）
- CI 构建修复：read_page/soul_selector 中 buildDefaultAvatar 引用
- MergeService 多批处理数据保留
- LLMProvider RetryInterceptor
- 未使用 import 清理

### v0.1.4（2026-05-11）
- CLI 工具（12 命令）
- lib/core/ 纯 Dart 化
- BibTeX 元数据增强

### v0.1.3（2026-05-10）
- 161 → 320 测试扩展
- APIs 公开化
- extractContent 崩溃修复

### v0.1.2（2026-05-11）
- MinerU API v4 迁移
- 论文库筛选/批量删除
- 下载进度条
- DPAPI 修复

### v0.1.1（2026-05-11）
- MinerU v4 异步任务
- ParseService 重构
- SettingsPage 扩展

### v0.1.0（2026-05-09）
- 初始版本：搜索/上传/解析/翻译/问答/摘要

---

## 十三、联系方式

**仓库：** https://github.com/jonah791/alice-paperpal  
**作者：** @jonah791  

如有问题，请在 GitHub 仓库提交 Issue。
