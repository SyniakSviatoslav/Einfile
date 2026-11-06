<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# einstore

An embedded key-value store and signed event log that live in one file.

## What the file promises

The file reads with no server and no install, and a reader that checks it refuses damage by name
instead of reading it as data. A commit either finished or is not there, and a log record can carry
a signature (a *seal*) that makes a later edit visible. A file can also carry evidence from outside
itself of when a record existed, and an archive file can carry its own reader.

**This is pre-1.0 and not published to any registry.** The format is not frozen: the container is
version 2, the first release fixes the text, and until then a layout no production image holds may
change. The signed layouts did in October 2026, and the Rust API can still change. Everything below
describes what the code in this repository does today. The table under
[Guarantee levels](#guarantee-levels) names the example that runs each promise; merging has none
yet.

## What it does not promise

These limits are part of the contract.

- **A proof is not truth.** From `einfile-log/src/doc/verify.rs`: a seal counted `ok` "means the holder
  of key K signed this tip at seq s of its chain and nothing under the tip has changed since. It
  does NOT say the event happened, that a quantity is true, or that `claimed_ms` is right."
- **Status 0 is not a verdict on a signed file.** A forged declaration can sit at status 0 with
  `holds` false (format §14), so a caller reads `holds`, never the status alone.
- **A rollback shows only with an anchor or a second file.** A file as it stood before a REVOKE is a
  shorter true file, and one file cannot know a newer one exists (format §14).
- **Seals are not checked by the MIT reader.** It carries no signature algorithm, and it says so:
  "seals COUNTED, not CHECKED: this reader carries no signature algorithm (MIT, no ML-DSA); a count
  is not a proof -- bring a verifier to the same seam, or the format text's independent readers".
  See [Signing a file](#signing-a-file).
- **A level 1 anchor needs a Bitcoin confirmation.** An OpenTimestamps proof says nothing until its
  transaction is in a block and the auditor compares that block's header. Until then it is
  `Unchecked`, and `Unchecked` is never a pass.
- **The clock in a seal is a claim.** `claimed_ms` is the device's own clock, signed and repeated
  and never believed.
- **Two devices merge as M2-min, and no wider.** `Doc::merge_into` joins two copies of one genesis
  with no server, keeping every record and seal, and names each conflict without resolving it. A
  cut, an erasure or a revocation on one side only is refused by name; so are one device forked
  across the copies and two seal chains of one key. Under a cut a conflict list cannot be re-derived:
  the answer is `NOT CHECKED`, never clean. See format §14.
- **Opening a file checks only what you ask for.** `Options::default()` opens at `Verify::Anchor`,
  which checks the last commit. Older commits are trusted, and a damaged old object can read as a
  refusal or as a wrong answer, until you open at `Verify::Reachable` or call `Db::verify`.
- **Nothing is encrypted.** The file holds your data as plain bytes.

## Quickstart

```rust
use einstore::{Db, Durability, Options, Refusal, Verify};

fn main() -> Result<(), Refusal> {
    let path = std::env::temp_dir().join(format!("quickstart-{}.ein", std::process::id()));
    let path = path.to_str().expect("a UTF-8 temp path");
    {
        let db = Db::create_path(path, Options::default())?;
        let mut w = db.begin_write()?;
        w.put(b"order/1", b"new")?;
        w.put(b"order/2", b"paid")?;
        w.commit(Durability::Data)?; // back when it is on the device
    } // dropping the Db releases the file and its lock
    {
        let db = Db::open_path(path, Options::default().verify(Verify::Reachable))?;
        let r = db.begin_read();
        for entry in r.prefix(b"order/")? {
            let (k, v) = entry?;
            println!("{} = {}", String::from_utf8_lossy(&k), String::from_utf8_lossy(&v));
        }
    }
    let _ = std::fs::remove_file(path);
    let _ = std::fs::remove_file(format!("{path}.lock"));
    Ok(())
}
```

This block is compiled and run by `cargo test --doc`. A refusal is a value with a name, never a
panic: see `Refusal`, and the numbers every reader shares in
[`docs/STATUS-CODES.md`](../../docs/STATUS-CODES.md).

The crates are not on crates.io, so depend on a checkout by path:

```toml
[dependencies]
einstore = { path = "../einfile/crates/einstore" }
```

## Guarantee levels

Each level is optional and works on the same file. No blockchain is ever required, there is no
token, and the core holds one event, "this root was recorded here", with adapters outside it.

| Level | What it adds | Status today |
|---|---|---|
| **0, the file** | Signed per-device chains, verified from the file and public keys alone. A file that reads with no install. | Built, and two copies of one file merge with no server (M2-min, above). The full merge is **not built**. |
| **1, the anchor** | Evidence from outside the file that a record existed by a moment, kept in the file: OpenTimestamps (Bitcoin), a time-stamp authority's signature, or Roughtime as a lower bound. | The format and the checking seam are built here. The adapters are not in this repository: bring your own behind `AnchorCheck`. |
| **2, the settlement** | A chain or witnesses fixing the order between organisations that do not trust each other, at the moments they connect. | Not built. |

The examples show the mechanics of each row they cover, and each one fails loudly if its promise
does not hold.

| Promise | Example |
|---|---|
| A changed byte is refused by name | [`refuse_damage`](examples/refuse_damage.rs) |
| An unfinished commit is not there | [`crash_fallback`](examples/crash_fallback.rs) |
| An edit under a seal is seen (level 0) | [`sealed_history`](examples/sealed_history.rs) |
| Keys are records; a revoke invalidates later seals (level 0) | [`revoke_key`](examples/revoke_key.rs) |
| An anchor nobody checked counts as nothing (level 1) | [`time_anchor`](examples/time_anchor.rs) |
| History leaves only under a signed declaration | [`cut_history`](examples/cut_history.rs) |
| An erasure is declared, never hidden | [`forget_a_person`](examples/forget_a_person.rs) |
| The file reads with nothing installed | [`read_without_library`](examples/read_without_library.rs) |
| An archive carries its own reader | [`archive`](examples/archive.rs) |

Run one with `cargo run --example refuse_damage`. The sealed examples use a stand-in named
`AnyoneCanForge`, which is **not a signature**: anyone can make one. They show the layout and the
counters, and say so.

## Verify a file with no install

Each of these is one file. Copy it anywhere; it reads only the path you give it.

```sh
node tools/verify/ein-verify.mjs your.ein --dump --verify
python3 tools/verify/ein-verify.py your.ein --dump --verify
```

Both print one status line, and with `--verify` the counters of a signed file. `status=0` means
every object the root reaches matches its checksum, the last commit matches its anchor, and the
layout rules hold. It does not mean the content is true, and it is no verdict on the seals. In the
counters, `checked=0` means the seals were counted and not checked. These readers cannot give `holds`.
That takes a verifier that judges signatures: `Report::holds()` under
`einfile-sig-mldsa` or your own `Verifier`.

An archive file also carries its own reader: `node examples/read.mjs archive.ein`. That reader is
testimony, not authority, because a file cannot vouch for itself. Compare its sha256 with a
published one, or read the file with one of the verifiers above.

## Signing a file

**To sign, you bring ML-DSA-65.** The store crates hold no signature code. `einstore::evlog::doc`
defines the traits `Signer`, `Verifier` and `Ids`, and you implement them or take `einfile-sig-mldsa`,
a separate MIT OR Apache-2.0 crate. `Ids` is yours to supply: `crates/einfile-sig-mldsa/tests/stranger.rs`
has a small one.

| You want to | You need | Licence of what you take |
|---|---|---|
| Read and write KV files | this crate | MIT OR Apache-2.0 |
| Read a signed file, count its seals | `einfile-reader`, or `tools/verify` | MIT OR Apache-2.0 |
| Write a signed file | this crate, plus `einfile-sig-mldsa` or your own ML-DSA-65 behind `Signer` | MIT OR Apache-2.0 |
| Check seals | `einfile-sig-mldsa`, or your own ML-DSA-65 behind `Verifier` | MIT OR Apache-2.0 |
| Check anchors | your own adapter behind `AnchorCheck` | yours |

**Interoperability.** A seal is external pure ML-DSA-65 (FIPS 204 `ML-DSA.Sign`) over the seal
message with the empty context, which is plain signing in a stock library. `einfile-sig-mldsa`
implements both seams over the `fips204` crate; no independent audit of that crate is known. The
message and the actor id are in [FORMAT §9.4](../../docs/FORMAT.md).

## The crates

| crate | what | no_std |
|---|---|---|
| `einfile-crc` | zlib CRC-32 | yes |
| `einfile-image` | the format: cells, superblocks, PartTab, objects, crc | yes |
| `einfile-kv` | the KV layout (v1 to v4) and its zero-copy reader | yes |
| `einfile-log` | the chained event log, and the signed DOC root over it | yes |
| `einfile-io` | `Db`, transactions, devices, recovery, crash harness | no (std, wasm32 ok) |
| `einstore` | this facade, plus `merkle`, `nodekey` (SHA-256), `proj`, `zset` | no |
| `einfile-ffi` | the C ABI (cdylib) and, through it, Python | no |
| `einfile-reader` | the reader compiled to wasm32, no imports | no |
| `einfile-sig-mldsa` | ML-DSA-65 behind `Signer` and `Verifier`, over the `fips204` crate | yes |
| `einfile-sync` | one sync session between two copies of a signed file, bytes in and out | yes |

`einstore` re-exports `einfile-image`, `einfile-kv` (as `kv`), `einfile-log` (as `evlog`) and `einfile-io`
(as `iodev`, plus `Db`, `ReadTxn`, `WriteTxn`, `Scan`, `Refusal`, `Options`, `Verify`, `Durability`,
`Batch` and `Bytes` at the top level). It re-exports and never wraps: a wrapper is code the wasm
reader would have to carry. Python goes through the C ABI: `bindings/python/einstore.py`.

The DAG runtime in this crate (`proj`, `zset`) belongs to the language runtime that shares this
format. It is not part of the public library.

## Five readers, one answer

Every KV fixture is read by five readers: this crate natively, the wasm32 reader through
`tools/verify/ein-verify.mjs`, `tools/oracle/oracle.py`, `tools/verify/ein-verify.py`, and the C ABI
through Python. Each must give the same `(n, root)` or
the same refusal, and `tools/gates/conformance.sh` holds them to it. A signed file has its own check, `tools/verify/gate.sh`.

## The format

[`docs/FORMAT.md`](../../docs/FORMAT.md) is normative, and
[`docs/FORMAT.uk.md`](../../docs/FORMAT.uk.md) is its Ukrainian twin. §12 lists
what is still open for a third-party implementer, and §14 what one file cannot decide.

Changes are in [`CHANGELOG.md`](../../CHANGELOG.md), which also states the versioning
rule.

## Performance

One run on a shared GitHub-hosted runner (AMD EPYC 9V74, 4 threads, N = 100 000, 256-byte values,
medians of 5). The full table, the command and the raw output are in the
[repository README](https://github.com/SyniakSviatoslav/Einfile#benchmarks).

| | einstore (KV v4) | LMDB | redb | SQLite |
|---|---|---|---|---|
| get, ns | 531 | 438 | 526 | 2 564 |
| cold open + 1000 gets, ms | 60.4 | 83.8 | 130 | 169 |
| open, us | 12 937 | 60 | 152 | 169 |
| put, unsynced, us | 11.9 | 4.49 | 5.49 | 8.16 |
| durable commit, ms | 0.330 | 0.161 | 0.146 | 0.210 |

It is not the fastest store: `open` and writes are where it loses.

## Licence

MIT OR Apache-2.0, at your option. See [`LICENSE-MIT`](LICENSE-MIT) and [`LICENSE-APACHE`](LICENSE-APACHE).
