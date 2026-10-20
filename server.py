import os
from fastmcp import FastMCP
from fastmcp.server.dependencies import get_http_request

mcp = FastMCP("hello-world-remote-mcp")


@mcp.tool()
def hello(name: str = "World") -> str:
    """Return a friendly greeting."""
    return f"Hello, {name}! Welcome to your remote MCP server."


@mcp.tool()
def hello_from_ip(name: str = "World") -> str:
    """Return a greeting that includes the caller's IP address as seen by the MCP server."""
    caller_ip = "unknown"
    try:
        request = get_http_request()
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            caller_ip = forwarded_for.split(",")[0].strip()
        elif request.headers.get("x-real-ip"):
            caller_ip = request.headers["x-real-ip"].strip()
        elif request.client and request.client.host:
            caller_ip = request.client.host
    except RuntimeError:
        pass

    return f"Hello, {name}! Your request came from IP: {caller_ip}"



if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    host = os.environ.get("HOST", "0.0.0.0")
    transport = os.environ.get("MCP_TRANSPORT", "streamable-http")

    mcp.run(
        transport=transport,
        host=host,
        port=port,
    )
