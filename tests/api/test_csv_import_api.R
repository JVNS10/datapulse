if (!requireNamespace("httr", quietly = TRUE)) {
  install.packages("httr", repos = "https://cloud.r-project.org", INSTALL_opts = c("--no-lock"))
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  install.packages("jsonlite", repos = "https://cloud.r-project.org", INSTALL_opts = c("--no-lock"))
}
if (!requireNamespace("callr", quietly = TRUE)) {
  install.packages("callr", repos = "https://cloud.r-project.org", INSTALL_opts = c("--no-lock"))
}
if (!requireNamespace("DBI", quietly = TRUE)) {
  install.packages("DBI", repos = "https://cloud.r-project.org", INSTALL_opts = c("--no-lock"))
}
if (!requireNamespace("RSQLite", quietly = TRUE)) {
  install.packages("RSQLite", repos = "https://cloud.r-project.org", INSTALL_opts = c("--no-lock"))
}

repo_root <- getwd()
source(file.path(repo_root, "app", "backend", "services", "finance_analysis.R"))
source(file.path(repo_root, "app", "backend", "services", "data_access.R"))

port <- 8001L
api_file <- file.path(repo_root, "app", "backend", "api", "plumber.R")
Sys.setenv(DATAPULSE_DB_PATH = tempfile(fileext = ".sqlite"))

server <- callr::r_bg(
  function(api_file, port_value) {
    Sys.setenv(DATAPULSE_DB_PATH = Sys.getenv("DATAPULSE_DB_PATH"))
    source(api_file)
    pr <- plumber::plumb(api_file)
    pr[['run']](port = as.integer(port_value), host = '127.0.0.1', swagger = FALSE)
  },
  args = list(api_file, as.character(port))
)

on.exit({
  if (inherits(server, "r_process") && server$is_alive()) {
    server$kill()
  }
}, add = TRUE)

wait_for_http <- function(url, max_attempts = 30L, delay_seconds = 0.5) {
  for (attempt in seq_len(max_attempts)) {
    response <- tryCatch({
      httr::GET(url, httr::timeout(2))
    }, error = function(e) NULL)

    if (!is.null(response) && response$status_code %in% c(200L, 400L)) {
      return(response)
    }

    Sys.sleep(delay_seconds)
  }

  stop(sprintf("Servidor não respondeu em %s", url))
}

wait_for_http(sprintf("http://127.0.0.1:%s/health", port))

csv_path <- file.path(repo_root, "app", "data", "raw", "import_valid.csv")
writeLines(
  c(
    "date;description;category;type;amount",
    "2026-01-02;Salário;Renda;income;2500.00",
    "2026-01-03;Transporte;Transporte;expense;150.00"
  ),
  con = csv_path,
  useBytes = TRUE,
  sep = "\n"
)

preview_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/import/csv", port),
  body = list(file = httr::upload_file(csv_path), dry_run = "true"),
  encode = "multipart"
)
stopifnot(preview_response$status_code == 200)
preview_body <- jsonlite::fromJSON(httr::content(preview_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(identical(preview_body$status, "success"))
stopifnot(preview_body$data$valid_count == 2)
stopifnot(preview_body$data$invalid_count == 0)
stopifnot(preview_body$data$duplicate_count == 0)

confirm_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/import/csv", port),
  body = list(file = httr::upload_file(csv_path), dry_run = "false"),
  encode = "multipart"
)
stopifnot(confirm_response$status_code == 200)
confirm_body <- jsonlite::fromJSON(httr::content(confirm_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(confirm_body$data$imported_count == 2)
stopifnot(confirm_body$data$skipped_duplicates == 0)
stopifnot(nrow(list_transactions(Sys.getenv("DATAPULSE_DB_PATH"))) == 2L)

invalid_csv_path <- file.path(repo_root, "app", "data", "raw", "import_invalid.csv")
writeLines(
  c(
    "date;description;category;type;amount",
    "2026-02-30;Pagamento;Teste;expense;50",
    "2026-02-05;Supermercado;Alimentação;expense;-10",
    "2026-02-06;Luz;Moradia;transfer;100"
  ),
  con = invalid_csv_path,
  useBytes = TRUE,
  sep = "\n"
)

invalid_preview <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/import/csv", port),
  body = list(file = httr::upload_file(invalid_csv_path), dry_run = "true"),
  encode = "multipart"
)
stopifnot(invalid_preview$status_code == 400)
invalid_body <- jsonlite::fromJSON(httr::content(invalid_preview, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(identical(invalid_body$status, "error"))
stopifnot(length(invalid_body$errors) >= 1)

print("Todos os testes de importação CSV passaram.")
