# Prepares the bundled basketball example dataset from a HoopR pull at
# ~/Desktop/basketball2025.csv (2025-26 NCAA Division I men's basketball
# season). The source has 86 columns, most of them huge nested
# broadcast/box-score/play-by-play blobs that are irrelevant to Elo
# ratings; only the game-level columns needed for calculate_elo() (plus
# a couple of nice-to-have context columns) are kept.
#
# Unlike volleyball_sets, this source already has separate home/away
# columns and a real neutral_site flag, making it a good example of a
# schema calculate_elo() handles without any team1/team2 relabeling.

raw <- readr::read_csv("~/Desktop/basketball2025.csv", show_col_types = FALSE, guess_max = 10000)

basketball_games <- raw[raw$status_type_completed, c(
  "game_id", "game_date", "season", "season_type", "neutral_site",
  "conference_competition",
  "home_location", "home_score", "home_current_rank",
  "away_location", "away_score", "away_current_rank"
)]

names(basketball_games)[names(basketball_games) == "game_date"] <- "date"

# 99 is HoopR's sentinel for "unranked", not a real rank.
basketball_games$home_current_rank[basketball_games$home_current_rank == 99] <- NA
basketball_games$away_current_rank[basketball_games$away_current_rank == 99] <- NA

basketball_games <- basketball_games[order(basketball_games$date, basketball_games$game_id), ]
rownames(basketball_games) <- NULL
basketball_games <- tibble::as_tibble(basketball_games)

usethis::use_data(basketball_games, overwrite = TRUE)
