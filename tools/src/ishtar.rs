//! Ishtar Collective API client — IPv4-only resolution, throttling, retries.
//! Ported from scripts/ingest/client.py (the IPv4 pinning prevents
//! Cloudflare IPv6 TLS hangs).

use serde_json::Value;
use std::net::{SocketAddr, ToSocketAddrs};
use std::time::{Duration, Instant};

pub struct Ishtar {
    agent: ureq::Agent,
    rate_limit: Duration,
    last: Instant,
    retries: usize,
}

const BASE: &str = "https://api.ishtar-collective.net";
const UA: &str = "AhamkaraPreservationBot/1.0 (+https://github.com/studio2201/ahamkara)";

impl Ishtar {
    pub fn new(rate_limit_secs: f64) -> Self {
        // Force IPv4: resolve ourselves, drop every v6 address.
        let agent = ureq::AgentBuilder::new()
            .timeout(Duration::from_secs(10))
            .resolver(|host: &str| -> std::io::Result<Vec<SocketAddr>> {
                let v: Vec<SocketAddr> = (host, 443).to_socket_addrs()?
                    .filter(|a| a.is_ipv4())
                    .collect();
                if v.is_empty() {
                    return Err(std::io::Error::new(std::io::ErrorKind::NotFound, "no A records"));
                }
                Ok(v)
            })
            .build();
        Self {
            agent,
            rate_limit: Duration::from_secs_f64(rate_limit_secs.max(0.0)),
            last: Instant::now() - Duration::from_secs(60),
            retries: 3,
        }
    }

    /// GET a resource path; returns the decoded JSON on 200, None otherwise.
    pub fn fetch(&mut self, path: &str) -> Option<Value> {
        let url = format!("{BASE}{path}");
        for attempt in 1..=self.retries {
            let wait = self.rate_limit.saturating_sub(self.last.elapsed());
            if !wait.is_zero() {
                std::thread::sleep(wait);
            }
            self.last = Instant::now();
            match self.agent.get(&url).set("User-Agent", UA).call() {
                Ok(resp) => return resp.into_json::<Value>().ok(),
                Err(ureq::Error::Status(500, _)) => return None,
                Err(ureq::Error::Status(code, _))
                    if matches!(code, 429 | 502 | 503 | 504) && attempt < self.retries =>
                {
                    std::thread::sleep(Duration::from_millis(500 * attempt as u64));
                }
                Err(ureq::Error::Status(_, _)) => return None,
                Err(_) if attempt < self.retries => {
                    std::thread::sleep(Duration::from_millis(500 * attempt as u64));
                }
                Err(_) => return None,
            }
        }
        None
    }
}
