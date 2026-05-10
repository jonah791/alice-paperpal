# ALICE PaperPal

**ALICE PaperPal** — 基于 MinerU + DeepSeek V4 的论文辅助阅读桌面工具。

搜索论文、导入 PDF、自动解析、自动翻译、AI 问答与摘要。AI 伙伴会记住你的偏好和过往对话，像真人一样陪伴你阅读论文。

## 快速开始

### 下载安装

从 [Releases](https://github.com/jonah791/alice-paperpal/releases) 下载最新版 `paperpal.exe`。

### 从源码构建

```bash
git clone https://github.com/jonah791/alice-paperpal.git
cd alice-paperpal
flutter pub get
flutter build windows --release
```

构建产物在 `build/windows/x64/runner/Release/paperpal.exe`。

### 首次使用

1. 双击运行
2. 在设置页填入 DeepSeek API Key（[注册获取](https://platform.deepseek.com)）
3. 选择或创建一个 AI 伙伴（灵魂）
4. 搜索论文或上传 PDF
5. 自动解析 + 自动翻译 → 开始阅读

## 功能

| 功能 | 说明 |
|---|---|
| **AI 灵魂** | 预置 4 个角色（学术导师/代码专家/审稿人/科普达人），也可用自然语言创建自定义灵魂 |
| **元灵魂** | 底层生命规则，让 AI 伙伴自然地引用过往、表达情绪、说"我不确定" |
| **对话记忆** | 每次对话自动生成摘要，跨 session 注入，AI 伙伴记得你之前讨论过什么 |
| **用户画像** | LLM 自动维护你的兴趣和偏好，你不需要做任何操作 |
| **头像系统** | 内置默认头像 + 从相册选择，AI 伙伴有一个"脸" |
| **论文搜索** | arXiv + Semantic Scholar 一键搜索，实时下载进度 |
| **本地上传** | 选择本地 PDF，自动解析 |
| **URL 导入** | 粘贴 arXiv 链接或 PDF 直链，自动下载 |
| **PDF 文件关联** | 双击 .pdf 自动用 PaperPal 打开（运行 `windows/install_assoc.bat`） |
| **自动解析** | MinerU v4 API 异步解析：公式 → LaTeX、表格 → HTML、图片提取 |
| **论文库管理** | 按状态筛选（已解析/已翻译/错误），支持批量删除 |
| **自动翻译** | 非中文论文自动检测 + DeepSeek 全文翻译，原文/译文/对照三模式 |
| **AI 问答** | 流式输出，逐字显示，基于灵魂+记忆+画像的个性化回答 |
| **摘要生成** | 一句话 + 结构化摘要 |
| **公式解释** | 点击公式 → AI 解读 |
| **多论文对比** | 长按选择多篇论文 → AI 对比分析 |
| **笔记系统** | 阅读时添加笔记，持久化保存 |
| **导出** | Markdown / BibTeX 导出 |
| **暗黑模式** | 跟随系统 / 手动切换 |
| **论文库** | 本地缓存 + 持久化，重启不丢失 |

## 架构

```
ALICE PaperPal (Flutter Desktop)
    │
    ├── MinerU v4 API     PDF → Markdown/LaTeX/HTML（异步任务提交 → 轮询）
    ├── DeepSeek V4 API   问答 / 翻译 / 摘要
    ├── arXiv API         论文搜索
    └── Semantic Scholar  论文搜索
```

**无自建后端服务器。** 所有 API 直连外部服务，用户自备 API Key。

## 项目结构

```
paperpal/
├── lib/
│   ├── main.dart                    # 入口 + Dependencies DI
│   ├── core/
│   │   ├── api/                     # 外部 API 客户端
│   │   ├── models/                  # 数据模型
│   │   ├── services/                # 业务服务
│   │   └── utils/                   # 工具
│   └── ui/
│       ├── pages/                   # 页面
│       ├── widgets/                 # 组件
│       └── theme/                   # 主题
├── test/                            # 131 个单元测试
├── pubspec.yaml
├── API.md                           # 外部 API 契约
└── THIRD_PARTY_NOTICES.md           # 第三方许可
```

## 配置

| 配置项 | 说明 | 默认 |
|---|---|---|
| LLM API Key | DeepSeek / OpenAI / Claude | 必填 |
| LLM API Base | OpenAI 兼容 API 地址 | `https://api.deepseek.com` |
| MinerU API Key | MinerU 解析服务 Token | 必填 |
| MinerU 模型版本 | vlm（推荐）/ pipeline / MinerU-HTML | `vlm` |
| 公式识别 | 是否提取 LaTeX 公式 | 开启 |
| 表格识别 | 是否提取 HTML 表格 | 开启 |
| 自动翻译 | 非中文论文自动翻译 | 开启 |

## 技术栈

- **框架:** Flutter (Dart)
- **桌面:** 原生 Flutter Windows（无需 Python）
- **解析:** MinerU v4 API（异步任务模型，支持预签名上传）
- **LLM:** DeepSeek V4 / OpenAI / Claude
- **搜索:** arXiv + Semantic Scholar
- **安全:** HTTPS 强制 / DPAPI 加密 Key 存储 / 日志脱敏
- **测试:** 131 个单元测试覆盖 models/services/utils/API
- **CI:** GitHub Actions (analyze → test → build → release)

## 许可

[Apache 2.0](LICENSE)

## 致谢

- [MinerU](https://github.com/opendatalab/MinerU) — 高精度文档解析引擎
- [DeepSeek](https://deepseek.com) — LLM API
- [arXiv](https://arxiv.org) — 论文搜索 API
- [Semantic Scholar](https://semanticscholar.org) — 论文搜索 API
- [Syncfusion](https://www.syncfusion.com) — PDF 库（社区许可）
