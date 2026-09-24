#' Luge finals at the Milano Cortina 2026 Winter Olympics
#'
#' Final results of all five luge events at the 2026 Winter Olympics, held at
#' the Cortina Sliding Centre in Cortina d'Ampezzo, Italy, Feb. 7-12, 2026.
#' Luge is timed to the thousandth of a second, and medals are often decided
#' by less than a tenth. It's a natural fit for recreating the New York
#' Times's 2010 "Fractions of a Second: An Olympic Musical", which played
#' each finisher as a note at the moment they crossed the line.
#'
#' Only sleds that completed every run are included. In singles, the top 20
#' after three runs advanced to the fourth, so the others' totals aren't
#' comparable.
#'
#' @format A tibble with 77 rows and 11 columns:
#' \describe{
#'   \item{event}{The event: Men's singles, Women's singles, Men's doubles,
#'     Women's doubles or Team relay (a factor in that order).}
#'   \item{rank}{Final place.}
#'   \item{bib}{Start number.}
#'   \item{athlete}{The athlete or athletes. Doubles partners are separated by
#'     " / "; relay team members are separated by commas.}
#'   \item{country}{The country.}
#'   \item{run_1, run_2, run_3, run_4}{Time for each run, in seconds. Doubles
#'     had two runs, so `run_3` and `run_4` are `NA`. For the team relay these
#'     are the four legs: women's singles, men's doubles, men's singles and
#'     women's doubles.}
#'   \item{total_time}{Total time in seconds, the sum of the runs.}
#'   \item{behind}{Seconds behind the winner of the event.}
#' }
#' @source Wikipedia's results page for each event
#'   (<https://en.wikipedia.org/wiki/Luge_at_the_2026_Winter_Olympics>), which
#'   cites the official Olympic results. One total on Wikipedia (Timon
#'   Grancagnolo, men's singles) has transposed digits. Here it is corrected
#'   to the sum of his runs, which matches the page's own time-behind figure.
#'   See `data-raw/luge_finals.R` in the package source.
#' @examples
#' luge_finals
#'
#' # Hear each event's finishers cross the line, four times slower than real life
#' luge_finals |>
#'   sonify_data(time = behind, time_scale = 4, sequence = event, instrument = "bell")
"luge_finals"

#' Nebraska men's basketball, 2025-26
#'
#' Every game of the best season in Nebraska men's basketball history: a
#' 28-7 record, a 20-0 start, and the program's first NCAA tournament wins,
#' reaching the Sweet 16.
#'
#' @format A tibble with 35 rows and 10 columns:
#' \describe{
#'   \item{game_number}{Game number, 1 to 35.}
#'   \item{date}{Date of the game (Central time).}
#'   \item{opponent}{The opponent.}
#'   \item{location}{"home", "away" or "neutral".}
#'   \item{game_type}{"regular season", "Big Ten tournament" or
#'     "NCAA tournament" (a factor).}
#'   \item{conference_game}{`TRUE` for Big Ten games.}
#'   \item{husker_score, opponent_score}{Points scored by each team.}
#'   \item{point_margin}{`husker_score` minus `opponent_score`. Positive
#'     numbers are wins.}
#'   \item{result}{"W" or "L".}
#' }
#' @source ESPN schedule data via the hoopR package
#'   (`hoopR::load_mbb_schedule(2026)`). The record and final game were
#'   checked against huskers.com. See `data-raw/husker_games.R` in the package
#'   source.
#' @examples
#' husker_games
#'
#' # Hear the season: higher notes for bigger wins
#' husker_games |>
#'   sonify_data(point_margin, instrument = "bell", bpm = 180)
"husker_games"

#' Houses built in Nebraska, by year
#'
#' The number of single-family houses in Nebraska by the year they were
#' built, from 1800 to 2026, compiled from parcel records. It's already
#' counted, one row per year, so give `houses` to the `weight` argument of
#' [sonify_histogram()].
#'
#' A few things to know before you listen:
#'
#' * **Round-number years.** Before 1950, 42% of houses have a year ending
#'   in 0, where you'd expect about 10%, and 58% end in 0 or 5. 1900 alone has
#'   19,205 houses, compared with 730 in 1901. From 1980 on the pattern mostly
#'   disappears. Why old houses pile up on round numbers isn't documented yet.
#'   With one bin per year, you can hear it.
#' * **Recent years are incomplete.** 2025 (408 houses) and 2026 (1) were only
#'   partly recorded when the data was compiled, so they're far lower than the
#'   years before them. That's not a housing crash.
#' * **Missing years.** 45 of the years between 1800 and 2026 have no houses
#'   and no row.
#' * **Unknown years.** About 13,000 parcels have no build year recorded.
#'   They aren't included.
#'
#' @format A tibble with 182 rows and 2 columns:
#' \describe{
#'   \item{year_built}{The year the house was built.}
#'   \item{houses}{How many single-family houses were built that year.}
#' }
#' @source Compiled by Matt Waite from Nebraska parcel records. See
#'   `data-raw/ne_house_years.R` in the package source.
#' @examples
#' ne_house_years
#'
#' # One bin per decade
#' ne_house_years |>
#'   sonify_histogram(year_built, weight = houses, binwidth = 10, instrument = "marimba")
"ne_house_years"
