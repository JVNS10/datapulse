repo_root <- getwd()
source(file.path(repo_root, "app", "backend", "services", "data_access.R"))

path <- init_database()
message(sprintf("Banco inicializado em: %s", path))
