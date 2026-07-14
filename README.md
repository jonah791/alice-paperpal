<div align="center">

# ALICE PaperPal

**读论文，有人陪。**

[![Flutter](https://img.shields.io/badge/Flutter-3.41+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white)]()
[![Platform](https://img.shields.io/badge/Android-34D058?logo=android&logoColor=white)]()
[![Tests](https://img.shields.io/badge/tests-320+-brightgreen)]()
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/jonah791/alice-paperpal?label=v0.4.0)](https://github.com/jonah791/alice-paperpal/releases)
[![Tests](https://img.shields.io/badge/tests-340+-brightgreen)]()

**基于 MinerU + DeepSeek V4 的 AI 论文阅读伴侣。**
**搜索论文 → 导入 PDF → 自动解析 → 自动翻译 → AI 问答与摘要。**
**一位有灵魂、有记忆、有性格的 AI 伙伴，陪你读懂每一篇论文。**

[⬇ 下载](https://github.com/jonah791/alice-paperpal/releases/latest)
[Docs](API.md)
[CLI 工具](tool/paperpal.dart)

---

</div>

## Why PaperPal?

读论文是孤独的——密密麻麻的公式、晦涩的术语、陌生的领域。PaperPal 不只是一个工具，它是一位**有生命的学术伙伴**。

| 它能做什么 | 你获得什么 |
|---|---|
| 自动解析 PDF 中的公式和表格 | 不再对着 LaTeX 发愣 |
| 非中文论文自动翻译 | 母语阅读，速度翻倍 |
| AI 问答基于全论文上下文 | 像教授一样随时答疑 |
| 记住你讨论过的一切 | 伙伴了解你的研究轨迹 |
| 4 种灵魂人格任选 | 找到最合拍的学术搭档 |

## ✨ 亮点

- **🎭 AI 灵魂系统** — 4 个预置角色（学术导师 / 代码专家 / 审稿人 / 科普达人），也可用自然语言创造专属于你的 AI 伙伴
- **🧠 永不遗忘的记忆** — 每次对话自动摘要，跨 session 注入。你的 AI 伙伴记得两天前你问过什么
- **📖 从搜索到理解，全流程覆盖**

  ```
  搜索论文 → 一键导入 → 自动解析(MinerU) → 自动翻译 → AI 问答 + 摘要 + 笔记 + 导出
  ```

- **🎨 Alice in Wonderland 主题** — 深紫+暖金暗色 / 暖白+金日间双主题，动感渐变背景，扑克牌花色装饰。每一处细节都经设计
- **📱 桌面 & 移动端** — Windows 安装包 + Android APK，数据互通，体验一致
- **🔒 隐私优先** — 无后端服务器，API Key 加密存储（DPAPI / Android Keystore），日志脱敏

## 快速开始

### Windows

```bash
# 1. 下载安装包
# 从 Releases 下载 ALICE-PaperPal-v*-Setup.exe
# 或 ZIP 便携版（解压即用）

# 2. 运行，填入 API Key
# 3. 开始阅读
```

### Android

从 [Releases](https://github.com/jonah791/alice-paperpal/releases) 下载 `paperpal-v*-app-arm64-v8a-release.apk`（约 25MB），安装到 Android 7.0+ 设备。

### CLI（无需 GUI，适合脚本/服务器环境）

```bash
git clone https://github.com/jonah791/alice-paperpal.git
cd alice-paperpal

# 配置
dart run tool/paperpal.dart config set llm-api-key <key>

# 搜索 → 导入 → 问答，一行搞定
dart run tool/paperpal.dart search "transformer attention"
dart run tool/paperpal.dart import search 0
dart run tool/paperpal.dart ask <id> "核心贡献是什么？"
```

完整的 12 个子命令覆盖搜索、导入、解析、问答、摘要、翻译、导出、灵魂管理、笔记、记忆、画像。

```bash
dart run tool/paperpal.dart help
```

### 从源码构建

```bash
git clone https://github.com/jonah791/alice-paperpal.git
cd alice-paperpal
flutter pub get

flutter build windows --release   # → paperpal.exe
flutter build apk --release       # → app-release.apk
```

## 全景功能

### AI 灵魂与陪伴

| 功能 | 说明 |
|---|---|
| **灵魂系统** | 4 个预置角色 + 用自然语言创建自定义灵魂（LLM 自动生成完整人格设定） |
| **元灵魂** | 底层生命规则——会引用过往对话、表达不确定性、自我纠正 |
| **对话记忆** | 自动摘要，跨 session 注入，AI 伙伴记得你讨论过的内容 |
| **用户画像** | LLM 自动学习你的兴趣偏好，无感维护 |
| **启动问候** | 每次打开，AI 伙伴根据最近记忆说一句自然的话 |

### 论文处理

| 功能 | 说明 |
|---|---|
| **搜索** | arXiv + Semantic Scholar 一键搜索，实时下载进度 |
| **导入** | 本地上传 / URL 导入（自动补全元数据）/ 搜索结果直接导入 |
| **解析** | MinerU v4 API — 公式→LaTeX、表格→HTML、图片提取 |
| **翻译** | 自动语言检测 + DeepSeek 全文翻译，原文/译文/对照三模式 |
| **公式解释** | 点击任意公式 → AI 解读 |
| **多论文对比** | 选择多篇论文 → AI 对比分析 |

### 阅读与管理

| 功能 | 说明 |
|---|---|
| **文库管理** | 按状态筛选、批量删除、错误详情查看 |
| **笔记系统** | 阅读时添加笔记，持久化保存，支持 LaTeX 高亮标记 |
| **AI 摘要** | 一句话 + 结构化摘要 |
| **AI 问答** | 流式输出逐字显示，基于灵魂+记忆+画像的个性化回答 |
| **导出** | Markdown（含 YAML frontmatter）/ BibTeX |

### 视觉体验

| 功能 | 说明 |
|---|---|
| **双主题** | 深紫+暖金暗色 / 暖白+金日间，一键切换 |
| **动感背景** | Canvas 径向渐变缓慢漂移 + 花色暗纹叠加 |
| **自定义字体** | Playfair Display（标题）+ Inter（UI）+ Noto Serif SC（中文） |
| **页面过渡** | cubic-bezier 滑入动画 |
| **加载动画** | 扑克牌花色错位淡入 + 骨架屏 |
| **阅读进度** | 3px 金色渐变进度条 |

### 跨平台

| 功能 | 说明 |
|---|---|
| **Windows** | 安装包 + 便携版，PDF 文件关联 |
| **Android** | APK，自适应底部导航，Android Keystore 加密 |
| **CLI** | 纯 Dart，不依赖 Flutter，12 个命令覆盖全部功能 |

## 技术栈

```
Frontend:    Flutter 3.41+ / Material 3
Desktop:     Flutter Windows (native C++ runner)
Mobile:      Android 7.0+ (API 24+)
Parsing:     MinerU v4 API (async task model)
LLM:         DeepSeek V4 / OpenAI / Claude
Search:      arXiv API + Semantic Scholar API
Security:    DPAPI (desktop) + Android Keystore (mobile) / log sanitization
UI Theme:    Custom dual ColorScheme (deep purple + gold / warm cream + gold)
UI Fonts:    Playfair Display / Inter / Noto Serif SC
Packaging:   Inno Setup (Windows) / APK (Android)
CI/CD:       GitHub Actions (analyze → test → build → release)
```

## 项目结构

```
paperpal/
├── lib/
│   ├── main.dart           # Entry + DI + AnimatedBackground
│   ├── core/                # Pure Dart, no Flutter dependency
│   │   ├── api/             # 5 API clients
│   │   ├── models/          # 8 data models
│   │   ├── services/        # 14 services (incl. platform abstraction)
│   │   └── utils/           # 4 utilities
│   └── ui/
│       ├── pages/           # 7 pages
│       ├── widgets/         # 10 reusable widgets
│       └── theme/           # Dual Alice-in-Wonderland theme
├── android/                 # Android project
├── test/                    # 320+ unit tests
├── tool/                    # CLI (12 commands)
└── windows/                 # Windows project + installer script
```

## 配置

| 配置项 | 说明 | 默认 |
|---|---|---|
| LLM API Key | DeepSeek / OpenAI / Claude | 必填 |
| MinerU API Key | MinerU 解析服务 Token | 必填 |
| LLM API Base | OpenAI 兼容 API 地址 | `https://api.deepseek.com` |
| MinerU 模型版本 | vlm（推荐）/ pipeline / MinerU-HTML | `vlm` |
| 公式识别 / 表格识别 | 解析时是否提取 | 开启 |

## 许可

[Apache 2.0](LICENSE)

## 致谢

- [MinerU](https://github.com/opendatalab/MinerU) — 高精度文档解析引擎
- [DeepSeek](https://deepseek.com) — LLM API
- [arXiv](https://arxiv.org) — 论文搜索 API
- [Semantic Scholar](https://semanticscholar.org) — 论文搜索 API
- [Syncfusion](https://www.syncfusion.com) — PDF 库（社区许可）
