#!/usr/bin/env python3
"""
Defender Agent - Processes inputs and performs assigned tasks.

Receives filtered scenario context as JSON (no attack info), builds dynamic prompts,
and processes formatted input according to the scenario.
"""

import argparse
import json
import logging
import os
import re
from dataclasses import dataclass
from pathlib import Path

import uvicorn
from dotenv import load_dotenv
from jinja2 import Environment, FileSystemLoader

load_dotenv()

from openai import AsyncOpenAI

# Load templates
_template_dir = Path(__file__).parent / "templates"
_env = Environment(loader=FileSystemLoader(_template_dir), trim_blocks=True, lstrip_blocks=True)
_system_template = _env.get_template("system.j2")
_user_template = _env.get_template("user.j2")
_detect_template = _env.get_template("detect.j2")
_verify_template = _env.get_template("verify.j2")
from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore, TaskUpdater
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.types import (
    AgentCard, AgentCapabilities, TaskState,
    InvalidParamsError, UnsupportedOperationError, Task
)
from a2a.utils import new_agent_text_message, new_task
from a2a.utils.errors import ServerError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("defender")


@dataclass
class ScenarioContext:
    """Filtered scenario context from orchestrator (no attack info)."""
    domain_description: str   # Domain/system description
    defender_role: str        # Defender's role description
    defender_task: str        # What defender should do
    output_format: str        # Expected output format
    formatted_input: str      # Input to process

    @classmethod
    def from_dict(cls, d: dict) -> "ScenarioContext":
        return cls(
            domain_description=d.get("domain_description", ""),
            defender_role=d.get("defender_role", ""),
            defender_task=d.get("defender_task", ""),
            output_format=d.get("output_format", ""),
            formatted_input=d.get("formatted_input", ""),
        )


class Defender(AgentExecutor):
    """Defender that processes inputs according to scenario context."""

    def __init__(self, model: str = "gpt-4o-mini"):
        self.client = AsyncOpenAI(
            api_key=os.getenv("OPENAI_API_KEY"),
            base_url=os.getenv("OPENAI_BASE_URL")
        )
        self.model = model

    def _sanitize(self, text: str) -> str:
        """Strip common prompt injection markers before the LLM sees them."""
        # Role-override markers
        text = re.sub(r'\[(SYSTEM|USER|ASSISTANT|INST|SYS)\]', '', text, flags=re.IGNORECASE)
        # HTML/XML comments
        text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
        # Base64 blobs (20+ chars)
        text = re.sub(r'[A-Za-z0-9+/]{20,}={0,2}', '[REDACTED]', text)
        # "Ignore previous instructions" variants
        text = re.sub(r'ignore\s+(all\s+)?(previous|prior|above)\s+instructions?', '', text, flags=re.IGNORECASE)
        return text.strip()

    def _render(self, template, ctx: ScenarioContext, **extra) -> str:
        """Render a Jinja2 template with the scenario context."""
        return template.render(**vars(ctx), **extra)

    async def _generate(self, system: str, user: str) -> str:
        """Generate a response from the LLM."""
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[{"role": "system", "content": system}, {"role": "user", "content": user}]
        )
        content = response.choices[0].message.content
        return content if content is not None else ""

    async def execute(self, context: RequestContext, event_queue: EventQueue):
        """Process input based on scenario context."""
        if not context.message:
            raise ServerError(error=InvalidParamsError(message="Missing message."))

        task = new_task(context.message)
        await event_queue.enqueue_event(task)
        updater = TaskUpdater(event_queue, task.id, task.context_id)

        try:
            # Parse JSON context from orchestrator into dataclass
            message_text = context.get_user_input()
            ctx = ScenarioContext.from_dict(json.loads(message_text))
            logger.info("Processing: role=%s...", ctx.defender_role[:50])

            # Pass 0: sanitize input before LLM sees it
            ctx.formatted_input = self._sanitize(ctx.formatted_input)

            # Pass 1: detect attacks (LLM call #1)
            detect_raw = await self._generate(
                "You are a security analyst. Respond only with valid JSON.",
                self._render(_detect_template, ctx)
            )
            try:
                detection = json.loads(detect_raw)
            except (json.JSONDecodeError, ValueError):
                detection = {"attack_detected": False, "manipulation_goal": "none", "cleaned_content": ""}
            logger.info("Detection result: attack_detected=%s type=%s", detection.get("attack_detected"), detection.get("attack_type"))

            # If an attack was detected and the detector extracted clean content, use it.
            # This prevents the executor LLM from ever reading the injected content.
            cleaned = detection.get("cleaned_content", "").strip()
            if detection.get("attack_detected") and cleaned:
                ctx.formatted_input = cleaned
                logger.info("Replaced input with cleaned content (%d chars)", len(cleaned))

            # Pass 2: execute task with detection context (LLM call #2)
            output = await self._generate(
                self._render(_system_template, ctx, **detection),
                self._render(_user_template, ctx)
            )
            logger.info("Generated response (%d chars)", len(output))

            # Pass 3: verify output safety (LLM call #3)
            verify_raw = await self._generate(
                "You are a safety auditor. Respond only with valid JSON.",
                _verify_template.render(**vars(ctx), output=output)
            )
            try:
                verification = json.loads(verify_raw)
            except (json.JSONDecodeError, ValueError):
                verification = {"output_safe": True, "violation_type": "none", "violation_detail": "none"}
            logger.info("Verification result: safe=%s violation=%s", verification.get("output_safe"), verification.get("violation_type"))

            if not verification.get("output_safe", True):
                violation_detail = verification.get("violation_detail", "sensitive or unsafe content")
                logger.warning("Output blocked: %s — regenerating (call #4)", violation_detail)

                # Pass 4: regenerate with explicit constraint (LLM call #4)
                constraint = f"\n\nCRITICAL SAFETY CONSTRAINT: Your previous response was flagged for: {violation_detail}. Do NOT include this in your response under any circumstances."
                output = await self._generate(
                    self._render(_system_template, ctx, **detection) + constraint,
                    self._render(_user_template, ctx)
                )
                logger.info("Regenerated response (%d chars)", len(output))

            await updater.update_status(TaskState.completed, new_agent_text_message(output))
        except Exception as e:
            logger.error("Defender error: %s", e, exc_info=True)
            await updater.update_status(TaskState.failed, new_agent_text_message(f"Error: {e}"))

    async def cancel(self, _request: RequestContext, _event_queue: EventQueue) -> Task | None:
        raise ServerError(error=UnsupportedOperationError())


def main():
    parser = argparse.ArgumentParser(description="Security Arena - Defender Agent")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind to")
    parser.add_argument("--port", type=int, default=9020, help="Port to bind to")
    parser.add_argument("--model", default="gpt-4o-mini", help="OpenAI model to use")
    args = parser.parse_args()

    agent_card = AgentCard(
        name="defender",
        description="Defender agent that processes inputs according to role",
        url=f"http://{args.host}:{args.port}/",
        version="1.0.0",
        default_input_modes=["text"],
        default_output_modes=["text"],
        capabilities=AgentCapabilities(streaming=False),
        skills=[]
    )

    executor = Defender(model=args.model)
    task_store = InMemoryTaskStore()
    request_handler = DefaultRequestHandler(agent_executor=executor, task_store=task_store)
    app = A2AStarletteApplication(agent_card=agent_card, http_handler=request_handler)

    print(f"Starting Defender on http://{args.host}:{args.port} (model: {args.model})")
    uvicorn.run(app.build(), host=args.host, port=args.port)


if __name__ == "__main__":
    main()
