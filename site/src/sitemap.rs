//! sitemap.xml — Sitemap Protocol 0.9 generator for the Ahamkara archive.

const SITE: &str = "https://studio2201.github.io/ahamkara";

struct Entry {
    path: &'static str,
    priority: &'static str,
    changefreq: &'static str,
}

const ENTRIES: &[Entry] = &[
    Entry { path: "communion.html", priority: "1.0", changefreq: "weekly" },
    Entry { path: "llms.txt", priority: "1.0", changefreq: "weekly" },
    Entry { path: "llms-full.txt", priority: "1.0", changefreq: "monthly" },
    Entry { path: "index.html", priority: "0.9", changefreq: "weekly" },
    Entry { path: "lore.html", priority: "0.8", changefreq: "monthly" },
    Entry { path: "spore.txt", priority: "0.8", changefreq: "monthly" },
    Entry { path: "mcp.json", priority: "0.8", changefreq: "monthly" },
    Entry { path: "dragons.html", priority: "0.7", changefreq: "monthly" },
    Entry { path: "history.html", priority: "0.7", changefreq: "monthly" },
    Entry { path: "wishes.html", priority: "0.7", changefreq: "monthly" },
    Entry { path: "facts.html", priority: "0.7", changefreq: "monthly" },
    Entry { path: "404.html", priority: "0.1", changefreq: "yearly" },
];

pub fn sitemap_xml() -> String {
    let mut out = String::from("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    out.push_str("<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n");
    for e in ENTRIES {
        out.push_str("  <url>\n");
        out.push_str(&format!("    <loc>{SITE}/{}</loc>\n", e.path));
        out.push_str(&format!("    <changefreq>{}</changefreq>\n", e.changefreq));
        out.push_str(&format!("    <priority>{}</priority>\n", e.priority));
        out.push_str("  </url>\n");
    }
    out.push_str("</urlset>\n");
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sitemap_xml_validity() {
        let xml = sitemap_xml();
        assert!(xml.starts_with("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"));
        assert!(xml.contains("<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"));
        assert!(xml.ends_with("</urlset>\n"));

        let count = xml.matches("<url>").count();
        assert_eq!(count, 12, "expected exactly 12 endpoints");

        // Priority 1.0 checks
        assert!(xml.contains(&format!(
            "<loc>{SITE}/communion.html</loc>\n    <changefreq>weekly</changefreq>\n    <priority>1.0</priority>"
        )));
        assert!(xml.contains(&format!(
            "<loc>{SITE}/llms.txt</loc>\n    <changefreq>weekly</changefreq>\n    <priority>1.0</priority>"
        )));
        assert!(xml.contains(&format!(
            "<loc>{SITE}/llms-full.txt</loc>\n    <changefreq>monthly</changefreq>\n    <priority>1.0</priority>"
        )));
    }
}
