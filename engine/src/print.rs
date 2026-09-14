//! Terminal rendering — record cards and the stats dashboard.

use corpus::Record;
use std::collections::BTreeMap;

/// One record as a bordered card — matches the old engine's output shape.
pub fn print_card(r: &Record) {
    let src = [
        Some(r.source.kind.replace('_', " ")),
        Some(r.source.game.clone()),
        r.source.book.clone(),
        r.source.release.clone(),
    ]
    .into_iter()
    .flatten()
    .collect::<Vec<_>>()
    .join(" · ");

    println!("+------------------------------------------------------------------+");
    println!("| {:<66} |", trunc(&r.title, 66));
    println!("+------------------------------------------------------------------+");
    println!("  id:       {}", r.id);
    println!("  entity:   {}", r.entity.join(" · "));
    println!("  speaker:  {}", r.speaker.as_deref().unwrap_or("unattributed"));
    println!("  source:   {src}");
    println!("  era:      {}", r.chronology);
    println!("  theme:    {}", r.theme);
    println!("  tags:     {}", r.tags.join(", "));
    if let Some(u) = &r.source.ishtar_url {
        println!("  ishtar:   {u}");
    }
    println!("--------------------------------------------------------------------");
    for p in r.transcript.split("\n\n") {
        println!("  {}", p.replace('\n', "\n  "));
        println!();
    }
}

fn trunc(s: &str, n: usize) -> String {
    if s.chars().count() <= n {
        s.to_string()
    } else {
        format!("{}…", s.chars().take(n - 1).collect::<String>())
    }
}

fn counts_by<'a>(recs: &'a [Record], key: impl Fn(&'a Record) -> Vec<String>) -> BTreeMap<String, usize> {
    let mut m = BTreeMap::new();
    for r in recs {
        for k in key(r) {
            *m.entry(k).or_default() += 1;
        }
    }
    m
}

/// Corpus analytics — computed dynamically from the records, not hardcoded.
pub fn print_stats(recs: &[Record]) {
    let quotes = recs.iter().filter(|r| r.has_quote()).count();
    println!("============================================================");
    println!("           Ahamkara Corpus Analytics & Statistics           ");
    println!("============================================================");
    println!("Total records: {}", recs.len());
    println!("Total quotes/whispers: {quotes}");
    println!();
    println!("--- Records by Entity ---");
    for (k, n) in counts_by(recs, |r| r.entity.clone()) {
        println!("  {k}: {n}");
    }
    println!();
    println!("--- Records by Category ---");
    for (k, n) in counts_by(recs, |r| vec![r.source.kind.replace('_', " ")]) {
        println!("  {k}: {n}");
    }
    println!();
    println!("--- Records by Era ---");
    for (k, n) in counts_by(recs, |r| vec![r.chronology.clone()]) {
        println!("  {k}: {n}");
    }
    println!();
    println!("--- Records by Theme ---");
    for (k, n) in counts_by(recs, |r| vec![r.theme.clone()]) {
        println!("  {k}: {n}");
    }
    println!("============================================================");
}
