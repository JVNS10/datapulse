resolve_db_path <- function(path = NULL) {
  if (!is.null(path) && nzchar(path)) {
    return(path)
  }

  env_path <- Sys.getenv("DATAPULSE_DB_PATH", unset = "")
  if (nzchar(env_path)) {
    return(env_path)
  }

  root <- if (dir.exists(file.path(getwd(), "app"))) getwd() else {
    candidate <- "/home/joao/Documentos/projetos em R.worktrees/csv-import-validation-persistence"
    if (dir.exists(file.path(candidate, "app"))) candidate else stop("Não foi possível localizar a raiz do projeto DataPulse.")
  }

  db_dir <- file.path(root, "app", "data", "sqlite")
  dir.create(db_dir, recursive = TRUE, showWarnings = FALSE)
  file.path(db_dir, "datapulse.db")
}

get_repo_root <- function() {
  if (dir.exists(file.path(getwd(), "app"))) {
    return(getwd())
  }

  candidate <- "/home/joao/Documentos/projetos em R.worktrees/csv-import-validation-persistence"
  if (dir.exists(file.path(candidate, "app"))) {
    return(candidate)
  }

  stop("Não foi possível localizar a raiz do projeto DataPulse.")
}

get_default_db_path <- function() {
  resolve_db_path()
}

initialize_database <- function(db_path = get_default_db_path()) {
  dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbExecute(
    con,
    "CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
      amount REAL NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )"
  )

  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)")

  invisible(db_path)
}

fetch_transactions <- function(db_path = get_default_db_path()) {
  initialize_database(db_path)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  result <- DBI::dbGetQuery(
    con,
    "SELECT id, date, description, category, type, amount, created_at FROM transactions ORDER BY date ASC, id ASC"
  )

  if (nrow(result) == 0L) {
    return(data.frame(
      id = integer(0),
      date = character(0),
      description = character(0),
      category = character(0),
      type = character(0),
      amount = numeric(0),
      created_at = character(0),
      stringsAsFactors = FALSE
    ))
  }

  result$amount <- as.numeric(result$amount)
  result
}

fetch_transaction_fingerprints <- function(db_path = get_default_db_path()) {
  tx <- fetch_transactions(db_path)
  if (nrow(tx) == 0L) {
    return(character(0))
  }

  lower_desc <- tolower(trimws(tx$description))
  lower_category <- tolower(trimws(tx$category))
  paste(
    as.character(tx$date),
    lower_desc,
    lower_category,
    tolower(trimws(tx$type)),
    sprintf("%.2f", as.numeric(tx$amount)),
    sep = "::"
  )
}

insert_transaction_rows <- function(rows, db_path = get_default_db_path()) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(0L)
  }

  initialize_database(db_path)
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbBegin(con)
  tryCatch({
    for (row_index in seq_len(nrow(rows))) {
      row <- rows[row_index, , drop = FALSE]
      DBI::dbExecute(
        con,
        "INSERT INTO transactions (date, description, category, type, amount) VALUES (?, ?, ?, ?, ?)",
        params = c(
          as.character(row$date),
          as.character(row$description),
          as.character(row$category),
          as.character(row$type),
          as.numeric(row$amount)
        )
      )
    }
    DBI::dbCommit(con)
  }, error = function(e) {
    DBI::dbRollback(con)
    stop(sprintf("Falha na gravação em SQLite: %s", e$message))
  })

  nrow(rows)
}

get_dashboard_summary <- function(db_path = get_default_db_path()) {
  tx <- fetch_transactions(db_path)

  if (nrow(tx) == 0L) {
    return(list(
      total_income = 0,
      total_expense = 0,
      net_balance = 0,
      transaction_count = 0,
      most_expensive_category = NULL,
      monthly_summary = list(),
      expenses_by_category = list()
    ))
  }

  tx$amount <- as.numeric(tx$amount)
  tx$type <- tolower(trimws(tx$type))

  total_income <- sum(tx$amount[tx$type == "income"], na.rm = TRUE)
  total_expense <- sum(tx$amount[tx$type == "expense"], na.rm = TRUE)
  net_balance <- total_income - total_expense

  expense_summary <- stats::aggregate(amount ~ category, data = subset(tx, type == "expense"), FUN = sum)
  if (nrow(expense_summary) > 0L) {
    expense_summary <- expense_summary[order(expense_summary$amount, decreasing = TRUE), ]
    names(expense_summary$amount) <- expense_summary$category
  }

  monthly_summary <- stats::aggregate(
    amount ~ format(as.Date(date), "%Y-%m") + type,
    data = tx,
    FUN = sum
  )
  row_names <- paste(monthly_summary[, 1], monthly_summary[, 2], sep = "::")
  month_map <- split(monthly_summary, row_names)
  summary_list <- lapply(month_map, function(item) {
    list(
      month = item[[1]],
      type = item[[2]],
      amount = as.numeric(item[[3]])
    )
  })

  list(
    total_income = round(total_income, 2),
    total_expense = round(total_expense, 2),
    net_balance = round(net_balance, 2),
    transaction_count = nrow(tx),
    most_expensive_category = if (nrow(expense_summary) > 0L) {
      list(category = expense_summary$category[1], amount = round(expense_summary$amount[1], 2))
    } else {
      NULL
    },
    monthly_summary = summary_list,
    expenses_by_category = if (nrow(expense_summary) > 0L) {
      stats::setNames(as.numeric(expense_summary$amount), expense_summary$category)
    } else {
      list()
    }
  )
}
