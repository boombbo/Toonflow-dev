# Cursor 自运行系统检索说明

## 目的

让 Cursor 每次修改前先检索、先计划、再执行，避免乱改、漏扫、误杀进程、误改主流程。

## 使用方式

### 只读自检

```powershell
powershell -ExecutionPolicy Bypass -File tools/dev/cursor-self-scan.ps1
```

输出：`docs-dev/CURSOR_SELF_SCAN_REPORT.md`

### 生成任务报告

```powershell
powershell -ExecutionPolicy Bypass -File tools/dev/cursor-task-report.ps1
```

输出：`docs-dev/CURSOR_LAST_TASK_REPORT.md`

## 工作流

1. 自检（`cursor-self-scan.ps1`）
2. 阅读 `docs-dev` 与 `.cursor/rules` 必查文档
3. 搜索相关源码（`rg`，排除 node_modules / dist）
4. 输出计划（Task Type / Planned Files / Forbidden Files）
5. 执行最小修改
6. 运行验证
7. 输出变更报告（见 `30-toonflow-change-report.mdc`）

## 安全边界

- 默认不改业务代码。
- 默认不改 `package.json` / `yarn.lock`。
- 默认不改数据库。
- 默认不杀进程（自检脚本仅探测端口）。
- 默认不清空 `data`。
- 默认不写密钥；脚本不读取 `.env`。

## Cursor 规则文件

| 文件 | 作用 |
|------|------|
| `.cursor/rules/00-toonflow-autonomous-retrieval.mdc` | 改代码前必检索、必答清单 |
| `.cursor/rules/10-toonflow-safe-edit-policy.mdc` | 禁改清单与优先策略 |
| `.cursor/rules/20-toonflow-known-facts.mdc` | 端口、Skill、高定模板等事实 |
| `.cursor/rules/30-toonflow-change-report.mdc` | 任务完成报告格式 |

## 推荐配合

若仓库中已有下列脚本，可与自检联用（本任务未强制创建）：

- `tools/dev/start-toonflow-dev.ps1`
- `tools/dev/stop-toonflow-dev.ps1`
- `tools/dev/check-toonflow-dev.ps1`

## 固定节奏

```text
先扫描 → 再计划 → 再执行 → 再报告 → 再验证
```
