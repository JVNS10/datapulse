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

Sys.setenv(DATAPULSE_DB_PATH = tempfile(fileext = ".sqlite"))
api_file <- file.path(repo_root, "app", "backend", "api", "plumber.R")
port <- 8001L

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

health_response <- httr::GET(sprintf("http://127.0.0.1:%s/health", port))
stopifnot(health_response$status_code == 200)
health_body <- jsonlite::fromJSON(httr::content(health_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(identical(health_body$status, "success"))
stopifnot(identical(health_body$data$status, "ok"))

create_payload <- list(
  date = "2026-01-02",
  description = "Salário",
  category = "Renda",
  type = "income",
  amount = 2500
)
create_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/transactions", port),
  body = jsonlite::toJSON(create_payload, auto_unbox = TRUE),
  encode = "raw",
  httr::content_type_json()
)
stopifnot(create_response$status_code == 200)
create_body <- jsonlite::fromJSON(httr::content(create_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(identical(create_body$status, "success"))
stopifnot(!is.null(create_body$data$id))

list_response <- httr::GET(sprintf("http://127.0.0.1:%s/api/transactions", port))
stopifnot(list_response$status_code == 200)
list_body <- jsonlite::fromJSON(httr::content(list_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(list_body$data$count >= 1)

transaction_id <- as.integer(create_body$data$id)
get_response <- httr::GET(sprintf("http://127.0.0.1:%s/api/transactions/%s", port, transaction_id))
stopifnot(get_response$status_code == 200)
get_body <- jsonlite::fromJSON(httr::content(get_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(identical(get_body$data$description, "Salário"))

update_payload <- list(
  date = "2026-01-02",
  description = "Salário ajustado",
  category = "Renda",
  type = "income",
  amount = 2700
)
update_response <- httr::PUT(
  sprintf("http://127.0.0.1:%s/api/transactions/%s", port, transaction_id),
  body = jsonlite::toJSON(update_payload, auto_unbox = TRUE),
  encode = "raw",
  httr::content_type_json()
)
stopifnot(update_response$status_code == 200)
updated_body <- jsonlite::fromJSON(httr::content(update_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(identical(updated_body$data$description, "Salário ajustado"))
stopifnot(updated_body$data$amount == 2700)

delete_response <- httr::DELETE(sprintf("http://127.0.0.1:%s/api/transactions/%s", port, transaction_id))
stopifnot(delete_response$status_code == 200)

after_delete <- httr::GET(sprintf("http://127.0.0.1:%s/api/transactions", port))
stopifnot(after_delete$status_code == 200)

payload <- list(
  transactions = list(
    list(
      date = "2026-01-02",
      description = "Salário",
      category = "Renda",
      type = "income",
      amount = 2500
    ),
    list(
      date = "2026-01-03",
      description = "Transporte",
      category = "Transporte",
      type = "expense",
      amount = 150
    )
  )
)

analyze_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/analyze", port),
  body = jsonlite::toJSON(payload, auto_unbox = TRUE),
  encode = "raw",
  httr::content_type_json()
)
stopifnot(analyze_response$status_code == 200)
analyze_body <- jsonlite::fromJSON(httr::content(analyze_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(identical(analyze_body$status, "success"))
stopifnot(is.numeric(analyze_body$data$total_income))
stopifnot(is.numeric(analyze_body$data$total_expense))
stopifnot(is.numeric(analyze_body$data$net_balance))
stopifnot(analyze_body$data$total_income == 2500)
stopifnot(analyze_body$data$total_expense == 150)
stopifnot(analyze_body$data$net_balance == 2350)
stopifnot(analyze_body$data$transaction_count == 2)
stopifnot(is.list(analyze_body$data$monthly_summary))
stopifnot(is.list(analyze_body$data$expenses_by_category))

missing_payload <- list()
missing_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/analyze", port),
  body = jsonlite::toJSON(missing_payload, auto_unbox = TRUE),
  encode = "raw",
  httr::content_type_json()
)
stopifnot(missing_response$status_code == 400)
missing_body <- jsonlite::fromJSON(httr::content(missing_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(identical(missing_body$status, "error"))

empty_payload <- list(transactions = list())
empty_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/analyze", port),
  body = jsonlite::toJSON(empty_payload, auto_unbox = TRUE),
  encode = "raw",
  httr::content_type_json()
)
stopifnot(empty_response$status_code == 200)
empty_body <- jsonlite::fromJSON(httr::content(empty_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(empty_body$data$total_income == 0)
stopifnot(empty_body$data$total_expense == 0)
stopifnot(empty_body$data$net_balance == 0)

insert_transaction(Sys.getenv("DATAPULSE_DB_PATH"), list(
  date = "2026-01-18",
  description = "Mercado",
  category = "Alimentação",
  type = "expense",
  amount = 420
))

filtered_empty_transactions_payload <- list(
  transactions = list(),
  filters = list(
    start_date = "2026-01-01",
    end_date = "2026-02-28",
    category = "Alimentação",
    type = "expense"
  )
)
filtered_empty_transactions_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/analyze", port),
  body = jsonlite::toJSON(filtered_empty_transactions_payload, auto_unbox = TRUE),
  encode = "raw",
  httr::content_type_json()
)
stopifnot(filtered_empty_transactions_response$status_code == 200)
filtered_empty_transactions_body <- jsonlite::fromJSON(httr::content(filtered_empty_transactions_response, "text", encoding = "UTF-8"), simplifyVector = TRUE)
stopifnot(filtered_empty_transactions_body$data$total_expense == 420)
stopifnot(filtered_empty_transactions_body$data$transaction_count == 1)

invalid_date_payload <- list(transactions = list(list(
  date = "2026-02-30",
  description = "Teste",
  category = "Alimentação",
  type = "expense",
  amount = 30
)))
invalid_date_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/analyze", port),
  body = jsonlite::toJSON(invalid_date_payload, auto_unbox = TRUE),
  encode = "raw",
  httr::content_type_json()
)
stopifnot(invalid_date_response$status_code == 400)

invalid_amount_payload <- list(transactions = list(list(
  date = "2026-03-01",
  description = "Teste",
  category = "Alimentação",
  type = "expense",
  amount = -15
)))
invalid_amount_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/analyze", port),
  body = jsonlite::toJSON(invalid_amount_payload, auto_unbox = TRUE),
  encode = "raw",
  httr::content_type_json()
)
stopifnot(invalid_amount_response$status_code == 400)

invalid_type_payload <- list(transactions = list(list(
  date = "2026-03-01",
  description = "Teste",
  category = "Alimentação",
  type = "transfer",
  amount = 15
)))
invalid_type_response <- httr::POST(
  sprintf("http://127.0.0.1:%s/api/analyze", port),
  body = jsonlite::toJSON(invalid_type_payload, auto_unbox = TRUE),
  encode = "raw",
  httr::content_type_json()
)
stopifnot(invalid_type_response$status_code == 400)

compatibility_check <- build_financial_summary(data.frame(
  date = as.Date(c("2026-01-02", "2026-01-03")),
  description = c("Salário", "Transporte"),
  category = c("Renda", "Transporte"),
  type = c("income", "expense"),
  amount = c(2500, 150),
  stringsAsFactors = FALSE
))
stopifnot(compatibility_check$totals$total_income == 2500)
stopifnot(compatibility_check$totals$total_expense == 150)
stopifnot(compatibility_check$totals$net_balance == 2350)

print("Todos os testes da API do DataPulse passaram.")
