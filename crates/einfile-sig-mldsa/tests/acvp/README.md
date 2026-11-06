<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# NIST ACVP vectors for external pure ML-DSA-65

`sig-gen-external.json` and `sig-ver-external.json` come from `usnistgov/ACVP-Server`,
`gen-val/json-files/ML-DSA-{sigGen,sigVer}-FIPS204/internalProjection.json`, fetched 2026-11-01
(vsId 42, isSample false). Every group was dropped but ML-DSA-65 + external + pure: sigGen tgId 3
(deterministic) and 15 (hedged), sigVer tgId 3. Nothing inside a group is edited.

They are NIST's test data, not this project's, and the repository's licence does not claim them.
`../acvp.rs` reads them at run time.
