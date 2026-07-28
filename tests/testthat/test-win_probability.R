test_that("equal ratings with no home advantage give 50/50 odds", {
  expect_equal(elo_win_prob(1500, 1500), 0.5)
})

test_that("home advantage increases the home team's win probability", {
  expect_gt(elo_win_prob(1500, 1500, home_advantage = 100), 0.5)
  expect_equal(
    elo_win_prob(1500, 1500, home_advantage = 100),
    elo_win_prob(1600, 1500, home_advantage = 0)
  )
})

test_that("probabilities are complementary when home advantage is 0", {
  p_a <- elo_win_prob(1620, 1480)
  p_b <- elo_win_prob(1480, 1620)
  expect_equal(p_a + p_b, 1)
})

test_that("a 400-point gap gives the standard 10:1 odds", {
  expect_equal(elo_win_prob(1900, 1500), 10 / 11, tolerance = 1e-8)
})
