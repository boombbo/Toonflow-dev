# director_pipeline_v1 · Skill 落盘说明

> **日期**：2026-05-20  
> **模式**：asset_only（仅 `production_skills/` 根目录）  
> **未改**：`Toonflow-app/src/**`、`Toonflow-web/src/**`、`package.json`、`yarn.lock`

## 新增文件

| 文件 | frontmatter `name` |
|------|-------------------|
| `production_skills/director_pipeline_00_overview.md` | `director_pipeline_overview` |
| `production_skills/director_pipeline_01_chief_roadmap.md` | `director_pipeline_chief_roadmap` |
| `production_skills/director_pipeline_02_a_draft_grid.md` | `director_pipeline_a_draft_grid` |
| `production_skills/director_pipeline_03_b_normalize.md` | `director_pipeline_b_normalize` |
| `production_skills/director_pipeline_04_c_validate_main.md` | `director_pipeline_c_validate_main` |
| `production_skills/director_pipeline_05_d_subgrid.md` | `director_pipeline_d_subgrid` |
| `production_skills/director_pipeline_06_assembly_ac_report.md` | `director_pipeline_assembly_ac` |
| `production_skills/director_pipeline_07_export_prompt_manifest.md` | `director_pipeline_export_manifest` |

源文件：`user/files/0*_*.md`（内容原样复制，未改写正文）。

## 扫描路径

`productionAgent` → `useProductionSkills()` → `data/skills/production_skills/*.md`（扁平，无子目录）。

## 手工验收（P3-1）

1. 设置 → Skill 管理，搜索 `director_pipeline`（应见 8 条）。
2. 制作页 productionAgent：
   - 「请激活 director_pipeline_overview，并说明 director_pipeline_v1 的阶段顺序。」
   - 「请继续激活 director_pipeline_chief_roadmap…」
3. 后端日志应出现 `activate_skill` 成功。

## 回滚

```powershell
Remove-Item -Force "D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\Toonflow-app\data\skills\production_skills\director_pipeline_0*.md"
Remove-Item -Force "D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\docs-dev\DIRECTOR_PIPELINE_V1_SKILLS_DEPLOY.md"
```

## 阶段定义

当前为 **P3-1：Skill 化导演流程手工跑通**；自动落盘 / workflow_config / D×N 循环属 **P3-3**。
