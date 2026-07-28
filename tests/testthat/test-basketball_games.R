test_that("basketball_games has the expected shape", {
  data(basketball_games)
  expect_true(nrow(basketball_games) > 0)
  expect_true(all(c(
    "game_id", "date", "season", "season_type", "neutral_site",
    "home_location", "home_score", "away_location", "away_score"
  ) %in% names(basketball_games)))
  expect_false(anyNA(basketball_games$home_score))
  expect_false(anyNA(basketball_games$away_score))
  expect_false(any(basketball_games$home_location == basketball_games$away_location))
})

test_that("calculate_elo runs on basketball_games with home/away columns and a real neutral flag", {
  data(basketball_games)
  elo <- calculate_elo(
    basketball_games,
    date = date, team1 = home_location, team2 = away_location,
    score1 = home_score, score2 = away_score,
    home_team = home_location, neutral = neutral_site, game_id = game_id
  )

  expect_equal(nrow(elo), 2 * nrow(basketball_games))

  neutral_ids <- as.character(basketball_games$game_id[basketball_games$neutral_site])
  neutral_rows <- elo[elo$game_id %in% neutral_ids, ]
  expect_true(nrow(neutral_rows) > 0)
  expect_false(any(neutral_rows$is_home))

  nonneutral_ids <- as.character(basketball_games$game_id[!basketball_games$neutral_site])
  nonneutral_rows <- elo[elo$game_id %in% nonneutral_ids, ]
  home_counts <- tapply(nonneutral_rows$is_home, nonneutral_rows$game_id, sum)
  expect_true(all(home_counts == 1))
})

test_that("basketball_games has no ties, consistent with basketball rules", {
  data(basketball_games)
  expect_false(any(basketball_games$home_score == basketball_games$away_score))
})
