# PaperPal

基于 [MinerU](https://github.com/opendatalab/MinerU) + DeepSeek V4 的论文辅助阅读桌面工具。

搜索论文、导入 PDF、自动解析、自动翻译、AI 问答与摘要。

## 快速开始

### 1. 环境要求

- **Flutter SDK** 3.29+（[安装指南](https://docs.flutter.dev/get-started/install/windows)）
- **Windows 10/11**

### 2. 构建

```bash
# 克隆仓库
git clone https://github.com/<user>/PaperPal.git
cd PaperPal

# 安装依赖
flutter pub get

# 构建 Windows EXE
flutter build windows --release
```

构建产物在 `build/windows/x64/runner/Release/PaperPal.exe`。

### 3. 下载安装包

从 [Releases](https://github.com/<user>/PaperPal/releases) 下载最新版 `PaperPal.exe`。

### 4. 首次使用

1. 双击运行
2. 在设置页填入 DeepSeek API Key（[注册获取](https://platform.deepseek.com)）
3. 搜索论文或上传 PDF
4. 自动解析 + 自动翻译 → 开始阅读

## 功能

| 功能 | 说明 |
|---|---|
| **论文搜索** | arXiv + Semantic Scholar 一键搜索，下载即解析 |
| **本地上传** | 选择本地 PDF，自动解析 |
| **URL 导入** | 粘贴 arXiv 链接，自动下载 |
| **PDF 文件关联** | 双击 .pdf 自动用 PaperPal 打开（运行 `windows/install_assoc.bat`） |
| **自动解析** | MinerU 引擎：公式 → LaTeX、表格 → HTML、图片提取 |
| **大 PDF 分批** | 超过 50 页自动分批，合并后无感 |
| **自动翻译** | 非中文论文自动检测 + DeepSeek 全文翻译，原文/译文/对照三模式 |
| **AI 问答** | 基于论文全文智能问答 |
| **摘要生成** | 一句话 + 结构化摘要 |
| **公式解释** | 选中公式 → AI 解读 |
| **多论文对比** | 长按选择多篇论文 → AI 对比分析 |
| **笔记系统** | 阅读时添加笔记，持久化保存 |
| **导出** | Markdown / BibTeX 导出 |
| **暗黑模式** | 跟随系统 / 手动切换 |
| **论文库** | 本地缓存 + 持久化，重启不丢失 |

## 架构

```
PaperPal (Flutter Desktop)
    │
    ├── MinerU API       PDF → Markdown/LaTeX/HTML
    ├── DeepSeek V4 API  问答 / 翻译 / 摘要
    ├── arXiv API        论文搜索
    └── Semantic Scholar 论文搜索
```

**无自建后端服务器。** 所有 API 直连外部服务，用户自备 API Key。

## 项目结构

```
PaperPal/
├── lib/
│   ├── main.dart                    # 入口 + Dependencies DI
│   ├── core/
│   │   ├── api/                     # 外部 API 客户端
│   │   ├── models/                  # 数据模型（手写）
│   │   ├── services/                # 业务服务
│   │   └── utils/                   # 工具
│   └── ui/
│       ├── pages/                   # 页面
│       ├── widgets/                 # 组件
│       └── theme/                   # 主题
├── test/
├── pubspec.yaml
├── API.md                           # 外部 API 契约
└── THIRD_PARTY_NOTICES.md           # 第三方许可
```

## 配置

| 配置项 | 说明 | 默认 |
|---|---|---|
| LLM API Key | DeepSeek / OpenAI / Claude | 必填 |
| LLM API Base | OpenAI 兼容 API 地址 | `https://api.deepseek.com` |
| MinerU Endpoint | 解析服务地址 | `https://mineru.net/api/v2` |
| 自动翻译 | 非中文论文自动翻译 | 开启 |
| 批次大小 | 大 PDF 每批页数 | 50 |

## 技术栈

- **框架:** Flutter (Dart)
- **桌面:** 原生 Flutter Windows（无需 Python）
- **解析:** MinerU API（可自部署）
- **LLM:** DeepSeek V4 / OpenAI / Claude
- **搜索:** arXiv + Semantic Scholar
- **安全:** HTTPS 强制 / 加密 Key 存储 / 日志脱敏
- **CI:** GitHub Actions (analyze → test → build)

## 许可

[Apache 2.0](LICENSE)

## 致谢

- [MinerU](https://github.com/opendatalab/MinerU) — 高精度文档解析引擎
- [DeepSeek](https://deepseek.com) — LLM API
- [arXiv](https://arxiv.org) — 论文搜索 API
- [Semantic Scholar](https://semanticscholar.org) — 论文搜索 API
- [Syncfusion](https://www.syncfusion.com) — PDF 库（社区许可）
