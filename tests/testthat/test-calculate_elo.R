make_games <- function() {
  data.frame(
    date = as.Date(c("2023-01-01", "2023-06-01", "2024-01-01", "2024-01-02")),
    season = c(2023, 2023, 2024, 2024),
    team1 = c("A", "A", "A", "B"),
    team2 = c("B", "B", "B", "A"),
    s1 = c(2, 3, 1, 0),
    s2 = c(2, 0, 1, 0),
    home = c("A", "B", NA, "B"),
    neu = c(FALSE, FALSE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
}

test_that("output shape and class are correct", {
  df <- make_games()
  elo <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2)

  expect_s3_class(elo, "elo_tbl")
  expect_s3_class(elo, "tbl_df")
  expect_equal(nrow(elo), 2 * nrow(df))
  expect_true(all(c(
    "game_id", "date", "season", "team", "opponent", "is_home",
    "score_for", "score_against", "result", "win_prob",
    "pre_elo", "post_elo", "elo_change"
  ) %in% names(elo)))
})

test_that("a single decisive game with no home advantage matches hand calculation", {
  df <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = 3, s2 = 1)
  elo <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, k = 32)

  a <- elo[elo$team == "A", ]
  b <- elo[elo$team == "B", ]

  expect_equal(a$pre_elo, 1500)
  expect_equal(b$pre_elo, 1500)
  expect_equal(a$win_prob, 0.5)
  expect_equal(a$result, 1)
  expect_equal(b$result, 0)
  expect_equal(a$post_elo, 1500 + 32 * 0.5)
  expect_equal(b$post_elo, 1500 - 32 * 0.5)
  # rating exchange is zero-sum
  expect_equal(a$elo_change, -b$elo_change)
})

test_that("ties are scored as 0.5 for both teams", {
  df <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = 2, s2 = 2)
  elo <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2)

  expect_equal(elo$result, c(0.5, 0.5))
  # equal pre-game ratings + a tie => no rating change
  expect_equal(elo$pre_elo, elo$post_elo)
})

test_that("home advantage shifts win probability toward the home team", {
  df <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = 2, s2 = 2, home = "A")
  elo <- calculate_elo(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    home_team = home, home_advantage = 100
  )
  a <- elo[elo$team == "A", ]
  b <- elo[elo$team == "B", ]

  expect_true(a$is_home)
  expect_false(b$is_home)
  expect_gt(a$win_prob, 0.5)
  expect_equal(a$win_prob, elo_win_prob(1500, 1500, home_advantage = 100))
  expect_equal(a$win_prob + b$win_prob, 1)
})

test_that("neutral flag suppresses home advantage for that game", {
  df <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = 2, s2 = 2, home = "A", neu = TRUE)
  elo <- calculate_elo(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    home_team = home, neutral = neu, home_advantage = 100
  )
  a <- elo[elo$team == "A", ]
  expect_false(a$is_home)
  expect_equal(a$win_prob, 0.5)
})

test_that("season carryover: reset sends every rating back to initial_rating", {
  df <- make_games()
  elo <- calculate_elo(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    season = season, carryover = "reset"
  )
  game3 <- elo[elo$game_id == "3", ]
  expect_equal(game3$pre_elo, c(1500, 1500))
})

test_that("season carryover: regress matches hand-computed values", {
  df <- make_games()
  elo <- calculate_elo(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    home_team = home, neutral = neu, season = season,
    carryover = "regress", regress_pct = 0.5, k = 32
  )
  a <- elo[elo$team == "A", ]
  b <- elo[elo$team == "B", ]

  # end of season 2023 (game 2): A = 1516.378..., B = 1483.622...
  a_end_2023 <- a$post_elo[a$game_id == "2"]
  b_end_2023 <- b$post_elo[b$game_id == "2"]

  a_start_2024 <- a$pre_elo[a$game_id == "3"]
  b_start_2024 <- b$pre_elo[b$game_id == "3"]

  expect_equal(a_start_2024, a_end_2023 + (1500 - a_end_2023) * 0.5)
  expect_equal(b_start_2024, b_end_2023 + (1500 - b_end_2023) * 0.5)
})

test_that("continuous carryover is the default and requires no season", {
  df <- make_games()
  elo <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2)
  expect_true(all(is.na(elo$season)))
})

test_that("reset/regress carryover require a season mapping", {
  df <- make_games()
  expect_error(
    calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, carryover = "reset"),
    "season"
  )
})

test_that("log margin-of-victory adjustment scales k with blowout size", {
  blowout <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = 5, s2 = 0)
  close   <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = 1, s2 = 0)

  fit <- function(d) {
    calculate_elo(d, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, mov_adjustment = "log")
  }
  elo_blowout <- fit(blowout)
  elo_close <- fit(close)

  change_blowout <- elo_blowout$elo_change[elo_blowout$team == "A"]
  change_close <- elo_close$elo_change[elo_close$team == "A"]

  expect_gt(change_blowout, change_close)
})

test_that("mov_adjustment 'log' leaves ties unaffected (multiplier of 1)", {
  df <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = 2, s2 = 2)
  elo_none <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, mov_adjustment = "none")
  elo_log  <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, mov_adjustment = "log")
  expect_equal(elo_none$post_elo, elo_log$post_elo)
})

test_that("custom mov_fun overrides mov_adjustment", {
  df <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = 3, s2 = 1)
  elo <- calculate_elo(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    k = 20, mov_fun = function(score1, score2, rating1, rating2) 0
  )
  # multiplier of 0 means no rating movement at all
  expect_equal(elo$pre_elo, elo$post_elo)
})

test_that("game_id defaults to row number and custom game_id is respected", {
  df <- data.frame(date = as.Date(c("2024-01-01", "2024-01-02")), team1 = c("A", "C"), team2 = c("B", "D"), s1 = c(1, 1), s2 = c(0, 0))
  elo_default <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2)
  expect_setequal(unique(elo_default$game_id), c("1", "2"))

  df$gid <- c("g1", "g2")
  elo_custom <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, game_id = gid)
  expect_setequal(unique(elo_custom$game_id), c("g1", "g2"))
})

test_that("games are processed in chronological order regardless of input row order", {
  df <- data.frame(
    date = as.Date(c("2024-02-01", "2024-01-01")),
    team1 = c("A", "A"), team2 = c("B", "B"), s1 = c(3, 3), s2 = c(0, 0)
  )
  elo <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, k = 20)
  a <- elo[elo$team == "A", ]
  a <- a[order(a$date), ]
  expect_equal(a$date, as.Date(c("2024-01-01", "2024-02-01")))
  expect_equal(a$pre_elo[1], 1500)
  expect_gt(a$pre_elo[2], 1500)
})

test_that("invalid inputs are rejected with informative errors", {
  df <- make_games()
  expect_error(calculate_elo(df, team1 = team1, team2 = team2, score1 = s1, score2 = s2))

  bad_same_team <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "A", s1 = 1, s2 = 0)
  expect_error(
    calculate_elo(bad_same_team, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2),
    "same team"
  )

  bad_na_score <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = NA, s2 = 0)
  expect_error(
    calculate_elo(bad_na_score, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2),
    "missing"
  )

  bad_home <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "B", s1 = 1, s2 = 0, home = "C")
  expect_error(
    calculate_elo(bad_home, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, home_team = home),
    "home_team"
  )

  bad_empty_team <- data.frame(date = as.Date("2024-01-01"), team1 = "A", team2 = "", s1 = 1, s2 = 0)
  expect_error(
    calculate_elo(bad_empty_team, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2),
    "empty"
  )

  expect_error(
    calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, k = -1),
    "positive"
  )
})
