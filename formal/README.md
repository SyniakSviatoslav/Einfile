<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# Models

`lean/` holds Lean 4 models of the log, merge, limits and the KV layouts. They state properties of a
model, not of the Rust, and the link between the two is by reading plus twin tests.
`tamarin/` holds a symbolic model of the seal protocol. It has never been parsed or proved.
