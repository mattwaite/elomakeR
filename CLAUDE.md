# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`elomakeR` is an R package that computes Elo ratings from a data frame of games for any head-to-head sport. The core design constraint: it must work with games data in whatever schema it already has, without requiring the caller to rename columns to a fixed `team1`/`team2`/`score1`/`score2` convention. This is achieved via tidy evaluation (data masking) in `calculate_elo()` — every column mapping argument (`date`, `team1`, `team2`, `score1`, `score2`, `home_team`, `neutral`, `season`, `game_id`) is unquoted and evaluated against `data`.

## Commands

Development happens via `devtools`/`roxygen2`/`testthat`, run through `Rscript` (no Makefile or npm scripts).

```r
devtools::document()   # regenerate NAMESPACE + man/*.Rd from roxygen comments — run after any @param/@export change
devtools::test()       # run the full testthat suite
devtools::check()      # full R CMD check equivalent (build + check); should stay at 0 errors/warnings/notes
devtools::load_all()   # load the package for interactive/manual testing without installing
```

Run a single test file:
```r
testthat::test_file("tests/testthat/test-calculate_elo.R")
```

Rebuild the README (has live executed R code chunks, not static markdown):
```r
devtools::build_readme()
```
This requires a real pandoc binary. `RSTUDIO_PANDOC` env var may need to point at one explicitly if not resolved automatically, e.g.:
```bash
export RSTUDIO_PANDOC="/Applications/quarto/bin/tools"
```

Rebuild a bundled dataset after editing its `data-raw/*.R` script:
```r
source("data-raw/basketball_games.R")   # or volleyball_sets.R
```

## Architecture

**`R/calculate_elo.R`** — the entire rating engine lives in one function, `calculate_elo()`. It:
1. Captures column-mapping arguments as quosures (`rlang::enquo`) and evaluates them against `data` into an internal `games` tibble with fixed internal names.
2. Validates inputs (no missing/empty team names, `team1 != team2` per row, `home_team` must equal `team1` or `team2` when set, etc.) — validation errors are deliberately loud rather than silently coerced, since bad input produces wrong ratings, not a crash.
3. Sorts games chronologically and runs a single sequential loop (ratings live in a `new.env()` keyed by team name, not a vectorized operation) — this is intentional since each game's expected score depends on the *current* rating state built up by all prior games for those teams.
4. Handles home advantage (added to expected-score calculation only, never stored in the rating itself), ties (`actual = 0.5`), margin-of-victory scaling (`mov_adjustment = "log"` or a custom `mov_fun`), and season carryover (`continuous`/`reset`/`regress`, applied at season-boundary transitions detected during the sorted loop).
5. Returns a long-format tibble subclassed `"elo_tbl"` — one row per team per game (not one row per game), which is what makes it pipe cleanly into dplyr/ggplot2 for standings and trajectories.

**`R/tuning.R`** — `suggest_learning_rate()`, `suggest_home_advantage()`, and `tune_elo()` are thin grid-search wrappers around `calculate_elo()`. They forward `...` (column mappings and other fixed args) straight through to `calculate_elo()` for each candidate parameter value — this works because R's `...` preserves NSE promises across the wrapper boundary without needing any `rlang::inject()`/`!!` gymnastics. Scoring is log-loss or accuracy via the private `.elo_log_loss()`/`.elo_accuracy()` helpers, computed over the full long-format output (safe to do without deduplicating team-perspective rows, since log-loss is symmetric: `LL(p, y) == LL(1-p, 1-y)`).

**`R/plot.R` + `R/zzz.R`** — `plot_elo()` is the real exported plotting function. `autoplot.elo_tbl` (for `ggplot2::autoplot()`) is registered dynamically in `.onLoad()` via `registerS3method("autoplot", "elo_tbl", ..., envir = asNamespace("ggplot2"))`, *not* declared with `@export`/a literal `autoplot.elo_tbl` function name in source. This avoids ggplot2 becoming a hard dependency (it's in `Suggests`, not `Imports`). Note the `envir` argument to `registerS3method()` must point at the namespace where the *generic* lives (ggplot2), not the package registering the method — passing this backwards produces a `check dependencies in R code` NOTE from `R CMD check` (`get(genname, envir=envir)` fails) rather than a load-time error, so it's easy to get wrong silently.

**Bundled example datasets** (`data/*.rda`, built from `data-raw/*.R`) exist specifically to stress-test the schema-agnostic design against real, messy data, not as toy fixtures:
- `basketball_games` — the primary/canonical example in docs. Already has separate home/away columns and a genuine `neutral_site` boolean.
- `volleyball_sets` — deliberately messier schema: arbitrary `team1`/`team2` labels (home team is `team2`, pointed to via `home_team`), outcome given as sets won rather than a single score column.

Each `data-raw/*.R` script documents exactly what cleaning was applied to the raw scrape (deduplication, dropping unplayed/incomplete rows, recoding sentinel values like a `99 = unranked` rank). When adding a new bundled dataset, follow that pattern: keep the source's real column names/quirks rather than normalizing them away, since the point is demonstrating the tidy-eval interface handles arbitrary schemas.

**Not bundled**: an NCAA baseball schedule export was evaluated as a third example and deliberately *not* added to the package (see README's "Data prep `calculate_elo()` won't do for you" section) — it required different, more invasive pre-processing (deduplicating mirrored per-team rows, deriving a home-team column from a per-row `Home`/`Away`/`Neutral` indicator) that lives outside what `calculate_elo()` is meant to solve. That README section is the reference for what kind of data-shape mismatches are expected to be handled by the caller, not the package.

## Conventions specific to this package

- Roxygen `@examples` that exercise the full bundled datasets are wrapped in `\donttest{}` — full-season loops (~5,000+ games) are too slow for routine `R CMD check` example timing.
- Tests hand-verify Elo arithmetic against manually computed expected values (see `tests/testthat/test-calculate_elo.R`) rather than only asserting structural properties — the rating formulas are the thing most likely to silently regress.
- `game_id` defaults to row number (as a string) when not mapped; always map a real `game_id` column when writing tests or examples that need to reference specific games in the output, since row-number IDs aren't stable across input reordering.
