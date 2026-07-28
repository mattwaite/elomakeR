make_series <- function(n = 60, seed = 1) {
  set.seed(seed)
  # "Strong" beats "Weak" about 75% of the time, with a plausible mix of
  # margins, so there is real signal for the tuners to find.
  dates <- as.Date("2024-01-01") + seq_len(n)
  s_wins <- rbinom(n, 1, 0.75)
  s1 <- ifelse(s_wins == 1, sample(2:3, n, replace = TRUE), sample(0:1, n, replace = TRUE))
  s2 <- ifelse(s_wins == 1, sample(0:1, n, replace = TRUE), sample(2:3, n, replace = TRUE))
  data.frame(date = dates, team1 = "Strong", team2 = "Weak", s1 = s1, s2 = s2)
}

test_that("suggest_learning_rate returns a valid grid and best_k from the grid", {
  df <- make_series()
  res <- suggest_learning_rate(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    k_grid = c(5, 15, 25, 35)
  )
  expect_named(res, c("best_k", "best_score", "metric", "grid"))
  expect_equal(nrow(res$grid), 4)
  expect_true(res$best_k %in% c(5, 15, 25, 35))
  expect_equal(res$best_score, min(res$grid$score))
})

test_that("suggest_learning_rate with accuracy metric maximizes instead of minimizes", {
  df <- make_series()
  res <- suggest_learning_rate(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    k_grid = c(5, 15, 25), metric = "accuracy"
  )
  expect_equal(res$best_score, max(res$grid$score))
})

test_that("suggest_home_advantage returns a valid grid", {
  df <- make_series()
  res <- suggest_home_advantage(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    home_advantage_grid = c(0, 50, 100)
  )
  expect_named(res, c("best_home_advantage", "best_score", "metric", "grid"))
  expect_equal(nrow(res$grid), 3)
  expect_true(res$best_home_advantage %in% c(0, 50, 100))
})

test_that("tune_elo searches the full k x home_advantage grid", {
  df <- make_series()
  res <- tune_elo(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    k_grid = c(10, 20), home_advantage_grid = c(0, 50, 100)
  )
  expect_named(res, c("best_k", "best_home_advantage", "best_score", "metric", "grid"))
  expect_equal(nrow(res$grid), 2 * 3)
  expect_equal(res$best_score, min(res$grid$score))
})

test_that("empty grids are rejected", {
  df <- make_series()
  expect_error(
    suggest_learning_rate(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, k_grid = numeric(0)),
    "k_grid"
  )
  expect_error(
    suggest_home_advantage(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2, home_advantage_grid = numeric(0)),
    "home_advantage_grid"
  )
})
