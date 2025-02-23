test_that("read_lines_chunked", {
  file <- readr_example("mtcars.csv")
  num_rows <- length(readLines(file))

  get_sizes <- function(data, pos) sizes[[length(sizes) + 1]] <<- length(data)

  # Full file in one chunk
  sizes <- list()
  read_lines_chunked(file, get_sizes)
  expect_equal(num_rows, sizes[[1]])

  # Each line separately
  sizes <- list()
  read_lines_chunked(file, get_sizes, chunk_size = 1)
  expect_true(all(sizes == 1))
  expect_equal(num_rows, length(sizes))

  # In chunks of 5
  sizes <- list()
  read_lines_chunked(file, get_sizes, chunk_size = 5)
  expect_true(all(sizes[1:6] == 5))
  expect_true(all(sizes[[7]] == 3))

  # Halting early
  get_sizes_stop <- function(data, pos) {
    sizes[[length(sizes) + 1]] <<- length(data)
    if (pos >= 5) {
      return(FALSE)
    }
  }
  sizes <- list()
  read_lines_chunked(file, get_sizes_stop, chunk_size = 5)
  expect_true(length(sizes) == 2)
  expect_true(all(sizes[1:2] == 5))
})

test_that("read_lines_raw_chunked", {
  file <- readr_example("mtcars.csv")
  num_rows <- length(readLines(file))

  get_sizes <- function(data, pos) sizes[[length(sizes) + 1]] <<- length(data)

  # Full file in one chunk
  sizes <- list()
  read_lines_raw_chunked(file, get_sizes)
  expect_equal(num_rows, sizes[[1]])

  # Each line separately
  sizes <- list()
  read_lines_raw_chunked(file, get_sizes, chunk_size = 1)
  expect_true(all(sizes == 1))
  expect_equal(num_rows, length(sizes))

  # In chunks of 5
  sizes <- list()
  read_lines_raw_chunked(file, get_sizes, chunk_size = 5)
  expect_true(all(sizes[1:6] == 5))
  expect_true(all(sizes[[7]] == 3))

  # Halting early
  get_sizes_stop <- function(data, pos) {
    sizes[[length(sizes) + 1]] <<- length(data)
    if (pos >= 5) {
      return(FALSE)
    }
  }
  sizes <- list()
  read_lines_raw_chunked(file, get_sizes_stop, chunk_size = 5)
  expect_true(length(sizes) == 2)
  expect_true(all(sizes[1:2] == 5))
})

test_that("read_delim_chunked", {
  file <- readr_example("mtcars.csv")
  unchunked <- read_csv(file)

  get_dims <- function(data, pos) dims[[length(dims) + 1]] <<- dim(data)

  # Full file in one chunk
  dims <- list()
  read_csv_chunked(file, get_dims)
  expect_equal(dim(unchunked), dims[[1]])

  # Each line separately
  dims <- list()
  read_csv_chunked(file, get_dims, chunk_size = 1)
  expect_true(all(vapply(dims[1:6], identical, logical(1), c(1L, 11L))))
  expect_equal(nrow(unchunked), length(dims))

  # In chunks of 5
  dims <- list()
  read_csv_chunked(file, get_dims, chunk_size = 5)
  expect_true(all(vapply(dims[1:6], identical, logical(1), c(5L, 11L))))
  expect_true(identical(dims[[7]], c(2L, 11L)))

  # In chunks of 5 with read_delim
  dims <- list()
  read_delim_chunked(file, delim = ",", get_dims, chunk_size = 5)
  expect_true(all(vapply(dims[1:6], identical, logical(1), c(5L, 11L))))
  expect_true(identical(dims[[7]], c(2L, 11L)))

  # Halting early
  get_dims_stop <- function(data, pos) {
    dims[[length(dims) + 1]] <<- dim(data)
    if (pos >= 5) {
      return(FALSE)
    }
  }
  dims <- list()
  read_csv_chunked(file, get_dims_stop, chunk_size = 5)
  expect_true(length(dims) == 2)
  expect_true(all(vapply(dims[1:2], identical, logical(1), c(5L, 11L))))
})

test_that("DataFrameCallback works as intended", {
  f <- readr_example("mtcars.csv")
  out0 <- subset(read_csv(f), gear == 3)
  attr(out0, "problems") <- NULL
  fun3 <- DataFrameCallback$new(function(x, pos) subset(x, gear == 3))

  out1 <- read_csv_chunked(f, fun3)

  # Need to set guess_max higher than 1 to guess correct column types
  out2 <- read_csv_chunked(f, fun3, chunk_size = 1, guess_max = 10)

  out3 <- read_csv_chunked(f, fun3, chunk_size = 10)

  expect_true(all.equal(out0, out1))
  expect_true(all.equal(out0, out2))
  expect_true(all.equal(out0, out3))


  # No matching rows
  out0 <- subset(read_csv(f), gear == 5)
  attr(out0, "problems") <- NULL

  fun5 <- DataFrameCallback$new(function(x, pos) subset(x, gear == 5))

  out1 <- read_csv_chunked(f, fun5)

  # Need to set guess_max higher than 1 to guess correct column types
  out2 <- read_csv_chunked(f, fun5, chunk_size = 1, guess_max = 10)

  out3 <- read_csv_chunked(f, fun5, chunk_size = 10)

  expect_true(all.equal(out0, out1))
  expect_true(all.equal(out0, out2))
  expect_true(all.equal(out0, out3))
})

test_that("ListCallback works as intended", {
  f <- readr_example("mtcars.csv")
  out0 <- read_csv(f)

  fun <- ListCallback$new(function(x, pos) x[["mpg"]])
  out1 <- read_csv_chunked(f, fun, chunk_size = 10)

  expect_equal(out0[["mpg"]], unlist(out1))
})


test_that("AccumulateCallback works as intended", {
  f <- readr_example("mtcars.csv")
  out0 <- read_csv(f)

  min_chunks <- function(x, pos, acc) {
    f <- function(x) {
      x[order(x$wt), ][1, ]
    }
    if (is.null(acc)) {
      acc <- data.frame()
    }
    f(rbind(x, acc))
  }

  fun1 <- AccumulateCallback$new(min_chunks)
  out1 <- read_csv_chunked(f, fun1, chunk_size = 10)
  expect_equal(min_chunks(out0, acc = NULL), out1)

  sum_chunks <- function(x, pos, acc) {
    sum(x$wt) + acc
  }

  fun2 <- AccumulateCallback$new(sum_chunks, acc = 0)
  out2 <- read_csv_chunked(f, fun2, chunk_size = 10)
  expect_equal(sum_chunks(out0, acc = 0), out2)

  expect_error(
    AccumulateCallback$new(function(x, i) x),
    "`callback` must have three or more arguments"
  )
})

test_that("Chunks include their spec (#1143)", {
  res <- read_csv_chunked(readr_example("mtcars.csv"),
      callback = ListCallback$new(function(x, pos) spec(x)),
      chunk_size = 20)

  expect_equal(res[[1]]$cols, spec_csv(readr_example("mtcars.csv"))$cols)
})
