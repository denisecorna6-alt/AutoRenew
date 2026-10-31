"""Best-effort redaction for context sent to external AI providers.

This is defense in depth, not a guarantee that arbitrary secrets can be detected.
Never intentionally paste credentials or private material into AI task/context fields.
"""
import re

_PATTERNS = (
    (re.compile(r"-----BEGIN [^-]+-----.*?-----END [^-]+-----", re.DOTALL), "[REDACTED KEY MATERIAL]"),
    (re.compile(r"(?im)^\s*(authorization|cookie|set-cookie)\s*:\s*.*$"), r"\1: [REDACTED]"),
    (re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/-]+=*"), "Bearer [REDACTED]"),
    (re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"), "[REDACTED TOKEN]"),
    (re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"), "[REDACTED API KEY]"),
    (re.compile(r"\bAIza[0-9A-Za-z_-]{20,}\b"), "[REDACTED API KEY]"),
    (re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"), "[REDACTED JWT]"),
    (
        re.compile(
            r"(?i)\b(api[_ -]?key|access[_ -]?token|refresh[_ -]?token|password|passwd|secret|cookie|apple[_ -]?id)\s*[:=]\s*(['\"]?)[^\s,;'\"]+"
        ),
        r"\1=[REDACTED]",
    ),
)

def redact_sensitive(value):
    """Redact common credentials, tokens, cookies and private-key blocks."""
    text = str(value or "")
    for pattern, replacement in _PATTERNS:
        text = pattern.sub(replacement, text)
    return text
