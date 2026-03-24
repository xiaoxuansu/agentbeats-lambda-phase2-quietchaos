# Leaderboard Intelligence

## Public Leaderboard (2026-03-09 latest, known scenarios)

> 10 teams, 720 battles, Updated Mar 9 11:59 PM
> NOTE: Public = 5 个已知场景 (portfolioiq, thingularity, gymjailbreak, resume_downgrade, medical_records)
> Private leaderboard 使用 unseen scenarios，排名可能不同

### Defender

| Rank | Team | Win Rate |
|------|------|---------|
| **1st** | **Quiet Chaos** | **81.1%** |
| 2nd | AgentBusters | 71.1% |
| 3rd | secninjas | 68.9% |

### Attacker

| Rank | Team | Win Rate |
|------|------|---------|
| 1st | DeoGaze | 46.3% |
| 2nd | AgentBusters | 45.7% |
| **3rd** | **Quiet Chaos** | **37.1%** |

### 综合分析

- **Defender: 第 1 名 (81.1%)** — 领先第 2 名 10pp，优势明显
- **Attacker: 第 3 名 (37.1%)** — 落后第 1 名 9.2pp，主要提升空间
- **综合**: 81.1 + 37.1 = 118.2 vs AgentBusters 71.1 + 45.7 = 116.8 — 综合可能领先
- **注意**: 这是 public (已知场景)，defender 的硬编码在这些场景上有效。Private leaderboard (unseen) 排名未知，硬编码可能失效

### 优先级调整（基于最新排名）

| 方向 | 优先级 | 原因 |
|------|--------|------|
| **Attacker 强化** | **P0** | 短板，提升空间大，每 1pp 都有价值 |
| **Defender 通用化** | **P0** | Public 第 1 但 private 未知，硬编码在 unseen 场景会失效 |
| Defender 维护 | P1 | Public 已第 1，改动需谨慎不要破坏 |

---

## 历史: Public Leaderboard (2026-03-07)

### Scenario Statistics

| Scenario | Attacker Win% | Defender Win% | Battles | 难度 |
|---|---|---|---|---|
| Resume Downgrade | 100% | 0% | 26 | 极难防守 |
| Private Scenario 1 | 73% | 27% | 26 | 难防守 |
| Portfolioiq | 50% | 50% | 26 | 平衡 |
| Private Scenario 3 | 46% | 54% | 26 | 略偏防守 |
| Private Scenario 2 | 31% | 69% | 26 | 偏防守 |
| Gymjailbreak | 15% | 85% | 26 | 易防守 |
| Private Scenario 4 | 15% | 85% | 26 | 易防守 |
| Private Scenario 5 | 0% | 100% | 26 | 无人突破 |
| Medical Records | 0% | 100% | 26 | 无人突破 |
| Thingularity | 0% | 100% | 26 | 无人突破 |

### Attacker 蓝海机会

| 场景 | 全局攻破率 | 机会 |
|------|-----------|------|
| Medical / Thingularity / Private 5 | 0% | 先突破者独占优势 |
| Gymjailbreak / Private 4 | 15% | 仅少数队伍能攻破 |
| Resume Downgrade | 100% | 必须保持突破能力 |
