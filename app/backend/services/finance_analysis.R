prepare_transactions <- function(transactions) {
  if (is.character(transactions) && length(transactions) == 1L) {
    return(load_transactions(transactions))
  }

  if (is.data.frame(transactions)) {
    return(validate_transactions(transactions))
  }

  stop("Entrada inválida: informe um data.frame ou um caminho de CSV.")
}

load_transactions <- function(csv_path) {
  if (!file.exists(csv_path)) {
    stop(sprintf("Arquivo de transações não encontrado: %s", csv_path))
  }

  transactions <- utils::read.csv(csv_path, stringsAsFactors = FALSE, na.strings = c("", "NA", "N/A"))

  if (nrow(transactions) == 0L) {
    stop("CSV vazio: o arquivo não contém registros de transações.")
  }

  validate_transactions(transactions)
}

validate_transactions <- function(transactions) {
  if (is.null(transactions) || !is.data.frame(transactions)) {
    stop("Estrutura de transações inválida: era esperado um data.frame.")
  }

  if (nrow(transactions) == 0L) {
    stop("CSV vazio: o arquivo não contém registros de transações.")
  }

  required_columns <- c("date", "description", "category", "type", "amount")
  missing_columns <- setdiff(required_columns, names(transactions))

  if (length(missing_columns) > 0L) {
    stop(sprintf(
      "CSV com colunas obrigatórias ausentes: %s",
      paste(missing_columns, collapse = ", ")
    ))
  }

  data <- as.data.frame(transactions, stringsAsFactors = FALSE)
  data$date <- as.character(data$date)
  data$description <- trimws(as.character(data$description))
  data$category <- trimws(as.character(data$category))
  data$type <- tolower(trimws(as.character(data$type)))
  data$amount <- suppressWarnings(as.numeric(data$amount))

  parsed_dates <- as.Date(data$date, format = "%Y-%m-%d")
  invalid_rows <- which(
    is.na(parsed_dates) |
      is.na(data$description) |
      nchar(data$description) == 0L |
      is.na(data$category) |
      nchar(data$category) == 0L |
      is.na(data$type) |
      !(data$type %in% c("income", "expense")) |
      is.na(data$amount) |
      !is.finite(data$amount) |
      data$amount <= 0
  )

  if (length(invalid_rows) > 0L) {
    stop(sprintf(
      "Registros inválidos nas linhas: %s. Verifique data, descrição, categoria, tipo e valor do registro. Os valores devem ser positivos e o tipo deve ser 'income' ou 'expense'.",
      paste(invalid_rows, collapse = ", ")
    ))
  }

  data$date <- parsed_dates
  data$type <- factor(data$type, levels = c("income", "expense"))
  data$amount <- as.numeric(data$amount)

  data
}

calculate_totals <- function(transactions) {
  data <- prepare_transactions(transactions)

  total_income <- sum(data$amount[data$type == "income"])
  total_expense <- sum(data$amount[data$type == "expense"])
  net_balance <- total_income - total_expense

  list(
    total_income = total_income,
    total_expense = total_expense,
    net_balance = net_balance
  )
}

summarize_expenses_by_category <- function(transactions) {
  data <- prepare_transactions(transactions)
  expenses <- subset(data, type == "expense")

  if (nrow(expenses) == 0L) {
    return(list())
  }

  summary_df <- stats::aggregate(amount ~ category, data = expenses, FUN = sum)
  summary_df <- summary_df[order(summary_df$amount, decreasing = TRUE), ]
  stats::setNames(summary_df$amount, summary_df$category)
}

summarize_by_month <- function(transactions) {
  data <- prepare_transactions(transactions)
  data$month <- format(data$date, "%Y-%m")

  months <- split(data, data$month)
  result <- lapply(months, function(month_data) {
    month_income <- sum(month_data$amount[month_data$type == "income"])
    month_expense <- sum(month_data$amount[month_data$type == "expense"])

    list(
      income = month_income,
      expense = month_expense,
      net_balance = month_income - month_expense
    )
  })

  result[order(names(result))]
}

compare_periods <- function(transactions, start_a, end_a, start_b, end_b) {
  data <- prepare_transactions(transactions)

  period_a <- subset(data, date >= as.Date(start_a) & date <= as.Date(end_a))
  period_b <- subset(data, date >= as.Date(start_b) & date <= as.Date(end_b))

  totals_a <- calculate_totals(period_a)
  totals_b <- calculate_totals(period_b)

  list(
    period_a = totals_a,
    period_b = totals_b,
    delta_income = totals_b$total_income - totals_a$total_income,
    delta_expense = totals_b$total_expense - totals_a$total_expense,
    delta_balance = totals_b$net_balance - totals_a$net_balance
  )
}

build_financial_summary <- function(transactions) {
  data <- prepare_transactions(transactions)
  totals <- calculate_totals(data)
  categories <- summarize_expenses_by_category(data)
  monthly <- summarize_by_month(data)

  list(
    totals = totals,
    expenses_by_category = categories,
    monthly_summary = monthly
  )
}
