repo_root <- if (dir.exists(file.path(getwd(), "app"))) getwd() else "/home/joao/Documentos/projetos em R.worktrees/csv-import-validation-persistence"

source(file.path(repo_root, "app", "backend", "services", "data_access.R"))
source(file.path(repo_root, "app", "backend", "services", "finance_analysis.R"))
source(file.path(repo_root, "app", "backend", "services", "csv_import.R"))

normalize_boolean <- function(value) {
  if (is.null(value)) return(FALSE)

  while (is.list(value) && length(value) > 0L) {
    if (is.null(names(value))) {
      value <- value[[1L]]
    } else {
      non_null <- Filter(Negate(is.null), value)
      if (length(non_null) == 0L) {
        return(FALSE)
      }
      value <- non_null[[1L]]
    }
  }

  if (is.logical(value)) return(as.logical(value)[1L])
  if (length(value) == 0L) return(FALSE)

  lower <- tolower(trimws(as.character(value[[1L]])))
  lower %in% c("true", "1", "yes", "y", "sim")
}

extract_form_value <- function(value) {
  if (is.null(value)) return(NULL)

  if (is.list(value) && !is.null(value$value)) {
    return(extract_form_value(value[['value']]))
  }

  if (is.list(value) && length(value) > 0L) {
    for (candidate in value) {
      unwrapped <- extract_form_value(candidate)
      if (!is.null(unwrapped)) {
        return(unwrapped)
      }
    }
    return(NULL)
  }

  if (is.raw(value)) {
    return(rawToChar(value))
  }

  if (is.character(value) || is.logical(value) || is.numeric(value)) {
    if (length(value) > 0L) {
      return(value[1L])
    }
  }

  NULL
}

normalize_transaction_rows <- function(body) {
  if (is.null(body)) {
    stop("Payload inválido: corpo da requisição ausente.")
  }

  if (is.data.frame(body)) {
    return(body)
  }

  if (is.list(body) && !is.null(body[['transactions']])) {
    return(normalize_transaction_rows(body[['transactions']]))
  }

  if (is.list(body) && length(body) == 0L) {
    return(data.frame(
      date = character(0),
      description = character(0),
      category = character(0),
      type = character(0),
      amount = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  if (is.list(body) && !is.null(names(body)) && all(c("date", "description", "category", "type", "amount") %in% names(body))) {
    return(as.data.frame(body, stringsAsFactors = FALSE))
  }

  if (is.list(body)) {
    row_list <- lapply(body, function(item) {
      if (is.data.frame(item) && nrow(item) > 0L) {
        return(item[1L, , drop = FALSE])
      }

      if (is.list(item) && !is.null(item[['date']])) {
        return(as.list(item))
      }

      if (is.atomic(item) && length(item) > 0L && !is.null(names(item)) && all(c("date", "description", "category", "type", "amount") %in% names(item))) {
        return(as.list(item))
      }

      stop("Payload inválido: cada transação deve conter date, description, category, type e amount.")
    })

    normalized_rows <- lapply(row_list, function(item) {
      data.frame(
        date = as.character(item[['date']]),
        description = as.character(item[['description']]),
        category = as.character(item[['category']]),
        type = as.character(item[['type']]),
        amount = suppressWarnings(as.numeric(item[['amount']])),
        stringsAsFactors = FALSE
      )
    })

    return(as.data.frame(do.call(rbind, normalized_rows), stringsAsFactors = FALSE))
  }

  stop("Payload inválido: estrutura inesperada de transações.")
}

build_api_response <- function(status, data, errors = list(), meta = list()) {
  response <- list(
    status = status,
    data = data,
    meta = c(list(generatedAt = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")), meta),
    errors = errors
  )

  if (length(errors) == 0L) {
    response$errors <- list()
  }

  response
}

extract_upload_path <- function(file_value, req = NULL) {
  if (is.list(file_value)) {
    if (!is.null(file_value$tempfile) && file.exists(file_value$tempfile)) {
      return(file_value$tempfile)
    }
    if (!is.null(file_value$datapath) && file.exists(file_value$datapath)) {
      return(file_value$datapath)
    }
    if (!is.null(file_value$filename) && nzchar(file_value$filename)) {
      path <- normalizePath(file_value$filename, winslash = "/", mustWork = FALSE)
      if (file.exists(path)) {
        return(path)
      }
    }

    for (key in names(file_value)) {
      candidate <- file_value[[key]]
      if (is.character(candidate) && length(candidate) == 1L && file.exists(candidate)) {
        return(candidate)
      }
      nested <- extract_upload_path(candidate, req = NULL)
      if (!is.null(nested)) {
        return(nested)
      }
    }
  }

  if (is.raw(file_value)) {
    temp_file <- tempfile(fileext = ".csv")
    writeBin(file_value, con = temp_file)
    return(temp_file)
  }

  if (is.character(file_value) && length(file_value) == 1L) {
    if (file.exists(file_value)) {
      return(file_value)
    }
    if (!is.na(file_value) && nzchar(file_value)) {
      temp_file <- tempfile(fileext = ".csv")
      writeBin(charToRaw(file_value), con = temp_file)
      return(temp_file)
    }
  }

  if (!is.null(req) && !is.null(req$body)) {
    body <- req$body
    if (is.list(body) && !is.null(body$file)) {
      return(extract_upload_path(body$file, req = NULL))
    }
    if (is.list(body) && !is.null(body[['file']])) {
      return(extract_upload_path(body[['file']], req = NULL))
    }
  }

  NULL
}

allowed_origins <- Sys.getenv("DATAPULSE_ALLOWED_ORIGINS", unset = "")
if (!nzchar(allowed_origins)) {
  allowed_origins <- paste0(
    c(
      "http://localhost:3000",
      "http://127.0.0.1:3000",
      "http://localhost:8000",
      "http://127.0.0.1:8000",
      "http://localhost:3222",
      "http://127.0.0.1:3222",
      "http://localhost:4321",
      "http://127.0.0.1:4321"
    ),
    collapse = ","
  )
}
allowed_origins <- unique(trimws(strsplit(allowed_origins, ",", fixed = TRUE)[[1]]))
allowed_origins <- allowed_origins[nzchar(allowed_origins)]

#* @filter cors
function(req, res) {
  origin <- if (is.null(req$HTTP_ORIGIN)) "" else trimws(req$HTTP_ORIGIN)
  if (nzchar(origin) && !(origin %in% allowed_origins)) {
    res$status <- 403
    return(list(error = "Origin not allowed by CORS policy"))
  }

  if (nzchar(origin)) {
    res$setHeader("Access-Control-Allow-Origin", origin)
    res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
    res$setHeader("Access-Control-Allow-Headers", "Content-Type, Accept, Authorization")
    res$setHeader("Access-Control-Max-Age", "86400")
  }

  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 204
    return("")
  }

  plumber::forward()
}

#* @apiTitle DataPulse API
#* @apiVersion 0.1.0
#* @serializer unboxedJSON
#* @get /health
function() {
  build_api_response(
    "success",
    list(
      service = "DataPulse",
      status = "ok",
      version = "0.1.0"
    )
  )
}

#* @serializer unboxedJSON
#* @get /api/dashboard/summary
function() {
  summary <- get_dashboard_summary(get_default_db_path())
  build_api_response("success", summary)
}

#* @serializer unboxedJSON
#* @get /api/transactions
function() {
  transactions <- fetch_transactions(get_default_db_path())
  build_api_response("success", transactions)
}

#* @serializer unboxedJSON
#* @get /api/transactions/<transaction_id>
function(req, res, transaction_id) {
  row <- get_transaction_by_id(get_default_db_path(), transaction_id)
  if (is.null(row)) {
    res$status <- 404
    return(build_api_response("error", NULL, errors = list(list(code = "NOT_FOUND", message = "Transação não encontrada."))))
  }

  build_api_response("success", transaction_to_api_payload(row))
}

#* @serializer unboxedJSON
#* @post /api/transactions
function(req, res) {
  body <- req$body
  if (is.null(body) || (!is.list(body) && !is.data.frame(body))) {
    res$status <- 400
    return(build_api_response("error", NULL, errors = list(list(code = "INVALID_PAYLOAD", message = "Payload inválido."))))
  }

  tryCatch({
    payload <- normalize_transaction_input(body)
    inserted <- insert_transaction(get_default_db_path(), payload)
    build_api_response("success", transaction_to_api_payload(inserted))
  }, error = function(e) {
    res$status <- 400
    build_api_response("error", NULL, errors = list(list(code = "INVALID_PAYLOAD", message = e$message)))
  })
}

#* @serializer unboxedJSON
#* @put /api/transactions/<transaction_id>
function(req, res, transaction_id) {
  body <- req$body
  if (is.null(body) || (!is.list(body) && !is.data.frame(body))) {
    res$status <- 400
    return(build_api_response("error", NULL, errors = list(list(code = "INVALID_PAYLOAD", message = "Payload inválido."))))
  }

  tryCatch({
    updated <- update_transaction(get_default_db_path(), transaction_id, body)
    build_api_response("success", transaction_to_api_payload(updated))
  }, error = function(e) {
    res$status <- 400
    build_api_response("error", NULL, errors = list(list(code = "INVALID_PAYLOAD", message = e$message)))
  })
}

#* @serializer unboxedJSON
#* @delete /api/transactions/<transaction_id>
function(req, res, transaction_id) {
  deleted <- delete_transaction(get_default_db_path(), transaction_id)
  if (!isTRUE(deleted)) {
    res$status <- 404
    return(build_api_response("error", NULL, errors = list(list(code = "NOT_FOUND", message = "Transação não encontrada."))))
  }

  build_api_response("success", list(id = as.integer(transaction_id), deleted = TRUE))
}

#* @serializer unboxedJSON
#* @post /api/analyze
function(req, res) {
  body <- req$body
  if (is.null(body) || (!is.list(body) && !is.data.frame(body))) {
    res$status <- 400
    return(build_api_response("error", NULL, errors = list(list(code = "INVALID_PAYLOAD", message = "Payload inválido: esperado uma lista de transações."))))
  }

  if (is.list(body) && length(body) == 0L) {
    res$status <- 400
    return(build_api_response("error", NULL, errors = list(list(code = "INVALID_PAYLOAD", message = "Payload inválido: esperado uma lista de transações."))))
  }

  if (is.list(body) && !is.null(body[['transactions']]) && is.list(body[['transactions']]) && length(body[['transactions']]) == 0L && !is.null(body[['filters']])) {
    filters <- body[['filters']]
    rows <- list_transactions_filtered(
      get_default_db_path(),
      start_date = if (!is.null(filters[['start_date']])) filters[['start_date']] else NULL,
      end_date = if (!is.null(filters[['end_date']])) filters[['end_date']] else NULL,
      category = if (!is.null(filters[['category']])) filters[['category']] else NULL,
      type = if (!is.null(filters[['type']])) filters[['type']] else NULL
    )
  } else {
    rows <- normalize_transaction_rows(body)
  }

  if (nrow(rows) == 0L) {
    result <- list(
      totals = list(total_income = 0, total_expense = 0, net_balance = 0),
      expenses_by_category = list(),
      monthly_summary = list(),
      transaction_count = 0L
    )
    return(build_api_response("success", result))
  }

  if (!is.null(body$filters)) {
    filters <- body$filters
    if (!is.null(filters$start_date) && nzchar(filters$start_date)) {
      rows <- rows[rows$date >= as.character(filters$start_date), , drop = FALSE]
    }
    if (!is.null(filters$end_date) && nzchar(filters$end_date)) {
      rows <- rows[rows$date <= as.character(filters$end_date), , drop = FALSE]
    }
    if (!is.null(filters$category) && nzchar(filters$category)) {
      rows <- rows[rows$category == as.character(filters$category), , drop = FALSE]
    }
    if (!is.null(filters$type) && nzchar(filters$type)) {
      rows <- rows[tolower(rows$type) == tolower(as.character(filters$type)), , drop = FALSE]
    }
  }

  tryCatch({
    summary <- build_financial_summary(rows)
    expenses_by_category <- summary$expenses_by_category
    if (is.null(expenses_by_category) || length(expenses_by_category) == 0L) {
      expenses_by_category <- list()
    } else if (is.numeric(expenses_by_category) && !is.list(expenses_by_category)) {
      expenses_by_category <- as.list(expenses_by_category)
    }

    payload <- list(
      total_income = summary$totals$total_income,
      total_expense = summary$totals$total_expense,
      net_balance = summary$totals$net_balance,
      transaction_count = nrow(rows),
      expenses_by_category = expenses_by_category,
      monthly_summary = summary$monthly_summary
    )
    build_api_response("success", payload)
  }, error = function(e) {
    res$status <- 400
    build_api_response("error", NULL, errors = list(list(code = "INVALID_PAYLOAD", message = e$message)))
  })
}

#* @serializer unboxedJSON
#* @post /api/import/csv
function(req, res, file = NULL, dry_run = TRUE, include_duplicates = FALSE) {
  upload_path <- extract_upload_path(file, req)
  if (is.null(upload_path)) {
    res$status <- 400
    return(build_api_response("error", NULL, errors = list(list(code = "CSV_IMPORT_ERROR", message = "Arquivo CSV não foi enviado no campo 'file'."))))
  }

  dry_run_value <- if (!is.null(req) && !is.null(req$body)) {
    extract_form_value(req$body$dry_run)
  } else {
    dry_run
  }
  include_duplicates_value <- if (!is.null(req) && !is.null(req$body)) {
    extract_form_value(req$body$include_duplicates)
  } else {
    include_duplicates
  }

  dry_run_flag <- normalize_boolean(dry_run_value)
  duplicate_flag <- normalize_boolean(include_duplicates_value)

  result <- tryCatch({
    import_csv_file(upload_path, dry_run = dry_run_flag, include_duplicates = duplicate_flag, db_path = get_default_db_path())
  }, error = function(e) {
    res$status <- 400
    build_api_response("error", NULL, errors = list(list(code = "CSV_IMPORT_ERROR", message = e$message)))
  })

  if (is.list(result) && !is.null(result$status) && identical(result$status, "error")) {
    res$status <- 400
    return(result)
  }

  if (!is.null(result$invalid_count) && result$invalid_count > 0L) {
    res$status <- 400
    return(build_api_response("error", NULL, errors = list(list(
      code = "CSV_INVALID_ROWS",
      message = sprintf("Existem %d linhas inválidas. Corrija o arquivo antes de confirmar a importação.", result$invalid_count)
    ))))
  }

  if (!is.null(result$duplicate_count) && result$duplicate_count > 0L && !dry_run_flag && !duplicate_flag) {
    res$status <- 400
    return(build_api_response("error", NULL, errors = list(list(
      code = "DUPLICATE_ROWS",
      message = sprintf("Foram detectadas %d duplicatas potenciais. Reenvie com include_duplicates = TRUE para confirmar a inclusão deliberada.", result$duplicate_count)
    ))))
  }

  build_api_response("success", result)
}
