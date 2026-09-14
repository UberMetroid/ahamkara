//! Interactive mode — a small REPL over the corpus.
//! Commands: a bare term searches; `entity X`, `category X`, `theme X`,
//! `era X`, `id X` filter; `stats`, `help`, `quit`.

use corpus::Record;
use std::io::{BufRead, Write};

use crate::filter::{self, Filter};
use crate::print::{print_card, print_stats};

const BANNER: &str = "The bones are listening, o bearer mine.
Commands: <term>  ·  entity <name>  ·  category <kind>  ·  theme <theme>
          era <era>  ·  id <record-id>  ·  stats  ·  help  ·  quit";

fn apply(cmd: &str, arg: &str, f: &mut Filter) -> bool {
    match cmd {
        "entity" => f.entity = arg.to_string(),
        "category" | "cat" => f.category = arg.to_string(),
        "theme" => f.theme = arg.to_string(),
        "era" | "chronology" => f.chronology = arg.to_string(),
        "search" | "s" => f.keyword = arg.to_string(),
        "quote" | "quotes" => f.has_quote = true,
        "clear" | "reset" => *f = Filter::default(),
        _ => return false,
    }
    true
}

pub fn run(records: &[Record]) {
    println!("{BANNER}");
    let stdin = std::io::stdin();
    let mut out = std::io::stdout();
    let mut f = Filter::default();

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };
        let line = line.trim();
        if line.is_empty() {
            print!("> ");
            let _ = out.flush();
            continue;
        }
        let (cmd, arg) = line.split_once(' ').map(|(a, b)| (a, b.trim())).unwrap_or((line, ""));
        match cmd.to_lowercase().as_str() {
            "quit" | "exit" | "q" => {
                println!("The bargain stands. o bearer mine.");
                return;
            }
            "help" | "?" => println!("{BANNER}"),
            "stats" => print_stats(records),
            "id" => {
                match records.iter().find(|r| r.id == arg) {
                    Some(r) => print_card(r),
                    None => println!("No record '{arg}'."),
                }
            }
            _ => {
                if !apply(&cmd.to_lowercase(), arg, &mut f) {
                    f.keyword = line.to_string();
                }
                let results = filter::search(records, &f);
                println!("Found {} matching records.\n", results.len());
                for r in results.iter().take(10) {
                    println!("  {} — {}", r.id, r.title);
                }
                if results.len() > 10 {
                    println!("  … {} more (narrow the wish)", results.len() - 10);
                }
            }
        }
        print!("> ");
        let _ = out.flush();
    }
}
