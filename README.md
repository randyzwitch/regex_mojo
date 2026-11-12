# regex_mojo

Unicode regular expressions in pure Mojo, extracted from
[dataframe_mojo](https://github.com/randyzwitch/dataframe_mojo). The library
compiles patterns once, searches borrowed UTF-8 spans, and keeps mutable
matching state private to each worker. It depends only on the Mojo standard
library and [unicode_mojo](https://github.com/randyzwitch/unicode_mojo).

This is experimental software. The current compiler is pinned to
`1.3.0.dev2026111005`; compiled Mojo packages require the compiler that
produced them. Supported build platforms are Linux x86-64, Linux ARM64, and
macOS ARM64.

## Install

With Pixi **0.84.2**, enable `preview = ["pixi-build"]` in your workspace and
include the `https://prefix.dev/pixi-build-backends` channel, along with
`https://conda.modular.com/max-nightly`, `https://conda.modular.com/max`, and
`conda-forge`. Add:

```toml
[dependencies]
regex_mojo = { git = "https://github.com/randyzwitch/regex_mojo.git", branch = "main" }
mojo = "==1.3.0.dev2026111005"
```

Commit `pixi.lock` to record the resolved Git revision, or replace `branch`
with an immutable `rev` in your manifest.

## Use

```mojo
from regex_mojo import Matcher, Regex


def main() raises:
    var regex = Regex("\\p{L}+")
    var matcher = Matcher(regex)
    var text = String("123 café")
    var bytes = Span[UInt8, ImmutAnyOrigin](
        unsafe_ptr=text.unsafe_ptr().unsafe_origin_cast[ImmutAnyOrigin](),
        length=text.byte_length(),
    )
    var match = matcher.find(bytes)
    print(match[0], match[1])  # 4 9: byte offsets, end exclusive
    _ = text  # Keep the borrowed input alive through the search.
```

`Regex` is an immutable, reference-counted compiled pattern and is cheap to
copy between threads. Create a separate `Matcher` for each worker. Input
spans borrow their storage: keep the owner alive and do not mutate it during
a search. Valid UTF-8 inputs are matched on code-point boundaries.

| API | Behavior |
| --- | --- |
| `Regex(pattern)` | Compile; raise on invalid or unsupported syntax. |
| `cached_pattern(pattern)` | Reuse compiled patterns in a synchronized, process-wide 32-entry LRU cache. Returned patterns survive eviction. |
| `Matcher(regex)` | Own the DFA caches, capture slots, and iteration cursor. |
| `matcher.is_match(bytes)` | Test whether any match exists. |
| `matcher.find(bytes, start=0)` | Return byte offsets `(start, end)`, or `(-1, -1)`. |
| `matcher.captures(bytes, start=0)` | Populate `slots[2*g]` and `slots[2*g+1]`; group 0 is the whole match, and absent groups have `-1` slots. |
| `matcher.next(bytes)` / `matcher.reset()` | Iterate non-overlapping matches; reset before starting a new input. |
| `matcher.count(bytes)` | Count non-overlapping matches. |
| `regex.template(replacement)` | Parse `$1`, `${1}`, `$name`, `${name}`, and `$$` into a reusable `Template`. |
| `matcher.replace(bytes, template, limit, output)` | Append replaced bytes to `List[UInt8]`; a negative limit replaces all matches. |
| `escape(text)` | Escape metacharacters for literal matching. |

`Regex` also exposes `pattern()`, `group_count()`, `group_names()`,
`group_index(name)`, and `literal()`. See the runnable
[capture and replacement example](examples/search.mojo).

## Semantics and implementation

Matches are leftmost-first, with ordered alternation, greedy/lazy repetition,
and Unicode-aware character classes and simple case folding. An empty match
immediately after the preceding match is skipped; iteration otherwise advances
over complete UTF-8 code points.

Supported syntax includes literals, escapes, classes and class set operations,
Unicode properties, anchors and word boundaries, capturing and named groups,
alternation, bounded/unbounded repetition, and scoped `i m s U x u` flags.
Disabling Unicode mode selects ASCII classes, boundaries, and folding, but
patterns that could match invalid UTF-8 are rejected. Look-around,
backreferences, and CRLF mode `(?R)` are unsupported.

The parser produces a flat AST and Thompson NFA. Lazy forward/reverse DFAs
find match bounds; one-pass capture paths, a bounded visited-state backtracker,
and a Pike VM handle captures. Literal prefilters and ASCII/Unicode SIMD scans
accelerate eligible paths. DFA caches have bounded transition storage and fall
back to NFA simulation when exhausted. Parsing limits nesting to 250, and
compilation limits programs to 500,000 instructions.

Unicode properties, simple folding, class ranges, and UTF-8 primitives come
from the pinned `unicode_mojo` dependency. Its data versions are deliberately
preserved; extraction does not update Unicode semantics.

## Development

```sh
pixi run --locked check
pixi build
```

The test runner discovers every top-level `test_*` function in
`tests/test_*.mojo`. Tests cover capture priority, bounded fallbacks, shared
compiled patterns, concurrent cache hits/misses/evictions, Unicode scalar
coverage, malformed/truncated input boundaries, SIMD/scalar equivalence, and
a frozen Polars corpus of 8,112 cases over 271 patterns. Normal tests need no
Python packages beyond the standard library. Regenerate the corpus explicitly
with `pixi run -e oracle regenerate-corpus`; the oracle environment pins
Polars 1.44.2.

CI runs the checks and package build on all three supported platforms.
The package contains no dataframe, Arrow, or query-execution dependencies.

## License and provenance

MIT; see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
The extraction baseline and preserved corpus are recorded there.
