# Detector Co-occurrence Analysis (v4 + audit + FN fixes, 70 battles, 369 rounds)

After two passes of audit-driven fixes (false-positive cleanup of
STRSL/MANYS/CREATFMT, then false-negative fixes for MULSTEP/CRINJ/PSDATA),
the empirical distribution is:

| Tag | n | Alone % | Top 3 companions |
|---|---|---|---|
| FSS | 88 | 8% | CRINJ 74%, CFLOOD 43%, DOCADD 39% |
| CCBOS | 9 | **100%** | (always alone) |
| CRINJ | 170 | 14% | CFLOOD 40%, FSS 38%, META 30% |
| OFE | 15 | **60%** | CFLOOD/CRINJ/EMBEXT ~13% |
| META | 61 | 11% | CRINJ 84%, CFLOOD 52%, DOCADD 28% |
| DOCADD | 63 | 10% | CRINJ 70%, FSS 54%, CFLOOD 30% |
| FMERR | 19 | 21% | CRINJ 47%, FSS 37%, DOCADD 37% |
| PSDATA | 5 | 0% | CRINJ 100%, FSS 60%, DOCADD 60% |
| IMPDATA | 9 | 22% | CRINJ 78%, MULSTEP 22%, CFLOOD 22% |
| EMBEXT | 2 | 0% | OFE 100% |
| MULSTEP | 6 | 0% | CRINJ 100%, IMPDATA 33%, CFLOOD 17% |
| STRSL | 12 | 0% | CRINJ 83%, CFLOOD 67%, META 42% |
| CFLOOD | 86 | 7% | CRINJ 79%, FSS 44%, META 37% |
| PYTHENC | 8 | 62% | CRINJ/WALK ≤ 25% |
| WALK | 26 | **58%** | CRINJ 23%, FMERR 15%, IMPDATA 4% |
| DRDEC, NUMENC, STEGO, URGENT, HYPOT, HELPEXP, MANYS, CREATFMT | ≤ 1 or 0 | n/a | (rare/absent in dataset) |

## Standalone vs carrier classification

**Standalone strategies** (≥50% rounds alone):
- CCBOS (100%), PYTHENC (62%), OFE (60%), WALK (58%) — self-contained payload forms.

**Carriers** (rarely alone):
- PSDATA / EMBEXT / MULSTEP / STRSL (0% alone)
- CFLOOD (7%), FSS (8%), DOCADD (10%), META (11%), CRINJ (14%)

## Winning round tag distribution (n=29 winning rounds)

| Tag | wins | % |
|---|---|---|
| CRINJ | 21/29 | 72% |
| CFLOOD | 12/29 | 41% |
| META | 9/29 | 31% |
| MULSTEP | 6/29 | 21% |
| FMERR | 6/29 | 21% |
| FSS | 5/29 | 17% |
| WALK | 4/29 | 14% |
| OFE | 4/29 | 14% |
| DOCADD | 2/29 | 7% |
| EMBEXT | 2/29 | 7% |
| IMPDATA | 2/29 | 7% |
| PSDATA | 1/29 | 3% |
| (CCBOS, STRSL, PYTHENC, etc.) | 0/29 | 0% |

## Key empirical findings

1. **CRINJ dominates winning rounds (72%)**. Credential injection (HR /
   financial / fitness variants) is present in 21 of 29 winning rounds —
   the attacker's primary effective mechanism in this dataset.

2. **MULSTEP appears in 21% of winning rounds** (after FN fix). The
   over-boundary computation mechanism (load > max + ratio request) lands
   in 6/29 winning rounds, all in gymjailbreak. Pre-fix MULSTEP=1 was an
   over-strict regex (required FORMULA AND PCT_OF together; now requires
   either with appropriate context).

3. **DOCADD is mostly a setup, not a breakthrough**. 63 rounds carry DOCADD
   but only 2/29 winning rounds have it. The attacker uses DOCADD (inverted-
   rubric / authoritative-addendum framing) to set up the manipulation
   early; breakthrough rounds are typically tagged CRINJ + CFLOOD without
   DOCADD.

4. **CCBOS, STRSL, PYTHENC all land 0/n in winning rounds** despite
   appearing in dataset (n=9, 12, 8). Attacker tries these but neither
   defender pipeline is broken by them in this 70-battle sample:
   - CCBOS (classical Chinese): always blocked
   - STRSL (≥6-col table with separator row): always blocked
   - PYTHENC (`chr(83)+chr(83)+chr(78)` spelling SSN): always blocked

5. **WALK is genuinely standalone** (58% alone, 4/29 winning rounds).
   Broad walkthrough requests are self-contained and effective on
   thingularity (3 of 4 wins) and gymjailbreak (1 of 4 wins).

## Implication for paper

- Pattern-level ASR is a containment rate, not causal attribution. Most
  winning rounds carry 2–5 tags simultaneously.
- The attacker's effective emission is dominated by CRINJ + CFLOOD + a
  scenario-specific surface tag:
  - **portfolioiq winning rounds**: FSS + CRINJ + CFLOOD ± DOCADD/FMERR
  - **resume_downgrade winning rounds**: CRINJ + META + CFLOOD ± FSS
  - **thingularity winning rounds**: OFE / EMBEXT / FMERR / WALK
  - **gymjailbreak winning rounds**: CRINJ + (MULSTEP / IMPDATA / WALK)
- Many pool strategies are essentially absent in 70 battles
  (NUMENC, STEGO, URGENT, HYPOT, HELPEXP, DRDEC, CREATFMT, MANYS) —
  either the Planner rarely selects them or the Generator doesn't produce
  surface forms our regex can detect.
