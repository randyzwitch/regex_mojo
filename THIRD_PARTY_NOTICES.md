# Source attribution and provenance

## dataframe_mojo

The engine, pattern cache, tests, and corpus generator were extracted from
Randy Zwitch's MIT-licensed
[dataframe_mojo](https://github.com/randyzwitch/dataframe_mojo) at commit
`37871eb4a4021e24af107b176f7682dfb9b128b9` (November 12, 2026):

- `dataframe/regex/*.mojo` → `regex_mojo/*.mojo`
- `dataframe/text/regex_cache.mojo` → `regex_mojo/cache.mojo`
- `tests/kernel_equivalence/test_regex*.mojo` → `tests/test_regex*.mojo`
- `tests/fixtures/regex/polars_corpus.tsv` and `scripts/regex_corpus.py`

The original MIT copyright and permission notice are preserved in `LICENSE`.
The test thread helper uses the job/slot/thread-entry structure from
`dataframe/parallel.mojo`. Dataframe-specific binding and column tests remain
in the original repository.

## unicode_mojo

Unicode properties, class ranges, simple case folding, and UTF-8 primitives
are supplied by the pinned
[unicode_mojo](https://github.com/randyzwitch/unicode_mojo) dependency. Its
Unicode data and Rust regex-derived tables are distributed under the notices
and license bundle in that repository. This repository does not vendor those
tables or their generators.

## Polars behavior corpus

`tests/fixtures/regex/polars_corpus.tsv` preserves the 8,112-row, 271-pattern
behavior corpus from dataframe_mojo without modification. Its generator
queries Polars string expressions; the oracle environment pins Polars 1.44.2.
Polars is a development-only reference and is not a runtime dependency. The
corpus records observable results, including unsupported-pattern errors; it
does not contain Polars implementation source.
