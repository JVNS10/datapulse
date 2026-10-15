async function apiRequest(path, options = {}) {
  const method = options.method || "GET";
  const fetchOptions = { method, headers: options.headers || {} };

  if (options.body) {
    fetchOptions.body = options.body;
  }

  const response = await fetch(`${API_BASE_URL}${path}`, fetchOptions);
  const contentType = response.headers.get("content-type") || "";

  if (!response.ok) {
    const text = await response.text();
    throw new Error(contentType.includes("application/json") ? JSON.parse(text).errors?.[0]?.message || text : text || "Erro na requisição.");
  }

  if (contentType.includes("application/json")) {
    return response.json();
  }

  return response.text();
}

async function getDashboardSummary() {
  return apiRequest("/api/dashboard/summary");
}

async function importCsvFile(file, dryRun, includeDuplicates) {
  const formData = new FormData();
  formData.append("file", file);
  formData.append("dry_run", String(Boolean(dryRun)));
  formData.append("include_duplicates", String(Boolean(includeDuplicates)));

  return apiRequest("/api/import/csv", {
    method: "POST",
    body: formData
  });
}

const API_BASE_URL = "http://127.0.0.1:8001";
