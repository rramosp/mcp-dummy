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
"""
You can add your unit tests here.
This is where you test your business logic, including agent functionality,
data processing, and other core components of your application.
"""


from google.adk.tools.mcp_tool import McpToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StreamableHTTPConnectionParams

from app.agent import mcp_toolset, root_agent


def test_agent_mcp_toolset_configured() -> None:
    """Verify root_agent is configured with the remote MCP toolset."""
    assert root_agent.name == "root_agent"
    assert mcp_toolset in root_agent.tools
    assert isinstance(mcp_toolset, McpToolset)
    assert isinstance(mcp_toolset._connection_params, StreamableHTTPConnectionParams)
