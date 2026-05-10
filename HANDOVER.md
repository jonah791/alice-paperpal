# ALICE PaperPal — 项目交接文档

**项目名：** ALICE PaperPal  
**版本：** v0.1.0  
**仓库：** https://github.com/jonah791/alice-paperpal  
**技术栈：** Flutter (Dart) 桌面端 Windows EXE  
**构建状态：** CI 自动构建 → Release 发布

---

## 一、项目概述

PaperPal 是一款基于 MinerU + DeepSeek V4 的论文辅助阅读桌面工具。支持搜索论文、导入 PDF、自动解析、自动翻译、AI 问答与摘要。核心特色是「AI 生命感系统」——灵魂、记忆、画像、头像让 AI 伙伴像真人一样陪伴用户阅读论文。

### 核心能力一览

| 能力 | 技术方案 |
|---|---|
| PDF 解析 | MinerU API（云端） |
| AI 对话 | DeepSeek V4 Flash / OpenAI / Claude |
| 论文搜索 | arXiv API + Semantic Scholar API |
| 本地存储 | Local 文件系统 + SharedPreferences |
| API Key 加密 | Windows DPAPI（`dart:ffi` 调用 `crypt32.dll`） |
| 桌面框架 | Flutter Windows（原生 C++ runner） |
| CI/CD | GitHub Actions（analyze → test → build → release） |

---

## 二、项目结构

```
paperpal/
├── lib/
│   ├── main.dart                          # 入口 + Dependencies DI
│   │
│   ├── core/
│   │   ├── api/                           # 外部 API 客户端（5 文件）
│   │   │   ├── arxiv_api.dart             # arXiv 搜索
│   │   │   ├── dio_client.dart            # 共享 Dio 工厂（HTTPS + 重试）
│   │   │   ├── llm_provider.dart          # LLM 提供者（流式/非流式）
│   │   │   ├── mineru_api.dart            # MinerU PDF 解析
│   │   │   └── s2_api.dart                # Semantic Scholar 搜索
│   │   │
│   │   ├── models/                        # 数据模型（7 文件）
│   │   │   ├── app_error.dart
│   │   │   ├── config.dart                # + AppThemeMode 枚举
│   │   │   ├── note.dart                  # 笔记
│   │   │   ├── paper.dart                 # 论文（含 toJson/fromJson）
│   │   │   ├── parse_result.dart
│   │   │   ├── search_result.dart
│   │   │   └── soul.dart                  # 灵魂定义
│   │   │
│   │   ├── services/                      # 业务服务（13 文件）
│   │   │   ├── avatar_service.dart        # 头像管理
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
│   │   │   ├── soul_service.dart          # 灵魂管理
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
│       ├── widgets/                       # 组件（3 文件）
│       │   ├── avatar_picker.dart         # 头像选择器
│       │   ├── explain_dialog.dart        # 公式/表格解释
│       │   └── soul_selector.dart         # 灵魂选择器
│       │
│       └── theme/
│           └── app_theme.dart             # 亮/暗主题
│
├── test/                                  # 测试（7 文件，37 个测试）
│   ├── core/
│   │   ├── memory_test.dart
│   │   ├── models_test.dart
│   │   ├── note_test.dart
│   │   ├── portrait_test.dart
│   │   ├── services_test.dart
│   │   └── soul_test.dart
│   └── widget_test.dart
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
runApp(PaperWiseApp(/* 11 services */));

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

### 3.4 流式响应

```dart
// LLMProvider.chatStream() 实现
Stream<String> chatStream(List<Map<String, String>> messages) async* {
  final response = await _dio.post(
    '/v1/chat/completions',
    data: {...},
    options: Options(responseType: ResponseType.stream),
  );
  // 解析 SSE: "data: {...}\n\n"
  await for (final line in lines) {
    if (line.startsWith('data: ')) {
      final delta = json['choices'][0]['delta']['content'];
      yield delta;
    }
  }
}
```

---

## 四、模块详解

### 4.1 灵魂系统（Soul）

| 文件 | 说明 |
|---|---|
| `lib/core/models/soul.dart` | 灵魂数据模型 |
| `lib/core/services/soul_service.dart` | 预置 4 个 + 自定义 + 元灵魂 |

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

### 5.1 本地构建

```bash
git clone https://github.com/jonah791/alice-paperpal.git
cd alice-paperpal
flutter pub get
flutter build windows --release
```

产物：`build/windows/x64/runner/Release/paperpal.exe` + DLL 文件

### 5.2 CI/CD 自动构建

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

### 5.3 发布新版

```bash
# 更新 CHANGELOG.md 中的版本
# 修改 pubspec.yaml 中的 version
git commit -m "release: v0.1.1"
git tag -a v0.1.1 -m "v0.1.1"
git push origin v0.1.1
# CI 自动构建并发布到 GitHub Releases
```

### 5.4 构建环境要求

| 环境 | 要求 | 备注 |
|---|---|---|
| Windows | Windows 10/11 | 开发机 |
| Flutter SDK | >= 3.41.9 | 通过 `flutter upgrade` 更新 |
| Visual Studio | Build Tools 2022 | 需含 C++ 工作负载（CI 上预装） |
| Android | 不需要 | 当前仅桌面端 |

---

## 六、测试覆盖

**当前 37 个测试，覆盖：**

| 测试文件 | 测试数 | 覆盖范围 |
|---|---|---|
| `test/core/models_test.dart` | 17 | Paper/ParseResult/SearchResult/AppConfig + TranslationService |
| `test/core/soul_test.dart` | 5 | Soul 模型序列化 |
| `test/core/memory_test.dart` | 5 | MemoryItem 序列化 |
| `test/core/note_test.dart` | 4 | Note 模型 CRUD |
| `test/core/services_test.dart` | 4 | ConfigService + ExportService |
| `test/core/portrait_test.dart` | 2 | PortraitService |
| `test/widget_test.dart` | 0 | 空壳 |

**未覆盖领域：**
- API 客户端（LLMProvider / MineruApi / ArxivApi / S2Api）— 需 mock HTTP
- UI 组件（SoulSelector / AvatarPicker / ExplainDialog）— 需 widget test
- 页面（SearchPage / ReadPage / SettingsPage / LibraryPage）
- 核心服务（PaperService / SoulService / ParseService / MemoryService）

---

## 七、已知问题与注意事项

| 问题 | 说明 |
|---|---|
| API Key 存 SharedPreferences | 加密后存 SharedPreferences，但加密仅在 Windows 上生效（DPAPI） |
| MinerU API 定价 | 云端 MinerU API 日限额 1000 页，超出后优先级降低；需付费或自部署 |
| 小语种检测 | 语言检测仅支持中/日/韩/英/俄，其他语言统一判断为英文 |
| 翻译后格式校验 | 仅校验 `$$` 成对性，复杂 LaTeX 结构可能被 LLM 破坏 |
| 记忆注入上限 | 每次对话最多注入最近 10 条记忆，超出部分被忽略 |
| `windows/runner/main.cpp` | 文件关联的 env var `PAPERPAL_PDF_PATH` 仅在 C++ runner 中设置 |

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

---

## 九、联系方式

**仓库：** https://github.com/jonah791/alice-paperpal  
**作者：** @jonah791  

如有问题，请在 GitHub 仓库提交 Issue。
