# Prepares the bundled example dataset from the raw scrape at
# ~/Documents/DataExperiments/NCAAVolleyballSetScores/set_scores.csv.
#
# Deliberately keeps the source's non-standard column names
# (team1/team2, team1_sets_won/team2_sets_won, etc.) since the point of
# this example is to demonstrate that calculate_elo() works with
# whatever schema a dataset happens to have. team2 is the home team in
# this source. The only cleanup applied is removing exact duplicate
# rows, games with no recorded score, and games with a blank team name
# (all scraping artifacts, ~0.2% of rows combined).

raw <- read.csv(
  "~/Documents/DataExperiments/NCAAVolleyballSetScores/set_scores.csv",
  stringsAsFactors = FALSE
)

volleyball_sets <- raw[!duplicated(raw), ]
volleyball_sets <- volleyball_sets[
  !is.na(volleyball_sets$team1_sets_won) & !is.na(volleyball_sets$team2_sets_won),
]
volleyball_sets <- volleyball_sets[
  volleyball_sets$team1 != "" & volleyball_sets$team2 != "",
]

volleyball_sets$date <- as.Date(volleyball_sets$date)
volleyball_sets <- volleyball_sets[order(volleyball_sets$date, volleyball_sets$contest_id), ]
rownames(volleyball_sets) <- NULL
volleyball_sets <- tibble::as_tibble(volleyball_sets)

usethis::use_data(volleyball_sets, overwrite = TRUE)
