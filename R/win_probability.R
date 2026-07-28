#' Elo win probability
#'
#' Computes the probability that team A beats team B given their Elo
#' ratings, using the standard logistic Elo formula. Useful for
#' generating predictions from a fitted rating table, and used
#' internally by [calculate_elo()].
#'
#' @param rating_a,rating_b Numeric vectors of Elo ratings (recycled
#'   against each other).
#' @param home_advantage Rating points to add to `rating_a` before
#'   computing the probability. Default `0`. Pass a negative value, or
#'   add it to `rating_b` instead, to give the advantage to team B.
#' @param scale The Elo scale factor. Default `400`, matching
#'   [calculate_elo()]'s default.
#'
#' @return A numeric vector of probabilities that team A wins (ties, if
#'   any, are not represented -- this is strictly P(A beats B) under the
#'   Elo model).
#'
#' @examples
#' elo_win_prob(1600, 1500)
#' elo_win_prob(1600, 1500, home_advantage = 100)
#'
#' @export
elo_win_prob <- function(rating_a, rating_b, home_advantage = 0, scale = 400) {
  1 / (1 + 10 ^ (((rating_b) - (rating_a + home_advantage)) / scale))
}
