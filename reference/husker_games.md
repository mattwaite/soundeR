# Nebraska men's basketball, 2025-26

Every game of the best season in Nebraska men's basketball history: a
28-7 record, a 20-0 start, and the program's first NCAA tournament wins,
reaching the Sweet 16.

## Usage

``` r
husker_games
```

## Format

A tibble with 35 rows and 10 columns:

- game_number:

  Game number, 1 to 35.

- date:

  Date of the game (Central time).

- opponent:

  The opponent.

- location:

  "home", "away" or "neutral".

- game_type:

  "regular season", "Big Ten tournament" or "NCAA tournament" (a
  factor).

- conference_game:

  `TRUE` for Big Ten games.

- husker_score, opponent_score:

  Points scored by each team.

- point_margin:

  `husker_score` minus `opponent_score`. Positive numbers are wins.

- result:

  "W" or "L".

## Source

ESPN schedule data via the hoopR package
(`hoopR::load_mbb_schedule(2026)`). The record and final game were
checked against huskers.com. See `data-raw/husker_games.R` in the
package source.

## Examples

``` r
husker_games
#> # A tibble: 35 × 10
#>    game_number date       opponent            location game_type conference_game
#>          <int> <date>     <chr>               <chr>    <fct>     <lgl>          
#>  1           1 2025-11-03 West Georgia        home     regular … FALSE          
#>  2           2 2025-11-08 Florida Internatio… home     regular … FALSE          
#>  3           3 2025-11-11 Maryland Eastern S… home     regular … FALSE          
#>  4           4 2025-11-15 Oklahoma            neutral  regular … FALSE          
#>  5           5 2025-11-20 New Mexico          neutral  regular … FALSE          
#>  6           6 2025-11-21 Kansas State        neutral  regular … FALSE          
#>  7           7 2025-11-25 Winthrop            home     regular … FALSE          
#>  8           8 2025-11-29 South Carolina Ups… home     regular … FALSE          
#>  9           9 2025-12-07 Creighton           home     regular … FALSE          
#> 10          10 2025-12-10 Wisconsin           home     regular … TRUE           
#> # ℹ 25 more rows
#> # ℹ 4 more variables: husker_score <int>, opponent_score <int>,
#> #   point_margin <int>, result <chr>

# Hear the season: higher notes for bigger wins
husker_games |>
  sonify_data(point_margin, instrument = "bell", bpm = 180)
35 notes · 11.7 seconds · bell
```
