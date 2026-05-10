# API 契约文档

本文档记录 PaperPal 调用的所有外部 API，供 Desktop (Flutter) 和 Mobile (Flutter) 端实现参考。

## 1. MinerU API

解析 PDF 文档为结构化 Markdown。

### 端点

`POST /file_parse`

### 请求

multipart/form-data:

| 字段 | 类型 | 说明 |
|---|---|---|
| `file` | File | PDF 文件 |
| `start_page_id` | int (Form) | 起始页（从 0 开始），默认 0 |
| `end_page_id` | int (Form) | 结束页（从 0 开始），默认 99999 |

### 响应

ZIP 文件，包含:
- `*.md` — Markdown 输出
- `*_content_list.json` — 结构化数据
- `images/` — 提取的图片

## 2. DeepSeek API

兼容 OpenAI Chat Completions 格式。

### 端点

`POST /v1/chat/completions`

### 请求

```json
{
  "model": "deepseek-v4-flash",
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "..."}
  ],
  "max_tokens": 4096
}
```

### 响应

```json
{
  "choices": [{"message": {"content": "..."}}]
}
```

## 3. arXiv API

### 端点

`GET http://export.arxiv.org/api/query`

### 参数

| 参数 | 说明 |
|---|---|
| `search_query` | 搜索词 |
| `max_results` | 最大结果数 |
| `sortBy` | `relevance` / `submittedDate` |
| `sortOrder` | `descending` / `ascending` |

### 响应

Atom XML，解析 `<entry>` 元素:
- `<title>` — 标题
- `<author><name>` — 作者
- `<published>` — 发布日期
- `<summary>` — 摘要
- `<link title="pdf">` — PDF 链接

## 4. Semantic Scholar API

### 端点

`GET https://api.semanticscholar.org/graph/v1/paper/search`

### 参数

| 参数 | 说明 |
|---|---|
| `query` | 搜索词 |
| `limit` | 最大结果数 |
| `fields` | `title,authors,year,abstract,externalIds,openAccessPdf,citationCount` |

### 响应

```json
{
  "data": [{
    "title": "...",
    "authors": [{"name": "..."}],
    "year": 2024,
    "abstract": "...",
    "openAccessPdf": {"url": "..."},
    "externalIds": {"DOI": "..."},
    "citationCount": 100
  }]
}
```
