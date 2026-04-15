# CCM — Claude Code Switch

Troque o Claude Code entre provedores de IA com um único comando.

[English](README.md) | [中文](README_CN.md)

---

## O que é o CCM?

O CCM é um utilitário de linha de comando em Shell Script que configura as variáveis de ambiente necessárias para o Claude Code se conectar a diferentes provedores de IA (DeepSeek, GLM, Kimi, Qwen, MiniMax, Doubao/Seed, StepFun, OpenRouter e o próprio Claude oficial).

Em vez de editar arquivos de configuração manualmente cada vez que você quer trocar de modelo, basta rodar `ccm deepseek` ou `ccm kimi global` e pronto.

---

## Instalação

### Instalação rápida (recomendada)

```bash
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
source ~/.zshrc   # ou ~/.bashrc se você usa bash
```

### Instalação local (a partir do repositório clonado)

```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
./install.sh
source ~/.zshrc
```

### Modos de instalação

| Modo | Comando | Quando usar |
|------|---------|-------------|
| **Usuário** (padrão) | `./install.sh` | Uso pessoal, disponível em qualquer diretório |
| **Sistema** | `./install.sh --system` | Máquina compartilhada, disponível para todos os usuários |
| **Projeto** | `./install.sh --project` | Instalação isolada dentro de um projeto específico |

### Opções adicionais do instalador

```bash
./install.sh --no-rc           # Não injeta funções no arquivo rc do shell
./install.sh --cleanup-legacy  # Remove instalações antigas
./install.sh --help            # Lista todas as opções disponíveis
```

### Desinstalar

```bash
./uninstall.sh
```

---

## Configuração inicial

Depois de instalar, você precisa informar ao CCM as suas chaves de API. Há duas formas de fazer isso:

- **Arquivo de configuração** `~/.ccm_config` — forma tradicional, texto simples
- **Keystore** (recomendado no Windows/WSL) — chaves criptografadas com DPAPI do Windows

### Forma 1: arquivo de configuração

```bash
ccm config
```

Esse comando abre o arquivo `~/.ccm_config` no seu editor. Preencha as chaves dos provedores que você vai usar:

```bash
# Idioma das mensagens (en ou zh)
CCM_LANGUAGE=en

# Chaves de API — preencha apenas os provedores que você usa
DEEPSEEK_API_KEY=sk-...
KIMI_API_KEY=sk-...
GLM_API_KEY=...
QWEN_API_KEY=sk-...
MINIMAX_API_KEY=...
ARK_API_KEY=...              # Doubao / Seed
STEPFUN_API_KEY=...
OPENROUTER_API_KEY=sk-or-v1-...
CLAUDE_API_KEY=sk-ant-...    # Opcional — só se usar API paga do Claude
```

Salve o arquivo. As mudanças são aplicadas automaticamente no próximo comando `ccm`.

### Forma 2: keystore criptografado (Windows/WSL)

Se você usa o CCM no Windows via WSL, o arquivo `~/.ccm_config` fica em texto puro e qualquer pessoa com acesso ao seu computador consegue ler as chaves. O keystore resolve isso armazenando cada chave criptografada com o **Windows DPAPI** — a chave de criptografia é vinculada à sua conta Windows e à sua máquina. Mesmo que alguém copie o arquivo, não consegue ler em outro computador.

```bash
# Armazenar uma chave (o valor nunca aparece na tela)
ccm keystore set DEEPSEEK_API_KEY

# Depois de armazenar, você pode remover a chave do ~/.ccm_config
# O CCM busca no keystore automaticamente quando não acha no arquivo
```

Veja a seção **[Keystore — armazenamento seguro](#keystore--armazenamento-seguro)** para detalhes completos.

### Verificar a configuração

```bash
ccm status
```

Mostra o provedor ativo, as variáveis exportadas e o status de cada chave (mascarada, nunca em texto puro).

---

## Uso básico

### Trocar de provedor

```bash
ccm deepseek          # DeepSeek
ccm kimi              # Kimi (global, padrão)
ccm kimi china        # Kimi (China)
ccm glm               # GLM (global, padrão)
ccm glm china         # GLM (China)
ccm qwen              # Qwen (global, padrão)
ccm qwen china        # Qwen (China)
ccm minimax           # MiniMax (global, padrão)
ccm minimax china     # MiniMax (China)
ccm seed              # Doubao / Seed (ark-code-latest)
ccm stepfun           # StepFun
ccm claude            # Claude oficial (usa sua assinatura Claude Pro)
ccm open kimi         # Kimi via OpenRouter
```

O comando configura as variáveis de ambiente no shell atual. Para usar o provedor novo, basta abrir o Claude Code normalmente — ele já vai usar o novo provedor.

### Trocar e abrir o Claude Code de uma vez

O comando `ccc` troca o provedor e já abre o Claude Code:

```bash
ccc deepseek          # Troca para DeepSeek e abre o Claude Code
ccc kimi global       # Troca para Kimi global e abre
ccc glm china         # Troca para GLM China e abre
ccc open kimi         # Troca para Kimi via OpenRouter e abre
```

### Verificar o status atual

```bash
ccm status   # ou: ccm st
```

Exemplo de saída:

```
Current provider:  deepseek
ANTHROPIC_BASE_URL:  https://api.deepseek.com/anthropic
ANTHROPIC_MODEL:     deepseek-chat
DEEPSEEK_API_KEY:    [set] sk-ab...ef12
```

---

## Referência de provedores

### Provedores diretos

| Provedor | Comando | Região padrão | Variável de chave |
|----------|---------|---------------|-------------------|
| DeepSeek | `ccm deepseek` | — | `DEEPSEEK_API_KEY` |
| Kimi | `ccm kimi [global\|china]` | global | `KIMI_API_KEY` |
| GLM | `ccm glm [global\|china]` | global | `GLM_API_KEY` |
| Qwen | `ccm qwen [global\|china]` | global | `QWEN_API_KEY` |
| MiniMax | `ccm minimax [global\|china]` | global | `MINIMAX_API_KEY` |
| Doubao/Seed | `ccm seed [variante]` | — | `ARK_API_KEY` |
| StepFun | `ccm stepfun` | — | `STEPFUN_API_KEY` |
| Claude | `ccm claude` | — | `CLAUDE_API_KEY` (opcional) |

### Variantes do Seed/Doubao

```bash
ccm seed              # ark-code-latest (padrão)
ccm seed doubao       # doubao-seed-code
ccm seed glm          # glm-5
ccm seed deepseek     # deepseek-v3.2
ccm seed kimi         # kimi-k2.5
```

### OpenRouter

OpenRouter é um gateway que dá acesso a vários modelos com uma única chave. Use sempre com o prefixo `open`:

```bash
ccm open              # Mostra ajuda e provedores disponíveis
ccm open claude       # Claude via OpenRouter
ccm open kimi         # Kimi via OpenRouter
ccm open deepseek     # DeepSeek via OpenRouter
ccm open glm          # GLM via OpenRouter
ccm open qwen         # Qwen via OpenRouter
ccm open minimax      # MiniMax via OpenRouter
ccm open stepfun      # StepFun via OpenRouter
ccm open sf-free      # StepFun tier gratuito
```

Requer `OPENROUTER_API_KEY` configurado.

---

## Keystore — armazenamento seguro

> **Para quem usa Windows via WSL.** No macOS as credenciais do Claude Pro já são salvas no Keychain automaticamente. No Linux puro, o keystore não está disponível.

### Por que usar o keystore?

O arquivo `~/.ccm_config` armazena as chaves em **texto puro**. Se alguém acessar seu computador — mesmo por alguns minutos — pode abrir esse arquivo e copiar todas as suas chaves de API.

O keystore guarda cada chave criptografada usando o **Windows DPAPI** (Data Protection API). O que isso significa na prática:

- Os arquivos ficam em `%APPDATA%\ccm\credentials\` como `.xml` criptografados
- A criptografia é vinculada à sua conta Windows **e** à sua máquina específica
- Se alguém copiar o arquivo para outro computador ou conta, não consegue descriptografar
- Você não precisa lembrar de nenhuma senha extra — o Windows cuida disso

### Armazenar uma chave

```bash
ccm keystore set DEEPSEEK_API_KEY
```

O CCM pede o valor sem ecoar na tela. Depois de salvar:

```
✅ DEEPSEEK_API_KEY stored (DPAPI-encrypted in %APPDATA%\ccm\credentials\)
💡 You can now remove DEEPSEEK_API_KEY from ~/.ccm_config — keystore is the fallback.
```

Repita para cada provedor que você usa:

```bash
ccm keystore set KIMI_API_KEY
ccm keystore set GLM_API_KEY
ccm keystore set OPENROUTER_API_KEY
# ... etc
```

### Ver quais chaves estão armazenadas

```bash
ccm keystore list
```

Saída:

```
🔐 Stored keys (DPAPI-encrypted in %APPDATA%\ccm\credentials\):
   DEEPSEEK_API_KEY
   KIMI_API_KEY
   GLM_API_KEY
```

### Conferir o valor de uma chave (mascarado)

```bash
ccm keystore show DEEPSEEK_API_KEY
# DEEPSEEK_API_KEY: [set] sk-ab...ef12
```

### Remover uma chave do keystore

```bash
ccm keystore delete DEEPSEEK_API_KEY
```

### Como o CCM usa o keystore automaticamente

Quando você roda `eval "$(ccm deepseek)"`, o CCM:

1. Procura `DEEPSEEK_API_KEY` no `~/.ccm_config`
2. Se não encontrar → busca automaticamente no keystore Windows
3. Se encontrar no keystore → passa o valor descriptografado direto para o `eval`

Ou seja, depois de armazenar no keystore você pode **apagar a linha do `~/.ccm_config`** e o comando `ccm deepseek` continua funcionando normalmente.

### Migração recomendada

```bash
# 1. Armazene todas as chaves no keystore
ccm keystore set DEEPSEEK_API_KEY
ccm keystore set KIMI_API_KEY
ccm keystore set GLM_API_KEY
# ... repita para cada chave

# 2. Abra o config e apague as linhas das chaves
ccm config
# (delete as linhas DEEPSEEK_API_KEY=..., KIMI_API_KEY=..., etc.)

# 3. Confirme que ainda funciona
eval "$(ccm deepseek)"
ccm status
```

---

## Funcionalidades avançadas

### Configurações no nível do usuário

Escreve as configurações diretamente em `~/.claude/settings.json`. Isso tem **prioridade máxima** — sobrepõe variáveis de ambiente e qualquer outra configuração.

Útil quando você usa outras ferramentas (como Quotio) que também modificam esse arquivo, ou quando quer um provedor padrão que persiste mesmo depois de reiniciar o terminal.

```bash
# Definir provedor padrão para todos os projetos
ccm user glm global      # GLM global como padrão global
ccm user glm china       # GLM China como padrão global
ccm user deepseek        # DeepSeek como padrão global
ccm user kimi global     # Kimi global como padrão global
ccm user claude          # Claude oficial como padrão global

# Voltar ao controle por variáveis de ambiente
ccm user reset
```

Para ver o status e provedores disponíveis:

```bash
ccm user help
```

### Configurações no nível do projeto

Sobrepõe as configurações apenas para o projeto atual, sem afetar outros projetos. Cria/remove o arquivo `.claude/settings.local.json` no diretório atual.

```bash
# Dentro do diretório do seu projeto:
ccm project glm global    # Usar GLM neste projeto
ccm project deepseek      # Usar DeepSeek neste projeto
ccm project reset         # Remover o override do projeto
```

### Hierarquia de prioridade (da mais alta para a mais baixa)

```
1. ~/.claude/settings.json        ← ccm user <provedor>
2. .claude/settings.local.json    ← ccm project <provedor>
3. Variáveis de ambiente           ← eval "$(ccm <provedor>)"
4. ~/.ccm_config                  ← ccm config
```

### Gerenciamento de contas Claude Pro

Se você tem mais de uma assinatura Claude Pro (ex: pessoal e trabalho), pode salvar e alternar entre elas:

```bash
# Salvar a conta atualmente logada com um nome
ccm save-account trabalho

# Salvar outra conta (faça login no Claude Code primeiro)
ccm save-account pessoal

# Listar contas salvas
ccm list-accounts

# Trocar para uma conta salva
ccm switch-account trabalho

# Ver qual conta está ativa no momento
ccm current-account

# Apagar uma conta salva
ccm delete-account pessoal
```

#### Trocar conta e provedor ao mesmo tempo

```bash
# Formato: ccm <modelo>:<conta>
eval "$(ccm claude:trabalho)"   # Trocar para a conta 'trabalho' e usar Claude
ccc claude:pessoal              # Trocar para 'pessoal' e abrir o Claude Code
```

---

## Configuração completa

### Localização do arquivo de configuração

```
~/.ccm_config
```

### Todas as variáveis disponíveis

```bash
# ── Idioma ──────────────────────────────────────────────────────
CCM_LANGUAGE=en          # en (inglês) ou zh (chinês)

# ── Chaves de API ───────────────────────────────────────────────
DEEPSEEK_API_KEY=sk-...
KIMI_API_KEY=sk-...
GLM_API_KEY=...
QWEN_API_KEY=sk-...
MINIMAX_API_KEY=...
ARK_API_KEY=...              # Doubao / Seed
STEPFUN_API_KEY=...
OPENROUTER_API_KEY=sk-or-v1-...
CLAUDE_API_KEY=sk-ant-...    # Opcional — API paga do Claude

# ── IDs dos modelos (opcional, só altere se necessário) ─────────
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2.5
KIMI_CN_MODEL=kimi-k2.5
GLM_MODEL=glm-5
QWEN_MODEL=qwen3-max-2026-01-23
MINIMAX_MODEL=MiniMax-M2.5
SEED_MODEL=ark-code-latest
STEPFUN_MODEL=step-3.5-flash
CLAUDE_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-6
HAIKU_MODEL=claude-haiku-4-5-20251001
```

### Atualizar IDs dos modelos

Quando o CCM lança uma nova versão com IDs de modelos atualizados:

```bash
ccm update-config    # Atualiza apenas os IDs desatualizados, sem sobrescrever suas chaves
```

---

## Segurança

### O que é exportado

A cada troca de provedor, o CCM exporta exatamente estas 7 variáveis de ambiente:

```
ANTHROPIC_BASE_URL
ANTHROPIC_AUTH_TOKEN
ANTHROPIC_MODEL
ANTHROPIC_DEFAULT_SONNET_MODEL
ANTHROPIC_DEFAULT_OPUS_MODEL
ANTHROPIC_DEFAULT_HAIKU_MODEL
CLAUDE_CODE_SUBAGENT_MODEL
```

As variáveis antigas são apagadas antes de cada troca (`unset`) para evitar conflitos.

### Mascaramento no status

O comando `ccm status` nunca exibe chaves em texto puro. Sempre mostra apenas os primeiros e últimos 4 caracteres:

```
DEEPSEEK_API_KEY: [set] sk-ab...ef12
```

### Validação de formato

O CCM avisa (sem bloquear) quando o formato de uma chave não corresponde ao padrão esperado do provedor:

- **Anthropic/Claude** → deve começar com `sk-ant-`
- **DeepSeek** → `sk-` seguido de 32+ caracteres alfanuméricos
- **OpenRouter** → deve começar com `sk-or-v1-`
- **Kimi** → deve começar com `sk-`

Exemplo:
```
⚠️  Warning: the deepseek API key format looks unexpected.
   Authentication may fail — check the key in ~/.ccm_config
```

### Proteção do arquivo de configuração

```bash
chmod 600 ~/.ccm_config    # Apenas seu usuário pode ler
```

O instalador faz isso automaticamente. Se precisar refazer:

```bash
chmod 600 ~/.ccm_config
```

---

## Uso sem instalação (diretamente do repositório)

Se você não quiser instalar, pode usar os scripts diretamente:

```bash
# Trocar provedor (aplica no shell atual via eval)
eval "$(./ccm.sh glm global)"
eval "$(./ccm.sh deepseek)"

# Trocar e abrir o Claude Code
./ccc glm china
./ccc deepseek

# Ver ajuda
./ccm.sh help
```

---

## Referência rápida de comandos

```bash
# ── Troca de provedor ──────────────────────────────────────────
ccm deepseek
ccm kimi [global|china]
ccm glm [global|china]
ccm qwen [global|china]
ccm minimax [global|china]
ccm seed [doubao|glm|deepseek|kimi]
ccm stepfun
ccm claude
ccm open <provedor>

# ── Abrir Claude Code já com o provedor certo ──────────────────
ccc <provedor> [região]
ccc open <provedor>

# ── Keystore (WSL/Windows) ─────────────────────────────────────
ccm keystore set <VARIAVEL>
ccm keystore show <VARIAVEL>
ccm keystore list
ccm keystore delete <VARIAVEL>

# ── Configurações persistentes ─────────────────────────────────
ccm user <provedor> [região]
ccm user reset
ccm project <provedor> [região]
ccm project reset

# ── Contas Claude Pro ──────────────────────────────────────────
ccm save-account <nome>
ccm switch-account <nome>
ccm list-accounts
ccm current-account
ccm delete-account <nome>

# ── Utilitários ────────────────────────────────────────────────
ccm status
ccm config
ccm update-config
ccm help
```

---

## Solução de problemas

### `ccm: command not found`

O instalador injeta uma função no seu arquivo rc. Certifique-se de ter recarregado:

```bash
source ~/.zshrc    # zsh
source ~/.bashrc   # bash
```

### A troca de provedor não persiste após abrir um novo terminal

Isso é esperado — as variáveis de ambiente valem apenas para a sessão atual. Para um padrão persistente, use:

```bash
ccm user glm global    # Define GLM como padrão em ~/.claude/settings.json
```

### `❌ Please configure DEEPSEEK_API_KEY`

A chave não está no `~/.ccm_config` nem no keystore. Para resolver:

```bash
# Opção 1: adicionar ao arquivo de configuração
ccm config
# (adicione a linha: DEEPSEEK_API_KEY=sk-...)

# Opção 2: armazenar no keystore (WSL/Windows)
ccm keystore set DEEPSEEK_API_KEY
```

### `⚠️ Warning: the deepseek API key format looks unexpected`

O CCM detectou que o formato da chave não corresponde ao padrão esperado. O comando continuou funcionando, mas se a autenticação falhar, verifique se copiou a chave corretamente.

### `ccm keystore is only available in WSL (Windows)`

O keystore usa o Windows DPAPI via PowerShell, que só está disponível em WSL. Se você usa Linux nativo, proteja o arquivo de configuração com:

```bash
chmod 600 ~/.ccm_config
```

---

## Novidades desta versão (fork)

Esta versão é um fork do projeto original com foco em segurança e qualidade:

### Segurança (P0)

- **Keystore Windows DPAPI** — armazene API keys criptografadas em `%APPDATA%\ccm\credentials\` em vez de texto puro em `~/.ccm_config`
- **Validação de formato de API keys** — aviso não-fatal quando o formato não corresponde ao padrão do provedor
- **Detecção estendida de placeholders** — rejeita automaticamente valores como `your_api_key_here`, `api_key_here`, strings com menos de 16 caracteres, etc.
- **Sanitização do Python inline** — valores sensíveis são passados via variáveis de ambiente para subprocessos Python, evitando quebras com tokens contendo aspas, barras ou newlines

---

## Licença

MIT — veja [LICENSE](LICENSE) para detalhes.
