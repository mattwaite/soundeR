## Prepare `luge_finals`: final results of every luge event at the
## Milano Cortina 2026 Winter Olympics (Cortina Sliding Centre, Feb. 7-12, 2026).
##
## Source: the Wikipedia results page for each event (CC BY-SA 4.0), which
## cites the official Olympic results. Scraped with rvest.
## Only sleds that completed every run are kept: in singles, the top 20 after
## three runs advanced to the fourth, so the others have incomparable totals.
##
## `total_time` is the sum of the run times (that's how luge totals work).
## Where Wikipedia's "Total" cell disagrees, the script prints the row. As of
## 2026-09-23 there is one: Timon Grancagnolo (men's singles, 9th) shows a
## total of 3:33.942, but his runs sum to 3:33.492 and the page's own "Behind"
## column (+2.301) agrees with the sum, so the total cell has transposed digits.

library(rvest)

base <- "https://en.wikipedia.org/wiki/Luge_at_the_2026_Winter_Olympics_%E2%80%93_"
events <- c(
  "Men's singles"   = "Men%27s_singles",
  "Women's singles" = "Women%27s_singles",
  "Men's doubles"   = "Men%27s_doubles",
  "Women's doubles" = "Women%27s_doubles",
  "Team relay"      = "Team_relay"
)

# "52.924 TR" -> 52.924; "3:31.191" -> 211.191; anything else -> NA
to_seconds <- function(x) {
  x <- trimws(sub("\\s.*$", "", x))
  out <- rep(NA_real_, length(x))
  mmss <- grepl("^[0-9]+:[0-9.]+$", x)
  parts <- strsplit(x[mmss], ":")
  out[mmss] <- vapply(parts, function(p) as.numeric(p[1]) * 60 + as.numeric(p[2]), numeric(1))
  plain <- grepl("^[0-9]+\\.[0-9]+$", x)
  out[plain] <- as.numeric(x[plain])
  out
}

read_event <- function(event, slug) {
  html <- paste(readLines(paste0(base, slug), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  # Doubles partners and relay team members are separated by <br>s.
  html <- gsub("<br[^>]*>", " / ", html)
  tables <- html_table(html_elements(read_html(html), "table.wikitable"), fill = TRUE)
  t <- as.data.frame(tables[[which.max(vapply(tables, nrow, integer(1)))]])
  names(t) <- make.unique(sub("\\[.*\\]$", "", names(t)))

  runs <- grep("^Run [0-9]$", names(t), value = TRUE)
  if (event == "Team relay") {
    # Legs, in order: women's singles, men's doubles, men's singles, women's doubles.
    runs <- names(t)[4:7]
    team <- strsplit(t$Country, " / ", fixed = TRUE)
    # The cell reads "Germany / Julia Taubitz / Tobias Wendl / Tobias Arlt / ...".
    t$Country <- vapply(team, `[`, character(1), 1)
    t$Athlete <- vapply(team, function(x) paste(x[-1], collapse = ", "), character(1))
  }
  athlete_col <- intersect(c("Athlete", "Athletes"), names(t))[1]
  run_times <- vapply(runs, function(r) to_seconds(t[[r]]), numeric(nrow(t)))
  if (is.null(dim(run_times))) run_times <- matrix(run_times, nrow = 1)

  data.frame(
    event = event,
    rank = ifelse(is.na(t$Rank), seq_len(nrow(t)), t$Rank),
    bib = as.integer(t$Bib),
    athlete = trimws(t[[athlete_col]]),
    country = trimws(t$Country),
    run_1 = run_times[, 1],
    run_2 = run_times[, 2],
    run_3 = if (length(runs) >= 3) run_times[, 3] else NA_real_,
    run_4 = if (length(runs) >= 4) run_times[, 4] else NA_real_,
    listed_total = to_seconds(t$Total),
    total_time = round(rowSums(run_times), 3),
    complete = rowSums(is.na(run_times)) == 0
  )
}

luge_finals <- do.call(rbind, Map(read_event, names(events), events))
luge_finals <- luge_finals[luge_finals$complete, ]
luge_finals$complete <- NULL

mismatch <- abs(luge_finals$total_time - luge_finals$listed_total) > 0.0005
if (any(mismatch)) {
  message("Listed total disagrees with the sum of runs (using the sum):")
  print(luge_finals[mismatch, c("event", "rank", "athlete", "listed_total", "total_time")])
}
luge_finals$listed_total <- NULL
luge_finals$event <- factor(luge_finals$event, levels = names(events))

# Seconds behind the event winner.
winner <- tapply(luge_finals$total_time, luge_finals$event, min)
luge_finals$behind <- round(luge_finals$total_time - as.numeric(winner[as.character(luge_finals$event)]), 3)
luge_finals <- luge_finals[order(luge_finals$event, luge_finals$rank), ]
rownames(luge_finals) <- NULL
luge_finals <- tibble::as_tibble(luge_finals)

# Sanity checks against the published results.
stopifnot(
  !anyNA(luge_finals$total_time),
  sum(mismatch) <= 1,
  all(tapply(luge_finals$rank, luge_finals$event, function(r) all(diff(r) > 0))),
  luge_finals$athlete[luge_finals$event == "Men's singles" & luge_finals$rank == 1] == "Max Langenhan",
  abs(luge_finals$total_time[luge_finals$event == "Men's singles" & luge_finals$rank == 1] - 211.191) < 1e-6,
  all(tapply(luge_finals$behind, luge_finals$event, min) == 0)
)

usethis::use_data(luge_finals, overwrite = TRUE)
