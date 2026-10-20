# Hello World Remote MCP Server

A minimal remote Model Context Protocol (MCP) server built with [FastMCP](https://github.com/jlowin/fastmcp) using the **Streamable HTTP** transport (`/mcp`).

## Quick Start (Local)

```bash
uv sync
uv run server.py
```

The server listens on `http://0.0.0.0:8080/mcp` by default.

## Configuration

| Environment Variable | Default | Description |
| --- | --- | --- |
| `HOST` | `0.0.0.0` | Bind address |
| `PORT` | `8080` | HTTP port |
| `MCP_TRANSPORT` | `streamable-http` | MCP transport (`streamable-http` or `sse`) |

## Connect a Client

### MCP Client Configuration (`mcp_config.json`)

```json
{
  "mcpServers": {
    "hello-world-remote": {
      "url": "http://localhost:8080/mcp"
    }
  }
}
```

### Deploy to Cloud Run

```bash
gcloud run deploy hello-world-mcp \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```
