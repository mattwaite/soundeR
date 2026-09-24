test_that("luge_finals has every event, ordered by place", {
  expect_equal(nrow(luge_finals), 77)
  expect_equal(levels(luge_finals$event),
               c("Men's singles", "Women's singles", "Men's doubles", "Women's doubles", "Team relay"))
  for (e in levels(luge_finals$event)) {
    d <- luge_finals[luge_finals$event == e, ]
    expect_equal(d$behind[1], 0)
    expect_true(all(diff(d$total_time) >= 0))
    expect_equal(d$rank, seq_len(nrow(d)))
  }
  runs <- rowSums(luge_finals[c("run_1", "run_2", "run_3", "run_4")], na.rm = TRUE)
  expect_equal(luge_finals$total_time, round(runs, 3))
})

test_that("husker_games is the 28-7 season", {
  expect_equal(nrow(husker_games), 35)
  expect_equal(sum(husker_games$result == "W"), 28)
  expect_equal(husker_games$point_margin, husker_games$husker_score - husker_games$opponent_score)
  expect_true(all(diff(husker_games$date) >= 0))
})

test_that("the flagship examples run on the real data", {
  s <- sonify_data(luge_finals, time = behind, time_scale = 1, sequence = event, instrument = "sine")
  expect_equal(nrow(notes(s)), 77)
  h <- sonify_data(husker_games, point_margin, instrument = "bell", bpm = 180)
  expect_equal(notes(h)$note[which.max(husker_games$point_margin)], "C6")
})

test_that("ne_house_years matches the source file", {
  expect_equal(nrow(ne_house_years), 182)
  expect_equal(sum(ne_house_years$houses), 515985)
  expect_equal(range(ne_house_years$year_built), c(1800L, 2026L))
  expect_false(anyDuplicated(ne_house_years$year_built) > 0)
})
