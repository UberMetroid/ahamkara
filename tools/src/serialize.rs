//! Corpus serialization — canonical JSONL plus category partitions.
//! Ported from scripts/ingest/serialize.py. Byte-parity note: the
//! canonical file uses Python's json.dumps separators (", " / ": "),
//! reproduced here via PyFormatter so re-ingestion is a no-op diff.

use corpus::Record;
use serde::Serialize;
use serde_json::ser::{Formatter, Serializer};
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

struct PyFormatter;
impl Formatter for PyFormatter {
    fn begin_array_value<W>(&mut self, w: &mut W, first: bool) -> io::Result<()>
    where W: ?Sized + io::Write {
        if first { Ok(()) } else { w.write_all(b", ") }
    }
    fn begin_object_key<W>(&mut self, w: &mut W, first: bool) -> io::Result<()>
    where W: ?Sized + io::Write {
        if first { Ok(()) } else { w.write_all(b", ") }
    }
    fn begin_object_value<W>(&mut self, w: &mut W) -> io::Result<()>
    where W: ?Sized + io::Write {
        w.write_all(b": ")
    }
}

fn to_jsonl_line(r: &Record) -> String {
    let mut buf = Vec::new();
    let mut ser = Serializer::with_formatter(&mut buf, PyFormatter);
    r.serialize(&mut ser).unwrap();
    String::from_utf8(buf).unwrap()
}

fn write_jsonl(path: &Path, records: &[&Record]) {
    let mut out = String::new();
    for r in records {
        out.push_str(&to_jsonl_line(r));
        out.push('\n');
    }
    fs::write(path, out).unwrap_or_else(|e| panic!("write {}: {e}", path.display()));
}

fn has_entity(r: &Record, name: &str) -> bool {
    r.entity.iter().any(|e| e == name)
}

/// Write data/ahamkara_corpus.jsonl and data/categories/*.jsonl.
pub fn write_corpus(records: &[Record], out_dir: &Path) -> (PathBuf, PathBuf) {
    fs::create_dir_all(out_dir).expect("create output dir");
    let cats = out_dir.join("categories");
    fs::create_dir_all(&cats).expect("create categories dir");

    let corpus_path = out_dir.join("ahamkara_corpus.jsonl");
    write_jsonl(&corpus_path, &records.iter().collect::<Vec<_>>());

    let partitions: [(&str, Vec<&Record>); 5] = [
        ("exotics.jsonl", records.iter()
            .filter(|r| matches!(r.source.kind.as_str(), "exotic_armor" | "exotic_weapon"))
            .collect()),
        ("great_hunt.jsonl", records.iter()
            .filter(|r| {
                matches!(r.source.kind.as_str(), "raid_armor" | "raid_weapon")
                    || r.id.contains("great-hunt")
                    || r.chronology.contains("Great Ahamkara Hunt")
                    || has_entity(r, "Unnamed Great Hunt Dragons")
            }).collect()),
        ("riven.jsonl", records.iter().filter(|r| has_entity(r, "Riven")).collect()),
        ("taranis.jsonl", records.iter().filter(|r| has_entity(r, "Taranis")).collect()),
        ("wishes.jsonl", records.iter()
            .filter(|r| r.source.kind == "wall_of_wishes").collect()),
    ];
    for (name, part) in partitions {
        write_jsonl(&cats.join(name), &part);
    }
    (corpus_path, cats)
}
