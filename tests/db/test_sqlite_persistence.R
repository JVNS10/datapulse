if (!requireNamespace("DBI", quietly = TRUE)) {
  stop("DBI não está instalado.")
}
if (!requireNamespace("RSQLite", quietly = TRUE)) {
  stop("RSQLite não está instalado.")
}

repo_root <- getwd()
source(file.path(repo_root, "app", "backend", "services", "finance_analysis.R"))
source(file.path(repo_root, "app", "backend", "services", "data_access.R"))

start_db <- function() {
  path <- tempfile(fileext = ".sqlite")
  Sys.setenv(DATAPULSE_DB_PATH = path)
  init_database(path)
  path
}

db_path <- start_db()

valid_dir <- tempfile(pattern = "datapulse_valid_")
if (!dir.exists(valid_dir)) dir.create(valid_dir, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(valid_dir, recursive = TRUE, force = TRUE), add = TRUE)
valid_db_path <- file.path(valid_dir, "nested", "datapulse.sqlite")
resolved_valid_db_path <- resolve_db_path(valid_db_path)
stopifnot(grepl("datapulse.sqlite$", resolved_valid_db_path))

empty_path_error <- tryCatch({
  resolve_db_path("")
  FALSE
}, error = function(e) TRUE)
stopifnot(empty_path_error)

directory_path_error <- tryCatch({
  resolve_db_path(valid_dir)
  FALSE
}, error = function(e) TRUE)
stopifnot(directory_path_error)

initial_rows <- list_transactions(db_path)
stopifnot(is.data.frame(initial_rows))
stopifnot(nrow(initial_rows) == 0L)

created <- insert_transaction(db_path, list(
  date = "2026-01-05",
  description = "Salário",
  category = "Renda",
  type = "income",
  amount = 2500
))
stopifnot(is.numeric(created$id))
stopifnot(created$id > 0)

rows <- list_transactions(db_path)
stopifnot(nrow(rows) == 1L)
stopifnot(rows$description[1] == "Salário")

by_id <- get_transaction_by_id(db_path, created$id)
stopifnot(identical(by_id$description, "Salário"))

updated <- update_transaction(db_path, created$id, list(
  description = "Salário ajustado",
  amount = 2700,
  category = "Renda",
  type = "income"
))
stopifnot(updated$description == "Salário ajustado")
stopifnot(updated$amount == 2700)

filtered <- list_transactions_filtered(db_path, start_date = "2026-01-01", end_date = "2026-01-31", type = "income")
stopifnot(nrow(filtered) == 1L)

by_category <- list_transactions_filtered(db_path, category = "Renda")
stopifnot(nrow(by_category) == 1L)

insert_transaction(db_path, list(
  date = "2026-01-10",
  description = "Mercado",
  category = "Alimentação",
  type = "expense",
  amount = 180
))

all_rows <- list_transactions(db_path)
stopifnot(nrow(all_rows) == 2L)

deleted <- delete_transaction(db_path, created$id)
stopifnot(isTRUE(deleted))
stopifnot(nrow(list_transactions(db_path)) == 1L)

reopened <- get_database_connection(db_path)
DBI::dbDisconnect(reopened)
stopifnot(nrow(list_transactions(db_path)) == 1L)

invalid <- tryCatch({
  insert_transaction(db_path, list(
    date = "2026-02-30",
    description = "Erro",
    category = "Teste",
    type = "expense",
    amount = 10
  ))
  FALSE
}, error = function(e) TRUE)
stopifnot(invalid)

print("Todos os testes de persistência com SQLite passaram.")
