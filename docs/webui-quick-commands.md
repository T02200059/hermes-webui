# WebUI quick_commands — Design Document

## Problem

Hermes `config.yaml` 的 `quick_commands`（alias + exec 类型自定义斜杠命令）只在 CLI (`cli.py:8164`)
和 Gateway (`gateway/run.py:7121`) 工作。WebUI 有自己的前端 slash 解析（`static/commands.js`），
不走 Gateway dispatch，所以完全看不到 `quick_commands`。

## Design

### Architecture

```
config.yaml                     WebUI Backend                  WebUI Frontend
quick_commands:        GET ──→  /api/quick-commands  ──→  _quickCommandsCache
  s:                           (read config.yaml)          getMatchingCommands()
    type: alias                                             send() intercept
    target: /status        POST ──→ /api/quick-commands/exec
  gwrestart:                       (subprocess, 30s timeout)
    type: exec
    command: hermes gateway restart
```

### 决策

| 决策 | 选项 | 选型 | 理由 |
|---|---|---|---|
| exec 执行位置 | 前端 vs 后端 | 后端 | 浏览器不能跑 shell，必须后端 subprocess |
| alias 展开方式 | 递归 send() vs 内联 dispatch | 递归 send() | 内联需重复 COMMANDS 匹配逻辑；递归复用 send() 全链路（echo、agent commands、plugin commands） |
| API 端点 | 合并 vs 分离 | 分离 GET/POST | GET 只读列表、POST 执行命令，语义清晰 |
| 自动补全注入 | 同步 vs 异步 | 异步（同 _agentCommandCache） | 首屏不阻塞，后续调用命中缓存 |

### 文件改动

```
api/routes.py         +55  GET /api/quick-commands + POST /api/quick-commands/exec
static/commands.js    +30  _quickCommandsCache, _loadQuickCommands(), 自动补全注入, 预加载
static/messages.js    +40  send() 里 alias 递归 send() + exec POST
```

总计 ~125 行，零新依赖。

### 安全

- exec 类型用 `subprocess.run(shell=True)`，与 CLI/Gateway 行为一致
- 30s 超时防止僵尸进程
- API 受 WebUI 现有 auth 保护（password-based session）
- 不暴露 shell 命令原文到前端（exec 类型只返回 desc 用于自动补全）

### 限制

- alias 目标里的 CLI-only flag（`--provider`, `--global`）不被 WebUI handler 支持
  例：`/modelgrok → /model grok-4.3 --provider xai-oauth --global` 展开正确但 cmdModel 不认识 flag
- exec 类型需要在浏览器实测确认（`/gwrestart` 太危险未测）

### 验证

- [x] GET `/api/quick-commands` 返回 config.yaml 的 6 条命令
- [x] 自动补全 `getMatchingCommands('s')` 返回 `s|quick-alias`
- [x] `/s` → `/status` alias 展开正确，单条 echo
- [x] `/modelgrok` → `/model grok-4.3 ...` 展开正确
- [ ] exec 类型端到端（需安全命令测试）
