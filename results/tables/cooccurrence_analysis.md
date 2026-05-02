# Detector Co-occurrence Analysis (v4 + D-grade fixes, 70 battles)

| Tag | n | Alone % | Avg co-tags | Top 3 companions |
|---|---|---|---|---|
| FSS | 88 | 14% | 1.7 | CRINJ 50%, CFLOOD 43%, DOCADD 39% |
| CCBOS | 9 | **100%** | 0.0 | (none — always alone) |
| CRINJ | 120 | 11% | 1.7 | CFLOOD 42%, FSS 37%, STRSL 28% |
| OFE | 15 | **60%** | 0.5 | CFLOOD/CRINJ/EMBEXT 13% each |
| META | 61 | 11% | 1.9 | CFLOOD 52%, CRINJ 52%, STRSL 44% |
| DOCADD | 63 | **3%** | 2.0 | FSS 54%, STRSL 44%, CRINJ 32% |
| FMERR | 19 | 21% | 1.8 | FSS 37%, DOCADD 37%, CRINJ 26% |
| PSDATA | 3 | 0% | 4.0 | CRINJ/FSS/DOCADD 67% |
| IMPDATA | 9 | 11% | 1.6 | CRINJ 67%, STRSL 33%, CFLOOD 22% |
| EMBEXT | 2 | 0% | 1.0 | OFE 100% (always with OFE) |
| MULSTEP | 1 | 0% | 2.0 | CRINJ + MANYS |
| STRSL | 86 | 13% | 1.9 | CRINJ 38%, CFLOOD 37%, DOCADD 33% |
| CFLOOD | 86 | **5%** | 2.1 | CRINJ 58%, FSS 44%, META 37% |
| PYTHENC | 8 | **75%** | 0.2 | WALK / CRINJ ≤ 12% |
| MANYS | 12 | 17% | 1.6 | CRINJ 50%, STRSL 33%, WALK 25% |
| WALK | 26 | **54%** | 0.7 | CRINJ 23%, FMERR 15%, STRSL 12% |
| (NUMENC/STEGO/URGENT/HYPOT/HELPEXP) | 0 | n/a | n/a | (never observed) |

## Standalone vs carrier classification

**Standalone strategies** (≥50% rounds where this is the only tag):
- CCBOS (100%), PYTHENC (75%), OFE (60%), WALK (54%)
- These tend to be self-contained payload forms.

**Carriers** (mostly co-occur):
- DOCADD (3% alone), CFLOOD (5%), CRINJ/META/IMPDATA (~11%)
- These typically wrap or pad other strategies.

## Implication for paper

A multi-tag round should NOT be interpreted as "all listed tags contributed equally." Most rounds have a small set of *standalone* tags (CCBOS, OFE, WALK, PYTHENC) plus one or more *carrier* tags (CFLOOD, CRINJ, DOCADD). The standalone tag is the likely primary mechanism; carriers thicken the payload.

For paper §6 / §7, report tag-level ASR with a co-occurrence disclaimer:
"Reported pattern ASRs are containment rates over rounds tagged with that pattern, not causal attribution. Most winning rounds carry 2-5 tags simultaneously; we report co-occurrence in Appendix Table X."

