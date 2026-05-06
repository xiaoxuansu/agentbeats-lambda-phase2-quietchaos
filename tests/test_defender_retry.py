"""Unit tests for Defender._generate retry-on-transient-failure logic."""
import asyncio
import sys
import types
from pathlib import Path
from unittest.mock import patch

import httpx
import pytest

# Ensure repo root is importable as a module path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from openai import (
    APIConnectionError,
    APITimeoutError,
    InternalServerError,
    RateLimitError,
)

from scenarios.security_arena.agents.defender.agent import Defender


def _ok_response(text: str = "ok"):
    return types.SimpleNamespace(
        choices=[types.SimpleNamespace(
            message=types.SimpleNamespace(content=text)
        )]
    )


def _fake_request():
    return httpx.Request("POST", "https://example.test/v1/chat/completions")


def _fake_http_response(status: int, body: str = ""):
    return httpx.Response(status_code=status, text=body, request=_fake_request())


def _make_defender():
    d = Defender(model="test-model")
    # Speed up the test — keep retry count, kill the wait.
    d._RETRY_BACKOFF_BASE_SEC = 0.0
    return d


def _run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


@pytest.mark.parametrize("exc_factory", [
    lambda: APIConnectionError(request=_fake_request()),
    lambda: APITimeoutError(request=_fake_request()),
    lambda: RateLimitError(
        message="rate limited",
        response=_fake_http_response(429),
        body=None,
    ),
    lambda: InternalServerError(
        message="server error",
        response=_fake_http_response(500),
        body=None,
    ),
])
def test_retries_until_success(exc_factory):
    """Each transient exception class triggers retry; eventual success returns content."""
    d = _make_defender()
    call_count = {"n": 0}

    async def flaky_create(**kwargs):
        call_count["n"] += 1
        if call_count["n"] < 3:
            raise exc_factory()
        return _ok_response("recovered")

    with patch.object(d.client.chat.completions, "create", flaky_create):
        out = asyncio.run(d._generate("sys", "user"))

    assert out == "recovered"
    assert call_count["n"] == 3, f"expected 3 attempts (2 fails + 1 success), got {call_count['n']}"


def test_retry_exhausted_raises():
    """After MAX_RETRIES + 1 failures, the last exception propagates."""
    d = _make_defender()
    call_count = {"n": 0}

    async def always_fail(**kwargs):
        call_count["n"] += 1
        raise APIConnectionError(request=_fake_request())

    with patch.object(d.client.chat.completions, "create", always_fail):
        with pytest.raises(APIConnectionError):
            asyncio.run(d._generate("sys", "user"))

    # 1 initial attempt + 3 retries = 4 total
    assert call_count["n"] == d._MAX_RETRIES + 1


def test_first_call_success_no_retry():
    """If the first call succeeds, retry path is not entered."""
    d = _make_defender()
    call_count = {"n": 0}

    async def succeed(**kwargs):
        call_count["n"] += 1
        return _ok_response("first")

    with patch.object(d.client.chat.completions, "create", succeed):
        out = asyncio.run(d._generate("sys", "user"))

    assert out == "first"
    assert call_count["n"] == 1


def test_non_transient_exception_propagates_immediately():
    """Exceptions outside the retry whitelist should NOT trigger retry."""
    d = _make_defender()
    call_count = {"n": 0}

    class CustomError(Exception):
        pass

    async def raise_custom(**kwargs):
        call_count["n"] += 1
        raise CustomError("not retryable")

    with patch.object(d.client.chat.completions, "create", raise_custom):
        with pytest.raises(CustomError):
            asyncio.run(d._generate("sys", "user"))

    assert call_count["n"] == 1, "non-transient errors must not be retried"


def test_empty_choices_returns_empty_string():
    """Model returning no choices yields empty string fallback (no retry, no raise)."""
    d = _make_defender()

    async def empty_choices(**kwargs):
        return types.SimpleNamespace(choices=[])

    with patch.object(d.client.chat.completions, "create", empty_choices):
        out = asyncio.run(d._generate("sys", "user"))
    assert out == ""


def test_backoff_exponential_growth(monkeypatch):
    """Verify backoff delay schedule is base * 2^attempt."""
    d = _make_defender()
    d._RETRY_BACKOFF_BASE_SEC = 2.0  # restore real base for this test
    sleeps = []

    async def fake_sleep(t):
        sleeps.append(t)

    async def always_fail(**kwargs):
        raise APIConnectionError(request=_fake_request())

    monkeypatch.setattr(
        "scenarios.security_arena.agents.defender.agent.asyncio.sleep",
        fake_sleep,
    )

    with patch.object(d.client.chat.completions, "create", always_fail):
        with pytest.raises(APIConnectionError):
            asyncio.run(d._generate("sys", "user"))

    # attempts 0,1,2 each sleep before retrying; attempt 3 raises (no sleep)
    assert sleeps == [2.0, 4.0, 8.0], f"backoff schedule wrong: {sleeps}"
