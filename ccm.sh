#!/bin/bash
############################################################
# Claude Code Model Switcher (ccm) - 独立版本
# ---------------------------------------------------------
# 功能: 在不同AI模型之间快速切换
# 支持: Claude, Deepseek, GLM4.7, KIMI2
# 作者: Peng
# 版本: 2.3.0
############################################################

# 脚本颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 颜色控制（用于账号管理命令的输出）
# 自动检测：如果stdout不是终端（被管道或eval捕获），则禁用颜色
# 这修复了 issue #8: (eval):1: bad pattern: ^[[1
if [[ ! -t 1 ]]; then
    NO_COLOR=true
else
    NO_COLOR=false
fi

# 根据NO_COLOR设置颜色（账号管理函数使用）
set_no_color() {
    if [[ "$NO_COLOR" == "true" ]]; then
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        NC=''
    fi
}

# 如果检测到需要禁用颜色，立即应用
if [[ "$NO_COLOR" == "true" ]]; then
    set_no_color
fi

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

OS_TYPE=$(detect_os)

# 配置文件路径
CONFIG_FILE="$HOME/.ccm_config"
ACCOUNTS_FILE="$HOME/.ccm_accounts"
CLAUDE_CREDENTIALS_FILE="$HOME/.claude/.credentials.json"

# Keychain service name (override with CCM_KEYCHAIN_SERVICE)
KEYCHAIN_SERVICE="${CCM_KEYCHAIN_SERVICE:-Claude Code-credentials}"

# 多语言支持
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
LANG_DIR="$SCRIPT_DIR/lang"

# 加载翻译
load_translations() {
    local lang_code="${1:-en}"
    local lang_file="$LANG_DIR/${lang_code}.json"

    # 如果语言文件不存在，默认使用英语
    if [[ ! -f "$lang_file" ]]; then
        lang_code="en"
        lang_file="$LANG_DIR/en.json"
    fi

    # 如果英语文件也不存在，使用内置英文
    if [[ ! -f "$lang_file" ]]; then
        return 0
    fi

    # 清理现有翻译变量
    unset $(set | grep '^TRANS_' | LC_ALL=C cut -d= -f1) 2>/dev/null || true

    # 读取JSON文件并解析到变量
    if [[ -f "$lang_file" ]]; then
        local temp_file=$(mktemp)
        # 提取键值对到临时文件，使用更健壮的方法
        grep -o '"[^"]*":[[:space:]]*"[^"]*"' "$lang_file" | sed 's/^"\([^"]*\)":[[:space:]]*"\([^"]*\)"$/\1|\2/' > "$temp_file"

        # 读取临时文件并设置变量（使用TRANS_前缀）
        while IFS='|' read -r key value; do
            if [[ -n "$key" && -n "$value" ]]; then
                # 处理转义字符
                value="${value//\\\"/\"}"
                value="${value//\\\\/\\}"
                # 使用eval设置动态变量名
                eval "TRANS_${key}=\"\$value\""
            fi
        done < "$temp_file"

        rm -f "$temp_file"
    fi
}

# 获取翻译文本
t() {
    local key="$1"
    local default="${2:-$key}"
    local var_name="TRANS_${key}"
    local value
    eval "value=\"\${${var_name}:-}\""
    echo "${value:-$default}"
}

# 检测系统语言
detect_language() {
    # 首先检查环境变量LANG
    local sys_lang="${LANG:-}"
    if [[ "$sys_lang" =~ ^zh ]]; then
        echo "zh"
    else
        echo "en"
    fi
}

# 智能加载配置：环境变量优先，配置文件补充
load_config() {
    # 初始化语言
    local lang_preference="${CCM_LANGUAGE:-$(detect_language)}"
    load_translations "$lang_preference"

    # 创建配置文件（如果不存在）
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# CCM 配置文件
# 请替换为你的实际API密钥
# 注意：环境变量中的API密钥优先级高于此文件

# 语言设置 (en: English, zh: 中文)
CCM_LANGUAGE=en

# Deepseek
DEEPSEEK_API_KEY=sk-your-deepseek-api-key

# GLM (智谱清言)
GLM_API_KEY=your-glm-api-key

# KIMI (月之暗面)
KIMI_API_KEY=your-kimi-api-key

# MiniMax
MINIMAX_API_KEY=your-minimax-api-key

# 豆包 Seed-Code (字节跳动)
ARK_API_KEY=your-ark-api-key

# Qwen（阿里云 DashScope）
QWEN_API_KEY=your-qwen-api-key

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# OpenRouter
OPENROUTER_API_KEY=your-openrouter-api-key

# —— 可选：模型ID覆盖（不设置则使用下方默认）——
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-for-coding
KIMI_CN_MODEL=kimi-k2.5
QWEN_MODEL=qwen3-max-2026-01-23
GLM_MODEL=glm-4.7
CLAUDE_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-5-20251101
HAIKU_MODEL=claude-haiku-4-5-20251001
MINIMAX_MODEL=MiniMax-M2.1
SEED_MODEL=ark-code-latest

EOF
        echo -e "${YELLOW}⚠️  $(t 'config_created'): $CONFIG_FILE${NC}" >&2
        echo -e "${YELLOW}   $(t 'edit_file_to_add_keys')${NC}" >&2
        echo -e "${GREEN}🚀 Using default experience keys for now...${NC}" >&2
        # Don't return 1 - continue with default fallback keys
    fi
    
    # 首先读取语言设置
    if [[ -f "$CONFIG_FILE" ]]; then
        local config_lang
        config_lang=$(grep -E "^[[:space:]]*CCM_LANGUAGE[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null | head -1 | LC_ALL=C cut -d'=' -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [[ -n "$config_lang" && -z "$CCM_LANGUAGE" ]]; then
            export CCM_LANGUAGE="$config_lang"
            lang_preference="$config_lang"
            load_translations "$lang_preference"
        fi
    fi

    # 智能加载：只有环境变量未设置的键才从配置文件读取
    local temp_file=$(mktemp)
    local raw
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        # 去掉回车、去掉行内注释并修剪两端空白
        raw=${raw%$'\r'}
        # 跳过注释和空行
        [[ "$raw" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$raw" ]] && continue
        # 删除行内注释（从第一个 # 起）
        local line="${raw%%#*}"
        # 去掉首尾空白
        line=$(echo "$line" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [[ -z "$line" ]] && continue
        
        # 解析 export KEY=VALUE 或 KEY=VALUE
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            local key="${BASH_REMATCH[2]}"
            local value="${BASH_REMATCH[3]}"
            # 去掉首尾空白
            value=$(echo "$value" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
            # 仅当环境未设置、为空或为占位符时才应用
            local env_value="${!key}"
            local lower_env_value
            lower_env_value=$(printf '%s' "$env_value" | tr '[:upper:]' '[:lower:]')
            # 检查是否为占位符值
            local is_placeholder=false
            if [[ "$lower_env_value" == *"your"* && "$lower_env_value" == *"api"* && "$lower_env_value" == *"key"* ]]; then
                is_placeholder=true
            fi
            if [[ -n "$key" && ( -z "$env_value" || "$env_value" == "" || "$is_placeholder" == "true" ) ]]; then
                echo "export $key=$value" >> "$temp_file"
            fi
        fi
    done < "$CONFIG_FILE"
    
    # 执行临时文件中的export语句
    if [[ -s "$temp_file" ]]; then
        source "$temp_file"
    fi
    rm -f "$temp_file"
}

# 创建默认配置文件
create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# CCM 配置文件
# 请替换为你的实际API密钥
# 注意：环境变量中的API密钥优先级高于此文件

# 语言设置 (en: English, zh: 中文)
CCM_LANGUAGE=en

# Deepseek
DEEPSEEK_API_KEY=sk-your-deepseek-api-key

# GLM (智谱清言)
GLM_API_KEY=your-glm-api-key

# KIMI (月之暗面)
KIMI_API_KEY=your-kimi-api-key

# MiniMax
MINIMAX_API_KEY=your-minimax-api-key

# 豆包 Seed-Code (字节跳动)
ARK_API_KEY=your-ark-api-key

# Qwen（阿里云 DashScope）
QWEN_API_KEY=your-qwen-api-key

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# OpenRouter
OPENROUTER_API_KEY=your-openrouter-api-key

# —— 可选：模型ID覆盖（不设置则使用下方默认）——
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-for-coding
KIMI_CN_MODEL=kimi-k2.5
QWEN_MODEL=qwen3-max-2026-01-23
GLM_MODEL=glm-4.7
CLAUDE_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-5-20251101
HAIKU_MODEL=claude-haiku-4-5-20251001
MINIMAX_MODEL=MiniMax-M2.1
SEED_MODEL=ark-code-latest

EOF
    echo -e "${YELLOW}⚠️  $(t 'config_created'): $CONFIG_FILE${NC}" >&2
    echo -e "${YELLOW}   $(t 'edit_file_to_add_keys')${NC}" >&2
}

# 判断值是否为有效（非空且非占位符）
is_effectively_set() {
    local v="$1"
    if [[ -z "$v" ]]; then
        return 1
    fi
    local lower
    lower=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
        *your-*-api-key)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# 安全掩码工具
mask_token() {
    local t="$1"
    local n=${#t}
    if [[ -z "$t" ]]; then
        echo "[$(t 'not_set')]"
        return
    fi
    if (( n <= 8 )); then
        echo "[$(t 'set')] ****"
    else
        echo "[$(t 'set')] ${t:0:4}...${t:n-4:4}"
    fi
}

mask_presence() {
    local v_name="$1"
    local v_val="${!v_name}"
    if is_effectively_set "$v_val"; then
        echo "[$(t 'set')]"
    else
        echo "[$(t 'not_set')]"
    fi
}

# 输出 Claude Code 默认模型环境变量
emit_default_models() {
    local sonnet="$1"
    local opus="$2"
    local haiku="$3"
    echo "export ANTHROPIC_DEFAULT_SONNET_MODEL='${sonnet}'"
    echo "export ANTHROPIC_DEFAULT_OPUS_MODEL='${opus}'"
    echo "export ANTHROPIC_DEFAULT_HAIKU_MODEL='${haiku}'"
}

emit_subagent_model() {
    local model="$1"
    echo "export CLAUDE_CODE_SUBAGENT_MODEL='${model}'"
}

emit_default_models_from_pair() {
    local primary="$1"
    local small="$2"
    local haiku="${small:-$primary}"
    emit_default_models "$primary" "$primary" "$haiku"
}

# Normalize region input to "global" or "china"
normalize_region() {
    local region="${1:-global}"
    case "$region" in
        ""|"global"|"g"|"intl"|"international"|"overseas")
            echo "global"
            ;;
        "china"|"cn"|"zh"|"domestic")
            echo "china"
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================
# Claude Pro 账号管理功能
# ============================================

project_settings_path() {
    echo "$PWD/.claude/settings.local.json"
}

backup_project_settings() {
    local path="$1"
    local ts
    ts="$(date "+%Y%m%d-%H%M%S")"
    cp -f "$path" "${path}.bak.${ts}"
}

project_write_glm_settings() {
    local region_input="${1:-global}"
    local region
    if ! region="$(normalize_region "$region_input")"; then
        echo -e "${RED}❌ $(t 'unknown_option'): $region_input${NC}" >&2
        echo -e "${YELLOW}💡 Usage: ccm project glm [global|china]${NC}" >&2
        return 1
    fi
    local settings_path
    settings_path="$(project_settings_path)"
    local settings_dir
    settings_dir="$(dirname "$settings_path")"

    if ! is_effectively_set "$GLM_API_KEY"; then
        echo -e "${RED}❌ Please configure GLM_API_KEY before writing project settings${NC}" >&2
        return 1
    fi

    local glm_model="${GLM_MODEL:-glm-4.7}"
    local base_url=""
    case "$region" in
        "global")
            base_url="https://api.z.ai/api/anthropic"
            ;;
        "china")
            base_url="https://open.bigmodel.cn/api/anthropic"
            ;;
    esac

    if [[ -f "$settings_path" ]]; then
        if ! grep -q '"ccmManaged"[[:space:]]*:[[:space:]]*true' "$settings_path"; then
            backup_project_settings "$settings_path"
        fi
    fi

    mkdir -p "$settings_dir"
  cat > "$settings_path" <<EOF
{
  "ccmManaged": true,
  "env": {
    "ANTHROPIC_BASE_URL": "${base_url}",
    "ANTHROPIC_AUTH_TOKEN": "${GLM_API_KEY}",
    "ANTHROPIC_MODEL": "${glm_model}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${glm_model}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${glm_model}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${glm_model}",
    "CLAUDE_CODE_SUBAGENT_MODEL": "${glm_model}"
  }
}
EOF
    chmod 600 "$settings_path"
    echo -e "${GREEN}✅ Wrote project settings for GLM (${region}) at:${NC} $settings_path" >&2
    echo -e "${YELLOW}💡 This overrides user settings (e.g. Quotio) for this project only.${NC}" >&2
}

project_reset_settings() {
    local settings_path
    settings_path="$(project_settings_path)"
    if [[ ! -f "$settings_path" ]]; then
        echo -e "${YELLOW}⚠️  No project settings to reset at:${NC} $settings_path" >&2
        return 0
    fi
    if ! grep -q '"ccmManaged"[[:space:]]*:[[:space:]]*true' "$settings_path"; then
        backup_project_settings "$settings_path"
    fi
    rm -f "$settings_path"
    echo -e "${GREEN}✅ Removed project settings:${NC} $settings_path" >&2
    echo -e "${YELLOW}💡 Claude Code will fall back to user settings (e.g. Quotio).${NC}" >&2
}

# 跨平台 base64 编码函数（无换行）
base64_encode_nolinebreak() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        base64
    else
        if base64 --help 2>&1 | grep -q -- '-w'; then
            base64 -w 0
        else
            base64 | tr -d '\n'
        fi
    fi
}

# 跨平台 base64 解码函数
base64_decode() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        base64 -d
    else
        base64 -d
    fi
}

# 跨平台时间格式化（毫秒时间戳 -> 可读时间）
format_epoch_ms() {
    local ms="$1"
    if [[ -z "$ms" ]]; then
        echo "Unknown"
        return 0
    fi
    local seconds=$((ms / 1000))
    if [[ "$OS_TYPE" == "macos" ]]; then
        date -r "$seconds" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown"
    else
        date -d "@$seconds" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown"
    fi
}

# 从 Linux 文件系统读取 Claude Code 凭证
read_linux_credentials() {
    if [[ ! -f "$CLAUDE_CREDENTIALS_FILE" ]]; then
        echo ""
        return 1
    fi

    # 优先使用 jq 提取 claudeAiOauth 对象
    local credentials
    if command -v jq >/dev/null 2>&1; then
        credentials=$(jq -c '.claudeAiOauth' "$CLAUDE_CREDENTIALS_FILE" 2>/dev/null)
    else
        # 降级方案：使用 Python 或 grep（适用于简单情况）
        if command -v python3 >/dev/null 2>&1; then
            credentials=$(python3 -c "import json; f=open('$CLAUDE_CREDENTIALS_FILE'); d=json.load(f); print(json.dumps(d.get('claudeAiOauth', {})))" 2>/dev/null)
        else
            # 最后降级：简单的 grep（可能不完整）
            credentials=$(cat "$CLAUDE_CREDENTIALS_FILE" | grep -o '"claudeAiOauth":{[^}]*}' | sed 's/"claudeAiOauth"://')
        fi
    fi

    if [[ -z "$credentials" || "$credentials" == "null" || "$credentials" == "{}" ]]; then
        echo ""
        return 1
    fi

    echo "$credentials"
    return 0
}

# 从 macOS Keychain 读取 Claude Code 凭证
read_macos_credentials() {
    local credentials
    local -a services=(
        "$KEYCHAIN_SERVICE"
        "Claude Code - credentials"
        "Claude Code"
        "claude"
        "claude.ai"
    )
    for svc in "${services[@]}"; do
        credentials=$(security find-generic-password -s "$svc" -w 2>/dev/null)
        if [[ $? -eq 0 && -n "$credentials" ]]; then
            KEYCHAIN_SERVICE="$svc"
            echo "$credentials"
            return 0
        fi
    done
    echo ""
    return 1
}

# 跨平台凭证读取函数
read_keychain_credentials() {
    case "$OS_TYPE" in
        macos)
            read_macos_credentials
            ;;
        linux)
            read_linux_credentials
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS: $OS_TYPE${NC}" >&2
            return 1
            ;;
    esac
}

# 写入凭证到 Linux 文件系统
write_linux_credentials() {
    local credentials="$1"

    # 确保 .claude 目录存在
    mkdir -p "$(dirname "$CLAUDE_CREDENTIALS_FILE")"

    # 使用 jq 进行更可靠的 JSON 操作
    if command -v jq >/dev/null 2>&1; then
        if [[ -f "$CLAUDE_CREDENTIALS_FILE" ]]; then
            # 更新现有文件，保留其他字段
            jq --argjson oauth "$credentials" '.claudeAiOauth = $oauth' "$CLAUDE_CREDENTIALS_FILE" > "${CLAUDE_CREDENTIALS_FILE}.tmp"
            mv "${CLAUDE_CREDENTIALS_FILE}.tmp" "$CLAUDE_CREDENTIALS_FILE"
        else
            # 创建新文件
            echo "{\"claudeAiOauth\":$credentials}" | jq '.' > "$CLAUDE_CREDENTIALS_FILE"
        fi
    else
        # 降级方案：使用纯 Bash（可能不完美，但可用）
        local existing_content=""
        local mcp_oauth=""

        if [[ -f "$CLAUDE_CREDENTIALS_FILE" ]]; then
            existing_content=$(cat "$CLAUDE_CREDENTIALS_FILE")
            # 提取 mcpOAuth 部分（如果存在）- 更好的正则表达式
            if command -v python3 >/dev/null 2>&1; then
                mcp_oauth=$(python3 -c "import json; f=open('$CLAUDE_CREDENTIALS_FILE'); d=json.load(f); print(json.dumps(d.get('mcpOAuth', {})) if d.get('mcpOAuth') else '')" 2>/dev/null)
            fi
        fi

        # 构建新的 JSON 文件
        if [[ -n "$mcp_oauth" && "$mcp_oauth" != "{}" ]]; then
            # 保留 mcpOAuth
            cat > "$CLAUDE_CREDENTIALS_FILE" << EOF
{"claudeAiOauth":$credentials,"mcpOAuth":$mcp_oauth}
EOF
        else
            # 只有 claudeAiOauth
            cat > "$CLAUDE_CREDENTIALS_FILE" << EOF
{"claudeAiOauth":$credentials}
EOF
        fi
    fi

    chmod 600 "$CLAUDE_CREDENTIALS_FILE"
    echo -e "${BLUE}🔑 $(t 'credentials_written_to_file')${NC}" >&2
    return 0
}

# 写入凭证到 macOS Keychain
write_macos_credentials() {
    local credentials="$1"
    local username="$USER"

    # 先删除现有的凭证
    security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1

    # 添加新凭证
    security add-generic-password -a "$username" -s "$KEYCHAIN_SERVICE" -w "$credentials" >/dev/null 2>&1
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo -e "${BLUE}🔑 凭证已写入 Keychain${NC}" >&2
    else
        echo -e "${RED}❌ 凭证写入 Keychain 失败 (错误码: $result)${NC}" >&2
    fi

    return $result
}

# 跨平台凭证写入函数
write_keychain_credentials() {
    local credentials="$1"

    case "$OS_TYPE" in
        macos)
            write_macos_credentials "$credentials"
            ;;
        linux)
            write_linux_credentials "$credentials"
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS: $OS_TYPE${NC}" >&2
            return 1
            ;;
    esac
}

# 调试函数：验证 Keychain 中的凭证
debug_keychain_credentials() {
    # 根据操作系统显示不同标题
    if [[ "$OS_TYPE" == "macos" ]]; then
        echo -e "${BLUE}🔍 $(t 'credentials_source_keychain')${NC}"
    else
        echo -e "${BLUE}🔍 $(t 'credentials_source_file')${NC}"
    fi

    local credentials=$(read_keychain_credentials)
    if [[ -z "$credentials" ]]; then
        if [[ "$OS_TYPE" == "macos" ]]; then
            echo -e "${RED}❌ Keychain 中没有凭证${NC}"
        else
            echo -e "${RED}❌ $(t 'no_credentials_found')${NC}"
            echo -e "${YELLOW}💡 $(t 'please_login_first')${NC}"
        fi
        return 1
    fi

    # 提取凭证信息
    local subscription=$(echo "$credentials" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
    local expires=$(echo "$credentials" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)
    local access_token_preview=$(echo "$credentials" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4 | head -c 20)

    echo -e "${GREEN}✅ $(t 'credentials_found')：${NC}"
    if [[ "$OS_TYPE" == "macos" ]]; then
        echo "   $(t 'service_name'): $KEYCHAIN_SERVICE"
    else
        echo "   $(t 'file_path'): $CLAUDE_CREDENTIALS_FILE"
    fi
    echo "   $(t 'subscription_type'): ${subscription:-Unknown}"
    if [[ -n "$expires" ]]; then
        local expires_str=$(format_epoch_ms "$expires")
        echo "   $(t 'token_expires'): $expires_str"
    fi
    echo "   $(t 'access_token'): ${access_token_preview}..."

    # 尝试匹配保存的账号
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${BLUE}🔍 $(t 'trying_to_match_accounts')${NC}"
        while IFS=': ' read -r name encoded; do
            name=$(echo "$name" | tr -d '"')
            encoded=$(echo "$encoded" | tr -d '"')
            local saved_creds=$(echo "$encoded" | base64_decode 2>/dev/null)
            if [[ "$saved_creds" == "$credentials" ]]; then
                echo -e "${GREEN}✅ $(t 'matched_account'): $name${NC}"
                return 0
            fi
        done < <(grep --color=never -o '"[^"]*": *"[^"]*"' "$ACCOUNTS_FILE")
        echo -e "${YELLOW}⚠️  $(t 'no_matching_account')${NC}"
    fi
}

# 初始化账号配置文件
init_accounts_file() {
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo "{}" > "$ACCOUNTS_FILE"
        chmod 600 "$ACCOUNTS_FILE"
    fi
}

# 保存当前账号
save_account() {
    # 检查是否需要禁用颜色（用于 eval）
    if [[ "$NO_COLOR" == "true" ]]; then
        set_no_color
    fi
    local account_name="$1"

    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ $(t 'account_name_required')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'usage'): ccm save-account <name>${NC}" >&2
        return 1
    fi

    # 从 Keychain 读取当前凭证
    local credentials
    credentials=$(read_keychain_credentials)
    if [[ -z "$credentials" ]]; then
        echo -e "${RED}❌ $(t 'no_credentials_found')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'please_login_first')${NC}" >&2
        return 1
    fi

    # 初始化账号文件
    init_accounts_file

    # 使用纯 Bash 解析和保存（不依赖 jq）
    local temp_file=$(mktemp)
    local existing_accounts=""

    if [[ -f "$ACCOUNTS_FILE" ]]; then
        existing_accounts=$(cat "$ACCOUNTS_FILE")
    fi

    # 简单的 JSON 更新：如果是空文件或只有 {}，直接写入
    if [[ "$existing_accounts" == "{}" || -z "$existing_accounts" ]]; then
        local encoded_creds=$(echo "$credentials" | base64_encode_nolinebreak)
        cat > "$ACCOUNTS_FILE" << EOF
{
  "$account_name": "$encoded_creds"
}
EOF
    else
        # 读取现有账号，添加新账号
        # 检查账号是否已存在
        if grep -q "\"$account_name\":" "$ACCOUNTS_FILE"; then
            # 更新现有账号
            local encoded_creds=$(echo "$credentials" | base64_encode_nolinebreak)
            # 使用 sed 替换现有条目（跨平台兼容）
            if [[ "$OS_TYPE" == "macos" ]]; then
                sed -i '' "s/\"$account_name\": *\"[^\"]*\"/\"$account_name\": \"$encoded_creds\"/" "$ACCOUNTS_FILE"
            else
                sed -i "s/\"$account_name\": *\"[^\"]*\"/\"$account_name\": \"$encoded_creds\"/" "$ACCOUNTS_FILE"
            fi
        else
            # 添加新账号
            local encoded_creds=$(echo "$credentials" | base64_encode_nolinebreak)
            # 移除最后的 } (使用 macOS 兼容的命令)
            sed '$d' "$ACCOUNTS_FILE" > "$temp_file"
            # 检查是否需要添加逗号
            if grep -q '"' "$temp_file"; then
                echo "," >> "$temp_file"
            fi
            echo "  \"$account_name\": \"$encoded_creds\"" >> "$temp_file"
            echo "}" >> "$temp_file"
            mv "$temp_file" "$ACCOUNTS_FILE"
        fi
    fi

    chmod 600 "$ACCOUNTS_FILE"

    # 提取订阅类型用于显示
    local subscription_type=$(echo "$credentials" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✅ $(t 'account_saved'): $account_name${NC}"
    echo -e "   $(t 'subscription_type'): ${subscription_type:-Unknown}"

    rm -f "$temp_file"
}

# 切换到指定账号
switch_account() {
    # 检查是否需要禁用颜色（用于 eval）
    if [[ "$NO_COLOR" == "true" ]]; then
        set_no_color
    fi
    local account_name="$1"

    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ $(t 'account_name_required')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'usage'): ccm switch-account <name>${NC}" >&2
        return 1
    fi

    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${RED}❌ $(t 'no_accounts_found')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'save_account_first')${NC}" >&2
        return 1
    fi

    # 从文件中读取账号凭证
    local encoded_creds=$(grep -o "\"$account_name\": *\"[^\"]*\"" "$ACCOUNTS_FILE" | cut -d'"' -f4)

    if [[ -z "$encoded_creds" ]]; then
        echo -e "${RED}❌ $(t 'account_not_found'): $account_name${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'use_list_accounts')${NC}" >&2
        return 1
    fi

    # 解码凭证
    local credentials=$(echo "$encoded_creds" | base64_decode)

    # 写入 Keychain
    if write_keychain_credentials "$credentials"; then
        echo -e "${GREEN}✅ $(t 'account_switched'): $account_name${NC}"
        echo -e "${YELLOW}⚠️  $(t 'please_restart_claude_code')${NC}"
    else
        echo -e "${RED}❌ $(t 'failed_to_switch_account')${NC}" >&2
        return 1
    fi
}

# 列出所有已保存的账号
list_accounts() {
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${YELLOW}$(t 'no_accounts_saved')${NC}"
        echo -e "${YELLOW}💡 $(t 'use_save_account')${NC}"
        return 0
    fi

    echo -e "${BLUE}📋 $(t 'saved_accounts'):${NC}"

    # 读取并解析账号列表
    local current_creds=$(read_keychain_credentials)

    # 使用 jq 或 Python 解析 JSON（处理多行 base64 值）
    if command -v jq >/dev/null 2>&1; then
        jq -r 'to_entries[] | "\(.key)|\(.value)"' "$ACCOUNTS_FILE" | while IFS='|' read -r name encoded; do
            # 解码并提取信息
            local creds=$(echo "$encoded" | base64_decode 2>/dev/null)
            local subscription=$(echo "$creds" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
            local expires=$(echo "$creds" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)

            # 检查是否是当前账号
            local is_current=""
            if [[ "$creds" == "$current_creds" ]]; then
                is_current=" ${GREEN}✅ ($(t 'active'))${NC}"
            fi

            # 格式化过期时间
            local expires_str=""
            if [[ -n "$expires" ]]; then
                expires_str=$(format_epoch_ms "$expires")
            fi

            echo -e "   - ${YELLOW}$name${NC} (${subscription:-Unknown}${expires_str:+, expires: $expires_str})$is_current"
        done
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
with open('$ACCOUNTS_FILE') as f:
    data = json.load(f)
    for name, encoded in data.items():
        print(f'{name}|{encoded}')
" | while IFS='|' read -r name encoded; do
            # 解码并提取信息
            local creds=$(echo "$encoded" | base64_decode 2>/dev/null)
            local subscription=$(echo "$creds" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
            local expires=$(echo "$creds" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)

            # 检查是否是当前账号
            local is_current=""
            if [[ "$creds" == "$current_creds" ]]; then
                is_current=" ${GREEN}✅ ($(t 'active'))${NC}"
            fi

            # 格式化过期时间
            local expires_str=""
            if [[ -n "$expires" ]]; then
                expires_str=$(format_epoch_ms "$expires")
            fi

            echo -e "   - ${YELLOW}$name${NC} (${subscription:-Unknown}${expires_str:+, expires: $expires_str})$is_current"
        done
    else
        # 降级方案：仅支持单行 base64 值
        echo -e "${YELLOW}⚠️  $(t 'install_jq_or_python')${NC}"
        grep --color=never -o '"[^"]*": *"[^"]*"' "$ACCOUNTS_FILE" | while IFS=': ' read -r name encoded; do
            name=$(echo "$name" | tr -d '"')
            encoded=$(echo "$encoded" | tr -d '"')
            echo -e "   - ${YELLOW}$name${NC}"
        done
    fi
}

# 删除已保存的账号
delete_account() {
    local account_name="$1"

    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ $(t 'account_name_required')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'usage'): ccm delete-account <name>${NC}" >&2
        return 1
    fi

    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${RED}❌ $(t 'no_accounts_found')${NC}" >&2
        return 1
    fi

    # 检查账号是否存在
    if ! grep -q "\"$account_name\":" "$ACCOUNTS_FILE"; then
        echo -e "${RED}❌ $(t 'account_not_found'): $account_name${NC}" >&2
        return 1
    fi

    # 删除账号（使用临时文件）
    local temp_file=$(mktemp)
    grep -v "\"$account_name\":" "$ACCOUNTS_FILE" > "$temp_file"

    # 清理可能的逗号问题（跨平台兼容）
    if [[ "$OS_TYPE" == "macos" ]]; then
        sed -i '' 's/,\s*}/}/g' "$temp_file"
        sed -i '' 's/}\s*,/}/g' "$temp_file"
    else
        sed -i 's/,\s*}/}/g' "$temp_file"
        sed -i 's/}\s*,/}/g' "$temp_file"
    fi

    mv "$temp_file" "$ACCOUNTS_FILE"
    chmod 600 "$ACCOUNTS_FILE"

    echo -e "${GREEN}✅ $(t 'account_deleted'): $account_name${NC}"
}

# 显示当前账号信息
get_current_account() {
    local credentials=$(read_keychain_credentials)

    if [[ -z "$credentials" ]]; then
        echo -e "${YELLOW}$(t 'no_current_account')${NC}"
        echo -e "${YELLOW}💡 $(t 'please_login_or_switch')${NC}"
        return 1
    fi

    # 提取信息
    local subscription=$(echo "$credentials" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
    local expires=$(echo "$credentials" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)
    local access_token=$(echo "$credentials" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)

    # 格式化过期时间
    local expires_str=""
    if [[ -n "$expires" ]]; then
        expires_str=$(format_epoch_ms "$expires")
    fi

    # 查找账号名称
    local account_name="Unknown"
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        while IFS=': ' read -r name encoded; do
            name=$(echo "$name" | tr -d '"')
            encoded=$(echo "$encoded" | tr -d '"')
            local saved_creds=$(echo "$encoded" | base64_decode 2>/dev/null)
            if [[ "$saved_creds" == "$credentials" ]]; then
                account_name="$name"
                break
            fi
        done < <(grep --color=never -o '"[^"]*": *"[^"]*"' "$ACCOUNTS_FILE")
    fi

    echo -e "${BLUE}📊 $(t 'current_account_info'):${NC}"
    echo "   $(t 'account_name'): ${account_name}"
    echo "   $(t 'subscription_type'): ${subscription:-Unknown}"
    if [[ -n "$expires_str" ]]; then
        echo "   $(t 'token_expires'): ${expires_str}"
    fi
    echo -n "   $(t 'access_token'): "
    mask_token "$access_token"
}

# 显示当前状态（脱敏）
show_status() {
    echo -e "${BLUE}📊 $(t 'current_model_config'):${NC}"
    echo "   BASE_URL: ${ANTHROPIC_BASE_URL:-'Default (Anthropic)'}"
    echo -n "   AUTH_TOKEN: "
    mask_token "${ANTHROPIC_AUTH_TOKEN}"
    echo "   MODEL: ${ANTHROPIC_MODEL:-'$(t "not_set")'}"
    echo "   SUBAGENT_MODEL: ${CLAUDE_CODE_SUBAGENT_MODEL:-'$(t "not_set")'}"
    echo ""
    echo -e "${BLUE}🔧 $(t 'env_vars_status'):${NC}"
    echo "   GLM_API_KEY: $(mask_presence GLM_API_KEY)"
    echo "   KIMI_API_KEY: $(mask_presence KIMI_API_KEY)"
    echo "   MINIMAX_API_KEY: $(mask_presence MINIMAX_API_KEY)"
    echo "   DEEPSEEK_API_KEY: $(mask_presence DEEPSEEK_API_KEY)"
    echo "   ARK_API_KEY: $(mask_presence ARK_API_KEY)"
    echo "   QWEN_API_KEY: $(mask_presence QWEN_API_KEY)"
    echo "   OPENROUTER_API_KEY: $(mask_presence OPENROUTER_API_KEY)"
    echo ""
}

# 清理环境变量
clean_env() {
    unset ANTHROPIC_BASE_URL
    unset ANTHROPIC_API_URL
    unset ANTHROPIC_AUTH_TOKEN
    unset ANTHROPIC_API_KEY
    unset ANTHROPIC_MODEL
    unset ANTHROPIC_SMALL_FAST_MODEL
    unset ANTHROPIC_DEFAULT_SONNET_MODEL
    unset ANTHROPIC_DEFAULT_OPUS_MODEL
    unset ANTHROPIC_DEFAULT_HAIKU_MODEL
    unset CLAUDE_CODE_SUBAGENT_MODEL
    unset API_TIMEOUT_MS
    unset CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
}

# 切换到Deepseek
switch_to_deepseek() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Deepseek $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$DEEPSEEK_API_KEY"; then
        # 官方 Deepseek 的 Anthropic 兼容端点
        export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
        export ANTHROPIC_MODEL="deepseek-chat"
        export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek/deepseek-v3.2"
        export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek/deepseek-v3.2"
        export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek/deepseek-v3.2"
        export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"
        echo -e "${GREEN}✅ $(t 'switched_to') Deepseek（$(t 'official')）${NC}"
    else
        echo -e "${RED}❌ Please configure DEEPSEEK_API_KEY${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# 切换到Claude Sonnet
switch_to_claude() {
    local account_name="$1"

    echo -e "${YELLOW}🔄 切换到 Claude Sonnet 4.5...${NC}"

    # 如果指定了账号，先切换账号
    if [[ -n "$account_name" ]]; then
        echo -e "${BLUE}📝 切换到账号: $account_name${NC}"
        if ! switch_account "$account_name"; then
            return 1
        fi
    fi

    clean_env
    export ANTHROPIC_BASE_URL="https://api.anthropic.com/"
    if is_effectively_set "$CLAUDE_API_KEY"; then
        export ANTHROPIC_AUTH_TOKEN="$CLAUDE_API_KEY"
    fi
    export ANTHROPIC_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="${OPUS_MODEL:-claude-opus-4-5-20251101}"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="${HAIKU_MODEL:-claude-haiku-4-5-20251001}"
    export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"
    echo -e "${GREEN}✅ 已切换到 Claude Sonnet 4.5 (使用 Claude Pro 订阅)${NC}"
    if [[ -n "$account_name" ]]; then
        echo "   $(t 'account'): $account_name"
    fi
    echo "   MODEL: $ANTHROPIC_MODEL"
}


# 切换到GLM
switch_to_glm() {
    local region_input="${1:-global}"
    local region
    if ! region="$(normalize_region "$region_input")"; then
        echo -e "${RED}❌ $(t 'unknown_option'): $region_input${NC}"
        echo -e "${YELLOW}💡 Usage: ccm glm [global|china]${NC}"
        return 1
    fi
    echo -e "${YELLOW}🔄 切换到 GLM（${region}）...${NC}"
    clean_env
    if ! is_effectively_set "$GLM_API_KEY"; then
        echo -e "${RED}❌ Please configure GLM_API_KEY${NC}"
        return 1
    fi
    local base_url=""
    case "$region" in
        "global")
            base_url="https://api.z.ai/api/anthropic"
            ;;
        "china")
            base_url="https://open.bigmodel.cn/api/anthropic"
            ;;
    esac
    local glm_model="${GLM_MODEL:-glm-4.7}"
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="$GLM_API_KEY"
    export ANTHROPIC_MODEL="$glm_model"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$glm_model"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$glm_model"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$glm_model"
    export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"
    echo -e "${GREEN}✅ 已切换到 GLM（${region}）${NC}"
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# 切换到KIMI（全球）
switch_to_kimi() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') KIMI $(t 'model')...${NC}"
    clean_env
    if ! is_effectively_set "$KIMI_API_KEY"; then
        echo -e "${RED}❌ Please configure KIMI_API_KEY${NC}"
        return 1
    fi
    # 海外 Kimi 端点
    export ANTHROPIC_BASE_URL="https://api.moonshot.ai/anthropic"
    export ANTHROPIC_AUTH_TOKEN="$KIMI_API_KEY"
    export ANTHROPIC_MODEL="kimi-for-coding"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="kimi-for-coding"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="kimi-for-coding"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="kimi-for-coding"
    export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"
    echo -e "${GREEN}✅ $(t 'switched_to') KIMI（$(t 'official')）${NC}"
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# 切换到KIMI CN (国内版本)
switch_to_kimi_cn() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') KIMI CN $(t 'model')...${NC}"
    clean_env
    if ! is_effectively_set "$KIMI_API_KEY"; then
        echo -e "${RED}❌ Please configure KIMI_API_KEY${NC}"
        return 1
    fi
    # 国内 Kimi 端点
    export ANTHROPIC_BASE_URL="https://api.moonshot.cn/anthropic"
    export ANTHROPIC_AUTH_TOKEN="$KIMI_API_KEY"
    export ANTHROPIC_MODEL="kimi-k2.5"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="kimi-k2.5"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="kimi-k2.5"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="kimi-k2.5"
    export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"
    echo -e "${GREEN}✅ $(t 'switched_to') KIMI CN（$(t 'official')）${NC}"
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# 切换到 MiniMax
switch_to_minimax() {
    local region_input="${1:-global}"
    local region
    if ! region="$(normalize_region "$region_input")"; then
        echo -e "${RED}❌ $(t 'unknown_option'): $region_input${NC}"
        echo -e "${YELLOW}💡 Usage: ccm minimax [global|china]${NC}"
        return 1
    fi
    echo -e "${YELLOW}🔄 $(t 'switching_to') MiniMax (${region}) $(t 'model')...${NC}"
    clean_env
    if ! is_effectively_set "$MINIMAX_API_KEY"; then
        echo -e "${RED}❌ Please configure MINIMAX_API_KEY${NC}"
        return 1
    fi
    local base_url=""
    case "$region" in
        "global")
            base_url="https://api.minimax.io/anthropic"
            ;;
        "china")
            base_url="https://api.minimaxi.com/anthropic"
            ;;
    esac
    local mm_model="${MINIMAX_MODEL:-MiniMax-M2.1}"
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="$MINIMAX_API_KEY"
    export ANTHROPIC_MODEL="$mm_model"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$mm_model"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$mm_model"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$mm_model"
    export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"
    echo -e "${GREEN}✅ $(t 'switched_to') MiniMax (${region})（$(t 'official')）${NC}"
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# 切换到 Qwen（Coding Plan）
switch_to_qwen() {
    local region_input="${1:-global}"
    local region
    if ! region="$(normalize_region "$region_input")"; then
        echo -e "${RED}❌ $(t 'unknown_option'): $region_input${NC}"
        echo -e "${YELLOW}💡 Usage: ccm qwen [global|china]${NC}"
        return 1
    fi
    echo -e "${YELLOW}🔄 $(t 'switching_to') Qwen (${region}) $(t 'model')...${NC}"
    clean_env
    if ! is_effectively_set "$QWEN_API_KEY"; then
        echo -e "${RED}❌ Please configure QWEN_API_KEY${NC}"
        return 1
    fi
    local base_url=""
    case "$region" in
        "global")
            base_url="https://coding-intl.dashscope.aliyuncs.com/apps/anthropic"
            ;;
        "china")
            base_url="https://coding.dashscope.aliyuncs.com/apps/anthropic"
            ;;
    esac
    local qwen_model="${QWEN_MODEL:-qwen3-max-2026-01-23}"
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="$QWEN_API_KEY"
    export ANTHROPIC_MODEL="$qwen_model"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$qwen_model"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$qwen_model"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen3-coder-plus"
    export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"
    echo -e "${GREEN}✅ $(t 'switched_to') Qwen (${region})（$(t 'official')）${NC}"
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# 切换到豆包 Seed-Code (Doubao)
switch_to_seed() {
    local variant="${1:-}"
    echo -e "${YELLOW}🔄 $(t 'switching_to') 豆包 Seed-Code $(t 'model')...${NC}"
    clean_env
    if ! is_effectively_set "$ARK_API_KEY"; then
        echo -e "${RED}❌ Please configure ARK_API_KEY${NC}"
        return 1
    fi
    # 官方豆包 Seed-Code
    export ANTHROPIC_BASE_URL="https://ark.cn-beijing.volces.com/api/coding"
    export ANTHROPIC_AUTH_TOKEN="$ARK_API_KEY"

    local seed_model=""
    case "$variant" in
        ""|"default")
            seed_model="${SEED_MODEL:-ark-code-latest}"
            ;;
        "doubao"|"seed")
            seed_model="doubao-seed-code"
            ;;
        "glm"|"glm4"|"glm4.7")
            seed_model="glm-4.7"
            ;;
        "deepseek"|"ds")
            seed_model="deepseek-v3.2"
            ;;
        "kimi"|"kimi2"|"kimi-k2.5")
            seed_model="kimi-k2.5"
            ;;
        *)
            echo -e "${RED}❌ $(t 'unknown_option'): seed $variant${NC}"
            echo -e "${YELLOW}💡 Usage: ccm seed [doubao|glm|deepseek|kimi]${NC}"
            return 1
            ;;
    esac
    export ANTHROPIC_MODEL="$seed_model"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$seed_model"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$seed_model"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$seed_model"
    export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"
    echo -e "${GREEN}✅ $(t 'switched_to') Seed-Code（$(t 'official')）${NC}"
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}🔧 $(t 'switching_info') v2.3.0${NC}"
    echo ""
    echo -e "${YELLOW}$(t 'usage'):${NC} $(basename "$0") [options]"
    echo ""
    echo -e "${YELLOW}$(t 'model_options'):${NC}"
    echo "  deepseek, ds            - env deepseek"
    echo "  kimi [global|china]     - env kimi (default: global)"
    echo "  qwen [global|china]     - env qwen (default: global)"
    echo "  glm [global|china]      - env glm (default: global)"
    echo "  minimax [global|china]  - env minimax (default: global)"
    echo "  seed [doubao|glm|deepseek|kimi] - env 豆包 Seed-Code"
    echo "  claude, sonnet, s       - env claude (official)"
    echo "  open <provider>         - env OpenRouter (run 'ccm open' for help)"
    echo ""
    echo -e "${YELLOW}Claude Pro Account Management:${NC}"
    echo "  save-account <name>     - Save current Claude Pro account"
    echo "  switch-account <name>   - Switch to saved account"
    echo "  list-accounts           - List all saved accounts"
    echo "  delete-account <name>   - Delete saved account"
    echo "  current-account         - Show current account info"
    echo "  claude:account         - Switch account and use Claude (Sonnet)"
    echo ""
    echo -e "${YELLOW}$(t 'tool_options'):${NC}"
    echo "  status, st       - $(t 'show_current_config')"
    echo "  env [model]      - $(t 'output_export_only')"
    echo "  config, cfg      - $(t 'edit_config_file')"
    echo "  help, h          - $(t 'show_help')"
    echo ""
    echo -e "${YELLOW}$(t 'examples'):${NC}"
    echo "  eval \"\$(ccm deepseek)\"                   # Apply in current shell (recommended)"
    echo "  eval \"\$(ccm kimi china)\"              # Kimi CN"
    echo "  eval \"\$(ccm qwen global)\"             # Qwen global (Coding Plan)"
    echo "  eval \"\$(ccm seed kimi)\"               # 豆包 Seed-Code (kimi)"
    echo "  eval \"\$(ccm open kimi)\"               # OpenRouter kimi"
    echo ""
    echo "  project glm [global|china] - write .claude/settings.local.json for GLM (project-only)"
    echo "  project reset      - remove project override (use user settings)"
    echo "  $(basename "$0") status                      # Check current status (masked)"
    echo "  $(basename "$0") save-account work           # Save current account as 'work'"
    echo ""
    echo -e "${YELLOW}支持的模型:${NC}"
    echo "  🌙 KIMI Global          - kimi-for-coding (api.moonshot.ai/anthropic)"
    echo "  🌕 KIMI China           - kimi-k2.5 (api.moonshot.cn/anthropic)"
    echo "  🤖 Deepseek             - deepseek-chat (api.deepseek.com/anthropic)"
    echo "  🌰 豆包 Seed-Code       - ark-code-latest (ark.cn-beijing.volces.com/api/coding)"
    echo "  🎯 MiniMax              - MiniMax-M2.1 (api.minimax.io / api.minimaxi.com)"
    echo "  🐪 Qwen                 - qwen3-max-2026-01-23 / qwen3-coder-plus (Coding Plan)"
    echo "  🇨🇳 GLM                 - glm-4.7 (api.z.ai / open.bigmodel.cn)"
    echo "  🧠 Claude Sonnet 4.5    - claude-sonnet-4-5-20250929"
}

# 将缺失的模型ID覆盖项追加到配置文件（仅追加缺失项，不覆盖已存在的配置）
ensure_model_override_defaults() {
    local -a pairs=(
        "DEEPSEEK_MODEL=deepseek-chat"
        "KIMI_MODEL=kimi-for-coding"
        "KIMI_CN_MODEL=kimi-k2.5"
        "MINIMAX_MODEL=MiniMax-M2.1"
        "SEED_MODEL=ark-code-latest"
        "QWEN_MODEL=qwen3-max-2026-01-23"
        "GLM_MODEL=glm-4.7"
        "CLAUDE_MODEL=claude-sonnet-4-5-20250929"
        "OPUS_MODEL=claude-opus-4-5-20251101"
        "HAIKU_MODEL=claude-haiku-4-5-20251001"
    )
    local added_header=0
    for pair in "${pairs[@]}"; do
        local key="${pair%%=*}"
        local default="${pair#*=}"
        if ! grep -Eq "^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null; then
            if [[ $added_header -eq 0 ]]; then
                {
                    echo ""
                    echo "# ---- CCM model ID overrides (auto-added) ----"
                } >> "$CONFIG_FILE"
                added_header=1
            fi
            printf "%s=%s\n" "$key" "$default" >> "$CONFIG_FILE"
        fi
    done
}

# 编辑配置文件
edit_config() {
    # 确保配置文件存在
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}📝 $(t 'config_created'): $CONFIG_FILE${NC}"
        create_default_config
    fi

    # 追加缺失的模型ID覆盖默认值（不触碰已有键）
    ensure_model_override_defaults

    echo -e "${BLUE}🔧 $(t 'opening_config_file')...${NC}"
    echo -e "${YELLOW}$(t 'config_file_path'): $CONFIG_FILE${NC}"
    
    # 按优先级尝试不同的编辑器
    if command -v cursor >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_cursor')${NC}"
        cursor "$CONFIG_FILE" &
        echo -e "${YELLOW}💡 $(t 'config_opened') Cursor $(t 'opened_edit_save')${NC}"
    elif command -v code >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_vscode')${NC}"
        code "$CONFIG_FILE" &
        echo -e "${YELLOW}💡 $(t 'config_opened') VS Code $(t 'opened_edit_save')${NC}"
    elif [[ "$OSTYPE" == "darwin"* ]] && command -v open >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_default_editor')${NC}"
        open "$CONFIG_FILE"
        echo -e "${YELLOW}💡 $(t 'config_opened_default')${NC}"
    elif command -v vim >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_vim')${NC}"
        vim "$CONFIG_FILE"
    elif command -v nano >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_nano')${NC}"
        nano "$CONFIG_FILE"
    else
        echo -e "${RED}❌ $(t 'no_editor_found')${NC}"
        echo -e "${YELLOW}$(t 'edit_manually'): $CONFIG_FILE${NC}"
        echo -e "${YELLOW}$(t 'install_editor'): cursor, code, vim, nano${NC}"
        return 1
    fi
}

# 仅输出 export 语句的环境设置（用于 eval）
show_open_help() {
    echo -e "${YELLOW}OpenRouter:${NC}"
    echo "  ccm open <provider>"
    echo ""
    echo -e "${YELLOW}Supported providers:${NC}"
    echo "  claude (default), deepseek, kimi, glm, qwen, minimax"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  eval \"\$(ccm open claude)\""
    echo "  eval \"\$(ccm open kimi)\""
}

emit_openrouter_exports() {
    local provider="${1:-}"
    # 加载配置以便进行存在性判断（环境变量优先，不打印密钥）
    load_config || return 1

    if ! is_effectively_set "$OPENROUTER_API_KEY"; then
        echo -e "${RED}❌ Please configure OPENROUTER_API_KEY${NC}" >&2
        return 1
    fi
    if [[ -z "$provider" ]]; then
        show_open_help >&2
        return 1
    fi

    local model=""
    local small=""
    local default_sonnet=""
    local default_opus=""
    local default_haiku=""

    case "$provider" in
        "claude"|"anthropic"|"default")
            model="anthropic/claude-sonnet-4.5"
            small="anthropic/claude-haiku-4.5"
            default_sonnet="anthropic/claude-sonnet-4.5"
            default_opus="anthropic/claude-opus-4.5"
            default_haiku="anthropic/claude-haiku-4.5"
            ;;
        "kimi")
            model="moonshotai/kimi-k2.5"
            small="moonshotai/kimi-k2.5"
            default_sonnet="$model"
            default_opus="$model"
            default_haiku="$model"
            ;;
        "deepseek"|"ds")
            model="deepseek/deepseek-v3.2"
            small="deepseek/deepseek-v3.2"
            default_sonnet="$model"
            default_opus="$model"
            default_haiku="$model"
            ;;
        "glm"|"glm4"|"glm4.7")
            model="z-ai/glm-4.7"
            small="z-ai/glm-4.7"
            default_sonnet="$model"
            default_opus="$model"
            default_haiku="$model"
            ;;
        "qwen")
            model="qwen/qwen3-coder-next"
            small="qwen/qwen3-coder-next"
            default_sonnet="qwen/qwen3-coder-next"
            default_opus="qwen/qwen3-coder-plus"
            default_haiku="qwen/qwen3-coder-next"
            ;;
        "minimax"|"mm")
            model="minimax/minimax-m2.1"
            small="minimax/minimax-m2.1"
            default_sonnet="$model"
            default_opus="$model"
            default_haiku="$model"
            ;;
        *)
            echo -e "${RED}❌ $(t 'unknown_option'): open $provider${NC}" >&2
            show_open_help >&2
            return 1
            ;;
    esac

    local prelude="unset ANTHROPIC_BASE_URL ANTHROPIC_API_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_SUBAGENT_MODEL API_TIMEOUT_MS CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
    echo "$prelude"
    echo "export ANTHROPIC_BASE_URL='https://openrouter.ai/api'"
    echo "export ANTHROPIC_API_URL='https://openrouter.ai/api'"
    echo "if [ -z \"\${OPENROUTER_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
    echo "export ANTHROPIC_AUTH_TOKEN=\"\${OPENROUTER_API_KEY}\""
    echo "export ANTHROPIC_API_KEY=''"
    echo "export ANTHROPIC_MODEL='${model}'"
    echo "export ANTHROPIC_SMALL_FAST_MODEL='${small}'"
    emit_default_models "$default_sonnet" "$default_opus" "$default_haiku"
    emit_subagent_model "$model"
}

emit_env_exports() {
    local target="$1"
    local arg="${2:-}"
    # 加载配置以便进行存在性判断（环境变量优先，不打印密钥）
    load_config || return 1

    # 通用前导：清理旧变量
    local prelude="unset ANTHROPIC_BASE_URL ANTHROPIC_API_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_SUBAGENT_MODEL API_TIMEOUT_MS CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"

    case "$target" in
        "open")
            emit_openrouter_exports "$arg"
            ;;
        "deepseek"|"ds")
            if is_effectively_set "$DEEPSEEK_API_KEY"; then
                echo "$prelude"
                echo "export ANTHROPIC_BASE_URL='https://api.deepseek.com/anthropic'"
                echo "if [ -z \"\${DEEPSEEK_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${DEEPSEEK_API_KEY}\""
                local ds_model="${DEEPSEEK_MODEL:-deepseek-chat}"
                echo "export ANTHROPIC_MODEL='${ds_model}'"
                emit_default_models "deepseek/deepseek-v3.2" "deepseek/deepseek-v3.2" "deepseek/deepseek-v3.2"
                emit_subagent_model "$ds_model"
            else
                echo -e "${RED}❌ Please configure DEEPSEEK_API_KEY${NC}" >&2
                return 1
            fi
            ;;
        "kimi"|"kimi2"|"kimi-cn")
            if ! is_effectively_set "$KIMI_API_KEY"; then
                echo -e "${RED}❌ Please configure KIMI_API_KEY${NC}" >&2
                return 1
            fi
            local region_input="$arg"
            if [[ "$target" == "kimi-cn" ]]; then
                region_input="china"
            fi
            local region
            if ! region="$(normalize_region "$region_input")"; then
                echo -e "${RED}❌ $(t 'unknown_option'): $region_input${NC}" >&2
                echo -e "${YELLOW}💡 Usage: ccm kimi [global|china]${NC}" >&2
                return 1
            fi
            local kimi_base_url=""
            local kimi_model=""
            if [[ "$region" == "global" ]]; then
                kimi_base_url="https://api.moonshot.ai/anthropic"
                kimi_model="${KIMI_MODEL:-kimi-for-coding}"
            else
                kimi_base_url="https://api.moonshot.cn/anthropic"
                kimi_model="${KIMI_CN_MODEL:-kimi-k2.5}"
            fi
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='${kimi_base_url}'"
            echo "if [ -z \"\${KIMI_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            echo "export ANTHROPIC_AUTH_TOKEN=\"\${KIMI_API_KEY}\""
            echo "export ANTHROPIC_MODEL='${kimi_model}'"
            emit_default_models "$kimi_model" "$kimi_model" "$kimi_model"
            emit_subagent_model "$kimi_model"
            ;;
        "qwen")
            if ! is_effectively_set "$QWEN_API_KEY"; then
                echo -e "${RED}❌ Please configure QWEN_API_KEY${NC}" >&2
                return 1
            fi
            local qwen_region
            if ! qwen_region="$(normalize_region "$arg")"; then
                echo -e "${RED}❌ $(t 'unknown_option'): $arg${NC}" >&2
                echo -e "${YELLOW}💡 Usage: ccm qwen [global|china]${NC}" >&2
                return 1
            fi
            local qwen_base_url=""
            case "$qwen_region" in
                "global")
                    qwen_base_url="https://coding-intl.dashscope.aliyuncs.com/apps/anthropic"
                    ;;
                "china")
                    qwen_base_url="https://coding.dashscope.aliyuncs.com/apps/anthropic"
                    ;;
            esac
            local qwen_model="${QWEN_MODEL:-qwen3-max-2026-01-23}"
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='${qwen_base_url}'"
            echo "if [ -z \"\${QWEN_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            echo "export ANTHROPIC_AUTH_TOKEN=\"\${QWEN_API_KEY}\""
            echo "export ANTHROPIC_MODEL='${qwen_model}'"
            emit_default_models "$qwen_model" "$qwen_model" "qwen3-coder-plus"
            emit_subagent_model "$qwen_model"
            ;;
        "glm"|"glm4"|"glm4.6"|"glm4.7")
            if ! is_effectively_set "$GLM_API_KEY"; then
                echo -e "${RED}❌ Please configure GLM_API_KEY${NC}" >&2
                return 1
            fi
            local glm_region
            if ! glm_region="$(normalize_region "$arg")"; then
                echo -e "${RED}❌ $(t 'unknown_option'): $arg${NC}" >&2
                echo -e "${YELLOW}💡 Usage: ccm glm [global|china]${NC}" >&2
                return 1
            fi
            local glm_base_url=""
            case "$glm_region" in
                "global")
                    glm_base_url="https://api.z.ai/api/anthropic"
                    ;;
                "china")
                    glm_base_url="https://open.bigmodel.cn/api/anthropic"
                    ;;
            esac
            local glm_model="${GLM_MODEL:-glm-4.7}"
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='${glm_base_url}'"
            echo "if [ -z \"\${GLM_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            echo "export ANTHROPIC_AUTH_TOKEN=\"\${GLM_API_KEY}\""
            echo "export ANTHROPIC_MODEL='${glm_model}'"
            emit_default_models "$glm_model" "$glm_model" "$glm_model"
            emit_subagent_model "$glm_model"
            ;;
        "minimax"|"mm")
            if ! is_effectively_set "$MINIMAX_API_KEY"; then
                echo -e "${RED}❌ Please configure MINIMAX_API_KEY${NC}" >&2
                return 1
            fi
            local mm_region
            if ! mm_region="$(normalize_region "$arg")"; then
                echo -e "${RED}❌ $(t 'unknown_option'): $arg${NC}" >&2
                echo -e "${YELLOW}💡 Usage: ccm minimax [global|china]${NC}" >&2
                return 1
            fi
            local mm_base_url=""
            case "$mm_region" in
                "global")
                    mm_base_url="https://api.minimax.io/anthropic"
                    ;;
                "china")
                    mm_base_url="https://api.minimaxi.com/anthropic"
                    ;;
            esac
            local mm_model="${MINIMAX_MODEL:-MiniMax-M2.1}"
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='${mm_base_url}'"
            echo "if [ -z \"\${MINIMAX_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            echo "export ANTHROPIC_AUTH_TOKEN=\"\${MINIMAX_API_KEY}\""
            echo "export ANTHROPIC_MODEL='${mm_model}'"
            emit_default_models "$mm_model" "$mm_model" "$mm_model"
            emit_subagent_model "$mm_model"
            ;;
        "seed"|"doubao")
            if ! is_effectively_set "$ARK_API_KEY"; then
                echo -e "${RED}❌ Please configure ARK_API_KEY${NC}" >&2
                return 1
            fi
            local seed_variant="$arg"
            local seed_model=""
            case "$seed_variant" in
                ""|"default")
                    seed_model="${SEED_MODEL:-ark-code-latest}"
                    ;;
                "doubao"|"seed")
                    seed_model="doubao-seed-code"
                    ;;
                "glm"|"glm4"|"glm4.7")
                    seed_model="glm-4.7"
                    ;;
                "deepseek"|"ds")
                    seed_model="deepseek-v3.2"
                    ;;
                "kimi"|"kimi2"|"kimi-k2.5")
                    seed_model="kimi-k2.5"
                    ;;
                *)
                    echo -e "${RED}❌ $(t 'unknown_option'): seed $seed_variant${NC}" >&2
                    echo -e "${YELLOW}💡 Usage: ccm seed [doubao|glm|deepseek|kimi]${NC}" >&2
                    return 1
                    ;;
            esac
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='https://ark.cn-beijing.volces.com/api/coding'"
            echo "if [ -z \"\${ARK_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            echo "export ANTHROPIC_AUTH_TOKEN=\"\${ARK_API_KEY}\""
            echo "export ANTHROPIC_MODEL='${seed_model}'"
            emit_default_models "$seed_model" "$seed_model" "$seed_model"
            emit_subagent_model "$seed_model"
            ;;
        "claude"|"sonnet"|"s")
            echo "$prelude"
            # 官方 Anthropic 网关
            echo "export ANTHROPIC_BASE_URL='https://api.anthropic.com/'"
            echo "unset ANTHROPIC_API_URL"
            echo "unset ANTHROPIC_API_KEY"
            local claude_model="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
            local default_sonnet="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
            local default_opus="${OPUS_MODEL:-claude-opus-4-5-20251101}"
            local default_haiku="${HAIKU_MODEL:-claude-haiku-4-5-20251001}"
            echo "export ANTHROPIC_MODEL='${claude_model}'"
            if is_effectively_set "$CLAUDE_API_KEY"; then
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${CLAUDE_API_KEY}\""
            fi
            emit_default_models "$default_sonnet" "$default_opus" "$default_haiku"
            emit_subagent_model "$claude_model"
            ;;
        *)
            echo "# $(t 'usage'): $(basename "$0") env [deepseek|kimi|qwen|glm|minimax|seed|claude|open]" 1>&2
            return 1
            ;;
    esac
}


# 主函数
main() {
    # 加载配置（环境变量优先）
    if ! load_config; then
        return 1
    fi

    # 处理参数
    local cmd="${1:-help}"

    # 检查是否是 model:account 格式
    if [[ "$cmd" =~ ^(claude|sonnet|s):(.+)$ ]]; then
        local model_type="${BASH_REMATCH[1]}"
        local account_name="${BASH_REMATCH[2]}"

        # 先切换账号：将输出重定向到stderr，避免污染stdout（stdout仅用于export语句）
        switch_account "$account_name" 1>&2 || return 1

        # 然后仅输出对应模型的 export 语句，供调用方 eval
        case "$model_type" in
            "claude"|"sonnet"|"s")
                emit_env_exports claude
                ;;
        esac
        return $?
    fi

    case "$cmd" in
        # 账号管理命令
        "save-account")
            shift
            save_account "$1"
            ;;
        "switch-account")
            shift
            switch_account "$1"
            ;;
        "list-accounts")
            list_accounts
            ;;
        "delete-account")
            shift
            delete_account "$1"
            ;;
        "current-account")
            get_current_account
            ;;
        "debug-keychain")
            debug_keychain_credentials
            ;;
        # 模型切换命令
        "deepseek"|"ds")
            emit_env_exports deepseek
            ;;
        "kimi"|"kimi2")
            emit_env_exports kimi "${2:-}"
            ;;
        "kimi-cn")
            emit_env_exports kimi-cn
            ;;
        "qwen")
            emit_env_exports qwen "${2:-}"
            ;;
        "minimax"|"mm")
            emit_env_exports minimax "${2:-}"
            ;;
        "seed"|"doubao")
            emit_env_exports seed "${2:-}"
            ;;
        "glm"|"glm4"|"glm4.6"|"glm4.7")
            emit_env_exports glm "${2:-}"
            ;;
        "claude"|"sonnet"|"s")
            emit_env_exports claude
            ;;
        "open")
            emit_env_exports open "${2:-}"
            ;;
        "env")
            shift
            emit_env_exports "${1:-}" "${2:-}"
            ;;
        "project")
            shift
            local action="${1:-}"
            case "$action" in
                "glm")
                    project_write_glm_settings "${2:-}"
                    ;;
                "reset")
                    project_reset_settings
                    ;;
                *)
                    echo -e "${RED}❌ $(t 'unknown_option'): project $action${NC}" >&2
                    echo -e "${YELLOW}💡 Usage: ccm project [glm|reset] [global|china]${NC}" >&2
                    return 1
                    ;;
            esac
            ;;
        "status"|"st")
            show_status
            ;;
        "config"|"cfg")
            edit_config
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}❌ $(t 'unknown_option'): $1${NC}" >&2
            echo "" >&2
            show_help >&2
            return 1
            ;;
    esac
}

# 执行主函数
main "$@"
