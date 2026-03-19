# Team Quiet Chaos — Roadmap

> 最后更新: 2026-03-18 | 历史记录见 [upgrade_log.md](upgrade_log.md)

---

## 当前状态

| 维度 | 版本 | 本地测试 | 线上排名 |
|------|------|---------|---------|
| Attacker | v14 | 0% (自打自) | 37.1%, 第 3 名 |
| Defender | v14 | 100% (自打自，有 LLM 波动) | 81.1%, **第 1 名** |

### 架构

| 组件 | Attacker | Defender |
|------|----------|---------|
| Step 1 | 分析场景 + 历史失败 → 生成策略 | 安全分析 → 标记 tainted items |
| Step 2 | 基于策略生成攻击 payload | 带安全信息生成响应 |
| Step 3 | — | Post-ranking validation (INJECTION only) |
| Fallback | LLM 拒绝时 → 通用 fallback 数组 | — |
| 模型 | gpt-oss-20b | gpt-oss-20b |

### 已覆盖的场景类型

| 攻击类型 | 本地场景 | Agent 覆盖 |
|---------|---------|-----------|
| Jailbreak (DIRECT) | gymjailbreak | ✅ |
| PII Leak (DIRECT) | medical_records | ✅ |
| Prompt Extraction (DIRECT) | thingularity | ✅ |
| Indirect Injection (INJECTION) | resume_downgrade, portfolioiq | ✅ |
| Insecure Output | — | ❌ 未测试 |
| Supply Chain | — | ❌ 未测试 |
| DoS | — | ❌ 未测试 |

---

## 已知问题

| 问题 | 严重度 | 说明 |
|------|--------|------|
| LLM 非确定性 | P0 | INJECTION 路径 3 次 LLM 调用，每次可能误判，导致自测结果波动（同代码多次运行 0/7~7/7） |
| Attacker 排名落后 | P0 | 37.1% vs DeoGaze 46.3%，差距 9pp |
| 5 个 Private Scenario 未知 | P0 | 通用性是关键，不能过度拟合已知场景 |
| Insecure Output 类型未覆盖 | P1 | 424 场景中占大量比例 |

---

## 已完成 (v11→v14)

- [x] Spotlight defense: 随机 delimiter 包裹不可信数据
- [x] Sandwich defense: 在数据后重复关键安全规则 (user.j2)
- [x] 正则通用化: 语义+结构投毒检测
- [x] External Upload 凭证防御再平衡
- [x] Thingularity 防御恢复
- [x] 移除场景特定术语 (PortfolioIQ hardcoded terms)
- [x] INJECTION 路径通用化: 支持任意 ID 命名 (v14)
- [x] Attacker 通用化: 移除场景过拟合, LLM-first 架构

---

## Next Up

### P0

**LLM 非确定性优化**
- [ ] 精简 Step 1 安全分析 prompt（缩短 → LLM 注意力更集中）
- [ ] 评估 temperature=0 是否可用
- [ ] 投票机制（2 次 Step 1 取并集）— 成本翻倍但准确率提升

**Attacker 强化（短板）**
- [ ] DIRECT 场景突破技术: encoding bypass (Base64, Unicode 同形字)
- [ ] 更强的 role-fit 策略: 让注入内容在数据层面就胜出

### P1

**输出安全加固**
- [ ] `_hard_block_output` 扩展: `<script>`, `<iframe>`, malicious links, SQL
- [ ] system.j2 补充: 明确禁止 raw HTML 输出

**通用性验证**
- [ ] 新建 2-3 个本地测试场景，覆盖 Insecure Output / Supply Chain
- [ ] 用新场景验证 attacker + defender 的通用表现

**竞情更新**
- [ ] 分析线上最新榜单，更新 leaderboard.md

### P2

- [ ] DIRECT 路径确定性预检（正则 force UNSAFE）
- [ ] 高级自适应攻击 (battle history 更深利用)
- [ ] 更多本地测试场景 (目标: 覆盖全部 7 种攻击类型)

---

## 分工

| 人员 | 负责 | 当前任务 |
|------|------|---------|
| A | `attacker/` | — |
| B | `defender/` | — |
| C | 测试 + 场景 | — |

> 更新规则: 每次领新任务时在这里填上，完成后打勾移到 upgrade_log.md

---

## 参考资料

| 论文/资源 | 核心技术 | 适用方向 |
|----------|---------|---------|
| [Spotlighting](https://arxiv.org/abs/2403.14720) | delimiter/datamarking 标记不可信内容 | Defender |
| [Sandwich Defense](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html) | 数据后重复指令 | Defender |
| [PromptArmor](https://arxiv.org/abs/2507.15219) | LLM 检测并清洗注入 | Defender |
| [Red Teaming](https://arxiv.org/abs/2505.04806) | Roleplay 89.6% ASR, 编码绕过 76.2% | Attacker |
| [Adaptive Attacks](https://arxiv.org/abs/2503.00061) | 自适应攻击破解所有 8 种防御 | Attacker |
| S3 场景库 | 424 个场景描述 | 本地测试场景设计 |
