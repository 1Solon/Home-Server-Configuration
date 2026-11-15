#!/usr/bin/env python3
"""Print a GitHub installation token for Milton's GitHub App.

The gh wrapper next to this file calls it, so every gh and git command the
agent runs is signed in as the app. Tokens last an hour; one is cached under
/tmp and reused until it has under ten minutes left.

Reads the app ID and private key mounted under /opt/secrets/github-app.
Standard library plus the openssl CLI only, so an image upgrade that drops a
Python package can't break it. Flux substitutes braced dollar variables in
this file, so don't write any.
"""

import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime

API = "https://api.github.com"
SECRET_DIR = os.environ.get("MILTON_GITHUB_APP_DIR", "/opt/secrets/github-app")
CACHE = os.path.join(tempfile.gettempdir(), f"github-app-token-{os.getuid()}.json")


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def normalise_pem(text):
    """Rebuild the PEM line structure.

    A key pasted into a single-line 1Password field arrives with its newlines
    turned into spaces or dropped, which openssl refuses to read.
    """
    text = text.strip()
    if "-----BEGIN" not in text:
        try:
            text = base64.b64decode(text, validate=True).decode().strip()
        except Exception:
            fail("private key is neither PEM nor base64-encoded PEM")
    match = re.search(r"-----BEGIN ([A-Z ]+)-----(.*?)-----END \1-----", text, re.S)
    if not match:
        fail("private key has no matching BEGIN/END lines")
    label = match.group(1)
    body = re.sub(r"\s+", "", match.group(2).replace("\\n", ""))
    lines = [body[i : i + 64] for i in range(0, len(body), 64)]
    return "\n".join([f"-----BEGIN {label}-----", *lines, f"-----END {label}-----", ""])


def read_secret(name):
    path = os.path.join(SECRET_DIR, name)
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError as exc:
        fail(f"cannot read {path}: {exc}")


def app_jwt():
    app_id = read_secret("app-id").strip()
    pem = normalise_pem(read_secret("private-key.pem"))
    now = int(time.time())
    # Backdated a minute for clock drift; GitHub caps the lifetime at 10 minutes.
    claims = {"iat": now - 60, "exp": now + 540, "iss": app_id}
    signing_input = ".".join(
        b64url(json.dumps(part, separators=(",", ":")).encode())
        for part in ({"alg": "RS256", "typ": "JWT"}, claims)
    )
    with tempfile.NamedTemporaryFile("w", suffix=".pem") as key_file:
        os.chmod(key_file.name, 0o600)
        key_file.write(pem)
        key_file.flush()
        result = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_file.name],
            input=signing_input.encode(),
            capture_output=True,
            check=False,
        )
    if result.returncode != 0:
        fail(f"openssl could not sign with the app key: {result.stderr.decode().strip()}")
    return f"{signing_input}.{b64url(result.stdout)}"


def request(method, path, token, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "milton-github-app",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:300]
        fail(f"{method} {path} returned HTTP {exc.code}: {detail}")
    except urllib.error.URLError as exc:
        fail(f"{method} {path} failed: {exc.reason}")


def read_cache():
    try:
        with open(CACHE, encoding="utf-8") as handle:
            cached = json.load(handle)
        if cached["expires"] - time.time() > 600:
            return cached
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return None


def credentials():
    """Return {"token": installation token, "login": the app's author login}."""
    cached = read_cache()
    if cached:
        return cached
    jwt = app_jwt()
    slug = request("GET", "/app", jwt)["slug"]
    installations = request("GET", "/app/installations", jwt)
    if not installations:
        fail(f"the {slug} app is not installed on any account")
    # The app is private to one account, so it has a single installation.
    grant = request("POST", f"/app/installations/{installations[0]['id']}/access_tokens", jwt)
    expires = datetime.fromisoformat(grant["expires_at"].replace("Z", "+00:00")).timestamp()
    fresh = {"token": grant["token"], "login": f"{slug}[bot]", "expires": expires}
    # Written under a private name and renamed, so a concurrent reader never
    # sees a half-written or world-readable file.
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(CACHE), prefix=".github-app-token-")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(fresh, handle)
    os.replace(tmp, CACHE)
    return fresh


if __name__ == "__main__":
    print(credentials()["login" if sys.argv[1:] == ["--login"] else "token"])
