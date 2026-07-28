#' Extract the most recent rating for each team
#'
#' Given the long-format output of [calculate_elo()], returns each
#' team's latest rating -- i.e. a current standings table.
#'
#' @param elo A tibble returned by [calculate_elo()].
#' @param season Optional. If supplied, restricts to games in this
#'   season (matching the `season` column) before finding each team's
#'   latest rating within that season.
#'
#' @return A tibble with one row per team: `team`, `rating`, `date` (the
#'   date of that team's most recent game), sorted by `rating`
#'   descending.
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
#' }
#'
#' @export
latest_ratings <- function(elo, season = NULL) {
  if (!is.null(season)) {
    elo <- elo[elo$season == season, ]
  }
  if (nrow(elo) == 0) {
    return(tibble::tibble(team = character(), rating = numeric(), date = elo$date))
  }

  ord <- order(elo$team, elo$date)
  elo <- elo[ord, ]
  last_idx <- !duplicated(elo$team, fromLast = TRUE)

  out <- tibble::tibble(
    team = elo$team[last_idx],
    rating = elo$post_elo[last_idx],
    date = elo$date[last_idx]
  )
  out[order(-out$rating), ]
}
