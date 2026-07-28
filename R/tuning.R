.elo_log_loss <- function(elo_tbl) {
  p <- pmin(pmax(elo_tbl$win_prob, 1e-10), 1 - 1e-10)
  y <- elo_tbl$result
  mean(-(y * log(p) + (1 - y) * log(1 - p)))
}

.elo_accuracy <- function(elo_tbl) {
  decisive <- elo_tbl$result != 0.5
  if (!any(decisive)) return(NA_real_)
  predicted_win <- elo_tbl$win_prob[decisive] > 0.5
  actual_win <- elo_tbl$result[decisive] == 1
  mean(predicted_win == actual_win)
}

.elo_score <- function(elo_tbl, metric) {
  if (metric == "log_loss") .elo_log_loss(elo_tbl) else .elo_accuracy(elo_tbl)
}

.best_index <- function(scores, metric) {
  if (metric == "log_loss") which.min(scores) else which.max(scores)
}

#' Suggest a learning rate (K-factor) by grid search
#'
#' Tries each value in `k_grid`, runs [calculate_elo()] over `data` with
#' that `k` (all other arguments held fixed via `...`), scores the
#' resulting pre-game win probabilities against the actual results, and
#' reports the best-scoring value.
#'
#' Pass a full prior season (or several seasons) to pick a `k` to carry
#' into a new season, or pass the current season's games so far to tune
#' `k` on the fly as the season progresses.
#'
#' @param data A data frame of games, as for [calculate_elo()].
#' @param ... Column mappings and other arguments forwarded to
#'   [calculate_elo()] (e.g. `date =`, `team1 =`, `team2 =`, `score1 =`,
#'   `score2 =`, `home_team =`, `season =`, `mov_adjustment =`). Do not
#'   pass `k` here -- it is supplied by `k_grid`.
#' @param k_grid Numeric vector of candidate `k` values to try. Default
#'   `seq(4, 60, by = 2)`.
#' @param metric One of `"log_loss"` (default; lower is better) or
#'   `"accuracy"` (higher is better; computed only over decisive, i.e.
#'   non-tied, games).
#'
#' @return A list with `best_k`, `best_score`, `metric`, and `grid` (a
#'   tibble of every `k` tried and its score).
#'
#' @examples
#' \donttest{
#' data(basketball_games)
#' suggest_learning_rate(
#'   basketball_games,
#'   date = date, team1 = home_location, team2 = away_location,
#'   score1 = home_score, score2 = away_score,
#'   home_team = home_location, neutral = neutral_site,
#'   k_grid = seq(10, 40, by = 10)
#' )
#' }
#'
#' @export
suggest_learning_rate <- function(data, ...,
                                   k_grid = seq(4, 60, by = 2),
                                   metric = c("log_loss", "accuracy")) {
  metric <- match.arg(metric)
  if (length(k_grid) == 0) stop("`k_grid` must have at least one value.", call. = FALSE)

  scores <- vapply(k_grid, function(k_val) {
    fit <- calculate_elo(data, ..., k = k_val)
    .elo_score(fit, metric)
  }, numeric(1))

  grid <- tibble::tibble(k = k_grid, score = scores)
  best <- .best_index(scores, metric)

  list(best_k = k_grid[best], best_score = scores[best], metric = metric, grid = grid)
}

#' Suggest a home-advantage value by grid search
#'
#' Tries each value in `home_advantage_grid`, runs [calculate_elo()] over
#' `data` with that home advantage (all other arguments held fixed via
#' `...`), scores the resulting pre-game win probabilities against the
#' actual results, and reports the best-scoring value.
#'
#' As with [suggest_learning_rate()], pass historical (e.g. prior-season)
#' data to get a value to use going forward, or the current season's
#' games so far to tune on the fly.
#'
#' @inheritParams suggest_learning_rate
#' @param home_advantage_grid Numeric vector of candidate home-advantage
#'   values to try. Default `seq(0, 200, by = 10)`.
#'
#' @return A list with `best_home_advantage`, `best_score`, `metric`, and
#'   `grid` (a tibble of every value tried and its score).
#'
#' @examples
#' \donttest{
#' data(basketball_games)
#' suggest_home_advantage(
#'   basketball_games,
#'   date = date, team1 = home_location, team2 = away_location,
#'   score1 = home_score, score2 = away_score,
#'   home_team = home_location, neutral = neutral_site,
#'   home_advantage_grid = seq(0, 150, by = 50)
#' )
#' }
#'
#' @export
suggest_home_advantage <- function(data, ...,
                                    home_advantage_grid = seq(0, 200, by = 10),
                                    metric = c("log_loss", "accuracy")) {
  metric <- match.arg(metric)
  if (length(home_advantage_grid) == 0) {
    stop("`home_advantage_grid` must have at least one value.", call. = FALSE)
  }

  scores <- vapply(home_advantage_grid, function(ha_val) {
    fit <- calculate_elo(data, ..., home_advantage = ha_val)
    .elo_score(fit, metric)
  }, numeric(1))

  grid <- tibble::tibble(home_advantage = home_advantage_grid, score = scores)
  best <- .best_index(scores, metric)

  list(
    best_home_advantage = home_advantage_grid[best],
    best_score = scores[best], metric = metric, grid = grid
  )
}

#' Jointly tune learning rate and home advantage by grid search
#'
#' Like [suggest_learning_rate()] and [suggest_home_advantage()] but
#' searches both parameters at once, which matters when they interact
#' (e.g. a higher home advantage changes which `k` best fits the data).
#'
#' @inheritParams suggest_learning_rate
#' @param home_advantage_grid Numeric vector of candidate home-advantage
#'   values to try. Default `seq(0, 200, by = 25)`.
#'
#' @return A list with `best_k`, `best_home_advantage`, `best_score`,
#'   `metric`, and `grid` (a tibble of every combination tried and its
#'   score).
#'
#' @examples
#' \donttest{
#' data(basketball_games)
#' tune_elo(
#'   basketball_games,
#'   date = date, team1 = home_location, team2 = away_location,
#'   score1 = home_score, score2 = away_score,
#'   home_team = home_location, neutral = neutral_site,
#'   k_grid = seq(10, 30, by = 10),
#'   home_advantage_grid = seq(0, 100, by = 50)
#' )
#' }
#'
#' @export
tune_elo <- function(data, ...,
                      k_grid = seq(4, 60, by = 4),
                      home_advantage_grid = seq(0, 200, by = 25),
                      metric = c("log_loss", "accuracy")) {
  metric <- match.arg(metric)
  if (length(k_grid) == 0 || length(home_advantage_grid) == 0) {
    stop("`k_grid` and `home_advantage_grid` must each have at least one value.", call. = FALSE)
  }

  grid <- expand.grid(k = k_grid, home_advantage = home_advantage_grid)
  grid$score <- vapply(seq_len(nrow(grid)), function(i) {
    fit <- calculate_elo(data, ..., k = grid$k[i], home_advantage = grid$home_advantage[i])
    .elo_score(fit, metric)
  }, numeric(1))
  grid <- tibble::as_tibble(grid)
  best <- .best_index(grid$score, metric)

  list(
    best_k = grid$k[best], best_home_advantage = grid$home_advantage[best],
    best_score = grid$score[best], metric = metric, grid = grid
  )
}
