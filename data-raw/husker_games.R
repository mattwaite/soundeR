## Prepare `husker_games`: every game of Nebraska men's basketball's 2025-26
## season, the best in program history (28-7, a 20-0 start, and the program's
## first NCAA tournament wins, reaching the Sweet 16).
##
## Source: ESPN schedule data via the hoopR package's load_mbb_schedule()
## (sportsdataverse). Record and Sweet 16 result cross-checked against
## huskers.com ("Huskers' Historic Season Comes to an End in Sweet 16",
## 2026-03-26): 28-7, lost 77-71 to Iowa.

library(hoopR)

sched <- load_mbb_schedule(seasons = 2026)
team <- "Nebraska Cornhuskers"
neb <- sched[sched$home_display_name == team | sched$away_display_name == team, ]
neb <- neb[neb$status_type_completed, ]
home <- neb$home_display_name == team

# ESPN timestamps are UTC; convert to Lincoln's time zone before taking the date,
# so late tip-offs don't slip to the next day.
tip <- as.POSIXct(neb$date, format = "%Y-%m-%dT%H:%M", tz = "UTC")
date <- as.Date(format(tip, tz = "America/Chicago"))

notes <- ifelse(is.na(neb$notes_headline), "", neb$notes_headline)
game_type <- ifelse(grepl("NCAA", notes), "NCAA tournament",
             ifelse(grepl("Big Ten Tournament", notes), "Big Ten tournament", "regular season"))

husker_games <- data.frame(
  date = date,
  opponent = ifelse(home, neb$away_location, neb$home_location),
  location = ifelse(neb$neutral_site, "neutral", ifelse(home, "home", "away")),
  game_type = factor(game_type, levels = c("regular season", "Big Ten tournament", "NCAA tournament")),
  conference_game = neb$conference_competition,
  husker_score = as.integer(ifelse(home, neb$home_score, neb$away_score)),
  opponent_score = as.integer(ifelse(home, neb$away_score, neb$home_score))
)
husker_games <- husker_games[order(husker_games$date), ]
husker_games$point_margin <- husker_games$husker_score - husker_games$opponent_score
husker_games$result <- ifelse(husker_games$point_margin > 0, "W", "L")
husker_games$game_number <- seq_len(nrow(husker_games))
husker_games <- husker_games[c("game_number", setdiff(names(husker_games), "game_number"))]
rownames(husker_games) <- NULL
husker_games <- tibble::as_tibble(husker_games)

# Sanity checks against the published record.
last <- husker_games[nrow(husker_games), ]
stopifnot(
  nrow(husker_games) == 35,
  sum(husker_games$result == "W") == 28,
  all(husker_games$result[1:20] == "W"),
  last$opponent == "Iowa", last$husker_score == 71, last$opponent_score == 77,
  last$date == as.Date("2026-03-26"),
  sum(husker_games$game_type == "NCAA tournament") == 3
)

usethis::use_data(husker_games, overwrite = TRUE)
