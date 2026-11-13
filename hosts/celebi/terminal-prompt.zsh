# Applied after common/p10k.zsh; only celebi imports this trial design.
typeset -g POWERLEVEL9K_MODE=nerdfont-v3
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs nix_shell virtualenv newline prompt_char)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time newline)
typeset -g POWERLEVEL9K_BACKGROUND=
typeset -g POWERLEVEL9K_FOREGROUND='#cad3f5'
typeset -g POWERLEVEL9K_VISUAL_IDENTIFIER_EXPANSION=
typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{LEFT,RIGHT}_WHITESPACE=
typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{SUBSEGMENT,SEGMENT}_SEPARATOR=
typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=
typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=
typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=
typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=
typeset -g POWERLEVEL9K_MULTILINE_{FIRST,NEWLINE,LAST}_PROMPT_{PREFIX,SUFFIX}=
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

# Draw each badge independently, including its cap and the transparent gap.
# No separator inherits the previous badge's background.
celebi_prompt_badge() {
  local segment=$1 background=$2 foreground=$3
  typeset -g "POWERLEVEL9K_${segment}_BACKGROUND=$background"
  typeset -g "POWERLEVEL9K_${segment}_FOREGROUND=$foreground"
  typeset -g "POWERLEVEL9K_${segment}_PREFIX=%k%F{$background}%K{$background}%F{$foreground}"
  typeset -g "POWERLEVEL9K_${segment}_SUFFIX=%k%F{$background} "
}
celebi_prompt_badge CONTEXT '#363a4f' '#8aadf4'
celebi_prompt_badge CONTEXT_ROOT '#ed8796' '#24273a'
celebi_prompt_badge DIR '#494d64' '#cad3f5'
celebi_prompt_badge VCS '#363a4f' '#a5adcb'
celebi_prompt_badge NIX_SHELL '#c6a0f6' '#24273a'
celebi_prompt_badge VIRTUALENV '#363a4f' '#f5bde6'
unfunction celebi_prompt_badge

# Retain the shared prompt's conditional context: local user hidden, SSH
# user@host visible, and root visible even outside SSH.
typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'
typeset -g POWERLEVEL9K_CONTEXT_ROOT_TEMPLATE='root@%m'
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
typeset -g POWERLEVEL9K_SHORTEN_FOLDER_MARKER='(.git|flake.nix)'
typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
typeset -g POWERLEVEL9K_DIR_MAX_LENGTH='60%'
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND='#cad3f5'
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND='#a5adcb'

typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=
typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_EXPANSION=$'\uF126'
typeset -g POWERLEVEL9K_VCS_{INCOMING,OUTGOING}_CHANGESFORMAT_FOREGROUND='#8bd5ca'
typeset -g POWERLEVEL9K_NIX_SHELL_VISUAL_IDENTIFIER_EXPANSION=$'\uF313'
typeset -g POWERLEVEL9K_NIX_SHELL_CONTENT_EXPANSION=nix
typeset -g POWERLEVEL9K_VIRTUALENV_VISUAL_IDENTIFIER_EXPANSION=$'\uE73C'

# The right side is quiet on success. Only failures and commands taking at
# least five seconds add detail; there is no second clock beside Plasma's.
typeset -g POWERLEVEL9K_STATUS_OK=false
typeset -g POWERLEVEL9K_STATUS_OK_PIPE=false
typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
typeset -g POWERLEVEL9K_STATUS_ERROR=true
typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL=true
typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE=true
typeset -g POWERLEVEL9K_STATUS_VERBOSE=true
typeset -g POWERLEVEL9K_STATUS_ICON_BEFORE_CONTENT=true
typeset -g POWERLEVEL9K_STATUS_ERROR_VISUAL_IDENTIFIER_EXPANSION='×'
typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_VISUAL_IDENTIFIER_EXPANSION='×'
typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_VISUAL_IDENTIFIER_EXPANSION='×'
typeset -g POWERLEVEL9K_STATUS_FOREGROUND='#ed8796'
typeset -g POWERLEVEL9K_STATUS_SUFFIX=' '
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND='#eed49f'
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=5

typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_RIGHT_WHITESPACE=' '
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS}_FOREGROUND='#c6a0f6'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS}_FOREGROUND='#ed8796'
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always
(( ! $+functions[p10k] )) || p10k reload
