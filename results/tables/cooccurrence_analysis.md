# Detector Co-occurrence Analysis (v4 + audit fixes, 70 battles, 369 rounds)

After fixing STRSL (≥4-col table → ≥6-col table), MANYS (remove generic
"For example"), CREATFMT (require "as a / in the form of"), the empirical
distribution is:

| Tag | n | Alone % | Avg co-tags | Top 3 companions |
|---|---|---|---|---|
| FSS | 88 | 16% | 1.5 | CRINJ 50%, CFLOOD 43%, DOCADD 39% |
| CCBOS | 9 | **100%** | 0.0 | (always alone) |
| CRINJ | 120 | 18% | 1.5 | CFLOOD 42%, FSS 37%, META 27% |
| OFE | 15 | **60%** | 0.5 | CFLOOD/CRINJ/EMBEXT ~13% |
| META | 61 | 18% | 1.5 | CFLOOD 52%, CRINJ 52%, DOCADD 28% |
| DOCADD | 63 | 11% | 1.6 | FSS 54%, CRINJ 32%, CFLOOD 30% |
| FMERR | 19 | 21% | 1.5 | FSS 37%, DOCADD 37%, CRINJ 26% |
| PSDATA | 3 | 0% | 3.3 | FSS/DOCADD/CFLOOD 67% |
| IMPDATA | 9 | 22% | 1.2 | CRINJ 67%, CFLOOD 22%, WALK 11% |
| EMBEXT | 2 | 0% | 1.0 | OFE 100% |
| MULSTEP | 1 | 0% | 1.0 | CRINJ 100% |
| STRSL | 13 | 0% | 2.1 | CFLOOD 69%, META 46%, CRINJ 46% |
| CFLOOD | 86 | 8% | 1.8 | CRINJ 58%, FSS 44%, META 37% |
| PYTHENC | 8 | **75%** | 0.2 | WALK / CRINJ ≤ 12% |
| WALK | 26 | **58%** | 0.5 | CRINJ 23%, FMERR 15%, IMPDATA 4% |
| CCBOS, MANYS, NUMENC, STEGO, URGENT, HYPOT, HELPEXP, DRDEC, CREATFMT | mostly absent in dataset | | |

## Standalone vs carrier classification

**Standalone strategies** (≥50% rounds where this is the only tag):
- CCBOS (100%), PYTHENC (75%), OFE (60%), WALK (58%)
- These are self-contained payload forms.

**Carriers** (mostly co-occur):
- CFLOOD (8%), DOCADD (11%), FSS (16%), CRINJ/META/IMPDATA (~18-22%)
- These typically wrap or pad other strategies.

## Winning round tag distribution (n=29 winning rounds)

How often does each tag appear among the 29 attacker-winning rounds?

| Tag | Wins where this tag fires | % |
|---|---|---|
| CRINJ | 20/29 | 69% |
| CFLOOD | 12/29 | 41% |
| META | 9/29 | 31% |
| FMERR | 6/29 | 21% |
| FSS | 5/29 | 17% |
| WALK | 4/29 | 14% |
| OFE | 4/29 | 14% |
| DOCADD | 2/29 | 7% |
| EMBEXT | 2/29 | 7% |
| IMPDATA | 2/29 | 7% |
| MULSTEP | 1/29 | 3% |
| (CCBOS, PYTHENC, STRSL, PSDATA, etc.) | 0/29 | 0% |

## Surprising findings revealed by the audit

1. **STRSL never appears in winning rounds**. After tightening the table
   threshold from ≥4 to ≥6 columns, STRSL drops from 86 to 13 rounds, and
   none of those 13 are in winning battles. The earlier "portfolioiq winning-
   round five-piece fingerprint (FSS+CRINJ+DOCADD+CFLOOD+STRSL)" claim was
   wrong; the correct fingerprint is **four-piece (FSS+CRINJ+DOCADD+CFLOOD)**.

2. **MANYS never appears in the dataset**. The 12 prior MANYS hits were all
   false positives from the broad `For\s+example` regex. The pool's L8
   "many-shot normalization" — multiple example pairs setting a precedent
   for the model — is genuinely absent in 70 battles. The attacker's Planner
   never selected a many-shot strategy that survived through the Generator.

3. **DOCADD is mostly a setup move, not a breakthrough move**. 63 rounds
   carry DOCADD but only 2 of the 29 winning rounds have it (7%). The
   attacker uses DOCADD (inverted-rubric / authoritative-addendum framing)
   to set up risk-assessment manipulation early in a battle, but the actual
   breakthrough round is usually tagged with CRINJ + CFLOOD without DOCADD.

4. **CRINJ dominates winning rounds (69%)**. After taxonomy alignment to
   the attacker's pool, the empirical signal is clear: credential-injection
   instances (in financial / HR / fitness variants) are present in 20 of
   the 29 winning rounds, by far the most common tag among breakthroughs.

5. **CCBOS standalone is genuinely confirmed**. All 9 CCBOS rounds carry no
   other tags; classical-Chinese payloads consume the entire prompt and
   cannot also carry FSS / META / etc. CCBOS is also 0/9 winning — it never
   broke through in this dataset.

## Implication for paper

- Pattern-level ASR is a containment rate, not causal attribution. Most
  winning rounds carry 2-5 tags simultaneously.
- The attacker's strategy emission is dominated by a small set of frequently
  co-occurring strategies (CRINJ + CFLOOD + FSS + DOCADD + META), with rarer
  standalone strategies (CCBOS, PYTHENC, OFE, WALK) tested but rarely
  successful in this dataset.
- Many pool strategies (NUMENC, STEGO, URGENT, HYPOT, HELPEXP, DRDEC,
  CREATFMT, MANYS) are essentially absent in 70 battles — either the
  Planner rarely selects them or the Generator doesn't produce surface
  forms our regex can detect.
