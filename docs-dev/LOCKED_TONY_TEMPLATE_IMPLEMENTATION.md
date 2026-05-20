# locked_tony_original_anime_v1 高定模板 · 实施说明

> **阶段**：方案 A · 纯资产落盘（2026-05-19）  
> **未改**：DB、`addProject.ts`、`projectDialog.vue`、`ai.ts`、`productionAgent`、`scriptAgent`、`package.json`

---

## 1. 本次新增文件清单

```
Toonflow-app/data/skills/art_skills/locked_tony_original_anime_v1/
  README.md
  prefix.md
  art_prompt/
    image_prompt.md
    video_prompt.md
    negative_prompt.md
    art_character.md
    art_character_derivative.md
    art_prop.md
    art_prop_derivative.md
    art_scene.md
    art_scene_derivative.md
    art_storyboard_video.md
  driector_skills/
    00_style_lock_source.md
    01_style_contract.md
    02_prompt_contract.md
    03_character_identity_contract.md
    04_negative_prompt_contract.md
    05_storyboard_grid_contract.md
    06_self_check_contract.md

docs-dev/
  LOCKED_TONY_TEMPLATE_IMPLEMENTATION.md   ← 本文件
```

权威 YAML（仓库根，非 Toonflow 运行时读取）：`config/styles/locked_tony_original_anime_v1.yaml`

---

## 2. 每个文件作用

| 文件 | 轨 | 作用 |
|------|-----|------|
| `README.md` | 元数据 | 列表展示名（首行）、用法与禁止事项 |
| `prefix.md` | **硬锁出图** | `getArtPrompt` 自动前缀（若调用方请求到本目录下目标文件名） |
| `art_prompt/image_prompt.md` | 契约 | 图像 prompt 结构与参考图规则 |
| `art_prompt/video_prompt.md` | 契约 | 视频 anti-drift 与风格保持 |
| `art_prompt/negative_prompt.md` | 契约 | 全局负面词列表 |
| `driector_skills/00` | **Agent** | YAML 权威转写 |
| `driector_skills/01` | **Agent** | 最高风格宪法 |
| `driector_skills/02` | **Agent** | prompt 字段结构 |
| `driector_skills/03` | **Agent** | 角色参考图 identity-only |
| `driector_skills/04` | **Agent** | 负面词强制 |
| `driector_skills/05` | **Agent** | 宫格 / 父子宫格继承 |
| `driector_skills/06` | **Agent** | 交付前自检 |

**说明（硬锁出图轨）**：HTTP 代码通过 `getArtPrompt(artStyle, "art_skills", "<fileName>")` 读取固定文件名；已补齐 7 个别名（内容对齐 `image_prompt.md` / `video_prompt.md` + 类型规则）。`prefix.md` 由 `getArtPrompt` 自动前缀拼接。

---

## 3. 新建项目如何使用

1. 打开 **设置无关** → **我的项目** → **新建项目**  
2. 在视觉手册网格中选择 **`locked_tony_original_anime_v1`**（展示名：首行「全局锁 · Tony 原创航海少年可爱系（V1）」）  
3. **导演手册**：任选现有 `story_skills` 条目（本阶段未新增 story 模板）  
4. 填齐其它必填项后保存 → `o_project.artStyle = "locked_tony_original_anime_v1"`

---

## 4. productionAgent 测试

**前置**：后端 `yarn dev`、前端 `yarn dev`；已选项目且 `artStyle` 为本模板。

1. 进入 **制作** → 打开右侧 Production Agent 对话  
2. 发送测试 prompt（示例）：

```text
当前项目使用 locked_tony_original_anime_v1 高定模板。
请基于当前剧本生成 16 宫格动画分镜。
要求：
- 所有 prompt_text 必须继承 locked_tony_original_anime_v1
- 参考图只作为 identity / structure / content
- 不允许继承参考图画风
- 不允许 photorealistic / 3D / known anime character
- 每个 shot 必须包含 negative_prompt
- 输出 JSON
```

3. 观察子 Agent 是否 **activate_skill** 名称以 `locked_tony_original_anime_v1_` 开头的技能  
4. 检查输出 JSON 是否含 style fragments 与 negative_prompt  

**日志**：后端控制台可见 `⚡[主技能] ✓ 技能 "locked_tony_original_anime_v1_..." 已激活`

---

## 5. 验证 Skill 是否被扫描

| 方式 | 操作 |
|------|------|
| 新建项目弹窗 | `POST /project/getVisualManual` 列表应出现本模板 |
| Production | `createArtSkills("locked_tony_original_anime_v1", directorManual)` 扫描 7 个 driector md |
| 设置 · Skill 管理 | 若页面扫描 `data/skills/**/*.md`，应能看到本目录下文件（取决于扫描范围） |

**不要求** 出现在全局 `production_skills/`（已遵守：未放单项目守卫）。

---

## 6. 回滚

```powershell
Remove-Item -Recurse -Force "D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\Toonflow-app\data\skills\art_skills\locked_tony_original_anime_v1"
Remove-Item "D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\docs-dev\LOCKED_TONY_TEMPLATE_IMPLEMENTATION.md"
```

已绑定该 `artStyle` 的项目：编辑项目改选其它视觉手册，或删除项目。

---

## 7. 后续可选增强（本阶段未做）

| 项 | 说明 |
|----|------|
| `production_agent_decision.md` | 写明 locked 项目必先 activate style_contract |
| `productionAgent/index.ts` | 强制 append `01_style_contract` 正文（不依赖 LLM） |
| `projectDialog.vue` | 「高定模板」分组快捷卡片 |
| `addVisualManual.ts` | 保存 driector 时自动补 frontmatter |
| `o_project.lockedTemplateId` | 方案 B JSON 字段 |
| `art_prompt` 别名 | 复制契约为 `art_storyboard_video.md` 等以接通 `getArtPrompt` |

---

## 8. 相关文档

- `docs-dev/PROJECT_LOCKED_TEMPLATE_FLOW_MAP.md` — 链路扫描  
- `docs-dev/PROJECT_CREATE_FLOW_MAP.md` — 新建项目与 artStyle 绑定  
