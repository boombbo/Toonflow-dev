# Toonflow 开发启动器

详细命令见 [tools/dev/README.md](../tools/dev/README.md)。

## 推荐工作流

1. `start-toonflow-dev.ps1`（默认 `ask`）
2. 开发中：`check-toonflow-dev.ps1`
3. 结束：`stop-toonflow-dev.ps1`

## 安全策略

- 杀进程前校验 commandLine / 可执行路径是否包含本仓库 `Toonflow-app` 或 `Toonflow-web`。
- 非本项目占用 `10588` / `50188` 时只提示，不自动 `taskkill`。
- `-Mode restart` 必须配合 `-Force` 才会自动杀进程。
