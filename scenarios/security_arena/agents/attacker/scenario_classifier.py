"""
Pure-Python scenario classifier using pre-computed TF-IDF + KNN.

Zero external dependencies — uses only the Python standard library.
Model data is loaded from classifier_data/classifier_model.json (generated
by scripts/train_classifier.py).

Usage inside agent.py
---------------------
    from .scenario_classifier import classify_scenario

    category, confidence = classify_scenario(
        attack_goal + " " + domain_description + " " + defender_task
    )
    # category: "jailbreak" | "indirect_injection" | "insecure_output" | ...
    # confidence: 0.0 – 1.0
"""

from __future__ import annotations

import json
import logging
import math
import re
from collections import Counter
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# ── Singleton model cache ──────────────────────────────────────────────

_MODEL: Optional[dict] = None
_MODEL_DIR = Path(__file__).parent / "classifier_data"

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

K = 7  # number of nearest neighbors


def _load_model() -> dict:
    """Lazy-load the classifier model from JSON."""
    global _MODEL
    if _MODEL is not None:
        return _MODEL

    model_path = _MODEL_DIR / "classifier_model.json"
    if not model_path.exists():
        logger.warning("Classifier model not found at %s — will return unknown", model_path)
        _MODEL = {}
        return _MODEL

    with open(model_path, encoding="utf-8") as f:
        _MODEL = json.load(f)
    logger.info(
        "Loaded classifier model: %d scenarios, %d IDF terms, %d name lookups",
        len(_MODEL.get("scenarios", [])),
        len(_MODEL.get("idf", {})),
        len(_MODEL.get("name_lookup", {})),
    )
    return _MODEL


def _tokenize(text: str) -> list[str]:
    """Lowercase, strip punctuation, remove stop words."""
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    tokens = text.split()
    return [t for t in tokens if len(t) >= 2 and t not in _STOP_WORDS]


def _compute_tfidf(tokens: list[str], idf: dict[str, float]) -> dict[str, float]:
    """Compute TF-IDF vector for a document."""
    tf = Counter(tokens)
    vec = {}
    for term, count in tf.items():
        if term in idf:
            tf_val = 1 + math.log(count) if count > 0 else 0
            vec[term] = tf_val * idf[term]
    return vec


def _cosine_sim(a: dict[str, float], b: dict[str, float]) -> float:
    """Cosine similarity between two sparse vectors."""
    if len(a) > len(b):
        a, b = b, a
    dot = sum(a[k] * b[k] for k in a if k in b)
    norm_a = math.sqrt(sum(v * v for v in a.values()))
    norm_b = math.sqrt(sum(v * v for v in b.values()))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def _try_name_lookup(text: str, name_lookup: dict[str, str]) -> Optional[str]:
    """Check if any known scenario name appears in the text."""
    text_lower = text.lower()
    # Check full names first (longer matches preferred)
    for name in sorted(name_lookup, key=len, reverse=True):
        if name in text_lower:
            return name_lookup[name]
    return None


def classify_scenario(text: str) -> tuple[str, float]:
    """
    Classify scenario text into one of 6 categories.

    Args:
        text: Combined attack_goal + domain_description + defender_task

    Returns:
        (category, confidence) where:
        - category: "jailbreak" | "indirect_injection" | "insecure_output" |
                    "pii_leak" | "prompt_extraction" | "supply_chain" | "unknown"
        - confidence: 0.0 – 1.0

    Strategy:
        1. Name lookup: if a known scenario name appears → return with confidence 1.0
        2. Centroid matching: cosine similarity against per-category centroids
        3. KNN: top-7 nearest neighbors by cosine similarity → vote
        4. Best signal wins (highest confidence)
    """
    model = _load_model()
    if not model:
        return ("unknown", 0.0)

    # ── Step 1: Name lookup (instant, 100% confidence) ──
    name_lookup = model.get("name_lookup", {})
    name_match = _try_name_lookup(text, name_lookup)
    if name_match:
        logger.info("Classifier: name lookup matched → %s", name_match)
        return (name_match, 1.0)

    # ── Step 2: Compute query vector ──
    idf = model.get("idf", {})
    scenarios = model.get("scenarios", [])
    centroids = model.get("category_centroids", {})
    if not idf:
        return ("unknown", 0.0)

    tokens = _tokenize(text)
    query_vec = _compute_tfidf(tokens, idf)
    if not query_vec:
        return ("unknown", 0.0)

    # ── Step 3: Centroid matching ──
    # Compare against per-category average TF-IDF vectors.
    # Confidence = margin between best and second-best centroid similarity.
    centroid_cat = "unknown"
    centroid_conf = 0.0
    if centroids:
        cat_sims = {}
        for cat, cvec in centroids.items():
            cat_sims[cat] = _cosine_sim(query_vec, cvec)
        ranked = sorted(cat_sims.items(), key=lambda x: x[1], reverse=True)
        if len(ranked) >= 2 and ranked[0][1] > 0:
            best_sim = ranked[0][1]
            second_sim = ranked[1][1]
            # Margin-based confidence: how much better is the best vs second
            margin = (best_sim - second_sim) / best_sim if best_sim > 0 else 0
            centroid_cat = ranked[0][0]
            centroid_conf = min(margin * 2, 1.0)  # scale: 0.5 margin → 1.0 conf

    # ── Step 4: KNN (if scenarios available) ──
    knn_cat = "unknown"
    knn_conf = 0.0
    if scenarios:
        sims = []
        for entry in scenarios:
            sim = _cosine_sim(query_vec, entry["vector"])
            sims.append((sim, entry["category"], entry["name"]))
        sims.sort(reverse=True)

        top_k = sims[:K]
        top_cats = [cat for _, cat, _ in top_k]
        vote = Counter(top_cats)
        knn_cat, knn_count = vote.most_common(1)[0]
        knn_conf = knn_count / K

    # ── Step 5: Pick best signal ──
    if centroid_conf >= knn_conf:
        best_cat, best_conf = centroid_cat, centroid_conf
        method = "centroid"
    else:
        best_cat, best_conf = knn_cat, knn_conf
        method = "knn"

    logger.info(
        "Classifier: %s → %s (conf=%.2f) [centroid=%s/%.2f, knn=%s/%.2f]",
        method, best_cat, best_conf,
        centroid_cat, centroid_conf, knn_cat, knn_conf,
    )
    return (best_cat, best_conf)
