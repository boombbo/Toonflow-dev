# Cursor Self Scan Report

## Time

- Local: 2026-05-19 19:00:06
- UTC: 2026-05-19 11:00:06 UTC

## Repo

- Root: `D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB`
- Toonflow-app: present
- Toonflow-web: present
- locked_tony_original_anime_v1 template: present

## Environment

- node: 
- yarn: 1.22.22

## Ports

| Port | Role | Status | PID |
|------|------|--------|-----|
| 10588 | Backend API | IN USE | 55380 |
| 50188 | Frontend Vite | IN USE | 62116 |

## Services

- Health `http://localhost:10588/api/gridDirector/health`: OK (200)
- Frontend `http://localhost:50188`: OK (200)

## Docs

- OK: docs-dev/TOONFLOW_PROJECT_MAP.md
- OK: docs-dev/SETTINGS_MODULES_DEEP_MAP.md
- OK: docs-dev/SKILL_MD_LOADING_MAP.md
- OK: docs-dev/MODEL_PROVIDER_MAP.md
- OK: docs-dev/MODEL_SERVICE_PANEL_DEEP_MAP.md
- OK: docs-dev/LOCAL_DEV_NO_AUTH_MODE.md
- OK: docs-dev/LOCKED_TONY_TEMPLATE_IMPLEMENTATION.md
- OK: docs-dev/PROJECT_CREATE_FLOW_MAP.md
- OK: docs-dev/PROJECT_LOCKED_TEMPLATE_FLOW_MAP.md
- OK: docs-dev/CURSOR_AUTONOMOUS_RETRIEVAL.md

## Cursor Rules

- OK: .cursor/rules/00-toonflow-autonomous-retrieval.mdc
- OK: .cursor/rules/10-toonflow-safe-edit-policy.mdc
- OK: .cursor/rules/20-toonflow-known-facts.mdc
- OK: .cursor/rules/30-toonflow-change-report.mdc

## Git Status

```
(no .git in repo root 鈥?skip git commands)
```

## Recent Files

```
(n/a)
```

## Warnings

- Repo root is not a git repository
- Port 10588 in use 鈥?second backend yarn dev will EADDRINUSE unless reusing existing server

## Suggested Next Step

1. Reuse existing backend on :10588; avoid starting duplicate yarn dev.
2. Frontend reachable at http://localhost:50188
3. Before code edits: run ``tools/dev/cursor-task-report.ps1`` and read docs-dev per .cursor/rules.
