---
name: define
description: Analisa, corrige e configura a separação entre os arquivos raiz README.md (público) e CLAUDE.md (sdd agent). Gatilhos: "define o projeto", "analisa o README", "atualiza o CLAUDE.md", "configura os arquivos do projeto", "o README está certo?", "o CLAUDE.md está completo?", ou qualquer pedido para revisar, criar ou ajustar README.md CLAUDE.md.
allowed-tools: Read Edit Write Glob Bash
license: Unlicense
metadata:
  author: thiagoeti
  version: 1.1.0
---

# Define

Regra de separação entre `README.md` e `CLAUDE.md` projeto.

---

## README.md — Arquivo público

**Audiência:** Qualquer pessoa que acesse o repositório (usuários, colaboradores e público em geral).

**Deve conter:**
- O que é o projeto (descrição objetiva).
- Como instalar e usar (instruções focadas no usuário final).
- Estrutura de arquivos **visível ao usuário** (apenas pastas e arquivos públicos).
- Diretrizes de como contribuir (se aplicável).
- Licença de uso.

**Nunca deve conter:**
- Detalhes de arquitetura ou desenvolvimento.
- Referências ao diretório `.claude` ou a qualquer Documentação de Design de Software (SDD).
- Scripts e ferramentas de workflow interno (ex.: `git.sh`).
- Backlog, histórico de tarefas ou decisões internas de desenvolvimento.

---

## CLAUDE.md — Arquivo para agentes de IA / SDD

**Audiência:** Claude Code, Codex e outros agentes de IA que trabalham no projeto.

**Deve conter:**
- Todas informações de desenvolvimento do projeto.
- Estrutura completa SDD `.claude/`
- Todos arquivos de especificação do projeto dentro de `.specs/`

**Nunca deve conter:**
- Instruções de uso voltadas ao usuário final
- Descrições de produto ou qualquer coisa voltada ao usuário final

**Formatação Exigida:**

Tabelas são o guia rápido do agente. Nesta ordem:

1. **Tabela de Especificações (`.specs/`)**: Listar todos os arquivos de especificação acompanhados de um breve resumo, ordenados por relevância.
2. **Tabela de Comandos e Arquivos (`.claude/`)**: Listar todos os comandos e arquivos de configuração do agente com uma breve descrição, ordenados por prioridade.

**Execução:**

1. Sem `CLAUDE.md` na raiz: rode `/init` para gerar a base. Com `CLAUDE.md`: pule (o `/init` sobrescreve).
2. Aplique as regras acima sobre o resultado.

---

## `.specs/` — Especificações do projeto

Uma spec por **assunto**, nunca um arquivo único que junta tudo.

| Regra | Valor |
|---|---|
| Granularidade | 1 arquivo = 1 assunto. |
| Duplicação | zero entre specs. Quando um assunto encosta em dois arquivos, o que não é dono aponta para o dono |
| Nome | kebab-case, substantivo do assunto (`skill-contract.md`, `git-workflow.md`) |
| Conteúdo | fato medido por comando, com data. Opinião e histórico narrativo ficam fora |
| Índice | toda spec entra na Tabela de Especificações do `CLAUDE.md` na **mesma** mudança que cria o arquivo |
| Detalhe × índice | detalhe mora nas .specs; o `CLAUDE.md` aponta para .specs, skills, etc |

**Leitura:** o agente lê a Tabela de Especificações primeiro e abre só a spec do assunto em questão. A coluna de resumo existe para isso — precisa dizer o que o arquivo **responde**, não como ele se chama.

---

## Skills do Projeto — `.claude/skills/`

Uma pasta por skill, `.claude/skills/<nome>/SKILL.md`. O agente registra a skill pelo nome da pasta.

Modelo:

| Skill | Quando aplicar |
|---|---|
| `/deploy` | Git, commit, push, publicação — o workflow do `git.sh`; o script mora na skill e a raiz é um symlink para ele |
| `/profile` | Todo prompt: escopo fechado, resposta direta, pergunta única na ambiguidade |

---

## Regra resumida

| Pergunta | README.md | CLAUDE.md |
|----------|-----------|-----------|
| "Como um usuário externo usa isso?" | ✅ | ❌ |
| "Como instalar/rodar o projeto?" | ✅ | ❌ |
| "Qual é a licença?" | ✅ | ❌ |
| "Como um dev/agente trabalha nisso?" | ❌ | ✅ |
| "Qual a arquitetura e as decisões de design?" | ❌ | ✅ |
| "Onde ficam as specs (`.specs/`)?" | ❌ | ✅ |
| "Quais skills o projeto tem e quando cada uma aplica?" | ❌ | ✅ |
| "Qual é o workflow de deploy?" | ❌ | ✅ |
