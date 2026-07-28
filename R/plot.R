#' Plot Elo rating trajectories
#'
#' Draws each team's rating over time as a step line. Requires the
#' ggplot2 package. Registered as a [ggplot2::autoplot()] method for
#' `elo_tbl` objects as well, so `autoplot(elo)` also works once
#' ggplot2 is loaded.
#'
#' @param elo A tibble returned by [calculate_elo()].
#' @param teams Optional character vector of team names to restrict the
#'   plot to. Default (`NULL`) plots every team, which is often too
#'   crowded to be useful.
#'
#' @return A ggplot object.
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
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   plot_elo(elo, teams = c("Duke", "Michigan"))
#' }
#' }
#'
#' @export
plot_elo <- function(elo, teams = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop(
      "Package \"ggplot2\" is required for plot_elo(). Install it with install.packages(\"ggplot2\").",
      call. = FALSE
    )
  }
  if (!is.null(teams)) {
    elo <- elo[elo$team %in% teams, ]
  }
  ggplot2::ggplot(elo, ggplot2::aes(x = .data$date, y = .data$post_elo, color = .data$team)) +
    ggplot2::geom_step() +
    ggplot2::labs(x = NULL, y = "Elo rating", color = NULL)
}

elo_autoplot_impl <- function(object, ...) {
  plot_elo(object, ...)
}
