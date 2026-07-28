#' Calculate Elo ratings over a sequence of games
#'
#' Runs the Elo rating system over a data frame of games, processing them
#' in chronological order, and returns a long-format tibble with one row
#' per team per game showing that team's rating immediately before and
#' after the game.
#'
#' Columns in `data` are mapped with tidy evaluation (data masking), so
#' this works with any input schema -- the columns do not need to be
#' named `team1`/`team2`/etc. See the `home_team` and `season` arguments
#' below for how to adapt the function to sports without a home team or
#' without a season structure.
#'
#' @param data A data frame of games, one row per game.
#' @param date <[`data-masking`][rlang::args_data_masking]> Column giving
#'   the date (or any orderable value) of each game.
#' @param team1,team2 <[`data-masking`][rlang::args_data_masking]> Columns
#'   naming the two teams in each game.
#' @param score1,score2 <[`data-masking`][rlang::args_data_masking]>
#'   Numeric columns giving each team's score. The winner is whichever
#'   score is larger; equal scores are treated as a tie.
#' @param home_team <[`data-masking`][rlang::args_data_masking]>
#'   Optional column giving the name of the home team for each game (its
#'   value should equal either `team1` or `team2` on that row). Leave as
#'   `NULL` (the default) to treat every game as a neutral site, i.e. to
#'   apply no home advantage anywhere.
#' @param neutral <[`data-masking`][rlang::args_data_masking]> Optional
#'   logical column. Rows where this is `TRUE` get no home advantage even
#'   if `home_team` is set for that row.
#' @param season <[`data-masking`][rlang::args_data_masking]> Optional
#'   column identifying the season each game belongs to. Required if
#'   `carryover` is `"reset"` or `"regress"`. Assumes seasons do not
#'   temporally overlap once `data` is sorted by `date`.
#' @param game_id <[`data-masking`][rlang::args_data_masking]> Optional
#'   column with an identifier for each game, carried through to the
#'   output. Defaults to the row number in `data`.
#' @param k Learning rate (K-factor): how many rating points are at stake
#'   in a single game. Higher values make ratings react faster to recent
#'   results. Default `20`. See [suggest_learning_rate()].
#' @param home_advantage Rating-point bonus added to the home team's
#'   rating when computing win probability (it is not added to its
#'   stored rating). Default `100`. Set to `0` to disable. See
#'   [suggest_home_advantage()].
#' @param initial_rating Rating assigned to a team the first time it
#'   appears. Default `1500`.
#' @param scale The Elo scale factor controlling how much a rating gap
#'   translates into win probability. Default `400`, the standard Elo
#'   value (a 400-point gap implies a 10:1 favorite).
#' @param mov_adjustment One of `"none"` (default) or `"log"`. `"log"`
#'   scales `k` up for lopsided wins and down for narrow ones, using the
#'   margin-of-victory formula popularized by FiveThirtyEight:
#'   `log(|score1 - score2| + 1) * 2.2 / (0.001 * |elo_diff| + 2.2)`.
#'   Always treated as `1` (no adjustment) for tied games. Ignored
#'   entirely if `mov_fun` is supplied.
#' @param mov_fun Optional custom margin-of-victory function,
#'   `function(score1, score2, rating1, rating2)`, returning a numeric
#'   multiplier applied to `k`. Overrides `mov_adjustment` when supplied.
#' @param carryover One of `"continuous"` (default: ratings simply carry
#'   forward across seasons unchanged), `"reset"` (every team's rating is
#'   set back to `initial_rating` at the start of each new season), or
#'   `"regress"` (each team's rating moves a fraction `regress_pct` of
#'   the way back to `initial_rating` at the start of each new season).
#'   Requires `season` to be mapped when not `"continuous"`.
#' @param regress_pct Fraction between 0 and 1 to regress ratings toward
#'   `initial_rating` at each season boundary when `carryover =
#'   "regress"`. Default `1/3`.
#'
#' @return A [tibble::tibble()], subclassed `"elo_tbl"`, with one row per
#'   team per game, sorted by date: `game_id`, `date`, `season`, `team`,
#'   `opponent`, `is_home`, `score_for`, `score_against`, `result` (`1`
#'   win, `0.5` tie, `0` loss), `win_prob` (pre-game probability of
#'   winning), `pre_elo`, `post_elo`, `elo_change`.
#'
#' @examples
#' \donttest{
#' data(basketball_games)
#' elo <- calculate_elo(
#'   basketball_games,
#'   date = date, team1 = home_location, team2 = away_location,
#'   score1 = home_score, score2 = away_score,
#'   home_team = home_location, neutral = neutral_site
#' )
#' latest_ratings(elo)
#'
#' # a messier, non-standard schema works the same way: team2 is the home
#' # team, and the outcome is given as sets won rather than a single score
#' data(volleyball_sets)
#' calculate_elo(
#'   volleyball_sets,
#'   date = date, team1 = team1, team2 = team2,
#'   score1 = team1_sets_won, score2 = team2_sets_won,
#'   home_team = team2
#' )
#' }
#'
#' @export
calculate_elo <- function(data,
                           date, team1, team2, score1, score2,
                           home_team = NULL, neutral = NULL,
                           season = NULL, game_id = NULL,
                           k = 20, home_advantage = 100,
                           initial_rating = 1500, scale = 400,
                           mov_adjustment = c("none", "log"), mov_fun = NULL,
                           carryover = c("continuous", "reset", "regress"),
                           regress_pct = 1 / 3) {

  mov_adjustment <- match.arg(mov_adjustment)
  carryover <- match.arg(carryover)

  if (missing(date) || missing(team1) || missing(team2) ||
      missing(score1) || missing(score2)) {
    stop("`date`, `team1`, `team2`, `score1`, and `score2` must all be supplied.", call. = FALSE)
  }
  stopifnot(is.data.frame(data), nrow(data) > 0)
  if (k <= 0) stop("`k` must be positive.", call. = FALSE)
  if (scale <= 0) stop("`scale` must be positive.", call. = FALSE)
  if (regress_pct < 0 || regress_pct > 1) stop("`regress_pct` must be between 0 and 1.", call. = FALSE)

  date_q    <- rlang::enquo(date)
  team1_q   <- rlang::enquo(team1)
  team2_q   <- rlang::enquo(team2)
  score1_q  <- rlang::enquo(score1)
  score2_q  <- rlang::enquo(score2)
  home_q    <- rlang::enquo(home_team)
  neutral_q <- rlang::enquo(neutral)
  season_q  <- rlang::enquo(season)
  game_id_q <- rlang::enquo(game_id)

  if (carryover != "continuous" && rlang::quo_is_null(season_q)) {
    stop("`season` must be mapped when `carryover` is \"", carryover, "\".", call. = FALSE)
  }

  n <- nrow(data)
  orig_row <- seq_len(n)

  games <- tibble::tibble(
    .orig_row = orig_row,
    date      = rlang::eval_tidy(date_q, data),
    team1     = as.character(rlang::eval_tidy(team1_q, data)),
    team2     = as.character(rlang::eval_tidy(team2_q, data)),
    score1    = as.numeric(rlang::eval_tidy(score1_q, data)),
    score2    = as.numeric(rlang::eval_tidy(score2_q, data)),
    home_team = if (rlang::quo_is_null(home_q)) NA_character_
                else as.character(rlang::eval_tidy(home_q, data)),
    neutral   = if (rlang::quo_is_null(neutral_q)) FALSE
                else as.logical(rlang::eval_tidy(neutral_q, data)),
    season    = if (rlang::quo_is_null(season_q)) NA
                else rlang::eval_tidy(season_q, data),
    game_id   = if (rlang::quo_is_null(game_id_q)) as.character(orig_row)
                else as.character(rlang::eval_tidy(game_id_q, data))
  )
  games$neutral[is.na(games$neutral)] <- FALSE

  if (anyNA(games$team1) || anyNA(games$team2) ||
      any(games$team1 == "") || any(games$team2 == "")) {
    stop("`team1` and `team2` cannot contain missing or empty-string values.", call. = FALSE)
  }
  if (anyNA(games$score1) || anyNA(games$score2)) {
    stop("`score1` and `score2` cannot contain missing values.", call. = FALSE)
  }
  if (any(games$team1 == games$team2)) {
    stop("Found a game where `team1` and `team2` are the same team.", call. = FALSE)
  }
  bad_home <- !is.na(games$home_team) &
    games$home_team != games$team1 & games$home_team != games$team2
  if (any(bad_home)) {
    stop("`home_team` must equal either `team1` or `team2` on every row where it is set.", call. = FALSE)
  }

  games <- games[order(games$date, games$.orig_row), ]

  ratings <- new.env(parent = emptyenv())
  get_rating <- function(team) {
    if (!exists(team, envir = ratings, inherits = FALSE)) {
      assign(team, initial_rating, envir = ratings)
    }
    get(team, envir = ratings, inherits = FALSE)
  }
  set_rating <- function(team, value) assign(team, value, envir = ratings)

  apply_season_carryover <- function() {
    for (team in ls(ratings)) {
      r <- get(team, envir = ratings, inherits = FALSE)
      new_r <- if (carryover == "reset") initial_rating
               else r + (initial_rating - r) * regress_pct
      assign(team, new_r, envir = ratings)
    }
  }

  mov_multiplier <- function(score1, score2, rating1, rating2, ha1, ha2, is_tie) {
    if (!is.null(mov_fun)) return(mov_fun(score1, score2, rating1, rating2))
    if (mov_adjustment == "none" || is_tie) return(1)
    elo_diff <- (rating1 + ha1) - (rating2 + ha2)
    margin <- abs(score1 - score2)
    log(margin + 1) * (2.2 / (0.001 * abs(elo_diff) + 2.2))
  }

  n_games <- nrow(games)
  out <- vector("list", n_games * 2)
  seen_season <- NULL

  for (i in seq_len(n_games)) {
    g <- games[i, ]

    if (carryover != "continuous") {
      if (is.null(seen_season)) {
        seen_season <- g$season
      } else if (!identical(g$season, seen_season)) {
        apply_season_carryover()
        seen_season <- g$season
      }
    }

    r1 <- get_rating(g$team1)
    r2 <- get_rating(g$team2)

    home_is_team1 <- !is.na(g$home_team) && !isTRUE(g$neutral) && g$home_team == g$team1
    home_is_team2 <- !is.na(g$home_team) && !isTRUE(g$neutral) && g$home_team == g$team2
    ha1 <- if (home_is_team1) home_advantage else 0
    ha2 <- if (home_is_team2) home_advantage else 0

    expected1 <- 1 / (1 + 10 ^ (((r2 + ha2) - (r1 + ha1)) / scale))
    expected2 <- 1 - expected1

    actual1 <- if (g$score1 > g$score2) 1 else if (g$score1 < g$score2) 0 else 0.5
    actual2 <- 1 - actual1

    mult <- mov_multiplier(g$score1, g$score2, r1, r2, ha1, ha2, is_tie = actual1 == 0.5)
    k_eff <- k * mult

    delta1 <- k_eff * (actual1 - expected1)
    new_r1 <- r1 + delta1
    new_r2 <- r2 - delta1

    set_rating(g$team1, new_r1)
    set_rating(g$team2, new_r2)

    out[[2 * i - 1]] <- tibble::tibble(
      game_id = g$game_id, date = g$date, season = g$season,
      team = g$team1, opponent = g$team2, is_home = home_is_team1,
      score_for = g$score1, score_against = g$score2, result = actual1,
      win_prob = expected1, pre_elo = r1, post_elo = new_r1,
      elo_change = new_r1 - r1
    )
    out[[2 * i]] <- tibble::tibble(
      game_id = g$game_id, date = g$date, season = g$season,
      team = g$team2, opponent = g$team1, is_home = home_is_team2,
      score_for = g$score2, score_against = g$score1, result = actual2,
      win_prob = expected2, pre_elo = r2, post_elo = new_r2,
      elo_change = new_r2 - r2
    )
  }

  result <- dplyr::bind_rows(out)
  result <- result[order(result$date, result$game_id, result$team), ]
  result <- tibble::as_tibble(result)
  class(result) <- c("elo_tbl", class(result))
  result
}
