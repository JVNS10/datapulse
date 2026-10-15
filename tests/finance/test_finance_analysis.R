repo_root <- getwd()
source(file.path(repo_root, "app", "backend", "services", "finance_analysis.R"))

# Dados de teste com valores conhecidos
transactions <- data.frame(
  date = c("2026-01-02", "2026-01-15", "2026-02-05", "2026-02-20", "2026-03-18", "2026-04-01", "2026-04-15"),
  description = c("Salário", "Venda de produto", "Aluguel", "Supermercado", "Consultoria", "Receita extra", "Internet"),
  category = c("Salário", "Vendas", "Moradia", "Alimentação", "Serviços", "Vendas", "Serviços"),
  type = c("income", "income", "expense", "expense", "expense", "income", "expense"),
  amount = c(3500, 1200, 1800, 420, 900, 1500, 180),
  stringsAsFactors = FALSE
)

summary_result <- calculate_totals(transactions)
stopifnot(isTRUE(all.equal(summary_result$total_income, 6200)))
stopifnot(isTRUE(all.equal(summary_result$total_expense, 3300)))
stopifnot(isTRUE(all.equal(summary_result$net_balance, 2900)))

category_result <- summarize_expenses_by_category(transactions)
stopifnot(category_result[["Moradia"]] == 1800)
stopifnot(category_result[["Alimentação"]] == 420)
stopifnot(category_result[["Serviços"]] == 1080)

monthly_result <- summarize_by_month(transactions)
stopifnot(monthly_result[["2026-01"]][["income"]] == 4700)
stopifnot(monthly_result[["2026-01"]][["expense"]] == 0)
stopifnot(monthly_result[["2026-02"]][["expense"]] == 2220)
stopifnot(monthly_result[["2026-04"]][["income"]] == 1500)
stopifnot(monthly_result[["2026-04"]][["expense"]] == 180)

comparison <- compare_periods(
  transactions,
  start_a = "2026-01-01",
  end_a = "2026-02-28",
  start_b = "2026-03-01",
  end_b = "2026-04-30"
)
stopifnot(comparison$period_a$total_income == 4700)
stopifnot(comparison$period_a$total_expense == 2220)
stopifnot(comparison$period_b$total_income == 1500)
stopifnot(comparison$period_b$total_expense == 1080)
stopifnot(comparison$delta_balance == -2060)

invalid_transactions <- transactions
invalid_transactions$amount[1] <- -100
expect_error <- tryCatch({
  validate_transactions(invalid_transactions)
  FALSE
}, error = function(e) TRUE)
stopifnot(expect_error)

empty_csv_path <- file.path(repo_root, "app", "data", "raw", "empty_transactions.csv")
write.csv(data.frame(), empty_csv_path, row.names = FALSE)
expect_empty_error <- tryCatch({
  load_transactions(empty_csv_path)
  FALSE
}, error = function(e) TRUE)
stopifnot(expect_empty_error)

print("Todos os testes do núcleo financeiro passaram.")
