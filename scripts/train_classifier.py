#!/usr/bin/env python3
"""
Train a pure-Python TF-IDF + cosine-similarity classifier.

Reads scenarios.json (from scrape_scenarios.py), computes IDF weights and
per-scenario TF-IDF vectors, and writes classifier_model.json.

The output file can be loaded at runtime with ZERO external dependencies
(only Python stdlib needed).

Usage:
    python scripts/train_classifier.py
"""

import json
import math
import re
import string
from collections import Counter
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "scenarios" / "security_arena" / "agents" / "attacker" / "classifier_data"

# ── Tokenizer ──────────────────────────────────────────────────────────

_STOP_WORDS = frozenset(
    "a an the is are was were be been being have has had do does did "
    "will would shall should may might can could of in to for on with "
    "at by from as into through during before after above below between "
    "out off over under again further then once here there when where "
    "why how all each every both few more most other some such no nor "
    "not only own same so than too very and but if or because until "
    "while about against this that these those it its he she they them "
    "their his her him what which who whom i me my we our you your "
    "also up".split()
)


def tokenize(text: str) -> list[str]:
    """Lowercase, strip punctuation, remove stop words, keep tokens >= 2 chars."""
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    tokens = text.split()
    return [t for t in tokens if len(t) >= 2 and t not in _STOP_WORDS]


# ── TF-IDF ─────────────────────────────────────────────────────────────

def compute_idf(documents: list[list[str]]) -> dict[str, float]:
    """Compute IDF = log(N / df) for each term across the corpus."""
    n = len(documents)
    df: Counter = Counter()
    for doc in documents:
        df.update(set(doc))
    return {term: math.log(n / count) for term, count in df.items()}


def compute_tfidf(tokens: list[str], idf: dict[str, float]) -> dict[str, float]:
    """Compute TF-IDF vector (sparse dict) for a single document."""
    tf = Counter(tokens)
    max_tf = max(tf.values()) if tf else 1
    vec = {}
    for term, count in tf.items():
        if term in idf:
            # Sublinear TF: 1 + log(tf)
            tf_val = 1 + math.log(count) if count > 0 else 0
            vec[term] = tf_val * idf[term]
    return vec


def cosine_sim(a: dict[str, float], b: dict[str, float]) -> float:
    """Cosine similarity between two sparse vectors."""
    # Iterate over the smaller dict for efficiency
    if len(a) > len(b):
        a, b = b, a
    dot = sum(a[k] * b[k] for k in a if k in b)
    norm_a = math.sqrt(sum(v * v for v in a.values()))
    norm_b = math.sqrt(sum(v * v for v in b.values()))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


# ── Main ───────────────────────────────────────────────────────────────

def main():
    # Load scraped data
    scenarios_path = DATA_DIR / "scenarios.json"
    with open(scenarios_path, encoding="utf-8") as f:
        scenarios = json.load(f)
    print(f"Loaded {len(scenarios)} scenarios")

    # Tokenize all documents
    documents = []
    for s in scenarios:
        text = f"{s['name']} {s['description']}"
        documents.append(tokenize(text))

    # Compute IDF
    idf = compute_idf(documents)
    print(f"Vocabulary size: {len(idf)}")

    # Compute TF-IDF vectors
    scenario_entries = []
    for s, tokens in zip(scenarios, documents):
        vec = compute_tfidf(tokens, idf)
        # Keep only top 80 features per scenario to limit file size
        if len(vec) > 80:
            top_keys = sorted(vec, key=vec.get, reverse=True)[:80]
            vec = {k: vec[k] for k in top_keys}
        scenario_entries.append({
            "category": s["category"],
            "name": s["name"],
            "folder": s["folder"],
            "vector": vec,
        })

    # Build name → category lookup for exact matching
    name_lookup = {}
    for s in scenarios:
        name_lookup[s["name"].lower()] = s["category"]
        name_lookup[s["folder"].lower()] = s["category"]

    # Build per-category keyword centroids for fallback
    cat_vectors: dict[str, Counter] = {}
    cat_counts: dict[str, int] = {}
    for entry in scenario_entries:
        cat = entry["category"]
        if cat not in cat_vectors:
            cat_vectors[cat] = Counter()
            cat_counts[cat] = 0
        cat_counts[cat] += 1
        for term, val in entry["vector"].items():
            cat_vectors[cat][term] += val

    # Average the centroid vectors
    category_centroids = {}
    for cat, vec in cat_vectors.items():
        n = cat_counts[cat]
        category_centroids[cat] = {term: val / n for term, val in vec.items()}

    # Self-test: classify each scenario, report accuracy at different thresholds
    K = 7
    results = []
    for entry, tokens in zip(scenario_entries, documents):
        true_cat = entry["category"]
        query_vec = compute_tfidf(tokens, idf)

        # Top-K nearest neighbor
        sims = []
        for other in scenario_entries:
            if other["name"] == entry["name"]:
                continue  # skip self
            sim = cosine_sim(query_vec, other["vector"])
            sims.append((sim, other["category"]))
        sims.sort(reverse=True)
        top_k = sims[:K]

        # Confidence = agreement proportion of top-K neighbors
        # 5/5 agree → 1.0, 4/5 → 0.8, 3/5 → 0.6
        top_cats = [cat for _, cat in top_k]
        vote_counter = Counter(top_cats)
        best_cat, best_count = vote_counter.most_common(1)[0]
        confidence = best_count / K

        results.append((true_cat, best_cat, confidence))

    # Report overall accuracy
    correct = sum(1 for t, p, _ in results if t == p)
    print(f"\nLeave-one-out accuracy (top-{K} KNN): {correct}/{len(results)} = {correct/len(results)*100:.1f}%")

    # Report per-category
    total_by_cat: Counter = Counter()
    correct_by_cat: Counter = Counter()
    for t, p, _ in results:
        total_by_cat[t] += 1
        if t == p:
            correct_by_cat[t] += 1
    for cat in sorted(total_by_cat):
        c = correct_by_cat.get(cat, 0)
        n = total_by_cat[cat]
        print(f"  {cat}: {c}/{n} ({c/n*100:.0f}%)")

    # Report precision/recall at confidence thresholds
    for threshold in [0.5, 0.6, 0.7, 0.8, 0.9]:
        above = [(t, p) for t, p, c in results if c >= threshold]
        if not above:
            print(f"\n  Threshold {threshold}: 0 scenarios classified")
            continue
        prec = sum(1 for t, p in above if t == p) / len(above)
        coverage = len(above) / len(results)
        print(f"  Threshold {threshold:.1f}: precision={prec:.1%}, coverage={coverage:.1%} ({len(above)}/{len(results)})")

    # Round IDF and vector values to 4 decimal places to save space
    idf_rounded = {k: round(v, 4) for k, v in idf.items()}
    for entry in scenario_entries:
        entry["vector"] = {k: round(v, 4) for k, v in entry["vector"].items()}
    for cat in category_centroids:
        category_centroids[cat] = {
            k: round(v, 4) for k, v in category_centroids[cat].items()
        }

    # Save model
    model = {
        "idf": idf_rounded,
        "scenarios": scenario_entries,
        "name_lookup": name_lookup,
        "category_centroids": category_centroids,
    }

    out_path = DATA_DIR / "classifier_model.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(model, f, ensure_ascii=False)
    size_kb = out_path.stat().st_size / 1024
    print(f"\nWrote {out_path} ({size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
