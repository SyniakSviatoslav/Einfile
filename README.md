<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
<!--
Maintainer notes (not rendered). Benchmark numbers come from one run on one named machine
(.github/workflows/bench-full.yml or a lab box), quoted with its command and raw output. Held back, each in a comment below:
  VALUE LINE           below the tagline: show a lawyer before it renders
  COMPARISON SENTENCE  How it compares: renders only with the dated table it cites
  ILLUSTRATION         an original dog, not drawn yet
Word rule: no claim of priority or exclusivity; `tools/gates/pq-words.sh` applies: say what runs, name the primitive.
-->

# einfile

**One file that merges without a server, proves its history, and reads itself.**

Proving means integrity, not truth, and rollback shows only with an anchor.<br>
Merge is M2-min: conflicts are named, a person resolves.<br>
Reading itself means archive files.

A database that is one file, like SQLite. Unlike SQLite, two copies merge, and anyone can check the file was not altered. See [When not to use it](#when-not-to-use-it).

<!--
HOLD: VALUE LINE. Operator wording, verbatim. Show a lawyer before it renders. Add no legal claim. `Erasure and guesses` in Limits must stay.

Designed for erasure: a record can be removed from a signed history without breaking it, and an erased id confirms no guess. Compliance is your organisation's, not a library's.
-->

---

**Status: pre-1.0. Nothing has been released.** The format is normative for the bytes written today and is not frozen: a layout no production image holds may still change before 1.0, and the 1.0 release fixes the text. No external audit is on record. Read [When not to use it](#when-not-to-use-it) and [Limits](#limits) before you rely on any of this.

## What it is

Ein is an embedded storage library and a file format. One `.ein` file can hold:

- **A key-value store.** Commits are all-or-nothing, and damage is refused by name instead of being read as data.
- **A signed event log.** Each device has its own chain, and a seal over the chain's tip makes a later edit visible.
- **Evidence from outside the file** that a record existed by a moment (an anchor).
- **Its own reader.** An archive file carries a wasm reader and the format text.

Merging, sealing and anchors work on the signed file (a DOC root), not on a plain key-value file. A file reads with no server. The format is pointer-free, so another language can read it from the text in [`docs/FORMAT.md`](docs/FORMAT.md) alone.

Nothing in the file is encrypted. It holds your data as plain bytes.

![The container: two superblock pages and an append-only arena of checksummed objects. The DOC root points to the event log, the KV tree, one head and seal per device, the keys, and the file's own reader.](docs/img/file-layout.svg)

## Quickstart

```rust
use einstore::{Db, Durability, Options, Refusal, Verify};

fn main() -> Result<(), Refusal> {
    let path = "shop.ein";
    let _ = std::fs::remove_file(path);
    {
        let db = Db::create_path(path, Options::default())?;
        let mut w = db.begin_write()?;
        w.put(b"order/0001", b"new")?;
        w.put(b"order/0002", b"paid")?;
        w.commit(Durability::Data)?; // back when it is on the device
    } // the Db drops here; the file and its lock are released
    let db = Db::open_path(path, Options::default().verify(Verify::Reachable))?;
    let r = db.begin_read();
    for e in r.prefix(b"order/")? {
        let (k, v) = e?;
        println!("{} = {}", String::from_utf8_lossy(&k), String::from_utf8_lossy(&v));
    }
    Ok(())
}
```

This is a shortened [`examples/kv.rs`](examples/kv.rs), which also reads one key, prints the fold root and shows a refusal. Python goes through the C ABI: [`examples/kv.py`](examples/kv.py).

This is the key-value layer alone. It shows none of the three things in the tagline. For those, see the examples:

| Promise | Example |
|---|---|
| A changed byte is refused by name | [`refuse_damage`](crates/einstore/examples/refuse_damage.rs) |
| An unfinished commit is not there | [`crash_fallback`](crates/einstore/examples/crash_fallback.rs) |
| An edit under a seal is seen (level 0) | [`sealed_history`](crates/einstore/examples/sealed_history.rs) |
| Keys are records; a revoke invalidates later seals (level 0) | [`revoke_key`](crates/einstore/examples/revoke_key.rs) |
| An anchor nobody checked counts as nothing (level 1) | [`time_anchor`](crates/einstore/examples/time_anchor.rs) |
| History leaves under a signed declaration, never without one | [`cut_history`](crates/einstore/examples/cut_history.rs) |
| An erasure is declared, never hidden | [`forget_a_person`](crates/einstore/examples/forget_a_person.rs) |
| The file reads with nothing installed | [`read_without_library`](crates/einstore/examples/read_without_library.rs) |
| An archive carries its own reader | [`archive`](crates/einstore/examples/archive.rs) |

The sealed examples use a stand-in named `AnyoneCanForge`, which is **not a signature**: anyone can make one. They show the layout and the counters, nothing more.

`Options::default()` opens at `Verify::Anchor`, which proves the last commit and no earlier one. Older commits are trusted until you open at `Verify::Reachable` or call `Db::verify`.

## Guarantee levels

Each level is optional and works on the same file. A chain is never required.

![Guarantee levels: 0 the file is built; 1 the anchor has its format and seam built, adapters elsewhere; 2 the settlement is not built.](docs/img/levels.svg)

| Level | What it adds | Status |
|---|---|---|
| **0, the file** | Per-device chains and seals, read from the file and public keys alone. M2-min merge of two copies. A file that reads with no install. | Format, writer and counters built. ML-DSA-65 checking in `einfile-sig-mldsa`: see [Signing](#signing). |
| **1, the anchor** | Evidence from outside the file that a record existed by a moment: OpenTimestamps, a time-stamp authority's signature, or Roughtime as a lower bound. | The format and the `AnchorCheck` seam are built. **The adapters are not in this repository.** An anchor nobody checked counts as nothing. |
| **2, the settlement** | Witnesses or a chain fixing the order between organisations that do not trust each other. | **Not built.** |

**What an ok seal says:** the holder of key K signed this tip at seq s of its chain, and nothing under the tip has changed since. It does not say the event happened, that a quantity is true, or that a clock in the seal is right.

**What merge does.** `Doc::merge_into` joins two copies of one genesis with no server and keeps every record and seal. When both sides wrote, your code names the conflicts and signs them as one MERGE record; nothing resolves them but a person. It refuses, by name, a cut, an erasure or a revocation on one side alone, one device forked across the copies, and two seal chains of one key. Under a cut a conflict list cannot be re-derived, so the answer is `NOT CHECKED`, never clean. It takes a `Verifier`, and the caller still owes the signed MERGE, so a real merge needs the provider from [Signing](#signing).

![Two copies of one genesis grow apart on two devices; merge_into keeps every record and seal, the caller names the conflict and signs a MERGE record; one-sided cuts, erasures, revocations and forks are refused by name.](docs/img/merge.svg)

## Verify a file with nothing installed

You need Python 3 or Node 22, and one file from this repository. Neither reader needs the library, a build or the network.

```sh
python3 -I tools/verify/ein-verify.py your.ein --dump --verify
node tools/verify/ein-verify.mjs your.ein --dump --verify
```

The Python file uses nothing outside the standard library and shares no code with the library. The Node file embeds the wasm reader. Both print one status line, exit with the status, and with `--verify` print a signed file's counters. On the conformance fixture `anch`, trimmed to three lines:

```text
seals COUNTED, not CHECKED: this reader carries no signature algorithm (stdlib, no ML-DSA); a count is not a proof -- bring a verifier, or the format text's independent readers
doc status=0 n=4 root=4203703982444439664
verify records=4 chained=4 legacy=0 redacted=0 broken=0 forks=0 seals=4 checked=0 heads=1 keys=1 genesis=1 segments=1 cut=9 cut_redacted=2 declared=2 keys_disagree=0 unsealed=0 merges=0 merges_bad=0
```

**What `status=0` means:** every object the root reaches matches its checksum, the last commit matches its anchor, and the layout rules hold.

**What it does not mean:** that the content is true, or that nobody forged it. CRC-32 is not cryptographic, and a reader with no signature algorithm cannot tell a forged file from an honest one if the forger recomputed the checksums and ids. `checked=0` means the seals were counted and not checked, and such a reader's overall verdict (`holds`) is false, whatever else it prints.

An archive file also carries its own reader:

```sh
node examples/read.mjs archive.ein
```

That reader is testimony, not authority, because a file cannot vouch for itself. `read.mjs` computes the sha256, checks the module's outline, and runs the reader it pins and no other. Any other reader is refused as `UNPINNED` and is not run. It counts seals too; it does not check them.

## Signing

- **The scheme.** `alg` 65 is external pure ML-DSA-65 (FIPS 204, `ML-DSA.Sign` and `ML-DSA.Verify`, algorithms 2 and 3) with the empty context: `M' = 0x00 ‖ 0x00 ‖ message`, `ctx = ""`. That is plain signing in a stock library.
- **Interoperability.** The format asks for nothing beyond plain FIPS 204. A signature from the internal interface over the bare message is a `bad` seal. The reference writer signs with `rnd = 0^32`, and verification does not depend on `rnd`.
- **The provider.** [`crates/einfile-sig-mldsa`](crates/einfile-sig-mldsa), MIT OR Apache-2.0, a small adapter over `fips204` 0.5 (MIT OR Apache-2.0), with RustCrypto `ml-dsa` as the fallback. `DeviceKey` is a `Signer`, `MlDsa65` a `Verifier`, and `Sha256Ids` the ready-made id scheme (FORMAT §9.4's nonce and tombstone, RFC 9162 segment roots), so signing needs no code of your own. Neither `fips204` nor the fallback has an independent audit.
- **Check a seal.** `verify(&store, &Sha256Ids, &MlDsa65, Trust::Genesis)?.holds()`. The `Sha256Ids` doc test seals one record and checks it in 15 lines. [`crates/einfile-sig-mldsa/tests/stranger.rs`](crates/einfile-sig-mldsa/tests/stranger.rs) seals a file, checks it (`seals_ok` 3, `holds`), changes one tip and watches it go bad, with no other code: `cargo test --manifest-path crates/einfile-sig-mldsa/Cargo.toml --test stranger`. Its ACVP test runs NIST's external-interface vectors.
- **The library crates hold no signature code.** `einstore::evlog::doc` defines the traits `Signer`, `Verifier` and `Ids`; the provider implements the first two, and you can bring your own.
- **The no-install readers are still blind.** `ein-verify.py`, `ein-verify.mjs` and an archive's own reader count seals and check none (see [Limits](#limits)); only code with a `Verifier` checks one.
- **The format's registry of signature algorithms has one entry:** `alg` 65. Any other number, or a key or signature of another length, must not verify.

## How it compares

<!--
HOLD: COMPARISON SENTENCE. Verbatim from the prior-art report, §4. It is not true of this repository today.
Conditions, all required before it goes live; remove the rendered HOLD line and this comment when all are ticked:
- [ ] ML-DSA checking lives in code anyone can take from the public repository, and a seal is really checked (`checked` above 0). Without this the sentence is false.
- [ ] The link goes to the dated table, and each `-` cell in it is named "not found".
- [ ] The word `found` is not replaced by `there is`. No word of priority or exclusivity is added.
- [ ] ML-DSA, Bitcoin and "script" stay out of the sentence: others have them, or they do not run yet.
- [ ] 38 is the number of rows in the table, einfile not counted. If the table changes, the number changes with it.

> We compared 38 systems on 2026-11-01 and found none that keeps, in one file, per-device signed history, offline merge with named conflicts, signed erasure, and its own sandboxed reader; the table and its sources are here, and corrections are welcome.

**Table and sources:** COMPARISON TABLE LINK
-->

Other tools do things better than Ein. Pick them when:

- **SQLite:** you want SQL and a file format stable since 2004. Its session extension also carries changes between copies, with three conflict policies, when a session recorded them.
- **DoltLite:** you want SQL with merge. It is a fork of SQLite with branches, merge and conflict tables in one file, and it publishes SQL conformance numbers.
- **Dolt:** you want a versioned SQL database with GPG-signed commits, conflicts as ordinary tables, and DoltHub.
- **Automerge:** you want merge to decide. It merges nested structures and text by itself, where Ein names a conflict and waits for a person.
- **Git:** you hold text. It has signed commits, many implementations and a habit people already have, and OpenTimestamps fits into its signing.

## When not to use it

- **You need the data kept secret.** Nothing in the file is encrypted.
- **You need to know who wrote a file, and you have no public keys you trust.** See Trust below.
- **You need merge to decide for you.** It names conflicts. If you want an automatic winner, use Automerge or another CRDT library.
- **You need a query language, or a server that enforces access.** This is a key-value store and a log in one file.
- **Several processes must write one file at once.** A writer holds an exclusive lock on `<path>.lock`.
- **You are not on a Unix.** `FileDevice`, the file back end, runs on Unix and nowhere else.
- **You need a format that will not change.** Not until 1.0.
- **You need a certification, an audit, or a reviewed signature implementation.** None is on record.
- **You need power-loss behaviour proved on your storage.** A kill-anywhere test for the Rust write path does not exist, and whether a superblock plus its PartTab is one atomic sector is not verified on any filesystem.
- **You have large images.** An image above 512 MiB through a file is not measured.
- **Your keys are not valid UTF-8.** Use UTF-8 keys. Two readers decode keys differently, and on a non-UTF-8 key they would diverge.

## Limits

These are part of the contract. Nothing in the format decides them, and a reader must not claim that it does. Most names are from [`docs/FORMAT.md`](docs/FORMAT.md) §14, which has the full text.

- **Trust.** Under `Trust::Genesis`, a good result means "signed by the keys this file names as its roots" and nothing more, because the roots are in a table nobody signs. Who signed is known under `Trust::Only` and no other trust, from roots you bring from outside the file.
- **Rollback.** The file as it stood before a REVOKE is a shorter true file, and one file cannot know a newer one exists. An anchor shows it, and so does comparing against a second, newer copy.
- **Whole-tail removal.** A device's newest records dropped together with their seals and HEADS row leave a shorter true file. Anchors or a second file show it; nothing else does.
- **A stolen root.** Nothing outranks a root, so its thief can tombstone or cut a REVOKE and sign the declaration.
- **A blind reader** counts; it does not check. `checked` is 0 and `holds` is false.
- **Removing an anchor.** Nobody signs the anchor chain. Anchors prove when present, and their absence says nothing.
- **Swapping files of one owner.** No seal names the file, so two files of one key both hold.
- **Order across devices.** Nobody signs it. `prev` links a device's own records and no others.
- **Legacy records.** Ids of the older FNV scheme do not bind them, and FNV preimages are untested.
- **A tombstone's bytes under a cut** are bound by a FORGOTTEN still in the file, and by nothing else. The archive shows them.
- **Time.** `claimed_ms` is a claim. An anchor's proof is what bounds time, and it needs a verifier that holds what the proof needs.
- **MERGE strip.** A holder can strip a MERGE with its seal and leave a shorter true file.
- **A conflict list under a cut** cannot be re-derived. The answer is `NOT CHECKED`, never clean.
- **A MERGE row or a REVOKE under a cut** fixes the seq and not the tip.
- **What a MERGE saw.** Its rows are the signer's claim.
- **After a rotation** an admitted key is not a root under `Trust::Genesis`, so such a file cannot be cut unless a verifier brings the new key.
- **Erasure and guesses.** An erased id confirms no guess when the record's nonce was drawn from entropy and is erased with the payload. A legacy record has no nonce, and a derived nonce (`FLAG_NONCE_DERIVED`, a writer with no entropy) can be recomputed from a guess, so neither has that cover. Both duties are the writer's: `Doc::redact_into` applies the replacement you give it.
- **Erasure and other copies.** A redaction writes a new file. The old file, an archive and any second copy keep the bytes until their holders delete them, and no file can show that they did.
- **Roles.** There are none. Any admitted key can sign any record, and `holds` stays true.
- **Revocation** travels with the file. A copy that has not received a REVOKE still holds.
- **One key per seal.** There is no k-of-n.
- **Algorithm ageing.** Nothing renews a seal or an anchor before its algorithm weakens.
- **An older object's header.** The crc covers the payload, not the header. A bit in an older object's digest or length is caught by the read that depends on it, or not at all (§5).
- **A crc32 collision** in a rewrite under a re-sealed record is not covered by the query results of §9.3.
- **Power loss.** No kill-anywhere test exists for the Rust write path, and one atomic sector for a superblock plus its PartTab is not verified (§2, §11 D4).
- **Bounds not tested.** `MAX_PAD_CELLS` at the bound, `MAX_VALUE_BYTES` at its real value, `MAX_WIDTH` at 64 and 65, and any image above 512 MiB through a file (§10).
- **Writers differ.** A Rust commit zeroes the chain the older language writer keeps in cells 10 and 11 (§11 D1).
- **Keys that are not UTF-8.** Two readers decode them differently and would diverge (§11 D6).
- **Readers differ.** One reader refuses non-zero cells 13-14 and the others ignore them; a v1-v3 TREE in a DOC may be refused, and no fixture covers either (§3.1, §12). Status 2 on a DOC is named NOT_A_KV for historical reasons.

### How far this has been attacked

No attack round that tested this format came back empty: each found defects, so the list above is what is known, not all there is. A sixth round stopped with nothing tested and is no evidence either way.

Six named attack cases have never been tested:

1. A thief rewriting a tombstone's actor
2. A FORGOTTEN listing an id twice or a ghost id
3. A replayed older TRUNCATE
4. Moved cut fields
5. A flagged record shorter than its nonce
6. Two-root trust

There are no fuzzers: every test case is named and one-off, so coverage is exactly the cases written. The Lean models state properties of a model, not of the Rust, and the link between the two is by reading plus twin tests. The Tamarin model has never been parsed or proved.

## Benchmarks

**One run, one named machine, medians of 5.** Raw output: [`docs/bench/2026-11-06-github-x86_64.txt`](docs/bench/2026-11-06-github-x86_64.txt) ([the run](https://github.com/SyniakSviatoslav/Einfile/actions/runs/42212439407)). Rows where Ein loses stay visible.

**Machine:** a shared GitHub-hosted runner (`ubuntu-24.04`): AMD EPYC 9V74, 4 threads, 16 GB RAM, ext4 on an Azure virtual NVMe disk (MSFT NVMe Accelerator v1.0), Linux 7.0.0-1017-azure, `rustc` 1.96.1, commit `22f8fa2`, N = 100 000 records, 256-byte values. A shared VM is not a lab machine: its neighbours and disk change from run to run, so the fsync and cold-read rows say little, and two runs are not comparable to each other.

```sh
cd bench
ES_BENCH_DIR=/path/on/the/disk/under/test \
  cargo run --release --locked --features competitors,mldsa -- full all 100000 256 5
```

| Row | Harness row | Unit | Ein (KV v3) | Ein (KV v4) | SQLite | LMDB | redb |
|---|---|---|---|---|---|---|---|
| get | `get_hot` | ns/get | 788 | 531 | 2 564 | **438** | 526 |
| prefix | `prefix` | us/scan | 4.73 | 6.75 | 22.1 | **3.59** | 7.93 |
| cold read | `get_cold` | ms | **55.7** | 60.4 | 169 | 83.8 | 130 |
| open | `open` | us | 5 140 | 12 937 | 169 | **60** | 152 |
| put, unsynced | `put` | us/put | 2 662 | 11.9 | 8.16 | **4.49** | 5.49 |
| delete, unsynced | `delete` | us/delete | 2 209 | 12.3 | 8.63 | **4.35** | 6.62 |
| durable commit | `put_durable` | ms/commit | 0.325 | 0.330 | 0.210 | 0.161 | **0.146** |
| bulk load | `load` | ms | 189 | 181 | 398 | **138** | 195 |
| compact | `compact` | ms | 164 | 208 | 135 | **97** | 248 |
| size on disk | `size` | bytes/record | **303** | 313 | 315 | 317 | 337 |
| integrity check | `verify` | ms | 20.0 | 20.5 | 23.3 | no such call | **13.5** |

Read it plainly: point and prefix reads are in the same range as redb and behind LMDB; a cold open-and-read is the fastest here; `open` is 30 to 215 times slower than the others, because Ein's open recovers the last commit's anchor; KV v3 writes are hundreds of times slower than everyone (each small commit rewrites the image), and KV v4 brings them to within 2 to 3 times of LMDB; a durable commit costs about twice LMDB's. The harness compared 17 checksums across the five engines: all equal.

Durable means: Ein `Durability::Data`, SQLite WAL with `synchronous=FULL`, redb `Durability::Immediate`, LMDB default flags. Competitor versions are pinned in [`bench/Cargo.toml`](bench/Cargo.toml): redb 4.4.0, heed 0.22.1 (LMDB), rusqlite 0.32.1.

Rows the others in this table lack (same run, N = 100 000, a seal every 32 records, real ML-DSA-65):

| Row | Unit | Ein | Harness |
|---|---|---|---|
| verify a signed file, every seal checked | records/s | 121 849 (821 ms for the file) | `verify_signed_rate` |
| the same walk, seals counted, none checked | ms | 329 | `verify_counted` |
| seal cost: one device commit, in memory | ms and bytes | 0.491 ms, 4 144 bytes (256-byte body included) | `seal_commit`, `seal_bytes` |
| sign one / verify one, through the seam | ms | 0.474 / 0.156 | `sign_one`, `verify_one` |
| merge two devices, 100 000 records, all verified, one MERGE sealed | ms | 1 781 | `merge` |
| archive size: added per file | bytes | 231 744 (reader 136 484, format text 95 127) | `archive_added` |

The archive row's formula is in FORMAT §9.5.

## Crates

| Crate | What | `no_std` |
|---|---|---|
| `einstore` | the facade: `Db`, transactions, and everything below | no |
| `einfile-crc` | zlib CRC-32, the one place hardware CRC needs `unsafe` | yes |
| `einfile-image` | the container: cells, superblocks, PartTab, objects, crc | yes |
| `einfile-kv` | the KV layout, v1 to v4, and its zero-copy reader | yes |
| `einfile-log` | the chained event log and the signed DOC root over it | yes |
| `einfile-io` | `Db`, transactions, devices, recovery, crash harness | no |
| `einfile-ffi` | the C ABI, and Python through it | no |
| `einfile-reader` | the reader compiled to wasm32, no imports | no |
| `einfile-sig-mldsa` | ML-DSA-65 behind `Signer` and `Verifier`, over `fips204` | yes |
| `einfile-sync` | one sync session over tails, bytes in and bytes out; no transport | yes |

## Format

[`docs/FORMAT.md`](docs/FORMAT.md) is the contract, and a Ukrainian twin states the same rules. Status codes are in [`docs/STATUS-CODES.md`](docs/STATUS-CODES.md). Fixtures with their expected answers and sha256 are in [`fixtures/`](fixtures/), listed in FORMAT §13: a reader that reaches those answers conforms. Where the text and the code differ, that is a defect: please report the section, the file or its sha256, and both answers.

## Licence

MIT OR Apache-2.0, at your option. Free for commercial use. See [`LICENSE-MIT`](LICENSE-MIT) and [`LICENSE-APACHE`](LICENSE-APACHE).

Report security problems privately: see [`SECURITY.md`](SECURITY.md).
