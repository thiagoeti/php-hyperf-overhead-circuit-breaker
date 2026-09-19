---
name: deploy
description: Deploy e versionamento via Git, usando o script git.sh na raiz do projeto. Use sempre que o usuário mencionar deploy, publicar, commitar, push, versionamento, atualizar repositório, subir para beta, main, colocar em produção, sincronizar branches, ou rodar o git.sh. Dispare mesmo sem a palavra "deploy" — qualquer menção a git, push, commit ou publicação de código aciona esta skill.
allowed-tools: Read Bash
license: Unlicense
metadata:
  author: thiagoeti
  version: 1.0.0
---

# Deploy

Toda publicação passa pelo script **`git.sh`** — ele é a **fonte única da verdade** do workflow git. Esta skill não reimplementa a lógica: ela escolhe o modo certo, mostra o que vai acontecer e executa `git.sh`.

> O arquivo **real** é [`git.sh`](git.sh) (dentro desta skill, versionado). A **raiz** do projeto tem apenas um **symlink** `git.sh → .claude/skills/deploy/git.sh` para conveniência de execução — esse link é ignorado pelo git (regra `/git.sh` no `.gitignore`).
>
> Rodar `bash git.sh` da raiz executa o conteúdo do arquivo real. O script usa `DIR="$(cd "$(dirname "$0")" && pwd)"`: como o shell **não** resolve o alvo do symlink em `$0` (vale para `sh`/`dash`/`bash`), `$0` é o link `git.sh` **na raiz**, então `DIR` aponta para a **raiz do repo** — que é onde os comandos git devem rodar. Nunca há duas versões para sincronizar.

```bash
bash git.sh [beta|main|full] ["message commit"]
```

Se o modo for omitido, o padrão é `beta`. Se a mensagem for omitida, usa `chore: update <data>`.

---

## Modos

| Modo | O que faz | Quando usar |
| :-- | :-- | :-- |
| **beta** _(padrão)_ | Stash do que estiver fora de beta → checkout beta → commit → pull --rebase → push `origin/beta`. | Trabalho do dia a dia, homologação. |
| **main** | Vai para main (carregando junto o que estiver pendente) → sincroniza (`pull --rebase`) → **merge `beta → main` (--no-ff)** → commita o pendente **por cima** do merge → push `origin/main` → volta para beta. | Promover beta para produção. |
| **full** | Mergeia **todos** os branches remotos em beta e os deleta (os mergeados) → push beta → **promove beta → main** → volta para beta. | Pipeline completo / sincronizar tudo de uma vez. |

---

## Como executar

**0. Verifique o symlink antes de qualquer coisa:**

```bash
ln -s .claude/skills/deploy/git.sh git.sh
```

Se o symlink não existir, crie-o. Se existir um arquivo real no lugar (não é symlink), pare e avise o usuário — não sobrescreva.

**1. Diagnóstico antes de publicar** (sempre mostre ao usuário o estado atual):

```bash
git -C "$(git rev-parse --show-toplevel)" status -sb
```

**2. Escolha o modo pelo pedido e execute sem perguntar:**

```bash
# beta (padrão) — com mensagem personalizada
bash git.sh beta "feat: message commit"

# main — promove beta para produção
bash git.sh main

# full — pipeline completo
bash git.sh full "chore: release"
```

---

## Garantias do git.sh (não precisa duplicar aqui)

O script já trata, e falha com mensagem clara, nestes casos:

- Modo inválido, fora de repositório git, **HEAD destacado**.
- Rebase / merge / cherry-pick **em andamento** (inclusive em worktrees).
- **Sem remote `origin`** ou **identidade git** (`user.name`/`user.email`) não configurada.
- Working tree sujo ao trocar de branch → **stash automático** e restauração no destino; conflito ao restaurar **preserva o stash** e para com instruções (nada se perde).
- Branch de feature de origem é apagado com `-d` **seguro** (recusa se tiver commits não mergeados) — nunca com `-D` forçado.
- No `full`, branch só é deletado **remotamente** se o delete **local** teve sucesso.
- Os pulls de promoção/sincronização usam `--no-edit` (não abrem editor); falhas abortam o rebase deixando os commits locais a salvo.
- Ao final, sempre retorna para **beta** e imprime `git status -sb`.

---

## Regras de uso

- **Não reimplemente git** em scripts paralelos — sempre chame `git.sh`. Qualquer ajuste de comportamento é feito **no próprio `git.sh`**.
- **Mensagens de commit**, seguindo Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`…).
- **`main`/`full` mexem em produção** — confirme com o usuário antes de executar.
- Se o script parar pedindo resolução manual (conflito de stash/merge), **não force**: relate a mensagem do script ao usuário e siga as instruções que ele imprimiu.

---
