# DataPulse

DataPulse é uma aplicação de análise financeira desenvolvida em R, com API REST em Plumber, frontend web em HTML/CSS/JavaScript e persistência em SQLite. O núcleo financeiro continua centralizado em R para evitar duplicação de regras de negócio entre backend e interface.

## Status atual

Etapa 6A: Persistência com SQLite e CRUD concluída e validada.

A solução mantém o motor financeiro em R, enquanto a API expõe operações de leitura, criação, atualização e exclusão de transações, armazenadas em banco SQLite local. A camada de persistência foi integrada ao backend sem quebrar os fluxos existentes de análise financeira e do dashboard.

## Arquitetura

- Frontend: dashboard em HTML, CSS e JavaScript, com filtros, métricas e ações de CRUD.
- Backend: API REST em R com Plumber.
- Serviço financeiro: funções de validação e agregação em R, incluindo cálculo de totais, categorias e monthly summary.
- Persistência: SQLite com DBI/RSQLite, centralizada em módulos de acesso a dados.

## Estrutura relevante

```text
DataPulse/
├── README.md
├── PROJECT_STATUS.md
├── app/
│   ├── backend/
│   │   ├── api/plumber.R
│   │   ├── services/
│   │   │   ├── finance_analysis.R
│   │   │   └── data_access.R
│   │   └── scripts/
│   ├── frontend/
│   │   ├── index.html
│   │   ├── css/styles.css
│   │   └── js/
│   │       ├── api.js
│   │       └── app.js
│   └── data/sqlite/
├── docs/
│   └── arquitetura.md
├── tests/
│   ├── api/test_plumber_api.R
│   └── db/test_sqlite_persistence.R
├── requirements.R
├── .gitignore
└── teste.r
```

## Como executar

### 1) Backend

```bash
cd "/home/joao/Documentos/projetos em R" && Rscript -e "source('app/backend/api/plumber.R'); pr <- plumber::plumb('app/backend/api/plumber.R'); pr[['run']](port = 8001, host = '127.0.0.1', swagger = FALSE)"
```

### 2) Frontend

```bash
cd "/home/joao/Documentos/projetos em R/app/frontend" && python3 -m http.server 3222
```

### 3) Acesso

- Frontend: http://127.0.0.1:3222/
- API: http://127.0.0.1:8001/
- Health check: http://127.0.0.1:8001/health

## Contrato da API

### Endpoints principais

- GET /health
- GET /api/transactions
- POST /api/transactions
- GET /api/transactions/{id}
- PUT /api/transactions/{id}
- DELETE /api/transactions/{id}
- POST /api/analyze

### Payload padrão

```json
{
  "status": "success",
  "data": { ... },
  "meta": { "timestamp": "..." },
  "errors": []
}
```

A análise financeira continua sendo calculada em R e retorna totais, despesas por categoria e resumo mensal.

## Validação executada

Os testes abaixo foram executados com sucesso no ambiente atual:

```bash
cd "/home/joao/Documentos/projetos em R" && Rscript tests/db/test_sqlite_persistence.R && Rscript tests/api/test_plumber_api.R
```

Evidência observada:

- `Todos os testes de persistência com SQLite passaram.`
- `Todos os testes da API do DataPulse passaram.`

## Regras de implementação

- A lógica financeira permanece no backend em R.
- O frontend apenas consulta e renderiza respostas da API.
- O SQLite é a fonte primária de persistência para transações.
- Validações e erros HTTP retornam status úteis para client e testes.

## Considerações finais

A etapa de persistência com SQLite e CRUD foi concluída sem remover o comportamento da análise financeira já validada. O projeto segue em uma arquitetura incremental, com o backend em R funcionando como núcleo de negócio e a interface como camada de apresentação.
