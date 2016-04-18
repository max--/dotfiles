## Git ##
# %b                    => current branch
# %a                    => current action (rebase/merge)

## Prompt ##
# %F{color_name}...%f   => color
# %~                    => current path
# %*                    => time
# %n                    => username
# %m                    => shortname host
# %(?..)                => prompt conditional - %(condition.true.false)


get_colored() {
    echo "%F{$2}$1%f"
}
get_colored2() {
    echo "\[\e[$2m\]$1\[\e[0m\]"
}
get_colored_transformed() {
    echo "\[\e[$3;$2m\]$1\[\e[0m\]"
}

get_prompt_char() {
    echo "%B$(get_colored '⨠' $1)%b"
}

get_user() {
    local _user="%B$(get_colored '◉ %n' $1)%b"
    # [[ "$SSH_CONNECTION" != '' ]] && _user="%B$(get_colored '◉ ssh' $1)"
    echo ${_user}
}

get_date() {
    echo "$(get_colored '【%*】' $1)"
}

get_path() {
    echo "$(get_colored '%~' $1)"
}

# Displays the execution time of the last command
get_cmd_exec_time() {
	local stop=$(date +%s)
	local start=${cmd_timestamp:-$stop}
	integer elapsed=$stop-$start
    echo "$(get_colored $(to_human_time $elapsed) $1)"
}

# Check if repo is dirty (files untracked, unstaged, staged) and if HEAD is ahead or behind
get_git_status () {
	# shows the full path in the title
	print -Pn '\e]0;%~\a'

	local _s=

    local full_status=

	local branch=
	local commit_hash=
	local commit_name=
	local commit=
	local local_status=
	local remote_status=

    local has_untracked=false
    local has_unstagged=false
    local is_clean=false

	local symbol_ahead="⇡"
	local symbol_behind="⇣"
	local symbol_untracked="✗"
	local symbol_unstagged="✷"
	local symbol_staged="✓"

	# git status to retrieve infos
	_s=$(command git status --porcelain -b --ignore-submodules=dirty 2>/dev/null)

	# untracked
	[[ -n $(echo "$_s" | grep '^?? ' 2> /dev/null) ]] &&
        has_untracked=true
	# unstaged
	[[ -n $(echo "$_s" | grep '^.[MTD] ' 2> /dev/null) ]] &&
        has_unstagged=true
	# staged
	[[ -n $(echo "$_s" | grep '^[AMRD]. ' 2> /dev/null) ]] &&
        is_clean=true

    if [[ $is_clean == true ]] ; then
        local_status=" $(get_colored ${symbol_staged} green)"
    elif [[ $has_untracked == true && $has_unstagged == true ]] ; then
        local_status=" $(get_colored ${symbol_unstagged} yellow) $(get_colored ${symbol_untracked} red)"
    else
        if [[ $has_untracked == true ]] ; then
            local_status=" $(get_colored ${symbol_untracked} red)"
        elif [[ $has_unstagged == true ]] ; then
            local_status=" $(get_colored ${symbol_unstagged} yellow)"
        fi
    fi

	# ahead
	[[ -n $(echo "$_s" | grep '^## .*ahead' 2> /dev/null) ]] &&
		remote_status=" $(get_colored ${symbol_ahead} cyan)"
	# behind
	[[ -n $(echo "$_s" | grep '^## .*behind' 2> /dev/null) ]] &&
		remote_status=" $(get_colored ${symbol_behind} cyan)"

    # last commit hash/name
    [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1 &&
        branch="$(git rev-parse --abbrev-ref HEAD)" &&
        commit_name="$(git log -1 --pretty=%B)" &&
        commit_hash="$(git log --pretty=format:'%h' -n 1)"

    # include commit name if length <= 20
    commit=$commit_hash
    [[ $(expr "${commit_name}" : '.*') -le 20 ]] && commit=$commit"("$commit_name")"

    # check if directory is a git repo
    [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1 &&
        full_status="$(get_colored '[' grey)$(get_colored ${branch} yellow)$(get_colored '::' grey)$(get_colored ${commit} cyan)%b${local_status}${remote_status}$(get_colored ']' grey)"

    echo $full_status
}

# Executed before every commands
prompt_preexec() {
	cmd_timestamp=$(date +%s)

	# Shows the current dir and executed command in the title when a process is active
	print -Pn "\e]0;"
	echo -nE "$PWD:t: $2"
	print -Pn "\a"
}

# Executed after every commands
prompt_precmd() {
    local EXIT="$?"
	local current_path=''
	print -Pn $current_path

    if [ $EXIT != 0 ]; then
        local prompt_max_preprompt='$(get_user magenta) $(get_path blue)$(get_git_status) $(get_date green)$(get_cmd_exec_time red) $(get_colored "✖︎" red)'
    else
        local prompt_max_preprompt='$(get_user magenta) $(get_path blue)$(get_git_status) $(get_date green)$(get_cmd_exec_time red)'
    fi
	print -P $prompt_max_preprompt


	# reset value since `preexec` isn't always triggered
	unset cmd_timestamp
}

prompt_setup() {
	autoload -Uz add-zsh-hook

	add-zsh-hook precmd prompt_precmd
	add-zsh-hook preexec prompt_preexec

	zstyle ':vcs_info:*' enable git
	zstyle ':vcs_info:git*' formats ' %b'
	zstyle ':vcs_info:git*' actionformats ' %b|%a'

	# show username@host if logged in through SSH
	# [[ "$SSH_CONNECTION" != '' ]] && prompt_pure_username='%n@%m '

	# prompt turns red if the previous command didn't exit with 0
	# PROMPT='%(?.%F{magenta}.%F{red})> %f \d'

    # RPROMPT="$(get_git_status)"
    export SUDO_PS1="$(get_colored_transformed '◉ root' 35 1) $(get_colored2 "\w" 34) \n$(get_colored2 "⨠" 31) "
    PROMPT='$(get_prompt_char red) %f'


    unset cmd_timestamp
}

prompt_setup "$@"
