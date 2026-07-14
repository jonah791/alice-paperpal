# MinerU Fallback 轻量 PDF 解析管线

## Problem

PaperPal 当前 100% 依赖 MinerU self-host 服务做 PDF→Markdown 解析。
新用户必须先部署 MinerU（Docker Compose + GPU）才能使用，这是最大的上手障碍。
MinerU 本身也有单点故障风险（服务下线/超时/API Key 过期）。

## Design

### 核心思路

不修改现有 MinerU 管线，在 `ParseService` 下游加一条 fallback 链。
仅在 MinerU 抛出异常时触发。

### 架构

```
importPdf()
  ├─ MinerU (现有完整管线)
  │   ├─ 成功 → ParseResult (type=mineru)，无变化
  │   └─ 失败 → fallback 链
  │       ├─ Level 1: pdf_text (poppler) → 非结构化 markdown + section 启发式拆分
  │       ├─ Level 2: pdf_text (flutter_pdf) → 按页逐字提取，无 section
  │       └─ Level 3: 仅元数据 → 空 markdown + 文件名做标题
  └─ 所有路径都返回 ParseResult → UI 层无感知
```

### 文件变更

#### 新增：`lib/core/services/pdf_fallback_service.dart`

```dart
class PdfFallbackService {
  Future<ParseResult> parseAsText(File pdfFile, int pageCount);
  ParseResult _parseWithPoppler(File pdfFile);
  ParseResult _parseWithFlutterPdf(File pdfFile);
  String _detectSection(String line);
}
```

- `parseAsText` 返回值兼容 `ParseResult`（markdown, title, empty imagePaths/contentListJson）
- `_parseWithPoppler` 调用 poppler-utils 的 `pdftotext.exe`，按空白行启发式拆 sections
- `_parseWithFlutterPdf` 使用现有 `syncfusion_flutter_pdf` 按页提取，无 section 识别
- 两种方法都提取标题（第一行加 `# `）并做简单 section 标记（`## Introduction`, `## Method` 等 heuristic）

#### 修改：`lib/core/services/paper_service.dart`

- `importPdf()` catch 块调用 `PdfFallbackService.parseAsText()`
- fallback 成功的 paper 标记 `PaperStatus.parsed`，但在 cache 中附带 `{parser: "fallback_text"|"fallback_raw"}`
- 仅在 fallback 也失败时才设 `PaperStatus.error`

#### 修改：`lib/core/services/parse_service.dart`

- 无改动。现有 `MineruApi` 依赖不变。

#### 修改：`lib/core/models/parse_result.dart`

- 新增字段 `String sourceType = 'mineru'`（取值：`mineru`, `fallback_text`, `fallback_raw`）

#### 修改：`lib/ui/pages/read_page.dart`

- 当 `parseResult.sourceType != 'mineru'` 时，顶部显示横幅提示「轻量解析模式，部分格式可能不完整」
- 图片仍正常渲染（无图则无图片错误），数学公式降级为纯文本
- 翻译/QA 功能不受影响（LLM 处理源是 markdown 文本，无论解析方式）

### 依赖

- `poppler-utils` (pdftotext) — 运行时依赖，在 `PATH` 中检测，不存在则跳 Level 1 直接走 Level 2
- `syncfusion_flutter_pdf` — 已存在，Level 2 使用

### 测试

#### 新增：`test/core/services/pdf_fallback_service_test.dart`

1. PDF → poppler 提取 → 非空 markdown
2. PDF → flutter_pdf 提取 → 非空 markdown
3. poppler 不可用时自动降级 Level 2
4. 空/损坏 PDF → Level 3 元数据模式
5. `sourceType` 正确标记

#### 新增：`test/integration/pdf_parse_fallback_test.dart`

1. 真实 PDF 通过 fallback 管线 → 可读 markdown
2. MinerU 模拟失败 → fallback 触发 → paper 状态为 `parsed` 非 `error`

### 向后兼容

- 所有现有测试不修改（不影响 MinerU 路径）
- `ParseResult.sourceType` 默认 `'mineru'`，所有现有消费者不受影响
- 缓存 key 不变，但已缓存的 `parsed` paper 无需 re-parse
