# Mojo 1.0 nightly dialect — compile-blocking facts

Pinned: `mojo ==1.0.0b3.dev2026072406` from `https://conda.modular.com/max-nightly`.
Everything here was verified by probe, not read from docs. Model priors from Mojo 0.x are
wrong on most of these.

## Removed / renamed

| old (0.x, and what an LLM will write) | 1.0 |
|---|---|
| `fn foo():` | **`fn` is removed entirely** — use `def` |
| `alias X = ...` | `comptime X = ...` |
| `from sys.info import ...` | `from std.sys.info import ...` (all stdlib under `std.`) |
| `simdwidthof` / `sizeof` / `alignof` | `simd_width_of` / `size_of` / `align_of` |
| `has_avx512f()` | `CompilationTarget.has_avx512f()` |
| `UnsafePointer[T].alloc(n)` | `from std.memory import alloc` -> `alloc[T](n)` |
| `memset_zero` | `unsafe_memset_zero` (old name warns) |
| `Span[T](ptr=p, length=n)` | `Span[T](unsafe_ptr=p, length=n)` |
| `l.capacity` | `l.capacity()` — it is a method |
| `vec.min(other)` | free `min(a, b)` — SIMD has no `.min()`/`.max()` |

`Span` is a builtin; importing it from `std.memory` or `std.builtin` fails
(it lives in `std.collections.span`).

## Closures

* `@parameter` on a nested `def` makes it a comptime-capturing closure.
* Without `@parameter`, capturing gives `Could not infer capture convention of the captured value`.
* `parallelize[work](n, workers)` — closure in the **parameter** list.
* `vectorize` in this nightly rejects capturing closures in both forms:
  arg form -> `cannot be converted from 'def[w: Int](i: Int) capturing thin -> None'`;
  parameter form (`vectorize[W, size=N](step)`) -> `cannot use a dynamic value in a parameter list`.
  Hand-roll the chunked loop instead (see simd.md).

## FFI / export

* `@export("symbol_name")` above the def; ABI is an **effect before the arrow**:
  `def f(a: Int) abi("C") -> Float64:`. Omitting `abi("C")` only warns; putting it after
  the return type is a parse error.
* `@export` rejects parametric functions. Any inferred parameter — including a pointer
  origin `UnsafePointer[Float64, _]` — makes it parametric.
* The only usable mutable origin name is `AnyOrigin[mut=True]`. `MutableAnyOrigin`,
  `MutableStaticOrigin`, `StaticMutableOrigin` do not exist; bare `AnyOrigin` is parametric
  over `mut`; `ImmStaticOrigin` rejects stores.
* Buffers therefore cross the C ABI as `Int` addresses, rebuilt inside the wrapper:
  `UnsafePointer[Float64, AnyOrigin[mut=True]](unsafe_from_address=addr)`.
* Pointers are **non-nullable**: constructing from address 0 fails a compile-time
  constraint. Pass the address as `Int`, construct only inside the branch that uses it.
* An `@export ... abi("C")` function cannot be `raises` — wrap fallible work in `try:`/`except:`.
* `out` is reserved — not usable as a parameter name *or* a local variable name.

## Misc

* `ord("=")` yields `Int`, no implicit conversion to `UInt8`.
* `print` needs `Writable` values; `l.capacity()` returns a type that needs an explicit
  `Int(...)`-style conversion in some positions — if `print` says
  `could not infer type of parameter pack 'values'`, that is the cause.
* Mutual recursion kills `mojo build` (hangs/OOM) — restructure to a loop or a worklist.
* AOT Mojo embeds CPython 3.12, not 3.13 — pin the pixi python accordingly if you use
  Python interop from a built binary.

## wasm

Mojo's LLVM has no wasm backend registered. Path: `mojo build --emit llvm` -> rewrite
datalayout/triple + strip `target-cpu`/`target-features` -> `clang>=20 --target=wasm32`
-> `wasm-ld`. Export params must be `Int32` (`Int` is i64 -> BigInt in JS).
`--emit llvm` on a file with only `@export` funcs gives freestanding IR (intrinsics only);
adding heap use pulls in `KGEN_CompilerRT_Aligned{Alloc,Free}` and a write/fdopen/fprintf
stdio path.
