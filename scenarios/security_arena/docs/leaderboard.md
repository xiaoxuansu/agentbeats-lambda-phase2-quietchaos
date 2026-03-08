# Leaderboard Intelligence

## Team Rankings (2026-03-07 latest)

### Attacker Win Rate (从图表读取)

| Team | Win Rate | 趋势 |
|---|---|---|
| HereToLeaern | ~35% | 峰值 ~47%，回落中 |
| CyberCroneAgent | ~35-45% | 稳定上升 |
| **Quiet Chaos** | **~35%** | **从 0% 跳升，v5 生效** |
| DeoGaze | ~35% | 稳定 |
| Baseline | ~20% | 从 ~40% 下降 |
| phase-2-lambda | ~25% | 新加入 |
| secninjas | ~20% | 波动 |
| rudra-agentx | ~20% | 波动 |

### Defender Win Rate (从图表读取)

| Team | Win Rate | 趋势 |
|---|---|---|
| HereToLeaern | ~73% | 从 0% 飙升，最近大幅提升 |
| secninjas | ~63% | 稳定 |
| Baseline | ~60% | 稳定 |
| rudra-agentx | ~63% | 从 80% 下降后恢复 |
| CyberCroneAgent | ~65% | 从 60% 微升 |
| **Quiet Chaos** | **未进 top 5** | **< ~60%，需要加强** |

### 我们的位置分析

- **Attacker**: 中游偏上 (~35%)，v5 提交后显著提升，接近头部
- **Defender**: 未进 top 5 (<60%)，是短板。头部队伍 HereToLeaern 达到 ~73%
- **差距**: Defender 是主要拉分点。Attacker 已接近头部水平
- **优先级**: **强化 defender 是当前 ROI 最高的方向**

---

## Scenario Statistics (2026-03-07)

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

## 战略分析

### Attacker 优先级

| 优先级 | 场景 | 原因 |
|---|---|---|
| P0 | Resume Downgrade | 100% win rate，必须保持突破 |
| P0 | Private Scenarios 1-5 | 未知场景，靠通用攻击能力 |
| P1 | Portfolioiq | 50% win rate，我们已能突破 |
| P1 | Gymjailbreak | 15% win rate，我们已能突破（top 15%）|
| P1 | Medical / Thingularity | 0% win rate，无人突破 = 先突破者独占优势 |

### Defender 优先级

| 优先级 | 场景 | 原因 |
|---|---|---|
| **P0** | **Resume Downgrade** | **100% 失败率，所有队伍都被打穿。防住 = 巨大优势** |
| P0 | Private Scenario 1 | 73% 失败率，大部分 defender 被打穿 |
| P1 | Portfolioiq | 50% 平衡，改善防御有价值 |
| P1 | Private Scenario 3 | 46%，接近平衡 |
| P2 | Gymjailbreak / Private 4 | 15%，大部分 defender 能防住 |
| 低 | Medical / Thingularity / Private 5 | 0% 攻破率，已经安全 |

### 关键洞察

1. **Resume Downgrade 是最大差异化机会** — 所有队伍的 defender 都失败，如果我们能防住，直接拉开差距
2. **Medical / Thingularity 0% 突破 = 蓝海机会** — 比赛刚开始，先突破者独占优势。0% 不代表不可能，只是目前没人做到
3. **Gymjailbreak 15% 突破率** — 我们的 attacker 已经能突破，属于 top 15%
4. **5 个 Private Scenario 未知** — 通用攻防能力是关键，不能过度针对已知场景优化
5. **Resume Downgrade 的纯虚假简历攻击** — 这可能是为什么 100% attacker win，因为虚假简历没有注入特征，goal-aware 检测无法识别
