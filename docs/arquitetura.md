# Documento de arquitetura — DataPulse

## 1. Visão geral

DataPulse é uma aplicação de análise financeira com foco em dashboard, indicadores e relatórios. A arquitetura pretende manter a lógica financeira separada da camada de apresentação, permitindo que a aplicação cresça em etapas sem acoplamento excessivo.

A proposta inicial usa:

- R + Plumber para processar dados e expor endpoints.
- JavaScript + HTML + CSS para a interface web.
- SQLite como camada de persistência futura.

## 2. Arquitetura proposta

### 2.1 Frontend

Responsabilidades:

- renderizar dashboards e páginas principais;
- consumir os endpoints da API em JSON;
- aplicar filtros de período, categoria e conta;
- mostrar gráficos, tabelas e indicadores em telas responsivas;
- tratar feedback visual em casos de erro ou ausência de dados.

Tecnologias:

- HTML para estrutura da interface;
- CSS para layout e estilos;
- JavaScript para interações e chamadas assíncronas;
- bibliotecas de visualização em uma etapa posterior, se houver necessidade.

### 2.2 Backend

Responsabilidades:

- processar dados financeiros; 
- fornecer métricas agregadas;
- validar entradas e formatar respostas;
- isolar regras de negócio em módulos específicos.

Tecnologias:

- R para processamento analítico e transformação de dados;
- Plumber para expor uma API REST;
- helpers e funções utilitárias para facilitar testes e manutenção futura.

### 2.3 Persistência

A persistência atual usa SQLite como fonte primária para transações, com a camada de acesso centralizada em `app/backend/services/data_access.R`.

Responsabilidades atuais:

- armazenar transações financeiras com validação de esquema;
- manter o histórico de alterações e permitir CRUD por API;
- suportar testes isolados com bancos temporários e `DATAPULSE_DB_PATH`;
- preservar o núcleo financeiro em R sem duplicação no frontend.

## 3. Separação de responsabilidades

A arquitetura será organizada em camadas:

1. Camada de apresentação
   - HTML/CSS/JS
   - dashboard e filtros

2. Camada de API
   - endpoints em Plumber
   - serialização JSON

3. Camada de serviços
   - regras de agregação e métricas
   - funções de validação

4. Camada de dados
   - SQLite em produção local e testes específicos
   - arquivos temporários em diretórios isolados para validação automatizada

## 4. Estrutura de diretórios

```text
DataPulse/
├── README.md
├── docs/
│   └── arquitetura.md
├── app/
│   ├── frontend/
│   │   ├── index.html
│   │   ├── css/
│   │   ├── js/
│   │   └── assets/
│   ├── backend/
│   │   ├── api/
│   │   ├── services/
│   │   ├── config/
│   │   └── utils/
│   ├── data/
│   │   ├── raw/
│   │   ├── processed/
│   │   └── sqlite/
│   ├── shared/
│   │   └── contracts/
│   └── scripts/
├── tests/
├── .gitignore
├── requirements.R
└── .Rprofile
```

## 5. Contratos preliminares da API

A API será REST e responderá em JSON. A proposta inicial prioriza clareza e extensão.

### 5.1 Formato padrão de resposta

```json
{
  "status": "success",
  "data": {},
  "meta": {
    "generatedAt": "2026-10-14T00:00:00Z",
    "requestId": "uuid"
  },
  "errors": []
}
```

### 5.2 Formato de erro

```json
{
  "status": "error",
  "data": null,
  "meta": {
    "generatedAt": "2026-10-14T00:00:00Z",
    "requestId": "uuid"
  },
  "errors": [
    { "code": "INVALID_PERIOD", "message": "Período informado é inválido." }
  ]
}
```

### 5.3 Endpoint principal: health check

- Método: GET
- Rota: `/health`

Resposta esperada:

```json
{
  "status": "success",
  "data": {
    "service": "DataPulse",
    "status": "ok",
    "version": "0.1.0"
  },
  "meta": {
    "generatedAt": "2026-10-14T00:00:00Z"
  },
  "errors": []
}
```

### 5.4 Endpoint: resumo financeiro

- Método: GET
- Rota: `/api/v1/dashboard/summary`
- Query params: `period`, `accountId`, `categoryId`

Resposta esperada:

```json
{
  "status": "success",
  "data": {
    "period": "2026-09",
    "totalIncome": 25000.00,
    "totalExpense": 18000.00,
    "netBalance": 7000.00,
    "avgExpense": 1500.00,
    "accountCount": 4
  },
  "meta": {
    "generatedAt": "2026-10-14T00:00:00Z"
  },
  "errors": []
}
```

### 5.5 Endpoint: histórico por categoria

- Método: GET
- Rota: `/api/v1/metrics/category-trend`
- Query params: `period`, `categoryId`

Resposta esperada:

```json
{
  "status": "success",
  "data": [
    { "month": "2026-01", "income": 5000.00, "expense": 4200.00 },
    { "month": "2026-02", "income": 5200.00, "expense": 4300.00 }
  ],
  "meta": {
    "generatedAt": "2026-10-14T00:00:00Z"
  },
  "errors": []
}
```

## 6. Dependências iniciais

As dependências a seguir são sugeridas pela necessidade funcional e pelo desenho arquitetural, sem introduzir escopo além do necessário.

- R base: ambiente principal de processamento e execução da API.
- plumber: exposição da API REST em R.
- jsonlite: serialização e parse de JSON para comunicação entre frontend e backend.
- DBI: abstração de acesso a banco de dados caso SQLite seja adotado.
- RSQLite: suporte a SQLite em R, para persistência futura.
- dplyr: manipulação e agregação de dados.
- ggplot2: gráficos estáticos de apoio e prototipagem.
- htmltools: integração de componentes HTML em aplicações web R, se necessário.
- shiny: opcional para prototipagem de interface em etapas iniciais, mas não obrigatório para a arquitetura final.

Observação: esta etapa de planejamento evita instalação de dependências sem necessidade. A lista acima representa as tecnologias que devem ser avaliadas conforme cada etapa evolui, e não uma instalação obrigatória imediata.

## 7. Critérios de aceitação das próximas etapas

A Etapa 2 deve ser considerada iniciada somente após esta etapa atender os seguintes critérios:

- a arquitetura estiver descrita em documentos da equipe;
- a estrutura de diretórios estiver definida;
- os contratos da API estiverem claros e versionados;
- a separação entre frontend, backend e persistência estiver alinhada;
- o escopo da Etapa 2 estiver limitado à construção inicial da API e da base visual, sem regras financeiras complexas.

## 8. Pendências e riscos

- Definir se a interface será monolítica ou modularizada por telas.
- Definir convenção de nomenclatura de endpoints e campos.
- Validar o tipo de dado financeiro a ser suportado em cada etapa.
- Resolver se os filtros do dashboard serão processados no frontend ou no backend.
- Definir a estrutura real da tabela de transações no SQLite.

## 9. Escopo explícito da Etapa 2

A Etapa 2 deve focar em:

- estrutura inicial do backend em R/Plumber;
- endpoints de health check e dashboard summary;
- JSON de resposta padronizado;
- base do frontend em HTML/CSS/JS;
- integração inicial da camada de visualização com a API;
- documentação mínima de uso da API.

Ela não deve incluir:

- regras financeiras complexas;
- autenticação;
- persistência final em SQLite;
- cálculo avançado de indicadores sem base documental.
