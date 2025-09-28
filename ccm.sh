#!/bin/bash
############################################################
# Claude Code Model Switcher (ccm) - 独立版本
# ---------------------------------------------------------
# 功能: 在不同AI模型之间快速切换
# 支持: Claude, Deepseek, GLM4.5, KIMI2
# 作者: Peng
# 版本: 2.0.0
############################################################

# 脚本颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_FILE="$HOME/.ccm_config"

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
    unset $(set | grep '^TRANS_' | cut -d= -f1) 2>/dev/null || true

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

# GLM4.5 (智谱清言)
GLM_API_KEY=your-glm-api-key

# KIMI2 (月之暗面)
KIMI_API_KEY=your-moonshot-api-key

# LongCat（美团）
LONGCAT_API_KEY=your-longcat-api-key

# Qwen（阿里云 DashScope）
QWEN_API_KEY=your-qwen-api-key

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# —— 可选：模型ID覆盖（不设置则使用下方默认）——
DEEPSEEK_MODEL=deepseek-chat
DEEPSEEK_SMALL_FAST_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2-turbo-preview
KIMI_SMALL_FAST_MODEL=kimi-k2-turbo-preview
QWEN_MODEL=qwen3-max
QWEN_SMALL_FAST_MODEL=qwen3-next-80b-a3b-instruct
GLM_MODEL=glm-4.5
GLM_SMALL_FAST_MODEL=glm-4.5-air
CLAUDE_MODEL=claude-sonnet-4-20250514
CLAUDE_SMALL_FAST_MODEL=claude-sonnet-4-20250514
OPUS_MODEL=claude-opus-4-1-20250805
OPUS_SMALL_FAST_MODEL=claude-sonnet-4-20250514
LONGCAT_MODEL=LongCat-Flash-Thinking
LONGCAT_SMALL_FAST_MODEL=LongCat-Flash-Chat

# 备用提供商（仅当且仅当官方密钥未提供时启用）
PPINFRA_API_KEY=your-ppinfra-api-key  # https://api.ppinfra.com/openai/v1/anthropic
EOF
        echo -e "${YELLOW}⚠️  $(t 'config_created'): $CONFIG_FILE${NC}"
        echo -e "${YELLOW}   $(t 'edit_file_to_add_keys')${NC}"
        return 1
    fi
    
    # 首先读取语言设置
    if [[ -f "$CONFIG_FILE" ]]; then
        local config_lang
        config_lang=$(grep -E "^[[:space:]]*CCM_LANGUAGE[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
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
            # 仅当环境未设置时才应用
            if [[ -n "$key" && -z "${!key}" ]]; then
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

# GLM4.5 (智谱清言)
GLM_API_KEY=your-glm-api-key

# KIMI2 (月之暗面)
KIMI_API_KEY=your-moonshot-api-key

# LongCat（美团）
LONGCAT_API_KEY=your-longcat-api-key

# Qwen（阿里云 DashScope）
QWEN_API_KEY=your-qwen-api-key

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# —— 可选：模型ID覆盖（不设置则使用下方默认）——
DEEPSEEK_MODEL=deepseek-chat
DEEPSEEK_SMALL_FAST_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2-turbo-preview
KIMI_SMALL_FAST_MODEL=kimi-k2-turbo-preview
QWEN_MODEL=qwen3-max
QWEN_SMALL_FAST_MODEL=qwen3-next-80b-a3b-instruct
GLM_MODEL=glm-4.5
GLM_SMALL_FAST_MODEL=glm-4.5-air
CLAUDE_MODEL=claude-sonnet-4-20250514
CLAUDE_SMALL_FAST_MODEL=claude-sonnet-4-20250514
OPUS_MODEL=claude-opus-4-1-20250805
OPUS_SMALL_FAST_MODEL=claude-sonnet-4-20250514
LONGCAT_MODEL=LongCat-Flash-Thinking
LONGCAT_SMALL_FAST_MODEL=LongCat-Flash-Chat

# 备用提供商（仅当且仅当官方密钥未提供时启用）
PPINFRA_API_KEY=your-ppinfra-api-key  # https://api.ppinfra.com/openai/v1/anthropic
EOF
    echo -e "${YELLOW}⚠️  $(t 'config_created'): $CONFIG_FILE${NC}"
    echo -e "${YELLOW}   $(t 'edit_file_to_add_keys')${NC}"
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

# 显示当前状态（脱敏）
show_status() {
    echo -e "${BLUE}📊 $(t 'current_model_config'):${NC}"
    echo "   BASE_URL: ${ANTHROPIC_BASE_URL:-'Default (Anthropic)'}"
    echo -n "   AUTH_TOKEN: "
    mask_token "${ANTHROPIC_AUTH_TOKEN}"
    echo "   MODEL: ${ANTHROPIC_MODEL:-'$(t "not_set")'}"
    echo "   SMALL_MODEL: ${ANTHROPIC_SMALL_FAST_MODEL:-'$(t "not_set")'}"
    echo ""
    echo -e "${BLUE}🔧 $(t 'env_vars_status'):${NC}"
    echo "   GLM_API_KEY: $(mask_presence GLM_API_KEY)"
    echo "   KIMI_API_KEY: $(mask_presence KIMI_API_KEY)"
    echo "   LONGCAT_API_KEY: $(mask_presence LONGCAT_API_KEY)"
    echo "   DEEPSEEK_API_KEY: $(mask_presence DEEPSEEK_API_KEY)"
    echo "   QWEN_API_KEY: $(mask_presence QWEN_API_KEY)"
    echo "   PPINFRA_API_KEY: $(mask_presence PPINFRA_API_KEY)"
}

# 清理环境变量
clean_env() {
    unset ANTHROPIC_BASE_URL
    unset ANTHROPIC_API_URL
    unset ANTHROPIC_AUTH_TOKEN
    unset ANTHROPIC_API_KEY
    unset ANTHROPIC_MODEL
    unset ANTHROPIC_SMALL_FAST_MODEL
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
        export ANTHROPIC_API_URL="https://api.deepseek.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
        export ANTHROPIC_API_KEY="$DEEPSEEK_API_KEY"
        export ANTHROPIC_MODEL="deepseek-chat"
        export ANTHROPIC_SMALL_FAST_MODEL="deepseek-coder"
        echo -e "${GREEN}✅ $(t 'switched_to') Deepseek（$(t 'official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # 备用：PPINFRA Anthropic 兼容
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/openai/v1/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/openai/v1/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="deepseek/deepseek-v3.1"
        export ANTHROPIC_SMALL_FAST_MODEL="deepseek/deepseek-v3.1"
        echo -e "${GREEN}✅ $(t 'switched_to') Deepseek（$(t 'ppinfra_backup')）${NC}"
    else
        echo -e "${RED}❌ $(t 'not_detected') DEEPSEEK_API_KEY，$(t 'and') PPINFRA_API_KEY $(t 'not_configured')，$(t 'cannot_switch')${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# 切换到Claude Sonnet
switch_to_claude() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Claude Sonnet 4...${NC}"
    clean_env
    export ANTHROPIC_MODEL="claude-sonnet-4-20250514"
    export ANTHROPIC_SMALL_FAST_MODEL="claude-sonnet-4-20250514"
    echo -e "${GREEN}✅ $(t 'switched_to') Claude Sonnet 4 ($(t 'using_pro_subscription'))${NC}"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到Claude Opus
switch_to_opus() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Claude Opus 4.1...${NC}"
    clean_env
    export ANTHROPIC_MODEL="claude-opus-4-1-20250805"
    export ANTHROPIC_SMALL_FAST_MODEL="claude-sonnet-4-20250514"
    echo -e "${GREEN}✅ $(t 'switched_to') Claude Opus 4.1 ($(t 'using_pro_subscription'))${NC}"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到GLM4.5
switch_to_glm() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') GLM4.5 $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$GLM_API_KEY"; then
        export ANTHROPIC_BASE_URL="https://open.bigmodel.cn/api/anthropic"
        export ANTHROPIC_API_URL="https://open.bigmodel.cn/api/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$GLM_API_KEY"
        export ANTHROPIC_API_KEY="$GLM_API_KEY"
        export ANTHROPIC_MODEL="glm-4.5"
        export ANTHROPIC_SMALL_FAST_MODEL="glm-4.5"
        echo -e "${GREEN}✅ $(t 'switched_to') GLM4.5（$(t 'official')）${NC}"
    else
        echo -e "${RED}❌ $(t 'not_detected') GLM_API_KEY。$(t 'glm_official_only')${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到KIMI2
switch_to_kimi() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') KIMI2 $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$KIMI_API_KEY"; then
        # 官方 Moonshot KIMI 的 Anthropic 兼容端点
        export ANTHROPIC_BASE_URL="https://api.moonshot.cn/anthropic"
        export ANTHROPIC_API_URL="https://api.moonshot.cn/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$KIMI_API_KEY"
        export ANTHROPIC_API_KEY="$KIMI_API_KEY"
        export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
        export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2-turbo-preview"
        echo -e "${GREEN}✅ $(t 'switched_to') KIMI2（$(t 'official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # 备用：PPINFRA Anthropic 兼容
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/openai/v1/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/openai/v1/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
        export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2-turbo-preview"
        echo -e "${GREEN}✅ $(t 'switched_to') KIMI2（$(t 'ppinfra_backup')）${NC}"
    else
        echo -e "${RED}❌ $(t 'not_detected') KIMI_API_KEY，$(t 'and') PPINFRA_API_KEY $(t 'not_configured')，$(t 'cannot_switch')${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到 Qwen（阿里云官方优先，缺省走 PPINFRA）
switch_to_qwen() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Qwen $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$QWEN_API_KEY"; then
        # 阿里云 DashScope 官方 Claude 代理端点
        export ANTHROPIC_BASE_URL="https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy"
        export ANTHROPIC_API_URL="https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy"
        export ANTHROPIC_AUTH_TOKEN="$QWEN_API_KEY"
        export ANTHROPIC_API_KEY="$QWEN_API_KEY"
        # 阿里云 DashScope 支持的模型
        local qwen_model="${QWEN_MODEL:-qwen3-max}"
        local qwen_small="${QWEN_SMALL_FAST_MODEL:-qwen3-next-80b-a3b-instruct}"
        export ANTHROPIC_MODEL="$qwen_model"
        export ANTHROPIC_SMALL_FAST_MODEL="$qwen_small"
        echo -e "${GREEN}✅ $(t 'switched_to') Qwen（$(t 'alibaba_dashscope_official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/openai/v1/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/openai/v1/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="qwen3-next-80b-a3b-thinking"
        export ANTHROPIC_SMALL_FAST_MODEL="qwen3-next-80b-a3b-thinking"
        echo -e "${GREEN}✅ $(t 'switched_to') Qwen（$(t 'ppinfra_backup')）${NC}"
    else
        echo -e "${RED}❌ $(t 'not_detected') QWEN_API_KEY $(t 'or') PPINFRA_API_KEY，$(t 'cannot_switch')${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}🔧 $(t 'switching_info') v2.1.0${NC}"
    echo ""
    echo -e "${YELLOW}$(t 'usage'):${NC} $(basename "$0") [options]"
    echo ""
    echo -e "${YELLOW}$(t 'model_options'):${NC}"
    echo "  deepseek, ds       - env deepseek"
    echo "  kimi, kimi2        - env kimi"
    echo "  longcat, lc        - env longcat"
    echo "  qwen               - env qwen"
    echo "  glm, glm4          - env glm"
    echo "  claude, sonnet, s  - env claude"
    echo "  opus, o            - env opus"
    echo ""
    echo -e "${YELLOW}$(t 'tool_options'):${NC}"
    echo "  status, st       - $(t 'show_current_config')"
    echo "  env [model]      - $(t 'output_export_only')"
    echo "  config, cfg      - $(t 'edit_config_file')"
    echo "  help, h          - $(t 'show_help')"
    echo ""
    echo -e "${YELLOW}$(t 'examples'):${NC}"
    echo "  eval \"\$(ccm deepseek)\"                   # Apply in current shell (recommended)"
    echo "  $(basename "$0") status                      # Check current status (masked)"
    echo ""
    echo -e "${YELLOW}$(t 'supported_models'):${NC}"
    echo "  🌙 KIMI2               - $(t 'official'): kimi-k2-turbo-preview"
    echo "  🤖 Deepseek            - $(t 'deepseek_features')"
    echo "  🐱 LongCat             - $(t 'longcat_features')"
    echo "  🐪 Qwen                - $(t 'qwen_features')"
    echo "  🇨🇳 GLM4.5             - $(t 'glm_features')"
    echo "  🧠 Claude Sonnet 4     - $(t 'claude_sonnet_features')"
    echo "  🚀 Claude Opus 4.1     - $(t 'claude_opus_features')"
}

# 将缺失的模型ID覆盖项追加到配置文件（仅追加缺失项，不覆盖已存在的配置）
ensure_model_override_defaults() {
    local -a pairs=(
        "DEEPSEEK_MODEL=deepseek-chat"
        "DEEPSEEK_SMALL_FAST_MODEL=deepseek-chat"
        "KIMI_MODEL=kimi-k2-turbo-preview"
        "KIMI_SMALL_FAST_MODEL=kimi-k2-turbo-preview"
        "LONGCAT_MODEL=LongCat-Flash-Thinking"
        "LONGCAT_SMALL_FAST_MODEL=LongCat-Flash-Chat"
        "QWEN_MODEL=qwen3-max"
        "QWEN_SMALL_FAST_MODEL=qwen3-next-80b-a3b-instruct"
        "GLM_MODEL=glm-4.5"
        "GLM_SMALL_FAST_MODEL=glm-4.5-air"
        "CLAUDE_MODEL=claude-sonnet-4-20250514"
        "CLAUDE_SMALL_FAST_MODEL=claude-sonnet-4-20250514"
        "OPUS_MODEL=claude-opus-4-1-20250805"
        "OPUS_SMALL_FAST_MODEL=claude-sonnet-4-20250514"
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
emit_env_exports() {
    local target="$1"
    # 加载配置以便进行存在性判断（环境变量优先，不打印密钥）
    load_config || return 1

    # 通用前导：清理旧变量
    local prelude="unset ANTHROPIC_BASE_URL ANTHROPIC_API_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL API_TIMEOUT_MS CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"

    case "$target" in
        "deepseek"|"ds")
            if is_effectively_set "$DEEPSEEK_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.deepseek.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.deepseek.com/anthropic'"
                echo "# $(t 'export_if_env_not_set')"
                echo "if [ -z \"\${DEEPSEEK_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${DEEPSEEK_API_KEY}\""
                local ds_model="${DEEPSEEK_MODEL:-deepseek-chat}"
                local ds_small="${DEEPSEEK_SMALL_FAST_MODEL:-deepseek-chat}"
                echo "export ANTHROPIC_MODEL='${ds_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${ds_small}'"
            elif is_effectively_set "$PPINFRA_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/openai/v1/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/openai/v1/anthropic'"
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local ds_model="${DEEPSEEK_MODEL:-deepseek/deepseek-v3.1}"
                local ds_small="${DEEPSEEK_SMALL_FAST_MODEL:-deepseek/deepseek-v3.1}"
                echo "export ANTHROPIC_MODEL='${ds_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${ds_small}'"
            else
                echo "# ❌ $(t 'not_detected') DEEPSEEK_API_KEY $(t 'or') PPINFRA_API_KEY" 1>&2
                return 1
            fi
            ;;
        "kimi"|"kimi2")
            if is_effectively_set "$KIMI_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.moonshot.cn/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.moonshot.cn/anthropic'"
                echo "if [ -z \"\${KIMI_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${KIMI_API_KEY}\""
                local kimi_model="${KIMI_MODEL:-kimi-k2-turbo-preview}"
                local kimi_small="${KIMI_SMALL_FAST_MODEL:-kimi-k2-turbo-preview}"
                echo "export ANTHROPIC_MODEL='${kimi_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${kimi_small}'"
            elif is_effectively_set "$PPINFRA_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/openai/v1/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/openai/v1/anthropic'"
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local kimi_model="${KIMI_MODEL:-kimi-k2-turbo-preview}"
                local kimi_small="${KIMI_SMALL_FAST_MODEL:-kimi-k2-turbo-preview}"
                echo "export ANTHROPIC_MODEL='${kimi_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${kimi_small}'"
            else
                echo "# ❌ $(t 'not_detected') KIMI_API_KEY $(t 'or') PPINFRA_API_KEY" 1>&2
                return 1
            fi
            ;;
        "qwen")
            if is_effectively_set "$QWEN_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy'"
                echo "export ANTHROPIC_API_URL='https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy'"
                echo "if [ -z \"\${QWEN_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${QWEN_API_KEY}\""
                local qwen_model="${QWEN_MODEL:-qwen3-max}"
                local qwen_small="${QWEN_SMALL_FAST_MODEL:-qwen3-next-80b-a3b-instruct}"
                echo "export ANTHROPIC_MODEL='${qwen_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${qwen_small}'"
            elif is_effectively_set "$PPINFRA_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/openai/v1/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/openai/v1/anthropic'"
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local qwen_model="${QWEN_MODEL:-qwen3-next-80b-a3b-thinking}"
                local qwen_small="${QWEN_SMALL_FAST_MODEL:-qwen3-next-80b-a3b-thinking}"
                echo "export ANTHROPIC_MODEL='${qwen_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${qwen_small}'"
            else
                echo "# ❌ $(t 'not_detected') QWEN_API_KEY $(t 'or') PPINFRA_API_KEY" 1>&2
                return 1
            fi
            ;;
        "glm"|"glm4"|"glm4.5")
            if is_effectively_set "$GLM_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://open.bigmodel.cn/api/anthropic'"
                echo "export ANTHROPIC_API_URL='https://open.bigmodel.cn/api/anthropic'"
                echo "if [ -z \"\${GLM_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${GLM_API_KEY}\""
local glm_model="${GLM_MODEL:-glm-4.5}"
                local glm_small="${GLM_SMALL_FAST_MODEL:-glm-4.5-air}"
                echo "export ANTHROPIC_MODEL='${glm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${glm_small}'"
            else
                echo "# ❌ GLM $(t 'requires_official_key') GLM_API_KEY" 1>&2
                return 1
            fi
            ;;
        "claude"|"sonnet"|"s")
            echo "$prelude"
            # 官方 Anthropic 默认网关，无需设置 BASE_URL
            echo "unset ANTHROPIC_BASE_URL"
            echo "unset ANTHROPIC_API_URL"
            echo "unset ANTHROPIC_API_KEY"
            local claude_model="${CLAUDE_MODEL:-claude-sonnet-4-20250514}"
            local claude_small="${CLAUDE_SMALL_FAST_MODEL:-claude-sonnet-4-20250514}"
            echo "export ANTHROPIC_MODEL='${claude_model}'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='${claude_small}'"
            ;;
        "opus"|"o")
            echo "$prelude"
            echo "unset ANTHROPIC_BASE_URL"
            echo "unset ANTHROPIC_API_URL"
            echo "unset ANTHROPIC_API_KEY"
            local opus_model="${OPUS_MODEL:-claude-opus-4-1-20250805}"
            local opus_small="${OPUS_SMALL_FAST_MODEL:-claude-sonnet-4-20250514}"
            echo "export ANTHROPIC_MODEL='${opus_model}'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='${opus_small}'"
            ;;
        "longcat")
            if ! is_effectively_set "$LONGCAT_API_KEY"; then
                # 兜底：直接 source 配置文件一次（修复某些行格式导致的加载失败）
                if [ -f "$HOME/.ccm_config" ]; then . "$HOME/.ccm_config" >/dev/null 2>&1; fi
            fi
            if is_effectively_set "$LONGCAT_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.longcat.chat/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.longcat.chat/anthropic'"
                echo "if [ -z \"\${LONGCAT_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${LONGCAT_API_KEY}\""
local lc_model="${LONGCAT_MODEL:-LongCat-Flash-Thinking}"
                local lc_small="${LONGCAT_SMALL_FAST_MODEL:-LongCat-Flash-Chat}"
                echo "export ANTHROPIC_MODEL='${lc_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${lc_small}'"
            else
                echo "# ❌ $(t 'not_detected') LONGCAT_API_KEY" 1>&2
                return 1
            fi
            ;;
        *)
            echo "# $(t 'usage'): $(basename "$0") env [deepseek|kimi|qwen|glm|claude|opus]" 1>&2
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
    case "${1:-help}" in
        "deepseek"|"ds")
            emit_env_exports deepseek
            ;;
        "kimi"|"kimi2")
            emit_env_exports kimi
            ;;
        "qwen")
            emit_env_exports qwen
            ;;
        "longcat"|"lc")
            emit_env_exports longcat
            ;;
        "glm"|"glm4"|"glm4.5")
            emit_env_exports glm
            ;;
        "claude"|"sonnet"|"s")
            emit_env_exports claude
            ;;
        "opus"|"o")
            emit_env_exports opus
            ;;
        "env")
            shift
            emit_env_exports "${1:-}"
            ;;
        "status"|"st")
            show_status
            ;;
        "config"|"cfg")
            edit_config
            ;;
        "help"|"h"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}❌ $(t 'unknown_option'): $1${NC}"
            echo ""
            show_help
            return 1
            ;;
    esac
}

# 执行主函数
main "$@"
