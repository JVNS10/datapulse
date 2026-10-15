# Project Status — DataPulse

## Etapa atual

Etapa 7B: hardening de segurança e consistência — concluída localmente com validação de regressão.

A solução mantém persistência real para transações em SQLite, fluxo de CRUD e importação CSV com pré-visualização e confirmação. O cálculo financeiro continua centralizado em R, e a API REST atua como interface principal para frontend e integrações. Correções recentes envolveram CORS restritivo por origem autorizada, validação explícita do caminho do SQLite e atualização da documentação operacional.

## Verificação final da Etapa 7B

- Frontend validado em `http://127.0.0.1:4321/` com backend em `http://127.0.0.1:8001/`.
- CORS revisado para permitir explicitamente `http://127.0.0.1:4321` e `http://localhost:4321`, mantendo bloqueio para origens desconhecidas.
- Validação no navegador: carregamento do dashboard com comunicação da API em `200`, ausência de erros de console e atualização do resumo após criação de transações de demonstração (receitas `2500`, despesas `150`, saldo líquido `2350`).
- Regressão confirmada: `Rscript tests/finance/test_finance_analysis.R`, `Rscript tests/db/test_sqlite_persistence.R`, `Rscript tests/api/test_plumber_api.R`, `Rscript tests/import/test_csv_import.R`, `node --check app/frontend/js/api.js` e `node --check app/frontend/js/app.js` passaram.

## Tabela de critérios de aceitação

| Critério | Status | Evidência |
| --- | --- | --- |
| Núcleo financeiro | Aprovado | `Rscript tests/finance/test_finance_analysis.R` -> `[1] "Todos os testes do núcleo financeiro passaram."` |
| Persistência SQLite | Aprovado | `Rscript tests/db/test_sqlite_persistence.R` -> `[1] "Todos os testes de persistência com SQLite passaram."` |
| API REST + CRUD | Aprovado | `Rscript tests/api/test_plumber_api.R` -> `[1] "Todos os testes da API do DataPulse passaram."` |
| Carregamento do dashboard pela API | Aprovado | navegador acessou a página em `http://127.0.0.1:3222/`, status `Dados atualizados pela API.` e tabela com 3 registros carregados do SQLite temporário |
| Cadastro via frontend | Aprovado | criação de `Teste auditoria` no formulário gerou `Transação cadastrada com sucesso.` e persistência via API com `count = 4` |
| Persistência após reinicialização do backend | Aprovado | após reiniciar o Plumber com o mesmo `DATAPULSE_DB_PATH`, a transação persistida continuou disponível na página |
| Edição via frontend | Aprovado | atualização de `Teste auditoria editado` retornou `Transação atualizada com sucesso.` e `amount = 375` via API |
| Exclusão via frontend | Aprovado | exclusão de `Teste auditoria editado` retornou `Transação excluída com sucesso.` e a transação não reapareceu após reinicialização |
| Filtros por período/categoria/tipo | Aprovado | filtros `2026-01-01` a `2026-02-28`, categoria `Alimentação` e tipo `expense` resultaram em `1 registro`, `R$ 420,00` de despesa e saldo `-R$ 420,00` |
| Receitas, despesas e saldo a partir do SQLite | Aprovado | `GET /api/transactions` e `POST /api/analyze` retornaram valores coerentes com os dados persistidos e a lógica de `build_financial_summary()` |
| Identificador inexistente | Aprovado | `GET /api/transactions/999999` -> HTTP 404 com `NOT_FOUND` |
| Payload inválido e datas inválidas | Aprovado | `POST /api/analyze` com `amount = -15` e data inválida -> HTTP 400 com `INVALID_PAYLOAD` |
| Falha de comunicação | Aprovado | backend desligado resultou em `net::ERR_CONNECTION_REFUSED` e status `API indisponível. A análise não foi atualizada.` na UI |
| Exclusão do SQLite do versionamento | Aprovado | `.gitignore` cobre `app/data/sqlite/*.sqlite`, `*.db` e `*.sqlite3`; `git check-ignore` confirma a regra para o banco temporário |
| Estado final do repositório | Aprovado | `git --no-pager diff --check` sem erros; revisão final concluída |

## Estado funcional confirmado

1. Persistência em SQLite
   - Arquivo relevante: app/backend/services/data_access.R
   - Evidência: comando executado com sucesso.
   - Resultado observável: `[1] "Todos os testes de persistência com SQLite passaram."`

2. API REST em Plumber
   - Arquivo relevante: app/backend/api/plumber.R
   - Evidência: comando executado com sucesso.
   - Resultado observável: `[1] "Todos os testes da API do DataPulse passaram."`

3. CRUD e filtros
   - Endpoints implementados: GET/POST/PUT/DELETE /api/transactions e filtros por data, categoria e tipo.
   - Resultado: validado por testes automatizados e validação no navegador.

4. Integração com o núcleo financeiro
   - Arquivo relevante: app/backend/services/finance_analysis.R
   - Resultado: a análise permaneceu no serviço em R e não foi duplicada no frontend.

5. Regressão e robustez
   - Tratamento de payloads vazios, inválidos e datas inválidas ajustado para responder com HTTP 400 quando aplicável.
   - Resultado: validado pela suíte de testes e pela validação de UI e API.

## Verificações finais executadas

```bash
cd "/home/joao/Documentos/projetos em R" && Rscript tests/db/test_sqlite_persistence.R && Rscript tests/api/test_plumber_api.R
```

Saída confirmada:

- `Todos os testes de persistência com SQLite passaram.`
- `Todos os testes da API do DataPulse passaram.`

## Status da implementação

- Status: concluído para a Etapa 6A
- Persistência: SQLite ativa e funcional
- API: REST com CRUD e análise financeira
- Frontend: dashboard em evolução sobre a API real
- Arquitetura: preservada conforme a regra de manter o cálculo financeiro em R

## Próximos passos recomendados

- Revisar UX de edição e exclusão no dashboard.
- Validar fluxo completo do frontend com dados persistidos.
- Atualizar documentação operacional e README para uso em ambiente local.
- Planejar a próxima etapa após a persistência, caso o projeto avance em novos recursos.
