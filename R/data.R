#' NCAA Division I men's basketball game results, 2025-26 season
#'
#' Final scores for every completed 2025-26 NCAA Division I men's
#' basketball game, one row per game, pulled with the `hoopR` package.
#' Included as the primary example for [calculate_elo()] and friends:
#' it has separate home/away columns (`home_location`/`away_location`)
#' rather than an arbitrary `team1`/`team2` split, and a genuine
#' `neutral_site` flag for tournament and showcase games played at
#' neither team's home venue.
#'
#' Filtered to games with `status_type_completed == TRUE`; all other
#' columns from the raw `hoopR` pull (venue, broadcast, box score,
#' play-by-play, etc.) were dropped as irrelevant to rating calculation.
#' A national-rank sentinel value of 99 (meaning "unranked") was
#' recoded to `NA`.
#'
#' @format A tibble with 6,300 rows and 12 columns:
#' \describe{
#'   \item{game_id}{Source identifier for the game.}
#'   \item{date}{Date the game was played.}
#'   \item{season}{Season label (all games here are the 2026 season, i.e. 2025-26).}
#'   \item{season_type}{`2` for regular season, `3` for postseason/tournament.}
#'   \item{neutral_site}{`TRUE` if neither team was at its home venue.}
#'   \item{conference_competition}{`TRUE` if both teams belong to the same conference.}
#'   \item{home_location, away_location}{Team names.}
#'   \item{home_score, away_score}{Final score.}
#'   \item{home_current_rank, away_current_rank}{National rank at game time, if ranked.}
#' }
#'
#' @source `hoopR`-pulled play-by-play/box-score data for the 2025-26
#'   NCAA Division I men's basketball season.
"basketball_games"

#' NCAA Division I women's volleyball set scores, 2025 season
#'
#' Match results for the 2025 NCAA Division I women's volleyball season,
#' one row per match, with set-by-set scores. Included as a second
#' example for [calculate_elo()], illustrating a messier, more arbitrary
#' input schema than [basketball_games]: `team2` is the home team, and
#' match outcome is given as sets won (`team1_sets_won`/`team2_sets_won`,
#' best of 5) rather than a single score column.
#'
#' Exact duplicate rows and matches with no recorded score were removed
#' from the original scrape; no other changes were made.
#'
#' @format A tibble with 5,087 rows and 20 columns:
#' \describe{
#'   \item{date}{Date the match was played.}
#'   \item{contest_id}{Source identifier for the match.}
#'   \item{team1}{Away team name.}
#'   \item{team1_rank}{Away team's national rank at match time, if ranked.}
#'   \item{team1_record}{Away team's win-loss record entering the match.}
#'   \item{team2}{Home team name.}
#'   \item{team2_rank}{Home team's national rank at match time, if ranked.}
#'   \item{team2_record}{Home team's win-loss record entering the match.}
#'   \item{team1_sets_won, team2_sets_won}{Sets won by each team (best of 5; match winner is whoever reaches 3).}
#'   \item{s1_t1, s1_t2, ..., s5_t1, s5_t2}{Point score for each team in sets 1 through 5 (`NA` if the set was not played).}
#' }
#'
#' @source Scraped play-by-play/box-score data for the 2025 NCAA D-I
#'   women's volleyball season.
"volleyball_sets"
