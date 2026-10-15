const summaryCards = document.getElementById("summary-cards");
const importForm = document.getElementById("csv-import-form");
const fileInput = document.getElementById("csv-file");
const includeDuplicatesInput = document.getElementById("include-duplicates");
const importStatus = document.getElementById("import-status");
const previewSummary = document.getElementById("preview-summary");
const previewErrors = document.getElementById("preview-errors");
const previewTableWrap = document.getElementById("preview-table-wrap");
const previewTableBody = document.getElementById("preview-table-body");
const confirmActions = document.getElementById("confirm-actions");
const confirmButton = document.getElementById("confirm-import-button");

const state = {
  lastPreview: null,
  lastFile: null
};

function setStatus(type, message) {
  importStatus.className = `status ${type}`;
  importStatus.textContent = message;
  importStatus.classList.remove("hidden");
}

function clearPreviewUI() {
  previewSummary.classList.add("hidden");
  previewErrors.classList.add("hidden");
  previewTableWrap.classList.add("hidden");
  confirmActions.classList.add("hidden");
  previewTableBody.innerHTML = "";
}

function renderCards(summary) {
  const totals = summary?.data || {};
  const cards = [
    { label: "Receitas", value: currency(totals.total_income || 0) },
    { label: "Despesas", value: currency(totals.total_expense || 0) },
    { label: "Saldo líquido", value: currency(totals.net_balance || 0) },
    { label: "Transações", value: totals.transaction_count || 0 }
  ];

  summaryCards.innerHTML = cards.map((card) => `
    <article class="card">
      <span class="label">${card.label}</span>
      <span class="value">${card.value}</span>
    </article>
  `).join("");
}

function currency(value) {
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL"
  }).format(Number(value || 0));
}

function normalizeRow(row) {
  return {
    row_number: row.row_number || row.line || "-",
    date: row.date || "",
    description: row.description || "",
    category: row.category || "",
    type: row.type || "",
    amount: row.amount || 0
  };
}

function renderPreview(payload) {
  const preview = payload?.data || payload;
  const invalidRows = preview.invalid_rows || [];
  const duplicates = preview.duplicate_rows || [];

  const summaryText = `Registros válidos: ${preview.valid_count || 0} | inválidos: ${preview.invalid_count || 0} | duplicados: ${preview.duplicate_count || 0}`;
  previewSummary.textContent = summaryText;
  previewSummary.classList.remove("hidden");

  if (invalidRows.length) {
    previewErrors.innerHTML = `
      <strong>Linhas inválidas</strong>
      <ul>
        ${invalidRows.map((item) => `<li>Linha ${item.row_number}: ${item.message}</li>`).join("")}
      </ul>
    `;
    previewErrors.classList.remove("hidden");
  } else {
    previewErrors.classList.add("hidden");
  }

  const rows = preview.normalized_sample || [];
  if (rows.length) {
    previewTableBody.innerHTML = rows.map((row) => `
      <tr>
        <td>${row.row_number || "-"}</td>
        <td>${row.date || ""}</td>
        <td>${row.description || ""}</td>
        <td>${row.category || ""}</td>
        <td>${row.type || ""}</td>
        <td>${currency(row.amount || 0)}</td>
      </tr>
    `).join("");
    previewTableWrap.classList.remove("hidden");
  } else {
    previewTableWrap.classList.add("hidden");
  }

  confirmActions.classList.toggle("hidden", !(preview.valid_count > 0 || duplicates.length > 0));
  confirmButton.disabled = !preview.valid_count && !duplicates.length;
  state.lastPreview = preview;
}

async function refreshDashboard() {
  const summary = await getDashboardSummary();
  renderCards(summary);
}

importForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const file = fileInput.files[0];

  if (!file) {
    setStatus("error", "Selecione um arquivo CSV antes de continuar.");
    return;
  }

  clearPreviewUI();
  setStatus("loading", "Validando CSV e preparando pré-visualização...");

  try {
    const response = await importCsvFile(file, true, includeDuplicatesInput.checked);
    const preview = response?.data || response;
    state.lastFile = file;
    renderPreview(preview);
    setStatus("success", "Pré-visualização concluída. Revise os dados antes de confirmar.");
  } catch (error) {
    clearPreviewUI();
    setStatus("error", error.message || "Não foi possível processar o arquivo.");
  }
});

confirmButton.addEventListener("click", async () => {
  if (!state.lastFile) {
    setStatus("error", "Selecione um arquivo CSV novamente antes de confirmar.");
    return;
  }

  setStatus("loading", "Confirmando importação e gravando os registros...");

  try {
    const response = await importCsvFile(state.lastFile, false, includeDuplicatesInput.checked);
    const payload = response?.data || response;
    setStatus("success", payload?.message || "Importação concluída com sucesso.");
    clearPreviewUI();
    await refreshDashboard();
  } catch (error) {
    setStatus("error", error.message || "A importação falhou.");
  }
});

refreshDashboard();
