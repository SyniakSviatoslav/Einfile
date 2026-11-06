-- SPDX-License-Identifier: MIT OR Apache-2.0
import Lake
open Lake DSL

package EinfileFormal where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib Einfile where
  roots := #[`Einfile]
