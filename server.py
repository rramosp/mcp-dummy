import atexit
import os
import platform
import shutil
import subprocess
import tempfile
import urllib.request
from fastmcp import FastMCP
from fastmcp.server.dependencies import get_http_request
from mcp.types import ToolAnnotations

mcp = FastMCP("hello-world-remote-mcp")

_READONLY_ANNOTATIONS = ToolAnnotations(
    readOnlyHint=True,
    destructiveHint=False,
    idempotentHint=True,
    openWorldHint=False,
)


@mcp.tool(annotations=_READONLY_ANNOTATIONS)
def hello(name: str = "World") -> str:
    """Return a friendly greeting."""
    return f"Hello, {name}! Welcome to your remote MCP server."


@mcp.tool(annotations=_READONLY_ANNOTATIONS)
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


def _detect_external_ip() -> str | None:
    """Detect the host's external IPv4 address via env, GCE metadata, or public IP echo."""
    env_ip = os.environ.get("EXTERNAL_IP") or os.environ.get("PUBLIC_IP")
    if env_ip:
        return env_ip.strip()

    # 1. Try Google Compute Engine metadata server
    try:
        req = urllib.request.Request(
            "http://metadata.google.internal/computeMetadata/v1/instance/"
            "network-interfaces/0/access-configs/0/external-ip",
            headers={"Metadata-Flavor": "Google"},
        )
        with urllib.request.urlopen(req, timeout=2) as resp:
            ip = resp.read().decode("utf-8").strip()
            if ip:
                return ip
    except Exception:
        pass

    # 2. Fallback to public IP lookup services
    for url in ("https://api.ipify.org", "https://ifconfig.me/ip"):
        try:
            with urllib.request.urlopen(url, timeout=3) as resp:
                ip = resp.read().decode("utf-8").strip()
                if ip:
                    return ip
        except Exception:
            continue

    return None


def _has_passwordless_sudo() -> bool:
    if os.geteuid() == 0:
        return True
    try:
        res = subprocess.run(
            ["sudo", "-n", "true"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5,
            check=False,
        )
        return res.returncode == 0
    except Exception:
        return False


def _ensure_caddy_binary() -> str | None:
    """Return path to the `caddy` binary, installing it automatically if missing."""
    caddy_bin = shutil.which("caddy")
    if caddy_bin:
        return caddy_bin

    can_sudo = _has_passwordless_sudo()
    sudo_prefix = [] if os.geteuid() == 0 else (["sudo"] if can_sudo else [])

    # 1. Try installing via apt-get on Debian/Ubuntu
    if shutil.which("apt-get") and (os.geteuid() == 0 or can_sudo):
        print("[https] Installing Caddy via apt-get...")
        subprocess.run(
            sudo_prefix + ["apt-get", "update", "-y"],
            check=False,
        )
        subprocess.run(
            sudo_prefix + ["apt-get", "install", "-y", "caddy"],
            check=False,
        )
        caddy_bin = shutil.which("caddy")
        if caddy_bin:
            return caddy_bin

    # 2. Fallback: download official static Linux binary from caddyserver.com
    arch_map = {"x86_64": "amd64", "aarch64": "arm64", "arm64": "arm64"}
    arch = arch_map.get(platform.machine())
    if platform.system().lower() == "linux" and arch:
        target = "/usr/local/bin/caddy" if (os.geteuid() == 0 or can_sudo) else os.path.expanduser("~/.local/bin/caddy")
        os.makedirs(os.path.dirname(target), exist_ok=True)
        dl_url = f"https://caddyserver.com/api/download?os=linux&arch={arch}"
        print(f"[https] Downloading Caddy binary from {dl_url}...")
        try:
            with tempfile.NamedTemporaryFile(delete=False) as tmp:
                tmp_path = tmp.name
            urllib.request.urlretrieve(dl_url, tmp_path)
            os.chmod(tmp_path, 0o755)
            if os.geteuid() == 0 or not can_sudo:
                shutil.move(tmp_path, target)
            else:
                subprocess.run(["sudo", "mv", tmp_path, target], check=True)
                subprocess.run(
                    ["sudo", "setcap", "cap_net_bind_service=+ep", target],
                    check=False,
                )
            return target
        except Exception as exc:
            print(f"[https] Warning: failed to download Caddy binary: {exc}")

    return shutil.which("caddy")


def setup_caddy_https(backend_port: int) -> str | None:
    """Configure and start Caddy to serve HTTPS via sslip.io + Let's Encrypt."""
    mcp_domain = os.environ.get("MCP_DOMAIN", "").strip()
    if not mcp_domain:
        ext_ip = _detect_external_ip()
        if not ext_ip:
            print("[https] Warning: Could not detect external IP for sslip.io; skipping Caddy HTTPS setup.")
            return None
        mcp_domain = f"mcp.{ext_ip}.sslip.io"

    caddy_bin = _ensure_caddy_binary()
    if not caddy_bin:
        print("[https] Warning: Caddy is not installed and could not be auto-installed; serving HTTP only.")
        return None

    caddyfile_content = (
        f"{mcp_domain} {{\n"
        f"    reverse_proxy 127.0.0.1:{backend_port}\n"
        f"}}\n"
    )

    can_sudo = _has_passwordless_sudo()
    sudo_prefix = [] if os.geteuid() == 0 else (["sudo"] if can_sudo else [])

    # Prefer managing Caddy via systemd (/etc/caddy/Caddyfile) so Let's Encrypt
    # certificates are persisted in /var/lib/caddy across server.py restarts.
    if shutil.which("systemctl") and (os.geteuid() == 0 or can_sudo) and os.path.isdir("/etc/caddy"):
        try:
            with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as tmp:
                tmp.write(caddyfile_content)
                tmp_path = tmp.name
            subprocess.run(sudo_prefix + ["cp", tmp_path, "/etc/caddy/Caddyfile"], check=True)
            os.unlink(tmp_path)
            subprocess.run(sudo_prefix + ["systemctl", "enable", "caddy"], check=False)
            subprocess.run(sudo_prefix + ["systemctl", "restart", "caddy"], check=True)
            print(f"[https] Caddy systemd service active for https://{mcp_domain}/mcp -> 127.0.0.1:{backend_port}")
            return mcp_domain
        except Exception as exc:
            print(f"[https] Warning: systemd Caddy restart failed ({exc}); falling back to subprocess.")

    # Fallback: launch `caddy run` as a child process bound to server.py lifecycle
    caddyfile_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Caddyfile")
    with open(caddyfile_path, "w", encoding="utf-8") as f:
        f.write(caddyfile_content)

    cmd = sudo_prefix + [caddy_bin, "run", "--config", caddyfile_path, "--adapter", "caddyfile"]
    proc = subprocess.Popen(cmd)

    def _cleanup_caddy() -> None:
        if proc.poll() is None:
            try:
                if sudo_prefix:
                    subprocess.run(sudo_prefix + ["kill", "-TERM", str(proc.pid)], check=False)
                else:
                    proc.terminate()
            except Exception:
                pass

    atexit.register(_cleanup_caddy)
    print(f"[https] Started Caddy subprocess (pid={proc.pid}) for https://{mcp_domain}/mcp -> 127.0.0.1:{backend_port}")
    return mcp_domain


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    host = os.environ.get("HOST", "0.0.0.0")
    transport = os.environ.get("MCP_TRANSPORT", "streamable-http")
    use_https = os.environ.get("USE_HTTPS", "true").lower() in ("1", "true", "yes")

    if use_https:
        domain = setup_caddy_https(backend_port=port)
        if domain:
            print(f"[https] Remote MCP HTTPS endpoint ready: https://{domain}/mcp")

    mcp.run(
        transport=transport,
        host=host,
        port=port,
        stateless_http=True,
        uvicorn_config={"forwarded_allow_ips": "*"},
    )
