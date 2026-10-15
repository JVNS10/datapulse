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

#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")

  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
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
#* @post /api/import/csv
function(req, file = NULL, dry_run = TRUE, include_duplicates = FALSE) {
  upload_path <- extract_upload_path(file, req)
  if (is.null(upload_path)) {
    stop("Arquivo CSV não foi enviado no campo 'file'.")
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
    build_api_response("error", NULL, errors = list(list(code = "CSV_IMPORT_ERROR", message = e$message)))
  })

  if (is.list(result) && !is.null(result$status) && result$status == "error") {
    return(result)
  }

  build_api_response("success", result)
}
