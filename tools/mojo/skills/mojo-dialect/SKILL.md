---
name: mojo-dialect
description: Write Mojo 1.0 that compiles on the first try. Use whenever writing, editing, porting or reviewing .mojo code — model priors are from Mojo 0.x and most of them are now compile errors (fn, alias, simdwidthof, UnsafePointer.alloc, bare stdlib imports).
---

# Mojo 1.0 dialect

Pinned: `mojo ==1.0.0b3.dev2026072406` (`https://conda.modular.com/max-nightly`).
Everything here is probe-verified. **Your priors about Mojo are from 0.x and are wrong.**
Before writing Mojo, check this list; after writing, run `mojolint --only dialect <path>`.

## The seven that break every first attempt

| you will write | correct |
|---|---|
| `fn foo():` | `def foo():` — **`fn` is removed entirely** |
| `alias W = 8` | `comptime W = 8` |
| `from sys.info import ...` | `from std.sys.info import ...` — all stdlib under `std.` |
| `simdwidthof` / `sizeof` / `alignof` | `simd_width_of` / `size_of` / `align_of` |
| `UnsafePointer[T].alloc(n)` | `from std.memory import alloc` -> `alloc[T](n)` |
| `vec.min(x)` / `vec.max(x)` | free `min(a, b)` / `max(a, b)` — SIMD has no such methods |
| `l.capacity` | `l.capacity()` — a method |

Also: `memset_zero` -> `unsafe_memset_zero`; `Span[T](ptr=...)` -> `Span[T](unsafe_ptr=...)`;
`has_avx512f()` -> `CompilationTarget.has_avx512f()`. `Span` is a builtin — importing it
from `std.memory` or `std.builtin` fails (it lives in `std.collections.span`).

## Types you will hit immediately

- `alloc[T](n)` returns `Pointer[T, MutUntrackedOrigin]`. A helper annotated
  `UnsafePointer[Float32, AnyOrigin[mut=True]]` will **not** accept it. Use
  `UnsafePointer[T, MutUntrackedOrigin]` for helpers, or `_` for the origin in
  non-exported functions.
- The only usable mutable origin name is `AnyOrigin[mut=True]`. `MutableAnyOrigin`,
  `MutableStaticOrigin`, `StaticMutableOrigin` do not exist.
- Pointers are **non-nullable**: building one from address 0 fails a compile-time
  constraint. Pass addresses as `Int` and construct inside the branch that uses them.
- `out` is reserved — not usable as a parameter name *or* a local variable name.
- `ord("=")` is `Int` and will not implicitly convert to `UInt8`.
- `print` needs `Writable` args; `could not infer type of parameter pack 'values'`
  means one argument needs an explicit conversion.

## Closures

```mojo
@parameter
def work(i: Int):
    ...
parallelize[work](n, num_workers)      # closure in the PARAMETER list
```
Without `@parameter`, capturing gives `Could not infer capture convention`.

`vectorize` rejects capturing closures in this nightly, both forms
(`capturing thin` conversion error / `cannot use a dynamic value in a parameter list`).
Hand-roll the chunked loop instead:

```mojo
comptime W = simd_width_of[DType.float32]()
var acc = SIMD[DType.float32, W](0)
var tail = n - (n % W)
for i in range(0, tail, W):
    acc = fma(a.load[width=W](i), b.load[width=W](i), acc)
var total = acc.reduce_add()
for i in range(tail, n):
    total += a[i] * b[i]
```

## FFI / `@export`

```mojo
@export("msk_dot")
def msk_dot(a: Int, b: Int, n: Int) abi("C") -> Float64:
```
- `abi("C")` is an **effect before the arrow**. After the return type is a parse error;
  omitting it only warns (and gives you the wrong ABI).
- `@export` rejects parametric functions — an inferred pointer origin counts as parametric.
- An `@export ... abi("C")` function cannot be `raises`; wrap in `try:`/`except:`.
- Buffers cross as `Int` addresses, rebuilt inside:
  `UnsafePointer[Float64, AnyOrigin[mut=True]](unsafe_from_address=addr)`.

## Build

- `mojo build --emit shared-lib` errors if the file defines `main`, and errors if the
  `-o` directory does not already exist.
- Build cost is ~5s and **fixed** regardless of function count — batch into one unit.
- Mutual recursion hangs/OOMs the compiler. Use a loop or a worklist.
- AOT binaries embed CPython 3.12, not 3.13.
- GPU needs the `max` conda package (libmax.so) alongside `mojo`; `DeviceContext()`
  raises, including `CUDA_ERROR_OUT_OF_MEMORY` when another process owns the card.

Full detail: `../../docs/dialect.md`. Perf work: the `mojo-perf` skill.
