<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# einfile-sig-mldsa

ML-DSA-65 (FIPS 204) behind `einfile-log`'s `Signer` and `Verifier`: the signature a sealed
[einfile](https://github.com/SyniakSviatoslav/Einfile) image carries.

- `DeviceKey`: one device's key, derived from a 32-byte seed (FIPS 204 `KeyGen`). The seed is the
  whole secret; the expanded secret is boxed and wiped on drop by `fips204`.
- `MlDsa65`: the verifier. An algorithm number other than 65, or a key or signature of the wrong
  length, is `false`, never a guess at another scheme.
- `Sha256Ids`: the ready-made id scheme of FORMAT §9.4 (sha256 record ids, a 16-byte nonce under
  `FLAG_SHA256`, the tombstone bit, RFC 9162 Merkle roots for cut segments), so you can seal,
  verify, cut and merge with nothing of your own.

The signature is external pure `ML-DSA.Sign` with the empty context, what stock libraries call plain
signing, so any FIPS 204 implementation verifies these files. Signing is deterministic
(`rnd = 0^32`): a device spends no entropy on it. `no_std` with `alloc`, builds for
`wasm32-unknown-unknown`, links no `getrandom`.

```rust
use einfile_image::Store;
use einfile_log::doc::{verify, Doc, Ids as _, Signer as _, Trust};
use einfile_log::{Record, FLAG_SHA256};
use einfile_sig_mldsa::{DeviceKey, MlDsa65, Sha256Ids};

let key = DeviceKey::from_seed(&[7u8; 32]); // keep the seed: it is the whole secret
let mut st = Store::create_bytes(1 << 20).unwrap();
Doc::init_bytes(&mut st, 0, &[key.key()]).unwrap();

// one record: a 16-byte nonce, then the body
let mut r = Record { id: [0; 32], prev: [0; 32], actor_pubkey: key.actor_id(), actor_seq: 1,
                     flags: FLAG_SHA256, payload: b"0123456789abcdefhello".to_vec() };
r.id = Sha256Ids.chained(&r);
Doc::commit_bytes(&mut st, &r, &key, 1_700_000_000_000, None).unwrap();

let report = verify(&st, &Sha256Ids, &MlDsa65, Trust::Genesis).unwrap();
assert_eq!(report.counters.seals_ok, 1);
assert!(report.holds());
```

## What it is not

The backend is the [`fips204`](https://crates.io/crates/fips204) crate, which has no independent
audit; neither has this crate. Tests run the NIST ACVP vectors for external pure signing and
verification. Why `fips204` and not another backend is written out in this crate's `Cargo.toml`.

## Licence

MIT OR Apache-2.0.
