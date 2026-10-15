# Project Status — DataPulse

## Estado atual do projeto

O DataPulse está em estado funcional local, com a API REST, o frontend, o cálculo financeiro em R e a persistência SQLite integrados e validados. A aplicação é orientada para demonstração técnica e uso local em ambiente de desenvolvimento, não para implantação pública sem autenticação e segregação de rede.

## Etapa atual

Etapa 8: finalização para portfólio e documentação técnica — em andamento/validada localmente.

## Componentes implementados

- frontend em HTML, CSS e JavaScript;
- backend em R com Plumber;
- núcleo financeiro em R com cálculos centralizados;
- persistência em SQLite com CRUD e transações;
- importação CSV com preview, validação e confirmação;
- testes automatizados para análise, API, banco e importação;
- documentação operacional para execução local.

## Regras de operação

- O cálculo financeiro permanece no backend em R.
- O frontend não duplica a lógica de negócio.
- O SQLite é usado como camada primária de persistência local.
- CORS usa allowlist explícita e não aceita `*` por padrão.
- O valor de `DATAPULSE_DB_PATH` pode ser configurado, mas o caminho não é aceito se estiver vazio, apontar para diretório ou não puder ser criado.
- O projeto não implementa autenticação nem autorização por usuário.

## Verificações executadas

### Testes automatizados

Comandos executados com sucesso:

```bash
cd "/home/joao/Documentos/projetos em R" && \
Rscript tests/finance/test_finance_analysis.R && \
Rscript tests/db/test_sqlite_persistence.R && \
Rscript tests/api/test_plumber_api.R && \
Rscript tests/import/test_csv_import.R && \
node --check app/frontend/js/api.js && \
node --check app/frontend/js/app.js
```

Resultado observado:

- núcleo financeiro: aprovado;
- persistência SQLite: aprovado;
- API: aprovada;
- importação CSV: aprovada;
- sintaxe JavaScript do frontend: aprovada.

### Verificação de qualidade

```bash
git --no-pager diff --check
```

Resultado: sem erros de diff/whitespace.

## Ambiente e execução local

Backend padrão:

- http://127.0.0.1:8001

Frontend padrão:

- http://127.0.0.1:4321

Variáveis esperadas:

```bash
export DATAPULSE_DB_PATH="/tmp/datapulse_portfolio.sqlite"
export DATAPULSE_ALLOWED_ORIGINS="http://localhost:3000,http://127.0.0.1:3000,http://localhost:3222,http://127.0.0.1:3222,http://localhost:4321,http://127.0.0.1:4321"
```

## Limitações e riscos conhecidos

- Não há autenticação ou autorização por usuário.
- O banco local não deve ser publicado junto com dados reais.
- O projeto foi concebido para uso local, estudos e apresentação técnica.
- Qualquer implantação pública exige autenticação, controle de acesso, isolamento de rede e revisão de segurança.

## Estado final da documentação

- README atualizado para visão profissional e execução local.
- docs/arquitetura.md atualizado para refletir a implementação real.
- Projeto preparado para apresentação em portfólio sem descrever funcionalidades que não existem.

## Observação final

O repositório permanece em desenvolvimento local e funcional, com a arquitetura e a documentação alinhadas ao que foi realmente implementado. Nenhuma funcionalidade financeira foi adicionada fora do escopo da importação e manutenção deste projeto.
