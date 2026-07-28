test_that("latest_ratings returns one row per team with the most recent post_elo", {
  df <- data.frame(
    date = as.Date(c("2024-01-01", "2024-01-02", "2024-01-03")),
    team1 = c("A", "B", "A"),
    team2 = c("B", "C", "C"),
    s1 = c(3, 0, 3),
    s2 = c(0, 3, 1)
  )
  elo <- calculate_elo(df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2)
  latest <- latest_ratings(elo)

  expect_equal(nrow(latest), 3)
  expect_setequal(latest$team, c("A", "B", "C"))

  a_rows <- elo[elo$team == "A", ]
  a_last <- a_rows$post_elo[which.max(a_rows$date)]
  expect_equal(latest$rating[latest$team == "A"], a_last)

  # sorted descending by rating
  expect_equal(latest$rating, sort(latest$rating, decreasing = TRUE))
})

test_that("latest_ratings filters by season when requested", {
  df <- data.frame(
    date = as.Date(c("2023-01-01", "2024-01-01")),
    season = c(2023, 2024),
    team1 = c("A", "A"),
    team2 = c("B", "B"),
    s1 = c(3, 0),
    s2 = c(0, 3)
  )
  elo <- calculate_elo(
    df, date = date, team1 = team1, team2 = team2, score1 = s1, score2 = s2,
    season = season, carryover = "reset"
  )

  latest_2023 <- latest_ratings(elo, season = 2023)
  expect_equal(latest_2023$rating[latest_2023$team == "A"] > 1500, TRUE)

  latest_2024 <- latest_ratings(elo, season = 2024)
  expect_equal(latest_2024$rating[latest_2024$team == "A"] < 1500, TRUE)
})
