# ZSAMPLES reverse-engineering spike

Throwaway tooling for decoding MacDive's proprietary `ZDIVE.ZSAMPLES`
binary profile format. Output is a written format spec at
`docs/import-formats/macdive-zsamples.md` (or a no-go note).

See `docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md`
for the full investigation plan.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# On macOS for LZFSE:
brew install lzfse
```

## Workflow

1. `python extract_corpus.py` — builds `corpus/` from `scripts/sample_data/`.
2. `python blob_inspect.py corpus/<uuid>.zsamples.bin` — human exploration.
3. `python compression_probe.py corpus/<uuid>.zsamples.bin` — Hypothesis 1.
4. `python batch_score.py hypotheses.h2_fixed_width` — score a hypothesis.
5. Iterate hypotheses, commit findings to `docs/import-formats/macdive-zsamples.md`.

## Running tests

```bash
cd scripts/reverse_engineering/zsamples
pytest -v
```

## Do not commit `corpus/`

It contains real user dive data from the sample SQLite.
The directory is gitignored.
