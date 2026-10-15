repo_root <- if (dir.exists(file.path(getwd(), "app"))) getwd() else "/home/joao/Documentos/projetos em R.worktrees/csv-import-validation-persistence"
source(file.path(repo_root, "app", "backend", "services", "data_access.R"))
source(file.path(repo_root, "app", "backend", "services", "finance_analysis.R"))
source(file.path(repo_root, "app", "backend", "services", "csv_import.R"))

new_test_db <- function() tempfile(fileext = ".db")

test_valid_csv_import <- function() {
  db_path <- new_test_db()
  csv_path <- tempfile(fileext = ".csv")
  writeLines(c(
    "date,description,category,type,amount",
    "2026-01-02,Salário,Renda,income,2500.00",
    "2026-01-03,Transporte,Transporte,expense,150.00"
  ), con = csv_path, useBytes = TRUE)

  preview <- preview_csv_import(csv_path, db_path)
  stopifnot(identical(preview$status, "preview_ok"))
  stopifnot(preview$valid_count == 2L)
  stopifnot(preview$invalid_count == 0L)
  stopifnot(isTRUE(nrow(fetch_transactions(db_path)) == 0L))

  imported <- confirm_csv_import(csv_path, include_duplicates = FALSE, db_path = db_path)
  stopifnot(identical(imported$status, "success"))
  stopifnot(imported$imported_count == 2L)
  stopifnot(isTRUE(nrow(fetch_transactions(db_path)) == 2L))
}

test_empty_and_missing_columns <- function() {
  db_path <- new_test_db()
  empty_csv <- tempfile(fileext = ".csv")
  writeLines("", con = empty_csv, useBytes = TRUE)

  error_empty <- tryCatch({
    read_csv_import_file(empty_csv)
    FALSE
  }, error = function(e) TRUE)
  stopifnot(isTRUE(error_empty))

  missing_csv <- tempfile(fileext = ".csv")
  writeLines(c(
    "date,description,category,type,amount",
    "2026-01-02,Salário,Renda,income,2500.00"
  ), con = missing_csv, useBytes = TRUE)

  missing_csv <- tempfile(fileext = ".csv")
  writeLines(c(
    "date,description,category,type",
    "2026-01-02,Salário,Renda,income"
  ), con = missing_csv, useBytes = TRUE)

  error_missing <- tryCatch({
    preview_csv_import(missing_csv, db_path)
    FALSE
  }, error = function(e) TRUE)
  stopifnot(isTRUE(error_missing))
}

test_invalid_rows_and_error_messages <- function() {
  db_path <- new_test_db()
  csv_path <- tempfile(fileext = ".csv")
  writeLines(c(
    "date,description,category,type,amount",
    "2026-01-02,Salário,Renda,income,2500.00",
    "31/02/2026,Compra,Alimentação,expense,50",
    "2026-01-03,Conta,Transporte,invalid,40",
    "2026-01-04,Zero,Transporte,expense,0",
    "2026-01-05,Negativo,Transporte,expense,-10",
    "2026-01-06,Texto,Transporte,expense,abc"
  ), con = csv_path, useBytes = TRUE)

  preview <- preview_csv_import(csv_path, db_path)
  stopifnot(preview$invalid_count == 5L)
  error_messages <- paste(unlist(lapply(preview$invalid_rows, function(item) item$message)), collapse = " ")
  stopifnot(grepl("Data inválida", error_messages, fixed = TRUE))
  stopifnot(grepl("Tipo de transação inválido", error_messages, fixed = TRUE))
  stopifnot(grepl("Valor inválido", error_messages, fixed = TRUE))
}

test_semicolon_bom_and_portuguese_headers <- function() {
  db_path <- new_test_db()
  csv_path <- tempfile(fileext = ".csv")
  content <- paste0(
    "\ufeffdate;descricao;categoria;tipo;valor\n",
    "02/01/2026;Salário;Renda;income;2500,00\n",
    "03/01/2026;Transporte;Transporte;expense;150,00\n"
  )
  writeBin(charToRaw(enc2utf8(content)), con = csv_path)

  preview <- preview_csv_import(csv_path, db_path)
  stopifnot(preview$valid_count == 2L)
  stopifnot(identical(preview$normalized_sample[[1]]$date, "2026-01-02"))
  stopifnot(identical(preview$normalized_sample[[2]]$amount, 150))
}

test_duplicate_rows_and_existing_records <- function() {
  db_path <- new_test_db()
  duplicate_csv <- tempfile(fileext = ".csv")
  writeLines(c(
    "date,description,category,type,amount",
    "2026-02-02,Salário,Renda,income,3000.00",
    "2026-02-02,Salário,Renda,income,3000.00"
  ), con = duplicate_csv, useBytes = TRUE)

  preview <- preview_csv_import(duplicate_csv, db_path)
  stopifnot(preview$duplicate_count == 1L)

  valid_csv <- tempfile(fileext = ".csv")
  writeLines(c(
    "date,description,category,type,amount",
    "2026-03-05,Reembolso,Financeiro,income,200.00"
  ), con = valid_csv, useBytes = TRUE)
  confirm_csv_import(valid_csv, include_duplicates = FALSE, db_path = db_path)

  same_csv <- tempfile(fileext = ".csv")
  writeLines(c(
    "date,description,category,type,amount",
    "2026-03-05,Reembolso,Financeiro,income,200.00"
  ), con = same_csv, useBytes = TRUE)

  current_same <- preview_csv_import(same_csv, db_path)
  stopifnot(current_same$duplicate_count == 1L)
}

test_preview_does_not_persist_and_confirmation_counts <- function() {
  db_path <- new_test_db()
  initial_count <- nrow(fetch_transactions(db_path))

  csv_path <- tempfile(fileext = ".csv")
  writeLines(c(
    "date,description,category,type,amount",
    "2026-10-01,Pagamento,Contas,expense,100.00",
    "2026-10-02,Receita,Salário,income,500.00"
  ), con = csv_path, useBytes = TRUE)

  preview <- preview_csv_import(csv_path, db_path)
  stopifnot(preview$valid_count == 2L)
  stopifnot(nrow(fetch_transactions(db_path)) == initial_count)

  imported <- confirm_csv_import(csv_path, include_duplicates = FALSE, db_path = db_path)
  stopifnot(imported$imported_count == 2L)
  stopifnot(nrow(fetch_transactions(db_path)) == initial_count + 2L)
}

test_rollback_and_preserve_existing_rows <- function() {
  db_path <- new_test_db()
  before_count <- nrow(fetch_transactions(db_path))

  invalid_rows <- data.frame(
    date = c("2026-11-01", "2026-11-02"),
    description = c("OK", "Bad row"),
    category = c("Renda", "X"),
    type = c("income", "invalid"),
    amount = c(100, 200),
    stringsAsFactors = FALSE
  )

  error_raised <- tryCatch({
    insert_transaction_rows(invalid_rows, db_path)
    FALSE
  }, error = function(e) TRUE)
  stopifnot(isTRUE(error_raised))
  stopifnot(nrow(fetch_transactions(db_path)) == before_count)

  valid_rows <- data.frame(
    date = c("2026-12-01"),
    description = c("Persistência"),
    category = c("Categoria"),
    type = c("expense"),
    amount = c(99.99),
    stringsAsFactors = FALSE
  )

  inserted <- insert_transaction_rows(valid_rows, db_path)
  stopifnot(inserted == 1L)
  stopifnot(nrow(fetch_transactions(db_path)) == before_count + 1L)
}

test_dashboard_after_import <- function() {
  db_path <- new_test_db()
  summary_before <- get_dashboard_summary(db_path)
  csv_path <- tempfile(fileext = ".csv")
  writeLines(c(
    "date,description,category,type,amount",
    "2026-07-01,Receita extra,Salário,income,500.00",
    "2026-07-02,Aluguel,Residencial,expense,200.00"
  ), con = csv_path, useBytes = TRUE)

  confirm_csv_import(csv_path, include_duplicates = FALSE, db_path = db_path)
  summary_after <- get_dashboard_summary(db_path)
  stopifnot(summary_after$transaction_count >= 1L)
  stopifnot(summary_after$total_income >= 500)
  stopifnot(summary_after$total_expense >= 200)
  stopifnot(summary_after$net_balance == summary_after$total_income - summary_after$total_expense)
  stopifnot(summary_before$transaction_count <= summary_after$transaction_count)
}

tryCatch({
  test_valid_csv_import()
  test_empty_and_missing_columns()
  test_invalid_rows_and_error_messages()
  test_semicolon_bom_and_portuguese_headers()
  test_duplicate_rows_and_existing_records()
  test_preview_does_not_persist_and_confirmation_counts()
  test_rollback_and_preserve_existing_rows()
  test_dashboard_after_import()
  print("Todos os testes de importação e regressão passaram.")
}, error = function(e) {
  message("Falha em teste de importação: ", e$message)
  quit(status = 1)
})
