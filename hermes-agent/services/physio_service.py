import datetime
import logging
import os

from anthropic import AsyncAnthropic

logger = logging.getLogger(__name__)

MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-haiku-4-5")  # Haiku — fast, cheap for this

_client: AsyncAnthropic | None = None


def _get_client() -> AsyncAnthropic:
    global _client
    if _client is None:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        _client = AsyncAnthropic(api_key=api_key)
    return _client


async def analyse_physio(snapshot: dict) -> dict:
    """
    Analyse a PhysioSnapshot dict and return a PhysioInsight dict.

    Input keys (all optional except capturedAt):
      capturedAt, stepCount, heartRateBpm, restingHeartRateBpm,
      hrv, activeCalories, sleepDurationMinutes, sleepQualityLabel

    Output keys:
      summary, contextHint, flags, generatedAt
    """
    metrics = _format_metrics(snapshot)

    system = (
        "You are a health-aware AI assistant for the Nivara personal wellbeing app. "
        "You receive a user's daily physiological snapshot and return a brief, "
        "warm, non-clinical insight. Be concise and encouraging — never alarmist."
    )

    prompt = (
        f"Today's health snapshot:\n{metrics}\n\n"
        "Respond with a JSON object (no markdown, no extra text) with exactly these keys:\n"
        '  "summary": A 1-2 sentence warm, plain-English insight about today\'s physical state.\n'
        '  "contextHint": A short phrase (5-10 words) for the AI context system, '
        'e.g. "good sleep, high activity" or "low sleep, sedentary".\n'
        '  "flags": A JSON array of applicable tags from this set: '
        '["low_sleep","good_sleep","high_activity","low_activity","elevated_rhr","low_rhr","good_hrv","low_hrv"].\n'
        '  "generatedAt": Current UTC ISO 8601 timestamp.\n\n'
        "Only include flags that are genuinely applicable. Return valid JSON only."
    )

    try:
        message = await _get_client().messages.create(
            model=MODEL,
            max_tokens=300,
            system=system,
            messages=[{"role": "user", "content": prompt}],
        )
        import json
        text = message.content[0].text.strip()
        result = json.loads(text)
        # Ensure all required keys present
        return {
            "summary": result.get("summary", ""),
            "contextHint": result.get("contextHint", ""),
            "flags": result.get("flags", []),
            "generatedAt": result.get(
                "generatedAt", datetime.datetime.utcnow().isoformat() + "Z"
            ),
        }
    except Exception as exc:
        logger.warning("Physio analysis failed, using heuristic: %s", exc)
        return _heuristic_insight(snapshot)


def _format_metrics(s: dict) -> str:
    lines = []
    if s.get("stepCount") is not None:
        lines.append(f"- Steps today: {s['stepCount']:,}")
    if s.get("heartRateBpm") is not None:
        lines.append(f"- Latest heart rate: {s['heartRateBpm']:.0f} bpm")
    if s.get("restingHeartRateBpm") is not None:
        lines.append(f"- Resting heart rate: {s['restingHeartRateBpm']:.0f} bpm")
    if s.get("hrv") is not None:
        lines.append(f"- HRV: {s['hrv']:.1f} ms")
    if s.get("activeCalories") is not None:
        lines.append(f"- Active calories burned: {s['activeCalories']:.0f} kcal")
    if s.get("sleepDurationMinutes") is not None:
        h, m = divmod(s["sleepDurationMinutes"], 60)
        label = s.get("sleepQualityLabel", "")
        lines.append(f"- Sleep last night: {h}h {m}m ({label})" if label else f"- Sleep: {h}h {m}m")
    return "\n".join(lines) if lines else "No metrics available."


def _heuristic_insight(s: dict) -> dict:
    flags = []
    parts = []

    sleep = s.get("sleepDurationMinutes")
    if sleep is not None:
        if sleep < 300:
            flags.append("low_sleep")
            parts.append("you got less than 5 hours of sleep")
        elif sleep >= 390:
            flags.append("good_sleep")
            parts.append("your sleep looks solid")

    steps = s.get("stepCount")
    if steps is not None:
        if steps >= 8000:
            flags.append("high_activity")
            parts.append("you've been quite active today")
        elif steps < 2000:
            flags.append("low_activity")
            parts.append("you've been mostly sedentary today")

    rhr = s.get("restingHeartRateBpm")
    if rhr is not None and rhr > 80:
        flags.append("elevated_rhr")
        parts.append("your resting heart rate is a little elevated")

    summary = (
        f"Looks like {', '.join(parts)}." if parts else "Your body data looks normal today."
    )
    context_hint = ", ".join(f.replace("_", " ") for f in flags) if flags else "physical metrics normal"

    return {
        "summary": summary,
        "contextHint": context_hint,
        "flags": flags,
        "generatedAt": datetime.datetime.utcnow().isoformat() + "Z",
    }
