required_packages <- c("plumber", "jsonlite", "httr", "DBI", "RSQLite", "callr")
for (package_name in required_packages) {
  if (!requireNamespace(package_name, quietly = TRUE)) {
    install.packages(package_name, repos = "https://cloud.r-project.org", INSTALL_opts = c("--no-lock"))
  }
}
