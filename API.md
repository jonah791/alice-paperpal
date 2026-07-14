# API 契约文档

本文档记录 PaperPal 调用的所有外部 API，供 Desktop (Flutter) 和 Mobile (Flutter) 端实现参考。

## 1. MinerU API (v4)

解析 PDF 文档为结构化 Markdown。异步任务模式。

### 端点

| 操作 | 方法 | 路径 |
|---|---|---|
| 提交 URL 解析任务 | POST | `/api/v4/extract/task` |
| 获取上传链接（本地文件） | POST | `/api/v4/file-urls/batch` |
| 查询任务结果 | GET | `/api/v4/extract/task/{task_id}` |
| 查询批量结果 | GET | `/api/v4/extract-results/batch/{batch_id}` |

### 请求（URL 解析）

```json
{
  "url": "https://cdn-mineru.openxlab.org.cn/demo/example.pdf",
  "model_version": "vlm"
}
```

### 请求（本地文件上传）

1. 获取预签名上传 URL: `POST /api/v4/file-urls/batch`
2. `PUT` 文件到预签名 URL
3. 轮询批量结果

### 响应（URL 查询完成时）

```json
{
  "code": 0,
  "data": {
    "task_id": "...",
    "state": "done",
    "full_zip_url": "https://cdn-mineru.openxlab.org.cn/pdf/..."
  }
}
```

### ZIP 内容

- `*.md` — Markdown 输出
- `*_content_list.json` — 结构化数据
- `images/` — 提取的图片

### 模型版本

| 值 | 说明 |
|---|---|
| `pipeline` | 默认 pipeline 模型 |
| `vlm` | VLM 模型（推荐） |
| `MinerU-HTML` | HTML 专用

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
