MAX_CSV_FILE_SIZE_BYTES <- 5 * 1024 * 1024
MAX_CSV_ROWS <- 10000L

normalize_csv_header <- function(header_name) {
  value <- tolower(trimws(as.character(header_name)))
  mapping <- c(
    "date" = "date",
    "data" = "date",
    "description" = "description",
    "descricao" = "description",
    "descripcao" = "description",
    "category" = "category",
    "categoria" = "category",
    "type" = "type",
    "tipo" = "type",
    "amount" = "amount",
    "valor" = "amount",
    "valor_total" = "amount",
    "valor total" = "amount"
  )

  if (value %in% names(mapping)) {
    return(mapping[[value]])
  }

  value
}

normalize_date_value <- function(value) {
  text <- trimws(as.character(value))
  if (is.na(text) || !nzchar(text)) {
    return(NA_character_)
  }

  candidates <- list(
    list(format = "%Y-%m-%d", regex = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"),
    list(format = "%d/%m/%Y", regex = "^[0-9]{2}/[0-9]{2}/[0-9]{4}$"),
    list(format = "%d-%m-%Y", regex = "^[0-9]{2}-[0-9]{2}-[0-9]{4}$"),
    list(format = "%d.%m.%Y", regex = "^[0-9]{2}\\.[0-9]{2}\\.[0-9]{4}$"),
    list(format = "%Y/%m/%d", regex = "^[0-9]{4}/[0-9]{2}/[0-9]{2}$")
  )

  for (candidate in candidates) {
    if (!grepl(candidate$regex, text)) {
      next
    }

    parsed_candidate <- tryCatch(as.Date(text, format = candidate$format), error = function(e) NA)
    if (is.na(parsed_candidate)) {
      next
    }

    normalized_text <- format(parsed_candidate, candidate$format)
    if (identical(normalized_text, text)) {
      return(format(parsed_candidate, "%Y-%m-%d"))
    }
  }

  NA_character_
}

normalize_type_value <- function(value) {
  text <- tolower(trimws(as.character(value)))
  if (is.na(text) || !nzchar(text)) {
    return(NA_character_)
  }

  mapping <- c(
    "income" = "income",
    "receita" = "income",
    "renda" = "income",
    "entrada" = "income",
    "expense" = "expense",
    "despesa" = "expense",
    "gasto" = "expense",
    "saida" = "expense",
    "saída" = "expense"
  )

  if (text %in% names(mapping)) {
    return(mapping[[text]])
  }

  text
}

normalize_amount_value <- function(value) {
  text <- trimws(as.character(value))
  if (is.na(text) || !nzchar(text)) {
    return(NA_real_)
  }

  cleaned <- gsub("\\s+", "", text)
  if (!grepl("[0-9]", cleaned)) {
    return(NA_real_)
  }

  if (grepl(",", cleaned) && grepl("\\.", cleaned)) {
    decimal_sep <- if (gregexpr(",", cleaned)[[1]][1] > gregexpr("\\.", cleaned)[[1]][1]) "," else "."
    if (decimal_sep == ",") {
      cleaned <- gsub("\\.", "", cleaned)
      cleaned <- gsub(",", ".", cleaned)
    } else {
      cleaned <- gsub(",", "", cleaned)
    }
  } else if (grepl(",", cleaned)) {
    if (grepl(",\\d{1,2}$", cleaned)) {
      cleaned <- gsub(",", ".", cleaned)
    } else {
      cleaned <- gsub(",", "", cleaned)
    }
  } else if (grepl("\\.", cleaned)) {
    if (grepl("\\.\\d{3}$", cleaned) && !grepl("\\.\\d{1,2}$", cleaned)) {
      cleaned <- gsub("\\.", "", cleaned)
    }
  }

  cleaned <- gsub("[^0-9.\\-]", "", cleaned)
  if (!nzchar(cleaned)) {
    return(NA_real_)
  }

  numeric_value <- suppressWarnings(as.numeric(cleaned))
  if (is.na(numeric_value) || !is.finite(numeric_value)) {
    return(NA_real_)
  }

  numeric_value
}

detect_csv_separator <- function(text) {
  if (!nzchar(text)) {
    return(",")
  }

  comma_count <- lengths(regmatches(text, gregexpr(",", text, fixed = TRUE)))
  semicolon_count <- lengths(regmatches(text, gregexpr(";", text, fixed = TRUE)))

  if (semicolon_count > comma_count) {
    return(";")
  }

  ","
}

extract_record_value <- function(record, field_name) {
  if (is.null(record)) {
    return(NULL)
  }

  if (is.list(record) && !is.null(record[[field_name]])) {
    return(record[[field_name]])
  }

  if (is.data.frame(record) && field_name %in% names(record)) {
    return(record[[field_name]][1L])
  }

  if (is.atomic(record) && !is.null(names(record)) && field_name %in% names(record)) {
    return(record[[field_name]])
  }

  NULL
}

build_duplicate_signature <- function(row) {
  date_value <- normalize_date_value(extract_record_value(row, "date"))
  description_value <- tolower(trimws(as.character(extract_record_value(row, "description"))))
  category_value <- tolower(trimws(as.character(extract_record_value(row, "category"))))
  type_value <- normalize_type_value(extract_record_value(row, "type"))
  amount_value <- round(as.numeric(extract_record_value(row, "amount")), 2)

  paste(date_value, description_value, category_value, type_value, sprintf("%.2f", amount_value), sep = "::")
}

validate_import_record <- function(row, row_position) {
  errors <- character(0)
  date_value <- normalize_date_value(extract_record_value(row, "date"))
  description_value <- trimws(as.character(extract_record_value(row, "description")))
  category_value <- trimws(as.character(extract_record_value(row, "category")))
  type_value <- normalize_type_value(extract_record_value(row, "type"))
  amount_value <- normalize_amount_value(extract_record_value(row, "amount"))

  if (is.na(date_value) || !nzchar(date_value)) {
    errors <- c(errors, "Data inválida ou ausente.")
  }

  if (is.na(description_value) || !nzchar(description_value)) {
    errors <- c(errors, "Descrição inválida ou ausente.")
  }

  if (is.na(category_value) || !nzchar(category_value)) {
    errors <- c(errors, "Categoria inválida ou ausente.")
  }

  if (is.na(type_value) || !(type_value %in% c("income", "expense"))) {
    errors <- c(errors, "Tipo de transação inválido. Use income ou expense.")
  }

  if (is.na(amount_value) || !is.finite(amount_value) || amount_value <= 0) {
    errors <- c(errors, "Valor inválido: o valor deve ser numérico, positivo e maior que zero.")
  }

  list(
    row_number = row_position,
    valid = length(errors) == 0L,
    errors = errors,
    normalized = list(
      date = date_value,
      description = description_value,
      category = category_value,
      type = type_value,
      amount = if (is.finite(amount_value)) round(amount_value, 2) else NA_real_
    )
  )
}

read_csv_import_file <- function(file_path) {
  if (is.null(file_path) || !file.exists(file_path)) {
    stop("Arquivo CSV não encontrado ou inexistente.")
  }

  info <- file.info(file_path)
  if (is.na(info$size) || info$size <= 0L) {
    stop("Arquivo CSV vazio ou sem conteúdo.")
  }
  if (info$size > MAX_CSV_FILE_SIZE_BYTES) {
    stop(sprintf("Arquivo CSV excede o limite de %s MB.", round(MAX_CSV_FILE_SIZE_BYTES / (1024 * 1024), 0)))
  }

  raw <- readBin(file_path, what = "raw", n = info$size)
  if (length(raw) >= 3L && identical(raw[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))) {
    raw <- raw[-c(1:3)]
  }

  text <- rawToChar(raw)
  if (!nzchar(text)) {
    stop("Arquivo CSV vazio após a leitura.")
  }

  text <- enc2utf8(text)
  separator <- detect_csv_separator(text)

  if (separator == ";") {
    import_df <- suppressWarnings(read.csv2(
      text = text,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = c("", "NA", "N/A"),
      colClasses = "character"
    ))
  } else {
    import_df <- suppressWarnings(read.csv(
      text = text,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = c("", "NA", "N/A"),
      colClasses = "character"
    ))
  }

  if (!is.data.frame(import_df) || nrow(import_df) == 0L) {
    stop("CSV sem registros válidos para importação.")
  }
  if (nrow(import_df) > MAX_CSV_ROWS) {
    stop(sprintf("CSV excede o limite de %d linhas por importação.", MAX_CSV_ROWS))
  }

  names(import_df) <- vapply(names(import_df), normalize_csv_header, character(1))
  required_columns <- c("date", "description", "category", "type", "amount")
  missing_columns <- setdiff(required_columns, names(import_df))

  if (length(missing_columns) > 0L) {
    stop(sprintf(
      "CSV com colunas obrigatórias ausentes: %s",
      paste(missing_columns, collapse = ", ")
    ))
  }

  import_df
}

preview_csv_import <- function(file_path, db_path = get_default_db_path()) {
  import_df <- read_csv_import_file(file_path)

  results <- list(
    valid_rows = list(),
    invalid_rows = list(),
    duplicate_rows = list(),
    normalized_rows = list(),
    valid_count = 0L,
    invalid_count = 0L,
    duplicate_count = 0L,
    has_errors = FALSE
  )

  existing_fingerprints <- fetch_transaction_fingerprints(db_path)
  fingerprint_counts <- table(c(existing_fingerprints, character(0)))
  current_fingerprints <- character(0)

  for (row_index in seq_len(nrow(import_df))) {
    record <- import_df[row_index, , drop = FALSE]
    validation <- validate_import_record(record, row_index + 1L)
    if (!validation$valid) {
      results$invalid_rows[[length(results$invalid_rows) + 1L]] <- list(
        row_number = validation$row_number,
        message = paste(validation$errors, collapse = "; ")
      )
      next
    }

    normalized_row <- as.data.frame(validation$normalized, stringsAsFactors = FALSE)
    normalized_row[['date']] <- validation$normalized[['date']]
    normalized_row[['description']] <- validation$normalized[['description']]
    normalized_row[['category']] <- validation$normalized[['category']]
    normalized_row[['type']] <- validation$normalized[['type']]
    normalized_row[['amount']] <- validation$normalized[['amount']]

    fingerprint <- build_duplicate_signature(normalized_row)
    duplicate_in_file <- fingerprint %in% current_fingerprints
    duplicate_in_db <- fingerprint %in% names(fingerprint_counts)

    current_fingerprints <- c(current_fingerprints, fingerprint)

    if (duplicate_in_file || duplicate_in_db) {
      results$duplicate_rows[[length(results$duplicate_rows) + 1L]] <- list(
        row_number = row_index + 1L,
        fingerprint = fingerprint,
        reason = if (duplicate_in_db) "registro já existente no banco" else "registro repetido dentro do próprio arquivo"
      )
      results$normalized_rows[[length(results$normalized_rows) + 1L]] <- as.list(normalized_row)
      next
    }

    results$valid_rows[[length(results$valid_rows) + 1L]] <- normalized_row
    results$normalized_rows[[length(results$normalized_rows) + 1L]] <- as.list(normalized_row)
  }

  results$valid_count <- length(results$valid_rows)
  results$invalid_count <- length(results$invalid_rows)
  results$duplicate_count <- length(results$duplicate_rows)
  results$has_errors <- results$invalid_count > 0L || results$duplicate_count > 0L

  list(
    status = if (results$invalid_count == 0L) "preview_ok" else "preview_errors",
    valid_count = results$valid_count,
    invalid_count = results$invalid_count,
    duplicate_count = results$duplicate_count,
    invalid_rows = results$invalid_rows,
    duplicate_rows = results$duplicate_rows,
    valid_rows = results$valid_rows,
    normalized_sample = lapply(results$normalized_rows, function(item) {
      list(
        date = extract_record_value(item, "date"),
        description = extract_record_value(item, "description"),
        category = extract_record_value(item, "category"),
        type = extract_record_value(item, "type"),
        amount = extract_record_value(item, "amount")
      )
    }),
    total_rows = nrow(import_df)
  )
}

confirm_csv_import <- function(file_path, include_duplicates = FALSE, db_path = get_default_db_path()) {
  preview <- preview_csv_import(file_path, db_path)

  if (preview$invalid_count > 0L) {
    stop(sprintf(
      "Existem %d linhas inválidas. Corrija o CSV antes de confirmar a importação.",
      preview$invalid_count
    ))
  }

  if (!include_duplicates && preview$duplicate_count > 0L) {
    stop(sprintf(
      "Foram detectadas %d duplicatas potenciais. Reenvie com include_duplicates = TRUE para importar as duplicatas deliberadamente.",
      preview$duplicate_count
    ))
  }

  rows_to_import <- preview$valid_rows
  if (include_duplicates && preview$duplicate_count > 0L) {
    rows_to_import <- preview$normalized_rows
  }

  if (length(rows_to_import) == 0L) {
    return(list(
      status = "success",
      imported_count = 0L,
      dry_run = FALSE,
      message = "Nenhuma linha foi importada.",
      duplicate_count = preview$duplicate_count
    ))
  }

  rows_df <- as.data.frame(do.call(rbind, lapply(rows_to_import, function(row) {
    data.frame(
      date = as.character(extract_record_value(row, "date")),
      description = as.character(extract_record_value(row, "description")),
      category = as.character(extract_record_value(row, "category")),
      type = as.character(extract_record_value(row, "type")),
      amount = as.numeric(extract_record_value(row, "amount")),
      stringsAsFactors = FALSE
    )
  })), stringsAsFactors = FALSE)

  if (!nrow(rows_df)) {
    stop("Não foi possível construir o conjunto de registros para importação.")
  }

  imported_count <- insert_transaction_rows(rows_df, db_path)

  list(
    status = "success",
    imported_count = imported_count,
    dry_run = FALSE,
    duplicate_count = preview$duplicate_count,
    invalid_count = preview$invalid_count,
    message = sprintf("Importação concluída com %d registros gravados.", imported_count)
  )
}

import_csv_file <- function(file_path, dry_run = TRUE, include_duplicates = FALSE, db_path = get_default_db_path()) {
  if (is.null(file_path) || !file.exists(file_path)) {
    stop("Arquivo CSV não encontrado ou inexistente.")
  }

  preview <- preview_csv_import(file_path, db_path)

  if (dry_run) {
    return(list(
      status = "preview",
      dry_run = TRUE,
      valid_count = preview$valid_count,
      invalid_count = preview$invalid_count,
      duplicate_count = preview$duplicate_count,
      invalid_rows = preview$invalid_rows,
      duplicate_rows = preview$duplicate_rows,
      normalized_sample = preview$normalized_sample,
      message = "Pré-visualização concluída; nenhum dado foi gravado no banco."
    ))
  }

  confirm_csv_import(file_path, include_duplicates = include_duplicates, db_path = db_path)
}
