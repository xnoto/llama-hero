from __future__ import annotations

from pathlib import Path
import forge.proxy.convert


path = Path(forge.proxy.convert.__file__)
source = path.read_text()

old = '''def openai_to_messages(openai_messages: list[dict[str, Any]]) -> list[Message]:
    """Convert OpenAI chat completions messages to forge Message objects.

    Handles system, user, assistant (with optional tool_calls), and tool
    role messages. Unknown roles are mapped to USER.
    """
    messages: list[Message] = []

    for msg in openai_messages:
'''

new = '''def openai_to_messages(openai_messages: list[dict[str, Any]]) -> list[Message]:
    """Convert OpenAI chat completions messages to forge Message objects.

    Handles system, user, assistant (with optional tool_calls), and tool
    role messages. Unknown roles are mapped to USER.

    llama.cpp's Qwen GGUF chat template rejects system messages unless they
    appear at the beginning. OpenCode may inject per-turn system messages, so
    coalesce all system messages and emit one leading system prompt before
    converting the remaining messages.
    """
    messages: list[Message] = []
    system_prompts: list[str] = []
    normalized_messages: list[dict[str, Any]] = []

    for msg in openai_messages:
        if msg.get("role") == "system":
            content = msg.get("content", "") or ""
            if isinstance(content, list):
                parts = []
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        parts.append(block.get("text", ""))
                    elif isinstance(block, str):
                        parts.append(block)
                content = "\\n".join(parts)
            if str(content).strip():
                system_prompts.append(str(content).strip())
            continue
        normalized_messages.append(msg)

    if system_prompts:
        messages.append(Message(
            MessageRole.SYSTEM,
            "\\n\\n".join(dict.fromkeys(system_prompts)),
            MessageMeta(MessageType.SYSTEM_PROMPT),
        ))

    for msg in normalized_messages:
'''

if new in source:
    raise SystemExit(0)

if old not in source:
    raise SystemExit(f"expected forge conversion block not found in {path}")

path.write_text(source.replace(old, new))
print(f"patched {path}")


source = path.read_text()

# Forge v0.6.0 exposes model reasoning text as assistant content before tool
# calls. OpenCode persists that content and sends it back on the next step,
# which makes Qwen repeat its own planning text and can destabilize long tool
# loops. Keep reasoning out of the client-visible transcript.
source = source.replace(
    '"content": tool_calls[0].reasoning or None,',
    '"content": None,',
)

reasoning_block = '''    # If there's reasoning, send it as a content delta first
    if tool_calls[0].reasoning:
        events.append({
            "id": cmpl_id,
            "object": "chat.completion.chunk",
            "model": model,
            "choices": [{
                "index": 0,
                "delta": {"role": "assistant", "content": tool_calls[0].reasoning},
                "finish_reason": None,
            }],
        })

'''
source = source.replace(reasoning_block, '')

path.write_text(source)
print(f"patched tool-call reasoning visibility in {path}")


server_path = path.with_name("server.py")
server_source = server_path.read_text()
server_source = server_source.replace(
    'await self._send_sse_body(writer, [{"error": error_msg}])',
    'await self._send_sse_body(writer, [{"error": {"message": error_msg, "type": "proxy_error"}}])',
)
server_path.write_text(server_source)
print(f"patched streaming error shape in {server_path}")
