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

# StepFun
STEPFUN_API_KEY=your-stepfun-api-key

# Qwen（阿里云 DashScope）
QWEN_API_KEY=your-qwen-api-key

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# OpenRouter
OPENROUTER_API_KEY=your-openrouter-api-key

# —— 可选：模型ID覆盖（不设置则使用下方默认）——
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2.5
KIMI_CN_MODEL=kimi-k2.5
QWEN_MODEL=qwen3-max-2026-01-23
GLM_MODEL=glm-5
CLAUDE_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-6
HAIKU_MODEL=claude-haiku-4-5-20251001
MINIMAX_MODEL=MiniMax-M2.5
SEED_MODEL=ark-code-latest
STEPFUN_MODEL=step-3.5-flash

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
            # 检查配置文件的值是否为占位符
            local lower_value
            lower_value=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
            local is_config_placeholder=false
            if [[ "$lower_value" == *"your"* && "$lower_value" == *"api"* && "$lower_value" == *"key"* ]]; then
                is_config_placeholder=true
            fi
            # 配置文件总是覆盖，除非配置值是占位符
            if [[ -n "$key" && "$is_config_placeholder" == "false" ]]; then
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

# StepFun
STEPFUN_API_KEY=your-stepfun-api-key

# Qwen（阿里云 DashScope）
QWEN_API_KEY=your-qwen-api-key

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# OpenRouter
OPENROUTER_API_KEY=your-openrouter-api-key

# —— 可选：模型ID覆盖（不设置则使用下方默认）——
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2.5
KIMI_CN_MODEL=kimi-k2.5
QWEN_MODEL=qwen3-max-2026-01-23
GLM_MODEL=glm-5
CLAUDE_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-6
HAIKU_MODEL=claude-haiku-4-5-20251001
MINIMAX_MODEL=MiniMax-M2.5
SEED_MODEL=ark-code-latest
STEPFUN_MODEL=step-3.5-flash

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
    # P0-4.3: reject clearly short strings (no real key is < 16 chars)
    if (( ${#v} < 16 )); then
        return 1
    fi
    local lower
    lower=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')
    # P0-4.3: extended placeholder patterns (no < > [ ] — invalid in case patterns)
    case "$lower" in
        *your*api*key*|*your*key*here*|*api_key_here*|*enter*key*|\
        *insert*key*|*add*key*|*put*key*|*replace*key*|*sample*key*|\
        *placeholder*|*api-key-here*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# P0-4.3: Warn (non-fatal) when an API key does not match its provider's known format.
# This catches copy-paste errors early without blocking legitimate but undocumented formats.
validate_api_key_format() {
    local provider="$1"
    local key="$2"

    [[ -z "$key" ]] && return 0

    local fmt_ok=true
    case "$provider" in
        "anthropic"|"claude")
            # Official Anthropic keys begin with sk-ant-
            [[ "$key" =~ ^sk-ant- ]] || fmt_ok=false
            ;;
        "deepseek")
            # DeepSeek keys: sk- followed by 32+ alphanumeric chars
            [[ "$key" =~ ^sk-[a-zA-Z0-9]{32,}$ ]] || fmt_ok=false
            ;;
        "openrouter")
            # OpenRouter keys: sk-or-v1-
            [[ "$key" =~ ^sk-or-v1- ]] || fmt_ok=false
            ;;
        "kimi")
            # Moonshot/Kimi keys start with sk-
            [[ "$key" =~ ^sk- ]] || fmt_ok=false
            ;;
        # GLM, Qwen, MiniMax, ARK — formats not publicly documented; skip check
        *)
            return 0
            ;;
    esac

    if ! $fmt_ok; then
        echo -e "${YELLOW}⚠️  Warning: the $provider API key format looks unexpected.${NC}" >&2
        echo -e "${YELLOW}   Authentication may fail — check the key in ~/.ccm_config${NC}" >&2
    fi
    return 0
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

    local glm_model="${GLM_MODEL:-glm-5}"
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

# Generic project-level settings writer for all providers
project_write_settings() {
    local provider="$1"
    local region="${2:-global}"

    # Normalize region if needed
    if [[ "$provider" =~ ^(glm|kimi|qwen|minimax)$ ]]; then
        local normalized_region
        if ! normalized_region="$(normalize_region "$region")"; then
            echo -e "${RED}❌ Invalid region: $region${NC}" >&2
            echo -e "${YELLOW}💡 Usage: ccm project $provider [global|china]${NC}" >&2
            return 1
        fi
        region="$normalized_region"
    fi

    local config
    config="$(get_provider_config "$provider" "$region")" || return 1

    local config_base_url="${config%%|*}"
    local rest="${config#*|}"
    local config_model="${rest%%|*}"
    local config_token_var="${rest##*|}"

    local config_token=""
    if [[ -n "$config_token_var" ]]; then
        config_token="${!config_token_var}"
    fi

    local settings_path
    settings_path="$(project_settings_path)"
    local settings_dir
    settings_dir="$(dirname "$settings_path")"

    # Backup existing settings if not ccm-managed
    if [[ -f "$settings_path" ]]; then
        if ! grep -q '"ccmManaged"[[:space:]]*:[[:space:]]*true' "$settings_path" 2>/dev/null; then
            backup_project_settings "$settings_path"
        fi
    fi

    mkdir -p "$settings_dir"

    # Write project settings (simple format, no need to preserve other settings)
    cat > "$settings_path" <<EOF
{
  "ccmManaged": true,
  "ccmProvider": "$provider",
  "ccmRegion": "$region",
  "env": {
    "ANTHROPIC_BASE_URL": "${config_base_url}",
    "ANTHROPIC_MODEL": "${config_model}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${config_model}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${config_model}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${config_model}",
    "CLAUDE_CODE_SUBAGENT_MODEL": "${config_model}"$([[ -n "$config_token" ]] && echo ",
    \"ANTHROPIC_AUTH_TOKEN\": \"$config_token\"")
  }
}
EOF
    chmod 600 "$settings_path"
    echo -e "${GREEN}✅ Wrote project settings for ${provider}${region:+ ($region)}${NC}" >&2
    echo -e "${BLUE}   File: $settings_path${NC}" >&2
    echo -e "${YELLOW}💡 This overrides user settings for this project only.${NC}" >&2
    echo -e "${YELLOW}💡 Use 'ccm project reset' to remove.${NC}" >&2
}

project_show_usage() {
    echo -e "${BLUE}Project-level settings (writes to .claude/settings.local.json)${NC}" >&2
    echo "" >&2
    echo "Usage:" >&2
    echo "  ccm project <provider> [region]   - Write provider settings to project-level" >&2
    echo "  ccm project reset                  - Remove project override" >&2
    echo "" >&2
    echo "Providers:" >&2
    echo "  glm [global|china]    - GLM" >&2
    echo "  deepseek              - DeepSeek" >&2
    echo "  kimi [global|china]   - Kimi" >&2
    echo "  qwen [global|china]   - Qwen" >&2
    echo "  minimax [global|china] - MiniMax" >&2
    echo "  seed                  - Doubao/Seed" >&2
    echo "  claude                - Claude (official)" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  ccm project glm global   # Use GLM for this project" >&2
    echo "  ccm project seed         # Use Seed for this project" >&2
    echo "  ccm project reset        # Remove project override" >&2
}

# ============================================
# User-level settings (~/.claude/settings.json)
# ============================================

USER_SETTINGS_PATH="$HOME/.claude/settings.json"

user_settings_path() {
    echo "$USER_SETTINGS_PATH"
}

backup_user_settings() {
    local path="$1"
    local ts
    ts="$(date "+%Y%m%d-%H%M%S")"
    cp -f "$path" "${path}.bak.${ts}"
}

# Get provider config for user-level settings
get_provider_config() {
    local provider="$1"
    local region="${2:-global}"
    local config_base_url=""
    local config_model=""
    local config_token_var=""

    case "$provider" in
        "glm"|"glm5")
            if ! is_effectively_set "$GLM_API_KEY"; then
                echo -e "${RED}❌ Please configure GLM_API_KEY first${NC}" >&2
                return 1
            fi
            config_token_var="GLM_API_KEY"
            config_model="${GLM_MODEL:-glm-5}"
            case "$region" in
                "global") config_base_url="https://api.z.ai/api/anthropic" ;;
                "china") config_base_url="https://open.bigmodel.cn/api/anthropic" ;;
            esac
            ;;
        "deepseek"|"ds")
            if ! is_effectively_set "$DEEPSEEK_API_KEY"; then
                echo -e "${RED}❌ Please configure DEEPSEEK_API_KEY first${NC}" >&2
                return 1
            fi
            config_token_var="DEEPSEEK_API_KEY"
            config_model="${DEEPSEEK_MODEL:-deepseek-chat}"
            config_base_url="https://api.deepseek.com/anthropic"
            ;;
        "kimi"|"kimi2")
            if ! is_effectively_set "$KIMI_API_KEY"; then
                echo -e "${RED}❌ Please configure KIMI_API_KEY first${NC}" >&2
                return 1
            fi
            config_token_var="KIMI_API_KEY"
            case "$region" in
                "global")
                    config_base_url="https://api.moonshot.ai/anthropic"
                    config_model="${KIMI_MODEL:-kimi-k2.5}"
                    ;;
                "china")
                    config_base_url="https://api.moonshot.cn/anthropic"
                    config_model="${KIMI_CN_MODEL:-kimi-k2.5}"
                    ;;
            esac
            ;;
        "qwen")
            if ! is_effectively_set "$QWEN_API_KEY"; then
                echo -e "${RED}❌ Please configure QWEN_API_KEY first${NC}" >&2
                return 1
            fi
            config_token_var="QWEN_API_KEY"
            config_model="${QWEN_MODEL:-qwen3-max-2026-01-23}"
            case "$region" in
                "global") config_base_url="https://coding-intl.dashscope.aliyuncs.com/apps/anthropic" ;;
                "china") config_base_url="https://coding.dashscope.aliyuncs.com/apps/anthropic" ;;
            esac
            ;;
        "minimax"|"mm")
            if ! is_effectively_set "$MINIMAX_API_KEY"; then
                echo -e "${RED}❌ Please configure MINIMAX_API_KEY first${NC}" >&2
                return 1
            fi
            config_token_var="MINIMAX_API_KEY"
            config_model="${MINIMAX_MODEL:-MiniMax-M2.5}"
            case "$region" in
                "global") config_base_url="https://api.minimax.io/anthropic" ;;
                "china") config_base_url="https://api.minimaxi.com/anthropic" ;;
            esac
            ;;
        "seed"|"doubao")
            if ! is_effectively_set "$ARK_API_KEY"; then
                echo -e "${RED}❌ Please configure ARK_API_KEY first${NC}" >&2
                return 1
            fi
            config_token_var="ARK_API_KEY"
            config_model="${SEED_MODEL:-ark-code-latest}"
            config_base_url="https://ark.cn-beijing.volces.com/api/coding"
            ;;
        "stepfun")
            if ! is_effectively_set "$STEPFUN_API_KEY"; then
                echo -e "${RED}❌ Please configure STEPFUN_API_KEY first${NC}" >&2
                return 1
            fi
            config_token_var="STEPFUN_API_KEY"
            config_model="${STEPFUN_MODEL:-step-3.5-flash}"
            config_base_url="https://api.stepfun.ai/v1/anthropic"
            ;;
        "claude"|"sonnet"|"s")
            config_token_var=""  # Uses Claude Pro subscription
            config_model="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
            config_base_url="https://api.anthropic.com/"
            ;;
        *)
            echo -e "${RED}❌ Unknown provider: $provider${NC}" >&2
            return 1
            ;;
    esac

    echo "${config_base_url}|${config_model}|${config_token_var}"
}

user_write_settings() {
    local provider="$1"
    local region="${2:-global}"

    # Normalize region if needed
    if [[ "$provider" =~ ^(glm|kimi|qwen|minimax)$ ]]; then
        local normalized_region
        if ! normalized_region="$(normalize_region "$region")"; then
            echo -e "${RED}❌ Invalid region: $region${NC}" >&2
            echo -e "${YELLOW}💡 Usage: ccm user $provider [global|china]${NC}" >&2
            return 1
        fi
        region="$normalized_region"
    fi

    local config
    config="$(get_provider_config "$provider" "$region")" || return 1

    local config_base_url="${config%%|*}"
    local rest="${config#*|}"
    local config_model="${rest%%|*}"
    local config_token_var="${rest##*|}"

    local config_token=""
    if [[ -n "$config_token_var" ]]; then
        config_token="${!config_token_var}"
    fi

    local settings_path
    settings_path="$(user_settings_path)"
    local settings_dir
    settings_dir="$(dirname "$settings_path")"

    # Backup existing settings if not ccm-managed
    if [[ -f "$settings_path" ]]; then
        if ! grep -q '"ccmManaged"[[:space:]]*:[[:space:]]*true' "$settings_path" 2>/dev/null; then
            backup_user_settings "$settings_path"
        fi
    fi

    mkdir -p "$settings_dir"

    # Use Python or jq to merge settings if available, otherwise use simple approach
    if command -v python3 >/dev/null 2>&1; then
        # P0-4.4: pass all values via env vars — avoids shell interpolation inside Python
        # which breaks tokens containing single quotes, backslashes, or newlines.
        CCM_SETTINGS_PATH="$settings_path" \
        CCM_PROVIDER="$provider" \
        CCM_REGION="$region" \
        CCM_BASE_URL="$config_base_url" \
        CCM_MODEL="$config_model" \
        CCM_TOKEN="${config_token:-}" \
        python3 << 'PYTHON_EOF'
import json
import os

settings_path = os.environ['CCM_SETTINGS_PATH']
provider     = os.environ['CCM_PROVIDER']
region       = os.environ['CCM_REGION']
base_url     = os.environ['CCM_BASE_URL']
model        = os.environ['CCM_MODEL']
token        = os.environ.get('CCM_TOKEN', '')

existing = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path, 'r') as f:
            existing = json.load(f)
    except Exception:
        existing = {}

# Preserve non-ccm settings but mark as ccm-managed
existing['ccmManaged'] = True
existing['ccmProvider'] = provider
existing['ccmRegion']   = region

# Set env
existing['env'] = {
    'ANTHROPIC_BASE_URL':               base_url,
    'ANTHROPIC_MODEL':                  model,
    'ANTHROPIC_DEFAULT_SONNET_MODEL':   model,
    'ANTHROPIC_DEFAULT_OPUS_MODEL':     model,
    'ANTHROPIC_DEFAULT_HAIKU_MODEL':    model,
    'CLAUDE_CODE_SUBAGENT_MODEL':       model,
}
if token:
    existing['env']['ANTHROPIC_AUTH_TOKEN'] = token

with open(settings_path, 'w') as f:
    json.dump(existing, f, indent=2)

os.chmod(settings_path, 0o600)
PYTHON_EOF
    else
        # Fallback: write minimal settings (will lose other settings).
        # JSON-escape the token for the heredoc: escape backslash then double-quote.
        local escaped_token=""
        if [[ -n "$config_token" ]]; then
            escaped_token="$(printf '%s' "$config_token" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        fi
        cat > "$settings_path" <<EOF
{
  "ccmManaged": true,
  "ccmProvider": "$provider",
  "ccmRegion": "$region",
  "env": {
    "ANTHROPIC_BASE_URL": "$config_base_url",
    "ANTHROPIC_MODEL": "$config_model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$config_model",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$config_model",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$config_model",
    "CLAUDE_CODE_SUBAGENT_MODEL": "$config_model"$([[ -n "$escaped_token" ]] && printf ',\n    "ANTHROPIC_AUTH_TOKEN": "%s"' "$escaped_token")
  }
}
EOF
        chmod 600 "$settings_path"
    fi

    echo -e "${GREEN}✅ Wrote user-level settings for ${provider}${region:+ ($region)}${NC}" >&2
    echo -e "${BLUE}   File: $settings_path${NC}" >&2
    echo -e "${YELLOW}💡 This overrides environment variables and takes highest priority.${NC}" >&2
    echo -e "${YELLOW}💡 Use 'ccm user reset' to restore environment variable control.${NC}" >&2
}

user_reset_settings() {
    local settings_path
    settings_path="$(user_settings_path)"

    if [[ ! -f "$settings_path" ]]; then
        echo -e "${YELLOW}⚠️  No user settings file at: $settings_path${NC}" >&2
        return 0
    fi

    if ! grep -q '"ccmManaged"[[:space:]]*:[[:space:]]*true' "$settings_path" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Settings file is not managed by ccm. Not modifying.${NC}" >&2
        echo -e "${YELLOW}   File: $settings_path${NC}" >&2
        return 0
    fi

    # Backup before reset
    backup_user_settings "$settings_path"

    # Remove env section and ccm markers using Python or jq
    if command -v python3 >/dev/null 2>&1; then
        CCM_SETTINGS_PATH="$settings_path" python3 << 'PYTHON_EOF'
import json
import os

settings_path = os.environ['CCM_SETTINGS_PATH']

with open(settings_path, 'r') as f:
    data = json.load(f)

# Remove ccm-managed keys
data.pop('ccmManaged', None)
data.pop('ccmProvider', None)
data.pop('ccmRegion', None)
data.pop('env', None)

with open(settings_path, 'w') as f:
    json.dump(data, f, indent=2)
PYTHON_EOF
        echo -e "${GREEN}✅ Removed ccm-managed settings from user settings${NC}" >&2
    else
        # Fallback: just remove the file
        rm -f "$settings_path"
        echo -e "${GREEN}✅ Removed user settings file${NC}" >&2
    fi

    echo -e "${YELLOW}💡 Claude Code will now use environment variables.${NC}" >&2
    echo -e "${YELLOW}   Use 'ccm <provider>' to set environment variables.${NC}" >&2
}

user_show_usage() {
    echo -e "${BLUE}User-level settings (writes to ~/.claude/settings.json)${NC}" >&2
    echo "" >&2
    echo "Usage:" >&2
    echo "  ccm user <provider> [region]   - Write provider settings to user-level" >&2
    echo "  ccm user reset                  - Remove ccm settings, restore env var control" >&2
    echo "" >&2
    echo "Providers:" >&2
    echo "  glm [global|china]    - GLM" >&2
    echo "  deepseek              - DeepSeek" >&2
    echo "  kimi [global|china]   - Kimi" >&2
    echo "  qwen [global|china]   - Qwen" >&2
    echo "  minimax [global|china] - MiniMax" >&2
    echo "  seed                  - Doubao/Seed" >&2
    echo "  claude                - Claude (official)" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  ccm user glm global   # Use GLM globally" >&2
    echo "  ccm user deepseek     # Use DeepSeek globally" >&2
    echo "  ccm user reset        # Remove, use env vars instead" >&2
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
            credentials=$(CCM_CREDS_FILE="$CLAUDE_CREDENTIALS_FILE" python3 -c "import json,os; d=json.load(open(os.environ['CCM_CREDS_FILE'])); print(json.dumps(d.get('claudeAiOauth', {})))" 2>/dev/null)
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
                mcp_oauth=$(CCM_CREDS_FILE="$CLAUDE_CREDENTIALS_FILE" python3 -c "import json,os; d=json.load(open(os.environ['CCM_CREDS_FILE'])); print(json.dumps(d.get('mcpOAuth', {})) if d.get('mcpOAuth') else '')" 2>/dev/null)
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
            # 移除最后的 } 并在上一行末尾添加逗号
            if [[ "$OS_TYPE" == "macos" ]]; then
                sed '$d' "$ACCOUNTS_FILE" | sed '$s/$/,/' > "$temp_file"
            else
                sed '$d' "$ACCOUNTS_FILE" | sed '$s/$/,/' > "$temp_file"
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
        CCM_ACCOUNTS_FILE="$ACCOUNTS_FILE" python3 -c "
import json, os
with open(os.environ['CCM_ACCOUNTS_FILE']) as f:
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
    # 检查用户级配置 (~/.claude/settings.json)
    local user_settings_path="$HOME/.claude/settings.json"
    if [[ -f "$user_settings_path" ]]; then
        # 检查是否有 env 设置
        if grep -q '"env"[[:space:]]*:' "$user_settings_path" 2>/dev/null; then
            local user_base_url=$(grep -o '"ANTHROPIC_BASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' "$user_settings_path" | cut -d'"' -f4)
            local user_model=$(grep -o '"ANTHROPIC_MODEL"[[:space:]]*:[[:space:]]*"[^"]*"' "$user_settings_path" | cut -d'"' -f4)
            local user_token=$(grep -o '"ANTHROPIC_AUTH_TOKEN"[[:space:]]*:[[:space:]]*"[^"]*"' "$user_settings_path" | cut -d'"' -f4)
            local ccm_managed=$(grep -o '"ccmManaged"[[:space:]]*:[[:space:]]*[a-z]*' "$user_settings_path" | grep -o 'true\|false')

            if [[ "$ccm_managed" == "true" ]]; then
                echo -e "${GREEN}👤 User config (ccm-managed):${NC} $user_settings_path"
            else
                echo -e "${YELLOW}⚠️  User config (external):${NC} $user_settings_path"
                echo -e "${YELLOW}   This overrides environment variables!${NC}"
            fi
            echo "   BASE_URL: ${user_base_url:-'N/A'}"
            echo "   MODEL: ${user_model:-'N/A'}"
            echo -n "   AUTH_TOKEN: "
            mask_token "$user_token"
            echo ""
            if [[ "$ccm_managed" != "true" ]]; then
                echo -e "${YELLOW}💡 Use 'ccm user <provider>' to take control, or edit the file directly.${NC}"
            else
                echo -e "${YELLOW}💡 Use 'ccm user reset' to restore environment variable control.${NC}"
            fi
            echo ""
        fi
    fi

    # 检查项目级配置
    local project_settings=""
    local project_settings_path="$(project_settings_path)"
    if [[ -f "$project_settings_path" ]]; then
        if grep -q '"ccmManaged"[[:space:]]*:[[:space:]]*true' "$project_settings_path" 2>/dev/null; then
            echo -e "${GREEN}📁 $(t 'project_config'):${NC} $project_settings_path"
            # 提取项目配置中的关键信息
            local proj_base_url=$(grep -o '"ANTHROPIC_BASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' "$project_settings_path" | cut -d'"' -f4)
            local proj_model=$(grep -o '"ANTHROPIC_MODEL"[[:space:]]*:[[:space:]]*"[^"]*"' "$project_settings_path" | cut -d'"' -f4)
            local proj_token=$(grep -o '"ANTHROPIC_AUTH_TOKEN"[[:space:]]*:[[:space:]]*"[^"]*"' "$project_settings_path" | cut -d'"' -f4)
            echo "   BASE_URL: ${proj_base_url:-'N/A'}"
            echo "   MODEL: ${proj_model:-'N/A'}"
            echo -n "   AUTH_TOKEN: "
            mask_token "$proj_token"
            echo ""
        fi
    fi

    # OpenRouter Configuration
    if is_effectively_set "$OPENROUTER_API_KEY"; then
        echo -e "${BLUE}🌐 OpenRouter:${NC}"
        if [[ "${ANTHROPIC_BASE_URL:-}" == *"openrouter"* ]]; then
            echo -e "   ${GREEN}Status:${NC} $(t 'openrouter_active')"
            echo "   MODEL: ${ANTHROPIC_MODEL:-'(not set)'}"
            echo "   SUBAGENT_MODEL: ${CLAUDE_CODE_SUBAGENT_MODEL:-'(not set)'}"
            # Detect provider from model name
            if [[ -n "${ANTHROPIC_MODEL:-}" ]]; then
                case "$ANTHROPIC_MODEL" in
                    *glm*) echo "   Provider: $(t 'openrouter_provider_glm')" ;;
                    *kimi*) echo "   Provider: $(t 'openrouter_provider_kimi')" ;;
                    *deepseek*) echo "   Provider: $(t 'openrouter_provider_deepseek')" ;;
                    *minimax*) echo "   Provider: $(t 'openrouter_provider_minimax')" ;;
                    *qwen*) echo "   Provider: $(t 'openrouter_provider_qwen')" ;;
                    *stepfun*)
                        echo "   Provider: $(t 'openrouter_provider_stepfun')"
                        [[ "$ANTHROPIC_MODEL" == *":free" ]] && echo -e "   ${GREEN}🆓 Free Tier${NC}"
                        ;;
                    *claude*|*anthropic*) echo "   Provider: $(t 'openrouter_provider_claude')" ;;
                    *) echo "   Provider: $(t 'openrouter_provider_unknown') ${ANTHROPIC_MODEL})" ;;
                esac
            fi
        else
            echo -e "   ${YELLOW}Status:${NC} $(t 'openrouter_configured_not_active')"
            echo -e "${YELLOW}   💡 $(t 'openrouter_use_eval_hint')${NC}"
        fi
        echo ""
    fi

    echo -e "${BLUE}📊 $(t 'current_model_config'):${NC}"
    echo "   BASE_URL: ${ANTHROPIC_BASE_URL:-'Default (Anthropic)'}"
    echo -n "   AUTH_TOKEN: "
    mask_token "${ANTHROPIC_AUTH_TOKEN}"
    echo "   MODEL: ${ANTHROPIC_MODEL:-'$(t "not_set")'}"
    echo "   SUBAGENT_MODEL: ${CLAUDE_CODE_SUBAGENT_MODEL:-'$(t "not_set")'}"
    echo "   OPUS_MODEL: ${ANTHROPIC_DEFAULT_OPUS_MODEL:-'$(t "not_set")'}"
    echo "   SONNET_MODEL: ${ANTHROPIC_DEFAULT_SONNET_MODEL:-'$(t "not_set")'}"
    echo "   HAIKU_MODEL: ${ANTHROPIC_DEFAULT_HAIKU_MODEL:-'$(t "not_set")'}"
    echo ""
    echo -e "${BLUE}🔧 $(t 'env_vars_status'):${NC}"
    echo "   GLM_API_KEY: $(mask_presence GLM_API_KEY)"
    echo "   KIMI_API_KEY: $(mask_presence KIMI_API_KEY)"
    echo "   MINIMAX_API_KEY: $(mask_presence MINIMAX_API_KEY)"
    echo "   DEEPSEEK_API_KEY: $(mask_presence DEEPSEEK_API_KEY)"
    echo "   ARK_API_KEY: $(mask_presence ARK_API_KEY)"
    echo "   QWEN_API_KEY: $(mask_presence QWEN_API_KEY)"
    echo "   STEPFUN_API_KEY: $(mask_presence STEPFUN_API_KEY)"
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
    export ANTHROPIC_DEFAULT_OPUS_MODEL="${OPUS_MODEL:-claude-opus-4-6}"
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
    local glm_model="${GLM_MODEL:-glm-5}"
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
    export ANTHROPIC_MODEL="kimi-k2.5"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="kimi-k2.5"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="kimi-k2.5"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="kimi-k2.5"
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
    local mm_model="${MINIMAX_MODEL:-MiniMax-M2.5}"
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
        "glm"|"glm5")
            seed_model="glm-5"
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
    echo "  stepfun                 - env StepFun"
    echo "  claude, sonnet, s       - env claude (official)"
    echo "  open <provider>         - env OpenRouter (run 'ccm open' for help)"
    echo ""
    echo -e "${YELLOW}User-level Settings (highest priority):${NC}"
    echo "  user <provider> [region] - write to ~/.claude/settings.json"
    echo "  user reset               - remove ccm settings, restore env var control"
    echo "  Providers: glm, deepseek, kimi, qwen, minimax, seed, stepfun, claude"
    echo ""
    echo -e "${YELLOW}Project-level Settings:${NC}"
    echo "  project <provider> [region] - write .claude/settings.local.json (project-only)"
    echo "  project reset              - remove project override"
    echo "  Providers: glm, deepseek, kimi, qwen, minimax, seed, claude"
    echo ""
    echo -e "${YELLOW}Claude Pro Account Management:${NC}"
    echo "  save-account <name>     - Save current Claude Pro account"
    echo "  switch-account <name>   - Switch to saved account"
    echo "  list-accounts           - List all saved accounts"
    echo "  delete-account <name>   - Delete saved account"
    echo "  current-account         - Show current account info"
    echo "  claude:account         - Switch account and use Claude (Sonnet)"
    echo ""
    echo -e "${YELLOW}Keystore — Encrypted API key storage (WSL/Windows):${NC}"
    echo "  keystore set <KEY_VAR>  - Store key encrypted with Windows DPAPI"
    echo "  keystore show <KEY_VAR> - Show stored key (masked)"
    echo "  keystore list           - List all stored key names"
    echo "  keystore delete <KEY>   - Remove a stored key"
    echo "  (run 'ccm keystore' for full help and workflow)"
    echo ""
    echo -e "${YELLOW}$(t 'tool_options'):${NC}"
    echo "  status, st       - $(t 'show_current_config')"
    echo "  env [model]      - $(t 'output_export_only')"
    echo "  config, cfg      - $(t 'edit_config_file')"
    echo "  update-config    - Update model IDs to latest defaults"
    echo "  help, h          - $(t 'show_help')"
    echo ""
    echo -e "${YELLOW}$(t 'examples'):${NC}"
    echo "  eval \"\$(ccm deepseek)\"                   # Apply in current shell (recommended)"
    echo "  eval \"\$(ccm kimi china)\"              # Kimi CN"
    echo "  eval \"\$(ccm qwen global)\"             # Qwen global (Coding Plan)"
    echo "  eval \"\$(ccm seed kimi)\"               # 豆包 Seed-Code (kimi)"
    echo "  eval \"\$(ccm open kimi)\"               # OpenRouter kimi"
    echo ""
    echo "  ccm user glm global    # Set GLM as default (highest priority)"
    echo "  ccm user reset         # Restore env var control"
    echo "  $(basename "$0") status                      # Check current status (masked)"
    echo "  $(basename "$0") save-account work           # Save current account as 'work'"
    echo ""
    echo -e "${YELLOW}支持的模型:${NC}"
    echo "  🌙 KIMI Global          - kimi-k2.5 (api.moonshot.ai/anthropic)"
    echo "  🌕 KIMI China           - kimi-k2.5 (api.moonshot.cn/anthropic)"
    echo "  🤖 Deepseek             - deepseek-chat (api.deepseek.com/anthropic)"
    echo "  🌰 豆包 Seed-Code       - ark-code-latest (ark.cn-beijing.volces.com/api/coding)"
    echo "  ⚡ StepFun              - step-3.5-flash (api.stepfun.ai)"
    echo "  🎯 MiniMax              - MiniMax-M2.5 (api.minimax.io / api.minimaxi.com)"
    echo "  🐪 Qwen                 - qwen3-max-2026-01-23 / qwen3-coder-plus (Coding Plan)"
    echo "  🇨🇳 GLM                 - glm-5 (api.z.ai / open.bigmodel.cn)"
    echo "  🧠 Claude Sonnet 4.5    - claude-sonnet-4-5-20250929"
}

# 将缺失的模型ID覆盖项追加到配置文件（仅追加缺失项，不覆盖已存在的配置）
ensure_model_override_defaults() {
    local -a pairs=(
        "DEEPSEEK_MODEL=deepseek-chat"
        "KIMI_MODEL=kimi-k2.5"
        "KIMI_CN_MODEL=kimi-k2.5"
        "MINIMAX_MODEL=MiniMax-M2.5"
        "SEED_MODEL=ark-code-latest"
        "STEPFUN_MODEL=step-3.5-flash"
        "QWEN_MODEL=qwen3-max-2026-01-23"
        "GLM_MODEL=glm-5"
        "CLAUDE_MODEL=claude-sonnet-4-5-20250929"
        "OPUS_MODEL=claude-opus-4-6"
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

# 更新配置文件中的模型 ID（当默认值变化时）
update_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}⚠️  Config file not found. Run 'ccm config' first.${NC}" >&2
        return 1
    fi

    echo -e "${BLUE}🔄 Checking for outdated model IDs...${NC}" >&2

    # 定义需要更新的键值对映射（旧值 -> 新值）
    # 格式: "KEY|OLD_VALUE|NEW_VALUE"
    local -a updates=(
        "KIMI_MODEL|kimi-for-coding|kimi-k2.5"
        "MINIMAX_MODEL|MiniMax-M2.1|MiniMax-M2.5"
        "GLM_MODEL|glm-4|glm-5"
        "GLM_MODEL|glm-4.6|glm-5"
        "GLM_MODEL|glm-4.7|glm-5"
    )

    local updated_count=0

    for update in "${updates[@]}"; do
        local key="${update%%|*}"
        local rest="${update#*|}"
        local old_value="${rest%%|*}"
        local new_value="${rest##*|}"

        # 检查配置文件中是否有需要更新的旧值
        if grep -qE "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*${old_value}([[:space:]]*$|[[:space:]]*#)" "$CONFIG_FILE" 2>/dev/null; then
            # 使用 sed 替换
            if [[ "$OS_TYPE" == "macos" ]]; then
                sed -i '' "s|^\([[:space:]]*${key}[[:space:]]*=[[:space:]]*\)${old_value}|\1${new_value}|" "$CONFIG_FILE"
            else
                sed -i "s|^\([[:space:]]*${key}[[:space:]]*=[[:space:]]*\)${old_value}|\1${new_value}|" "$CONFIG_FILE"
            fi
            echo -e "${GREEN}✅ Updated ${key}: ${old_value} → ${new_value}${NC}" >&2
            ((updated_count++))
        fi
    done

    # 同时确保缺失的键被添加
    ensure_model_override_defaults

    if [[ $updated_count -eq 0 ]]; then
        echo -e "${GREEN}✅ Config is up to date${NC}" >&2
    else
        echo -e "${GREEN}✅ Updated ${updated_count} model ID(s)${NC}" >&2
    fi
}

# ============================================
# Windows Credential Store (WSL — DPAPI)
# ============================================

# True (return 0) when running inside WSL.
detect_wsl() {
    [[ -f /proc/version ]] && grep -qiE "microsoft|wsl" /proc/version 2>/dev/null
}

# Write an API key to %APPDATA%\ccm\credentials\ encrypted with Windows DPAPI.
# The value is passed via an environment variable to avoid PowerShell injection.
write_windows_credential() {
    local var_name="$1"
    local key_value="$2"
    CCM_WINCRED_NAME="$var_name" CCM_WINCRED_VALUE="$key_value" \
    powershell.exe -NoProfile -NonInteractive -Command '
        $dir  = Join-Path $env:APPDATA "ccm\credentials"
        $null = New-Item -ItemType Directory -Path $dir -Force
        $sec  = ConvertTo-SecureString $env:CCM_WINCRED_VALUE -AsPlainText -Force
        $cred = New-Object PSCredential($env:CCM_WINCRED_NAME, $sec)
        $file = Join-Path $dir ($env:CCM_WINCRED_NAME + ".xml")
        $cred | Export-Clixml -Path $file -Force
    ' 2>/dev/null
}

# Read a DPAPI-encrypted key. Outputs the plaintext value or nothing.
read_windows_credential() {
    local var_name="$1"
    CCM_WINCRED_NAME="$var_name" \
    powershell.exe -NoProfile -NonInteractive -Command '
        $file = Join-Path $env:APPDATA "ccm\credentials\$($env:CCM_WINCRED_NAME).xml"
        if (Test-Path $file) {
            $cred = Import-Clixml -Path $file
            $cred.GetNetworkCredential().Password
        }
    ' 2>/dev/null
}

# Delete a stored key. Returns 0 if deleted, 1 if not found.
delete_windows_credential() {
    local var_name="$1"
    CCM_WINCRED_NAME="$var_name" \
    powershell.exe -NoProfile -NonInteractive -Command '
        $file = Join-Path $env:APPDATA "ccm\credentials\$($env:CCM_WINCRED_NAME).xml"
        if (Test-Path $file) { Remove-Item $file -Force; exit 0 } else { exit 1 }
    ' 2>/dev/null
    return $?
}

# List the names of all stored keys (one per line).
list_windows_credentials() {
    powershell.exe -NoProfile -NonInteractive -Command '
        $dir = Join-Path $env:APPDATA "ccm\credentials"
        if (Test-Path $dir) {
            Get-ChildItem -Path $dir -Filter "*.xml" |
                Select-Object -ExpandProperty BaseName
        }
    ' 2>/dev/null
}

# Resolve an API key: config file first, Windows keystore second (WSL only).
# Echoes the value to stdout. Returns 0 if found, 1 if not found.
# Side-effect: sets _CCM_KEY_SOURCE to "config" or "keystore".
_resolve_api_key() {
    local var_name="$1"
    local val="${!var_name:-}"
    _CCM_KEY_SOURCE="config"

    if is_effectively_set "$val"; then
        echo "$val"
        return 0
    fi

    if detect_wsl; then
        local ks_val
        ks_val="$(read_windows_credential "$var_name" 2>/dev/null)"
        if is_effectively_set "$ks_val"; then
            _CCM_KEY_SOURCE="keystore"
            echo "$ks_val"
            return 0
        fi
    fi

    return 1
}

# Emit the ANTHROPIC_AUTH_TOKEN export line.
# From keystore: embed the literal value (goes via eval — not logged).
# From config:   keep the ${VAR} reference (existing behaviour, no change).
_emit_auth_token() {
    local key_val="$1"
    local var_name="$2"
    if [[ "${_CCM_KEY_SOURCE:-config}" == "keystore" ]]; then
        printf 'export ANTHROPIC_AUTH_TOKEN=%s\n' "$(printf '%q' "$key_val")"
    else
        echo "export ANTHROPIC_AUTH_TOKEN=\"\${${var_name}}\""
    fi
}

# ============================================
# ccm keystore command
# ============================================

keystore_set() {
    local var_name="${1:-}"
    if [[ -z "$var_name" ]]; then
        echo -e "${RED}❌ Usage: ccm keystore set <KEY_VAR>${NC}" >&2
        echo -e "${YELLOW}   Example: ccm keystore set DEEPSEEK_API_KEY${NC}" >&2
        return 1
    fi
    if ! [[ "$var_name" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
        echo -e "${RED}❌ Invalid variable name: $var_name${NC}" >&2
        return 1
    fi

    local key_value
    read -rs -p "Enter value for $var_name: " key_value </dev/tty
    echo "" >&2

    if ! is_effectively_set "$key_value"; then
        echo -e "${RED}❌ Value is empty or looks like a placeholder.${NC}" >&2
        return 1
    fi

    if write_windows_credential "$var_name" "$key_value"; then
        echo -e "${GREEN}✅ $var_name stored (DPAPI-encrypted in %%APPDATA%%\\ccm\\credentials\\)${NC}" >&2
        echo -e "${YELLOW}💡 You can now remove $var_name from ~/.ccm_config — keystore is the fallback.${NC}" >&2
    else
        echo -e "${RED}❌ Failed to write to Windows Credential Manager. Is powershell.exe accessible?${NC}" >&2
        return 1
    fi
}

keystore_list() {
    local names
    names="$(list_windows_credentials 2>/dev/null)"
    if [[ -z "$names" ]]; then
        echo -e "${YELLOW}ℹ️  No keys stored in keystore yet.${NC}" >&2
        echo -e "${YELLOW}   Run: ccm keystore set DEEPSEEK_API_KEY${NC}" >&2
        return 0
    fi
    echo -e "${BLUE}🔐 Stored keys (DPAPI-encrypted in %%APPDATA%%\\ccm\\credentials\\):${NC}" >&2
    while IFS= read -r name; do
        [[ -n "$name" ]] && echo -e "   ${YELLOW}${name}${NC}" >&2
    done <<< "$names"
}

keystore_show() {
    local var_name="${1:-}"
    if [[ -z "$var_name" ]]; then
        echo -e "${RED}❌ Usage: ccm keystore show <KEY_VAR>${NC}" >&2
        return 1
    fi
    local val
    val="$(read_windows_credential "$var_name" 2>/dev/null)"
    if is_effectively_set "$val"; then
        echo -e "${BLUE}$var_name:${NC} $(mask_token "$val")" >&2
    else
        echo -e "${YELLOW}⚠️  $var_name not found in keystore.${NC}" >&2
        return 1
    fi
}

keystore_delete() {
    local var_name="${1:-}"
    if [[ -z "$var_name" ]]; then
        echo -e "${RED}❌ Usage: ccm keystore delete <KEY_VAR>${NC}" >&2
        return 1
    fi
    if delete_windows_credential "$var_name"; then
        echo -e "${GREEN}✅ $var_name removed from keystore.${NC}" >&2
    else
        echo -e "${YELLOW}⚠️  $var_name was not found in keystore.${NC}" >&2
    fi
}

keystore_show_usage() {
    echo -e "${BLUE}🔐 CCM Keystore — Windows DPAPI Credential Storage (WSL)${NC}" >&2
    echo "" >&2
    echo "Stores API keys encrypted with Windows DPAPI." >&2
    echo "Encrypted files live in: %APPDATA%\\ccm\\credentials\\" >&2
    echo "Keys are bound to your Windows user account + machine." >&2
    echo "Even a copy of the file is unreadable on another machine." >&2
    echo "" >&2
    echo -e "${YELLOW}Usage:${NC}" >&2
    echo "  ccm keystore set <KEY_VAR>    - Store a key (prompts, never echoed)" >&2
    echo "  ccm keystore show <KEY_VAR>   - Show masked value" >&2
    echo "  ccm keystore list             - List all stored key names" >&2
    echo "  ccm keystore delete <KEY_VAR> - Remove a key" >&2
    echo "" >&2
    echo -e "${YELLOW}Supported KEY_VAR names:${NC}" >&2
    echo "  DEEPSEEK_API_KEY  KIMI_API_KEY  GLM_API_KEY  QWEN_API_KEY" >&2
    echo "  MINIMAX_API_KEY   ARK_API_KEY   STEPFUN_API_KEY" >&2
    echo "  CLAUDE_API_KEY    OPENROUTER_API_KEY" >&2
    echo "" >&2
    echo -e "${YELLOW}Workflow:${NC}" >&2
    echo "  1. ccm keystore set DEEPSEEK_API_KEY   # stores encrypted" >&2
    echo "  2. Remove the key from ~/.ccm_config   # no more plaintext" >&2
    echo "  3. eval \"\$(ccm deepseek)\"               # reads from keystore automatically" >&2
}

# 仅输出 export 语句的环境设置（用于 eval）
show_open_help() {
    echo -e "${YELLOW}OpenRouter:${NC}"
    echo "  ccm open <provider>"
    echo ""
    echo -e "${YELLOW}Supported providers:${NC}"
    echo "  claude (default), deepseek, kimi, glm, qwen, minimax, stepfun"
    echo ""
    echo -e "${YELLOW}Free tier:${NC}"
    echo "  stepfun-free (sf-free) - stepfun/step-3.5-flash:free"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  eval \"\$(ccm open claude)\""
    echo "  eval \"\$(ccm open kimi)\""
    echo "  eval \"\$(ccm open sf-free)\""
}

emit_openrouter_exports() {
    local provider="${1:-}"
    # 加载配置以便进行存在性判断（环境变量优先，不打印密钥）
    load_config || return 1

    local or_key
    if ! or_key="$(_resolve_api_key "OPENROUTER_API_KEY")"; then
        echo -e "${RED}❌ Please configure OPENROUTER_API_KEY${NC}" >&2
        detect_wsl && echo -e "${YELLOW}💡 Or store it encrypted: ccm keystore set OPENROUTER_API_KEY${NC}" >&2
        return 1
    fi
    validate_api_key_format "openrouter" "$or_key"
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
            default_opus="anthropic/claude-opus-4.6"
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
        "glm"|"glm5")
            model="z-ai/glm-5"
            small="z-ai/glm-5"
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
            model="minimax/minimax-m2.5"
            small="minimax/minimax-m2.5"
            default_sonnet="$model"
            default_opus="$model"
            default_haiku="$model"
            ;;
        "stepfun"|"sf")
            model="stepfun/step-3.5-flash"
            small="stepfun/step-3.5-flash"
            default_sonnet="$model"
            default_opus="$model"
            default_haiku="$model"
            ;;
        "stepfun-free"|"sf-free")
            model="stepfun/step-3.5-flash:free"
            small="stepfun/step-3.5-flash:free"
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
    echo "if [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
    _emit_auth_token "$or_key" "OPENROUTER_API_KEY"
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

    _missing_key_error() {
        local var_name="$1"
        echo -e "${RED}❌ Please configure ${var_name} in ~/.ccm_config${NC}" >&2
        detect_wsl && echo -e "${YELLOW}💡 Or store it encrypted: ccm keystore set ${var_name}${NC}" >&2
    }

    case "$target" in
        "open")
            emit_openrouter_exports "$arg"
            ;;
        "deepseek"|"ds")
            local ds_key
            if ! ds_key="$(_resolve_api_key "DEEPSEEK_API_KEY")"; then
                _missing_key_error "DEEPSEEK_API_KEY"; return 1
            fi
            validate_api_key_format "deepseek" "$ds_key"
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='https://api.deepseek.com/anthropic'"
            echo "if [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            _emit_auth_token "$ds_key" "DEEPSEEK_API_KEY"
            local ds_model="${DEEPSEEK_MODEL:-deepseek-chat}"
            echo "export ANTHROPIC_MODEL='${ds_model}'"
            emit_default_models "deepseek/deepseek-v3.2" "deepseek/deepseek-v3.2" "deepseek/deepseek-v3.2"
            emit_subagent_model "$ds_model"
            ;;
        "kimi"|"kimi2"|"kimi-cn")
            local kimi_key
            if ! kimi_key="$(_resolve_api_key "KIMI_API_KEY")"; then
                _missing_key_error "KIMI_API_KEY"; return 1
            fi
            validate_api_key_format "kimi" "$kimi_key"
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
                kimi_model="${KIMI_MODEL:-kimi-k2.5}"
            else
                kimi_base_url="https://api.moonshot.cn/anthropic"
                kimi_model="${KIMI_CN_MODEL:-kimi-k2.5}"
            fi
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='${kimi_base_url}'"
            echo "if [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            _emit_auth_token "$kimi_key" "KIMI_API_KEY"
            echo "export ANTHROPIC_MODEL='${kimi_model}'"
            emit_default_models "$kimi_model" "$kimi_model" "$kimi_model"
            emit_subagent_model "$kimi_model"
            ;;
        "qwen")
            local qwen_key
            if ! qwen_key="$(_resolve_api_key "QWEN_API_KEY")"; then
                _missing_key_error "QWEN_API_KEY"; return 1
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
            echo "if [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            _emit_auth_token "$qwen_key" "QWEN_API_KEY"
            echo "export ANTHROPIC_MODEL='${qwen_model}'"
            emit_default_models "$qwen_model" "$qwen_model" "qwen3-coder-plus"
            emit_subagent_model "$qwen_model"
            ;;
        "glm"|"glm5")
            local glm_key
            if ! glm_key="$(_resolve_api_key "GLM_API_KEY")"; then
                _missing_key_error "GLM_API_KEY"; return 1
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
            local glm_model="${GLM_MODEL:-glm-5}"
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='${glm_base_url}'"
            echo "if [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            _emit_auth_token "$glm_key" "GLM_API_KEY"
            echo "export ANTHROPIC_MODEL='${glm_model}'"
            emit_default_models "$glm_model" "$glm_model" "$glm_model"
            emit_subagent_model "$glm_model"
            ;;
        "minimax"|"mm")
            local mm_key
            if ! mm_key="$(_resolve_api_key "MINIMAX_API_KEY")"; then
                _missing_key_error "MINIMAX_API_KEY"; return 1
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
            local mm_model="${MINIMAX_MODEL:-MiniMax-M2.5}"
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='${mm_base_url}'"
            echo "if [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            _emit_auth_token "$mm_key" "MINIMAX_API_KEY"
            echo "export ANTHROPIC_MODEL='${mm_model}'"
            emit_default_models "$mm_model" "$mm_model" "$mm_model"
            emit_subagent_model "$mm_model"
            ;;
        "seed"|"doubao")
            local ark_key
            if ! ark_key="$(_resolve_api_key "ARK_API_KEY")"; then
                _missing_key_error "ARK_API_KEY"; return 1
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
                "glm"|"glm5")
                    seed_model="glm-5"
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
            echo "if [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            _emit_auth_token "$ark_key" "ARK_API_KEY"
            echo "export ANTHROPIC_MODEL='${seed_model}'"
            emit_default_models "$seed_model" "$seed_model" "$seed_model"
            emit_subagent_model "$seed_model"
            ;;
        "stepfun")
            local sf_key
            if ! sf_key="$(_resolve_api_key "STEPFUN_API_KEY")"; then
                _missing_key_error "STEPFUN_API_KEY"; return 1
            fi
            echo "$prelude"
            echo "export ANTHROPIC_BASE_URL='https://api.stepfun.ai/v1/anthropic'"
            echo "if [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
            _emit_auth_token "$sf_key" "STEPFUN_API_KEY"
            local stepfun_model="${STEPFUN_MODEL:-step-3.5-flash}"
            echo "export ANTHROPIC_MODEL='${stepfun_model}'"
            emit_default_models "$stepfun_model" "$stepfun_model" "$stepfun_model"
            emit_subagent_model "$stepfun_model"
            ;;
        "claude"|"sonnet"|"s")
            echo "$prelude"
            # 官方 Anthropic 网关
            echo "export ANTHROPIC_BASE_URL='https://api.anthropic.com/'"
            echo "unset ANTHROPIC_API_URL"
            echo "unset ANTHROPIC_API_KEY"
            local claude_model="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
            local default_sonnet="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
            local default_opus="${OPUS_MODEL:-claude-opus-4-6}"
            local default_haiku="${HAIKU_MODEL:-claude-haiku-4-5-20251001}"
            echo "export ANTHROPIC_MODEL='${claude_model}'"
            local claude_key
            if claude_key="$(_resolve_api_key "CLAUDE_API_KEY")"; then
                validate_api_key_format "anthropic" "$claude_key"
                _emit_auth_token "$claude_key" "CLAUDE_API_KEY"
            fi
            emit_default_models "$default_sonnet" "$default_opus" "$default_haiku"
            emit_subagent_model "$claude_model"
            ;;
        *)
            echo "# $(t 'usage'): $(basename "$0") env [deepseek|kimi|qwen|glm|minimax|seed|stepfun|claude|open]" 1>&2
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
        "glm"|"glm5")
            emit_env_exports glm "${2:-}"
            ;;
        "stepfun")
            emit_env_exports stepfun
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
            local project_action="${1:-}"
            case "$project_action" in
                "glm"|"deepseek"|"ds"|"kimi"|"kimi2"|"qwen"|"minimax"|"mm"|"seed"|"doubao"|"claude"|"sonnet"|"s")
                    project_write_settings "$project_action" "${2:-}"
                    ;;
                "reset")
                    project_reset_settings
                    ;;
                ""|"help"|"-h"|"--help")
                    project_show_usage
                    ;;
                *)
                    echo -e "${RED}❌ $(t 'unknown_option'): project $project_action${NC}" >&2
                    project_show_usage
                    return 1
                    ;;
            esac
            ;;
        "user")
            shift
            local user_action="${1:-}"
            case "$user_action" in
                "glm"|"deepseek"|"ds"|"kimi"|"kimi2"|"qwen"|"minimax"|"mm"|"seed"|"doubao"|"stepfun"|"claude"|"sonnet"|"s")
                    user_write_settings "$user_action" "${2:-}"
                    ;;
                "reset")
                    user_reset_settings
                    ;;
                ""|"help"|"-h"|"--help")
                    user_show_usage
                    ;;
                *)
                    echo -e "${RED}❌ $(t 'unknown_option'): user $user_action${NC}" >&2
                    user_show_usage
                    return 1
                    ;;
            esac
            ;;
        "keystore"|"ks")
            shift
            local ks_action="${1:-}"
            if ! detect_wsl; then
                echo -e "${RED}❌ ccm keystore is only available in WSL (Windows).${NC}" >&2
                echo -e "${YELLOW}   On macOS, credentials are stored in Keychain automatically.${NC}" >&2
                return 1
            fi
            case "$ks_action" in
                "set")              keystore_set "${2:-}" ;;
                "show")             keystore_show "${2:-}" ;;
                "list")             keystore_list ;;
                "delete"|"del"|"rm") keystore_delete "${2:-}" ;;
                ""|"help"|"-h"|"--help") keystore_show_usage ;;
                *)
                    echo -e "${RED}❌ Unknown keystore action: $ks_action${NC}" >&2
                    keystore_show_usage
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
        "update-config"|"update")
            update_config
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
