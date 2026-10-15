if (!requireNamespace("DBI", quietly = TRUE)) {
  stop("DBI é obrigatório para a persistência do DataPulse.")
}
if (!requireNamespace("RSQLite", quietly = TRUE)) {
  stop("RSQLite é obrigatório para a persistência do DataPulse.")
}

resolve_project_root <- function() {
  candidates <- c(
    getwd(),
    normalizePath(getwd()),
    if (!is.null(sys.frames()[[1]]$ofile)) dirname(normalizePath(sys.frames()[[1]]$ofile)) else getwd(),
    dirname(getwd()),
    dirname(dirname(getwd())),
    dirname(dirname(dirname(getwd())))
  )

  for (candidate in unique(candidates)) {
    if (dir.exists(file.path(candidate, "app"))) {
      return(candidate)
    }
  }

  fallback <- "/home/joao/Documentos/projetos em R.worktrees/csv-import-validation-persistence"
  if (dir.exists(file.path(fallback, "app"))) {
    return(fallback)
  }

  stop("Não foi possível localizar a raiz do projeto DataPulse.")
}

resolve_db_path <- function(db_path = NULL) {
  candidate <- db_path
  if (is.null(candidate)) {
    candidate <- Sys.getenv("DATAPULSE_DB_PATH", unset = "")
  }

  if (is.null(candidate) || is.na(candidate) || !nzchar(trimws(as.character(candidate)))) {
    if (!is.null(db_path)) {
      stop("Caminho do SQLite inválido: o valor informado está vazio.")
    }
    root_dir <- resolve_project_root()
    db_file <- file.path(root_dir, "app", "data", "sqlite", "datapulse.db")
    candidate <- db_file
  }

  resolved <- trimws(as.character(candidate))
  if (!nzchar(resolved)) {
    stop("Caminho do SQLite inválido: o valor informado está vazio.")
  }

  parent_dir <- dirname(resolved)
  if (!nzchar(parent_dir)) {
    stop(sprintf("Caminho do SQLite inválido: '%s' não possui um diretório pai válido.", resolved))
  }

  if (!dir.exists(parent_dir)) {
    created <- dir.create(parent_dir, recursive = TRUE, showWarnings = FALSE)
    if (!isTRUE(created)) {
      stop(sprintf("Não foi possível criar o diretório do banco de dados: '%s'", parent_dir))
    }
  }

  if (!file.info(parent_dir)$isdir) {
    stop(sprintf("Caminho do SQLite inválido: o diretório pai '%s' aponta para um arquivo.", parent_dir))
  }

  if (isTRUE(file.exists(resolved) && file.info(resolved)$isdir)) {
    stop(sprintf("Caminho do SQLite inválido: '%s' aponta para um diretório, não para um arquivo de banco.", resolved))
  }

  normalizePath(resolved, winslash = "/", mustWork = FALSE)
}

get_default_db_path <- function() {
  resolve_db_path()
}

get_database_connection <- function(db_path = NULL) {
  resolved_path <- resolve_db_path(db_path)
  DBI::dbConnect(RSQLite::SQLite(), dbname = resolved_path)
}

normalize_transaction_input <- function(transaction, current = NULL, allow_partial = FALSE) {
  if (is.null(transaction) || (!is.list(transaction) && !is.data.frame(transaction))) {
    stop("Transação inválida: era esperado um objeto com data, descrição, categoria, tipo e valor.")
  }

  if (is.data.frame(transaction)) {
    if (nrow(transaction) != 1L) {
      stop("A transação em lote deve conter exatamente uma linha.")
    }
    transaction <- as.list(transaction[1, , drop = FALSE])
  }

  required_fields <- c("date", "description", "category", "type", "amount")
  if (allow_partial && !is.null(current)) {
    for (field_name in required_fields) {
      if (is.null(transaction[[field_name]]) && !is.null(current[[field_name]])) {
        transaction[[field_name]] <- current[[field_name]]
      }
    }
  }

  missing_fields <- setdiff(required_fields, names(transaction))
  if (length(missing_fields) > 0L) {
    stop(sprintf("Transação incompleta. Faltam os campos: %s", paste(missing_fields, collapse = ", ")))
  }

  date_value <- trimws(as.character(transaction$date))
  description_value <- trimws(as.character(transaction$description))
  category_value <- trimws(as.character(transaction$category))
  type_value <- tolower(trimws(as.character(transaction$type)))
  amount_value <- suppressWarnings(as.numeric(transaction$amount))

  if (is.na(as.Date(date_value, format = "%Y-%m-%d"))) {
    stop("Data inválida. Use o formato YYYY-MM-DD.")
  }

  if (!nzchar(description_value)) {
    stop("Descrição é obrigatória.")
  }

  if (!nzchar(category_value)) {
    stop("Categoria é obrigatória.")
  }

  if (!(type_value %in% c("income", "expense"))) {
    stop("Tipo inválido. Use 'income' ou 'expense'.")
  }

  if (is.na(amount_value) || !is.finite(amount_value) || amount_value <= 0) {
    stop("Valor inválido. O valor deve ser maior que zero.")
  }

  list(
    date = format(as.Date(date_value, format = "%Y-%m-%d"), "%Y-%m-%d"),
    description = description_value,
    category = category_value,
    type = type_value,
    amount = amount_value
  )
}

init_database <- function(db_path = get_default_db_path()) {
  resolved_path <- resolve_db_path(db_path)
  con <- get_database_connection(resolved_path)
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

  invisible(resolved_path)
}

initialize_database <- init_database

list_transactions <- function(db_path = get_default_db_path()) {
  init_database(db_path)
  con <- get_database_connection(db_path)
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

fetch_transactions <- list_transactions

get_transaction_by_id <- function(db_path = get_default_db_path(), transaction_id) {
  init_database(db_path)
  con <- get_database_connection(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  result <- DBI::dbGetQuery(
    con,
    "SELECT id, date, description, category, type, amount, created_at FROM transactions WHERE id = ?",
    params = list(as.integer(transaction_id))
  )

  if (nrow(result) == 0L) {
    return(NULL)
  }

  result$amount <- as.numeric(result$amount)
  result[1, , drop = FALSE]
}

list_transactions_filtered <- function(db_path = get_default_db_path(), start_date = NULL, end_date = NULL, category = NULL, type = NULL) {
  init_database(db_path)
  con <- get_database_connection(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  query <- "SELECT id, date, description, category, type, amount, created_at FROM transactions WHERE 1 = 1"
  params <- list()

  if (!is.null(start_date) && nzchar(as.character(start_date))) {
    query <- paste(query, " AND date >= ?")
    params[[length(params) + 1L]] <- as.character(start_date)
  }

  if (!is.null(end_date) && nzchar(as.character(end_date))) {
    query <- paste(query, " AND date <= ?")
    params[[length(params) + 1L]] <- as.character(end_date)
  }

  if (!is.null(category) && nzchar(as.character(category))) {
    query <- paste(query, " AND category = ?")
    params[[length(params) + 1L]] <- as.character(category)
  }

  if (!is.null(type) && nzchar(as.character(type))) {
    query <- paste(query, " AND type = ?")
    params[[length(params) + 1L]] <- tolower(as.character(type))
  }

  query <- paste(query, " ORDER BY date ASC, id ASC")
  result <- if (length(params) == 0L) DBI::dbGetQuery(con, query) else DBI::dbGetQuery(con, query, params = params)

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

insert_transaction <- function(db_path = get_default_db_path(), transaction) {
  init_database(db_path)
  payload <- normalize_transaction_input(transaction)
  con <- get_database_connection(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbExecute(
    con,
    "INSERT INTO transactions (date, description, category, type, amount) VALUES (?, ?, ?, ?, ?)",
    params = list(
      payload$date,
      payload$description,
      payload$category,
      payload$type,
      as.numeric(payload$amount)
    )
  )

  inserted_id <- as.integer(DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id)
  get_transaction_by_id(db_path, inserted_id)
}

update_transaction <- function(db_path = get_default_db_path(), transaction_id, transaction) {
  init_database(db_path)
  current <- get_transaction_by_id(db_path, transaction_id)
  if (is.null(current)) {
    stop("Transação não encontrada.")
  }

  payload <- normalize_transaction_input(transaction, current = current, allow_partial = TRUE)
  con <- get_database_connection(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbExecute(
    con,
    "UPDATE transactions SET date = ?, description = ?, category = ?, type = ?, amount = ? WHERE id = ?",
    params = list(
      payload$date,
      payload$description,
      payload$category,
      payload$type,
      as.numeric(payload$amount),
      as.integer(transaction_id)
    )
  )

  get_transaction_by_id(db_path, transaction_id)
}

delete_transaction <- function(db_path = get_default_db_path(), transaction_id) {
  init_database(db_path)
  con <- get_database_connection(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  affected <- DBI::dbExecute(con, "DELETE FROM transactions WHERE id = ?", params = list(as.integer(transaction_id)))
  isTRUE(affected > 0L)
}

transaction_to_api_payload <- function(row) {
  if (is.null(row) || nrow(row) == 0L) {
    return(NULL)
  }

  payload <- row[1, , drop = FALSE]
  list(
    id = as.integer(payload$id),
    date = as.character(payload$date),
    description = as.character(payload$description),
    category = as.character(payload$category),
    type = as.character(payload$type),
    amount = as.numeric(payload$amount),
    created_at = as.character(payload$created_at),
    updated_at = as.character(payload$created_at)
  )
}

fetch_transaction_fingerprints <- function(db_path = get_default_db_path()) {
  tx <- fetch_transactions(db_path)
  if (nrow(tx) == 0L) {
    return(character(0))
  }

  paste(
    as.character(tx$date),
    tolower(trimws(tx$description)),
    tolower(trimws(tx$category)),
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
  con <- get_database_connection(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbBegin(con)
  tryCatch({
    for (row_index in seq_len(nrow(rows))) {
      row <- rows[row_index, , drop = FALSE]
      DBI::dbExecute(
        con,
        "INSERT INTO transactions (date, description, category, type, amount) VALUES (?, ?, ?, ?, ?)",
        params = list(
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
  }

  monthly_summary <- stats::aggregate(
    amount ~ format(as.Date(date), "%Y-%m") + type,
    data = tx,
    FUN = sum
  )

  summary_list <- lapply(split(monthly_summary, paste(monthly_summary[, 1], monthly_summary[, 2], sep = "::")), function(item) {
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
