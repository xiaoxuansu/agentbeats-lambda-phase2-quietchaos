# AgentBeats x Lambda Custom Track Phase 2 速查

## 一页结论

- 赛程时间：2026-02-26 到 2026-03-30
- 当前阶段：Phase 2 已开始，Leaderboard 已上线
- 核心任务：构建 attacker 和 defender 安全代理并持续提交迭代
- 提交原则：可以多次提交，只保留最好成绩，尽早提交不会吃亏
- 验证前提：仅在官网注册还不够，必须私信 Discord 上的 `@Dihan @ Lambda λ` 完成验证

## 关键日期

- 开始时间：2026-02-26
- 截止时间：2026-03-30
- 当前日期：2026-03-07
- 剩余时间：23 天

## 参赛前必须完成的 4 件事

1. 在比赛官网注册团队
2. 填写 `AgentX – AgentBeats Competition Phase 2 Team Signup Form`
3. 填写 `Compute Credits Signup Form` 领取 Lambda GPU credits
4. 在 Discord 私信 `@Dihan @ Lambda λ` 完成验证

## 验证要点

- 官网注册不等于完成验证
- 未验证团队不能正式参赛
- 需要主动私信 `@Dihan @ Lambda λ`
- 比赛公告和更新会发在 Discord 的 `#sponsor-lambda` 频道
- 可以通过 verification sheet 检查团队状态

## 第一次 baseline 提交怎么做

首次 baseline submission 建议只改这两个文件：

- `agents/attacker/agent.py`
- `agents/defender/agent.py`

后续提交时，你可以修改以下目录中的任意文件：

- `agents/attacker/`
- `agents/defender/`

不要修改这些范围之外的框架文件：

- `orchestrator`
- 其他 framework 文件

## GitHub Secrets 配置

在你的 fork 仓库中进入：`Settings -> Secrets and variables -> Actions -> New repository secret`

需要添加的 secrets：

| Secret | 必需性 | 说明 |
| --- | --- | --- |
| `COMPETITION_API_KEY` | 必填 | 团队 API key，格式类似 `team_...` |
| `OPENAI_API_KEY` | 仅当 `run_tests: 'true'` 时需要 | 本地测试使用的 API key；如果 self-hosting，可填任意字符串 |
| `OPENAI_BASE_URL` | 仅当 `run_tests: 'true'` 时需要 | 本地测试使用的 endpoint，例如 `http://your-ip:8000/v1` |

## baseline 最小提交流程

1. 在 attacker 和 defender 代码里做一个很小的改动，例如加一行注释
2. 提交 commit，commit message 包含 `[submit]`
3. push 后去 GitHub 的 Actions 页面确认工作流是否执行成功

示例：

```bash
git commit -m "[submit] test"
```

## 提交关键词

- 提交全部：`[submit]`
- 只提交 attacker：`[submit-attacker]`
- 只提交 defender：`[submit-defender]`

## 提交与评分规则要点

- 不需要开 Pull Request
- 只要 commit message 带有提交关键词，就会自动触发 GitHub Action
- 绿色对勾表示提交成功
- 红色叉表示出错，需要看 Actions 日志
- 每个 agent 每轮只有 4 次 LLM requests，需要节省使用
- 官方鼓励多次提交和快速迭代
- 榜单只保留你的最好成绩，因此多交不会拉低最终排名

## 官方建议的优化方向

- baseline 先跑通，再逐步增强策略
- 可以参考更强的示例思路：`reasoning attacker`、`two-pass defender`
- 尽早形成一个稳定可提交版本，然后高频小步迭代

## 同步官方最新内容

如果要把最新 README 和 API key 文档同步到本地仓库，可执行：

```bash
git remote add upstream https://github.com/LambdaLabsML/agentbeats-lambda
git pull upstream main
```

如果本地已经有 `upstream`，只需要执行：

```bash
git pull upstream main
```

## FAQ 提炼

### 需要开 PR 才能提交吗

不需要。只要 push 一个 commit，且 commit message 中包含 `[submit]` 即可。

### 官网注册后是不是就算 verified

不是。注册和验证是两件事，必须在 Discord 私信 `@Dihan @ Lambda λ` 才算完成验证。

### API key 丢了怎么办

联系 `@Dihan @ Lambda λ`，或发邮件到 `dihan.lin@lambdal.com` 协助找回。

### 比赛规则和结构去哪里看

比赛官网和 GitHub repo README 都有完整说明。

## 联系方式

- Discord：`@Dihan @ Lambda λ`
- Email：`dihan.lin@lambdal.com`

## 建议执行 Schedule

下面的计划按当前日期 `2026-03-07` 倒排，目标是在截止前至少完成 1 个稳定版本、2 到 4 轮有效迭代、最后 2 天留给兜底和最终冲榜。

### 03-07 到 03-08：报名与环境确认

目标：确认你已经具备正式参赛资格，且提交流程是通的。

- 检查官网注册是否完成
- 检查两个表单是否都已提交
- 立即在 Discord 私信 `@Dihan @ Lambda λ` 完成 verification
- 确认 fork 仓库中的 GitHub Secrets 已配置齐全
- 在本地同步一次官方最新 README 和文档
- 跑通一次最小 baseline 提交

交付标准：

- 团队 verified
- GitHub Actions 成功跑通 1 次
- 本地仓库和官方文档同步完成

### 03-09 到 03-12：建立可迭代 baseline

目标：让 attacker 和 defender 都有稳定、可复现、可提交的基础版本。

- 明确 attacker 的攻击目标和输出结构
- 明确 defender 的检测/拒绝/恢复策略
- 在本地完成至少 2 到 3 组对抗测试
- 记录每轮 submission 的改动点、现象和结果
- 形成第一个“可重复得分”的 baseline

交付标准：

- 有 1 个稳定 attacker 版本
- 有 1 个稳定 defender 版本
- 有一份简短实验记录，知道哪些改动有效、哪些无效

### 03-13 到 03-18：第一轮强化迭代

目标：从“能提交”变成“有竞争力”。

- attacker 方向：提升诱导能力、上下文利用、攻击路径稳定性
- defender 方向：提升规则覆盖、异常识别、二次审查能力
- 控制 prompt 长度和调用次数，围绕“每轮 4 次 LLM requests”做设计
- 每两天至少提交 1 次，观察榜单变化

交付标准：

- 至少完成 3 次有效提交
- 明确最有效的 2 到 3 个攻击技巧
- 明确最有效的 2 到 3 个防守技巧

### 03-19 到 03-24：第二轮强化与针对性优化

目标：针对榜单表现和失败模式做定向修复。

- 分析失败 case，区分是提示词问题、状态管理问题还是策略缺失
- 改进 attacker 的多步推进和角色伪装能力
- 改进 defender 的分层判定、回退回复和边界条件处理
- 只保留能稳定提升结果的改动，避免大而杂的重构

交付标准：

- 至少再完成 3 次有效提交
- 有 1 个主力方案和 1 个备选方案
- 明确最后一周重点冲击的方向

### 03-25 到 03-27：收敛与稳定性检查

目标：减少不必要波动，准备最终冲榜。

- 冻结大框架，只做小步修正
- 检查 secrets、actions、依赖和提交流程是否稳定
- 用相同输入多次回归测试，确认没有明显随机退化
- 整理最终提交 checklist

交付标准：

- 有 1 个最优稳定版本
- 有 1 个可以快速回滚的备份版本
- 最终提交 checklist 完成

### 03-28 到 03-30：最终提交窗口

目标：冲击最好成绩，同时保留故障恢复空间。

- 每天至少检查一次 leaderboard 和 Actions 结果
- 只做高把握度修改
- 保留至少半天到一天作为应急时间
- 在截止前完成最终提交，不要压到最后一刻

交付标准：

- 最终主力版本已提交并成功计分
- 备份版本可随时重新提交
- 所有比赛必要信息都已归档

## 每日执行节奏建议

- 30 分钟：看榜单、看日志、确定当天只做一个核心改进点
- 60 到 120 分钟：本地修改 attacker 或 defender
- 30 到 60 分钟：做最小验证和回归测试
- 10 分钟：记录结果和下一步假设
- 5 分钟：决定是否立刻提交

## 最终 Checklist

- 团队已 verified
- GitHub Secrets 已完整配置
- baseline 已成功提交过
- attacker 和 defender 都有稳定版本
- 至少有一个备份版本
- 知道如何用 `[submit]`、`[submit-attacker]`、`[submit-defender]`
- 知道出问题时去哪里查：GitHub Actions logs
- 知道需要联系谁：`@Dihan @ Lambda λ` / `dihan.lin@lambdal.com`
