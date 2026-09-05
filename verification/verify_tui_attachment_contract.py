"""Offline contract probe against a supplied Hermes Agent checkout, no service restart.

Run with that checkout's venv:
  python verification/verify_tui_attachment_contract.py /path/to/hermes-agent

Uses real upload handlers, turn image consumption/routing, persistence shaping and
compression serialization. Provider configuration and session ownership are isolated
fixtures; no model calls, user configuration, credentials or running sessions are used.
"""
from __future__ import annotations

import base64
import io
import json
import os
from pathlib import Path
import random
import sys
import tempfile
import threading
from types import SimpleNamespace
from unittest.mock import patch


def main(source: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="hermes-attachment-contract-") as root:
        # Set before importing any Hermes module (many resolve home at import time).
        path = os.environ.get("PATH", "")
        os.environ.clear()
        os.environ.update(HOME=root, HERMES_HOME=root, PATH=path, HERMES_TEST_ISOLATION=root)
        os.chdir(root)
        sys.path.insert(0, str(source))
        from PIL import Image
        from tui_gateway import server
        from agent.context_compressor import ContextCompressor
        from agent.context_references import preprocess_context_references

        stream = io.BytesIO()
        Image.frombytes("RGB", (1024, 1024), random.Random(42).randbytes(1024 * 1024 * 3)).save(stream, format="PNG")
        image = stream.getvalue()
        assert len(image) > 3 * 1024 * 1024
        sid = "isolated-attachment-contract"
        agent = SimpleNamespace(provider="fixture", model="fixture", requested_provider="fixture")
        session = dict(agent=agent, agent_ready=threading.Event(), agent_error=None,
            attached_images=[], cwd=root, profile_home=root, history=[],
            history_lock=threading.RLock(), history_version=0, image_counter=0,
            running=False, session_key=sid, transport=None)
        server._sessions[sid] = session
        def call(method, **params):
            # Actual serialized JSON params, matching the app's RPC names and fields.
            params = json.loads(json.dumps(dict(session_id=sid, **params)))
            result = server._methods[method]("probe", params)
            assert "error" not in result, result.get("error")
            return result["result"]

        with patch.object(server, "_start_agent_build"), patch.object(server, "_ensure_active_session_slot", return_value=None):
            upload = call("image.attach_bytes", filename="shot.png",
                content_base64="data:image/png;base64," + base64.b64encode(image).decode())
            assert upload["attached"] is True
            staged = Path(upload["path"])
            assert staged.read_bytes() == image
            images, actual_agent = server._admit_prompt_turn(sid, session, "Describe", None, None)
            assert actual_agent is agent and images == [str(staged)]
            assert session["attached_images"] == []
            with patch("hermes_cli.config.load_config", return_value={"agent": {"image_input_mode": "native"}}):
                parts = server._route_turn_images(agent, "Describe", images)
            assert isinstance(parts, list)
            assert parts[0]["type"] == "text" and len(parts[0]["text"]) < 1024
            assert "base64" not in parts[0]["text"]
            media = parts[1]["image_url"]["url"]
            assert media.startswith("data:image/png;base64,")
            assert base64.b64decode(media.split(",", 1)[1]) == image
            persisted = server._build_persist_user_message("Describe", images, parts)
            assert "@image:" in persisted[0]["text"]
            assert "base64" not in server._content_display_text(persisted)
            compressor = ContextCompressor.__new__(ContextCompressor)
            summary = compressor._serialize_for_summary([{"role": "user", "content": persisted}])
            assert "base64" not in summary and len(summary) < 1024
            with patch("hermes_cli.config.load_config", return_value={"agent": {"image_input_mode": "text"}}):
                vision_ref = server._route_turn_images(agent, "Describe", images)
            assert "vision_analyze" in vision_ref and "base64" not in vision_ref
            assert len(vision_ref) < 1024

            binary = b"%PDF-1.7\n" + b"\x00\xff" * (1536 * 1024)
            file = call("file.attach", name="report file.pdf",
                data_url="data:application/pdf;base64," + base64.b64encode(binary).decode())
            assert file["attached"] is True
            assert Path(file["path"]).read_bytes() == binary
            expanded = preprocess_context_references("Inspect\n\n" + file["ref_text"],
                cwd=root, allowed_root=root, context_length=32000)
            assert not expanded.blocked and not expanded.warnings
            assert "binary file, not inlined as text" in expanded.message
            assert "application/pdf" in expanded.message
            assert "base64" not in expanded.message and len(expanded.message) < 2048
            print(json.dumps({"result": "PASS", "image_bytes": len(image),
                "model_text_chars": len(parts[0]["text"]), "compression_chars": len(summary),
                "binary_bytes": len(binary), "binary_context_chars": len(expanded.message),
                "verified": ["real image.attach_bytes", "turn queue consumed", "native image MIME/bytes",
                    "vision tool fallback", "persisted image sidecar", "compression strips image bytes",
                    "real file.attach", "binary reference expansion"]}, indent=2))
        server._sessions.pop(sid, None)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: verify_tui_attachment_contract.py HERMES_AGENT_SOURCE")
    main(Path(sys.argv[1]).resolve())
