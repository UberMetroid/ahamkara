"""Ishtar Collective API client: IPv4 enforcement, throttling, retries."""

import json
import socket
import time
import urllib.error
import urllib.request

# Force IPv4 socket resolution globally to prevent Cloudflare IPv6 TLS hangs
_orig_getaddrinfo = socket.getaddrinfo


def _getaddrinfo_ipv4(host, port, family=0, type=0, proto=0, flags=0):
    return _orig_getaddrinfo(host, port, socket.AF_INET, type, proto, flags)


socket.getaddrinfo = _getaddrinfo_ipv4

try:
    import urllib3.util.connection
    urllib3.util.connection.allowed_gai_family = lambda: socket.AF_INET
except ImportError:
    pass


class IshtarClient:
    """HTTP client for the Ishtar Collective API with IPv4 enforcement and rate limiting."""

    BASE_URL = "https://api.ishtar-collective.net"
    USER_AGENT = "AhamkaraPreservationBot/1.0 (+https://github.com/studio2201/ahamkara)"

    def __init__(self, rate_limit: float = 0.1, timeout: float = 10.0, max_retries: int = 3):
        self.rate_limit = rate_limit
        self.timeout = timeout
        self.max_retries = max_retries
        self._last_call = 0.0

    def _throttle(self):
        elapsed = time.time() - self._last_call
        if elapsed < self.rate_limit:
            time.sleep(self.rate_limit - elapsed)
        self._last_call = time.time()

    def fetch(self, path: str):
        """Fetch a resource path from Ishtar API with throttling and retry logic."""
        url = f"{self.BASE_URL}{path}"
        req = urllib.request.Request(url, headers={"User-Agent": self.USER_AGENT})

        for attempt in range(1, self.max_retries + 1):
            self._throttle()
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    if resp.status == 200:
                        raw = resp.read().decode("utf-8")
                        return json.loads(raw)
                    return None
            except urllib.error.HTTPError as e:
                if e.code == 500:
                    return None
                elif e.code in (429, 502, 503, 504) and attempt < self.max_retries:
                    time.sleep(0.5 * attempt)
                    continue
                else:
                    return None
            except (urllib.error.URLError, socket.timeout, ConnectionResetError):
                if attempt < self.max_retries:
                    time.sleep(0.5 * attempt)
                    continue
                return None
            except Exception:
                return None
        return None
