# ruff: noqa
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
from typing import Any

from google.adk.agents import Agent
from google.adk.apps import App
from google.adk.dependencies import _httpx as adk_httpx
from google.adk.models import Gemini
from google.adk.tools.mcp_tool import McpToolset
from google.adk.tools.mcp_tool.mcp_session_manager import (
    SseConnectionParams,
    StreamableHTTPConnectionParams,
)
from google.genai import types
from mcp.shared._httpx_utils import (
    MCP_DEFAULT_SSE_READ_TIMEOUT,
    MCP_DEFAULT_TIMEOUT,
)

# Prevent Google Auth mTLS transport probing from overriding custom httpx_client_factory
os.environ.setdefault("GOOGLE_API_USE_CLIENT_CERTIFICATE", "false")

MCP_SERVER_URL = os.environ.get("MCP_SERVER_URL", "http://localhost:8080/mcp")
MCP_TRANSPORT = os.environ.get("MCP_TRANSPORT", "streamable-http").lower()
MCP_PROXY_URL = os.environ.get("MCP_PROXY_URL", "").strip() or None
AGENT_MODEL = os.environ.get("AGENT_MODEL", "gemini-2.5-flash")


def _build_httpx_client_factory(proxy_url: str | None):
    """Build an ADK-compatible HTTPX AsyncClient factory routed via proxy_url."""
    if not proxy_url:
        return None

    def _factory(
        headers: dict[str, str] | None = None,
        timeout: Any | None = None,
        auth: Any | None = None,
    ) -> Any:
        if timeout is None:
            timeout = adk_httpx.Timeout(
                MCP_DEFAULT_TIMEOUT, read=MCP_DEFAULT_SSE_READ_TIMEOUT
            )
        kwargs: dict[str, Any] = {
            "timeout": timeout,
            "proxy": proxy_url,
        }
        if headers is not None:
            kwargs["headers"] = headers
        if auth is not None:
            kwargs["auth"] = auth
        return adk_httpx.AsyncClient(**kwargs)

    return _factory


_client_factory = _build_httpx_client_factory(MCP_PROXY_URL)
_conn_kwargs: dict[str, Any] = {"url": MCP_SERVER_URL}
if _client_factory is not None:
    _conn_kwargs["httpx_client_factory"] = _client_factory

connection_params = (
    SseConnectionParams(**_conn_kwargs)
    if MCP_TRANSPORT == "sse"
    else StreamableHTTPConnectionParams(**_conn_kwargs)
)

mcp_toolset = McpToolset(connection_params=connection_params)

root_agent = Agent(
    name="root_agent",
    model=Gemini(
        model=AGENT_MODEL,
        retry_options=types.HttpRetryOptions(attempts=3),
    ),
    instruction=(
        "You are a helpful assistant connected to a remote Hello World MCP server. "
        "Use the `hello` tool to greet users and `hello_from_ip` when asked to greet "
        "them or check the caller IP address seen by the remote MCP server."
    ),
    tools=[mcp_toolset],
)

app = App(
    root_agent=root_agent,
    name="app",
)
