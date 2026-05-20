# Toonflow 全局架构总图

> 只读扫描生成 · Mermaid 可在支持 Mermaid 的编辑器中预览

---

## 1. 仓库结构图

```mermaid
flowchart TB
  subgraph root["工作区 BBBBBBBBBBBB"]
    APP["Toonflow-app<br/>Express + Electron + data"]
    WEB["Toonflow-web<br/>Vue3 + Vite"]
    DOCS["docs-dev<br/>地图与流程文档"]
    TOOLS["tools/dev<br/>启动器 + Cursor 自检"]
    RULES[".cursor/rules<br/>Agent 约束"]
    CONFIG["config/styles<br/>YAML 权威源"]
  end
  APP --> DATA_SKILLS["data/skills"]
  APP --> DATA_VENDOR["data/vendor"]
  APP --> DATA_DB["data/db2.sqlite"]
  WEB --> DIST["dist → 集成到 app/data/web"]
```

---

## 2. 本地启动与端口图

```mermaid
flowchart LR
  START["start-toonflow-dev.ps1<br/>-Mode reuse/ask/restart"]
  P10588{"10588<br/>监听?"}
  HEALTH["GET /api/gridDirector/health"]
  BACKEND["Toonflow-app<br/>yarn dev<br/>TOONFLOW_LOCAL_DEV=1"]
  P50188{"50188<br/>监听?"}
  FRONT["Toonflow-web<br/>yarn dev"]
  BROWSER["浏览器<br/>localhost:50188"]
  START --> P10588
  P10588 -->|否/重启| BACKEND
  P10588 -->|复用| HEALTH
  BACKEND --> HEALTH
  HEALTH --> P50188
  P50188 -->|否/重启| FRONT
  P50188 -->|复用| BROWSER
  FRONT --> BROWSER
```

---

## 3. HTTP API 路由图

```mermaid
flowchart TB
  UI["Toonflow-web<br/>axios baseURL<br/>:10588/api"]
  APP["Toonflow-app app.ts"]
  AUTH["localMode / JWT<br/>中间件"]
  ROUTER["router.ts<br/>自动生成"]
  ROUTES["src/routes/**/*.ts"]
  RESP["success() / error()"]
  UI --> APP --> AUTH --> ROUTER --> ROUTES --> RESP
```

---

## 4. Agent 模型调用图

```mermaid
flowchart TB
  PA["productionAgent"]
  SA["scriptAgent"]
  AI["u.Ai.Text / Image / Video"]
  RESOLVE["resolveModelName"]
  DEPLOY["o_agentDeploy<br/>vendorId:modelName"]
  VENDOR["o_vendorConfig"]
  ADAPTER["data/vendor/openai.ts …"]
  SDK["Vercel AI SDK<br/>streamText / generateText"]
  API["第三方 / 本地 OpenAI-Compatible API"]
  PA --> AI
  SA --> AI
  AI --> RESOLVE --> DEPLOY --> VENDOR --> ADAPTER --> SDK --> API
```

---

## 5. Skill 加载图

```mermaid
flowchart TB
  PROJ["o_project"]
  ART["artStyle → art_skills/&lt;artName&gt;/driector_skills/*.md"]
  STORY["directorManual → story_skills/&lt;storyName&gt;/driector_skills/*.md"]
  PROD_SK["production_skills/*.md"]
  PA["productionAgent"]
  TOOL["activate_skill"]
  PROJ --> ART --> PA
  PROJ --> STORY --> PA
  PROD_SK --> PA
  PA --> TOOL
```

> 目录名 `driector_skills` 为代码固定错拼，勿改名。

---

## 6. 高定模板图

```mermaid
flowchart TB
  STYLE["artStyle = locked_tony_original_anime_v1"]
  PREFIX["prefix.md"]
  AP["art_prompt/*.md<br/>art_character / art_storyboard_video …"]
  DS["driector_skills 00~06"]
  GAP["getArtPrompt()<br/>HTTP 硬锁"]
  PA["productionAgent<br/>软锁 Skill"]
  OUT["prompt_text / video_prompt / negative_prompt"]
  STYLE --> PREFIX
  STYLE --> AP --> GAP --> OUT
  STYLE --> DS --> PA --> OUT
  PREFIX --> GAP
```

---

## 7. 项目创建图

```mermaid
flowchart LR
  DIALOG["projectDialog.vue"]
  ADD["POST /api/project/addProject"]
  DB["o_project"]
  GET["GET /api/project/getProject"]
  PINIA["Pinia project store"]
  SCRIPT["/scriptAgent"]
  PROD["/production"]
  DIALOG --> ADD --> DB --> GET --> PINIA
  PINIA --> SCRIPT
  PINIA --> PROD
```

---

## 8. 宫格分镜当前路线图

```mermaid
flowchart TB
  subgraph now["当前推荐路径"]
    PA["productionAgent"]
    SKILL["grid_director_storyboard Skill"]
    TABLE["storyboard table / panel"]
    PROMPT["prompt_text + video_prompt"]
    LOCK["locked_tony style contract"]
    PA --> SKILL --> TABLE --> PROMPT --> LOCK
  end
  subgraph later["后续 P3"]
    API["gridDirector createJob …"]
    WEB["views/gridDirector"]
    JOB["data/grid-director/runs"]
    API --> WEB --> JOB
  end
  now -.->|Skill 跑通后| later
```

---

## 相关文档

- 扫描详情：`PROJECT_GLOBAL_SCAN_REPORT.md`
- 任务索引：`PROJECT_NEXT_ACTION_INDEX.md`
