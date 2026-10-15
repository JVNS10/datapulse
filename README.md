# DataPulse

DataPulse é uma aplicação web de análise financeira planejada para usar R como motor de processamento, Plumber como API, HTML/CSS/JavaScript para a interface e SQLite como camada de persistência futura.

## Objetivo da etapa atual

Documentar a arquitetura inicial e o escopo técnico antes do desenvolvimento funcional. Esta etapa não implementa regras financeiras nem dados reais; ela define padrões de organização, integração e evolução incremental do projeto.

## Visão geral da arquitetura

- Frontend: interface em HTML, CSS e JavaScript, responsável por renderizar dashboards, filtros e gráficos.
- Backend: serviços em R com Plumber expõem endpoints REST para dados e métricas calculadas.
- Dados: SQLite será a camada persistente futura; em uma primeira fase os dados podem ser carregados em memória ou em arquivos locais para prototipagem.
- Integração: o frontend consome a API em JSON e a interface exibe dados tratados no cliente ou no backend.

## Estrutura de diretórios proposta

```text
DataPulse/
├── README.md
├── docs/
│   └── arquitetura.md
├── app/
│   ├── frontend/
│   │   ├── index.html
│   │   ├── css/
│   │   │   └── styles.css
│   │   ├── js/
│   │   │   ├── app.js
│   │   │   ├── api.js
│   │   │   └── charts.js
│   │   └── assets/
│   │       └── icons/
│   ├── backend/
│   │   ├── api/
│   │   │   └── plumber.R
│   │   ├── services/
│   │   │   ├── metrics.R
│   │   │   ├── finance.R
│   │   │   └── data_access.R
│   │   ├── config/
│   │   │   └── config.R
│   │   └── utils/
│   │       └── helpers.R
│   ├── shared/
│   │   └── contracts/
│   │       └── api-contracts.md
│   ├── data/
│   │   ├── raw/
│   │   ├── processed/
│   │   └── sqlite/
│   └── scripts/
│       └── setup.R
├── tests/
│   ├── api/
│   └── frontend/
├── .gitignore
├── .Rprofile
└── requirements.R
```

## Tecnologias previstas

- R: análise estatística, processamento, sumarizações e modelos.
- Plumber: API REST para expor funções do backend em JSON.
- JavaScript: integração assíncrona, renderização dinâmica e manipulação de DOM.
- HTML: estrutura da interface.
- CSS: layout, estilos e responsividade.
- SQLite: persistência futura de transações, categorias e saldos.

## Regras de desenvolvimento

- O backend deve expor endpoints bem definidos e estáveis.
- O frontend deve consumir a API sem depender de detalhes internos de implementação.
- As operações financeiras serão tratadas preferencialmente em módulos específicos e separadas da UI.
- Toda nova funcionalidade deve seguir uma regra de evolução incremental, sem acoplar etapas futuras à etapa atual.

## Critérios de aceitação desta etapa

- A arquitetura foi documentada.
- A estrutura de diretórios foi definida.
- Os contratos preliminares da API foram descritos.
- A separação de responsabilidades entre frontend e backend ficou clara.
- O escopo da Etapa 2 foi delimitado sem implementar regras financeiras.

## Pendências

- Definir a estrutura detalhada de tabelas do SQLite.
- Definir a estratégia de autenticação, caso seja necessária.
- Escolher a biblioteca de gráficos para o frontend.
- Definir a convenção de nomeação de endpoints e campos de resposta.
- Validar os requisitos reais de dashboard e relatórios da Etapa 2.

## Observação

O arquivo atual `teste.r` foi mantido como referência exploratória e não foi alterado por esta etapa de planejamento. A arquitetura do projeto foi definida em documentos específicos, sem introduzir funcionalidades financeiras.

## Etapa 2: Núcleo de análise financeira em R

Esta etapa implementa o módulo de análise financeira de forma independente do frontend e da API. O componente principal está em `app/backend/services/finance_analysis.R`.

### Modelo de transação

A camada de análise aceita transações no formato CSV com as colunas:

- `date`: data no formato `YYYY-MM-DD`
- `description`: descrição da transação
- `category`: categoria da transação
- `type`: `income` ou `expense`
- `amount`: valor numérico positivo, sem sinal ambíguo

As receitas e despesas usam a mesma representação: o valor é sempre positivo e o tipo define a natureza da transação.

### Como executar a análise

1. Abra o terminal na raiz do projeto.
2. Execute o script de exemplo:

```bash
cd "/home/joao/Documentos/projetos em R" && Rscript app/scripts/run_analysis.R
```

3. Para validar o módulo automaticamente, execute:

```bash
cd "/home/joao/Documentos/projetos em R" && Rscript tests/finance/test_finance_analysis.R
```

### Arquivos relevantes desta etapa

- `app/backend/services/finance_analysis.R` — funções de validação e cálculo financeiro
- `app/data/raw/transactions_sample.csv` — CSV de exemplo com transações fictícias
- `app/scripts/run_analysis.R` — execução do fluxo principal de análise
- `tests/finance/test_finance_analysis.R` — testes automatizados do núcleo financeiro

### Regras da etapa

- O processamento financeiro é independente da interface web.
- Não há persistência em banco nem API nesta etapa.
- Dados inválidos são rejeitados com mensagens claras.
- O projeto evita dependências externas e usa apenas base R.
