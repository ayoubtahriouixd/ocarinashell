# OcarinaShell · fish (phase 8). Sits on top of CachyOS's config (/usr/share/cachyos-fish-config), never replaces it.
# Start-up budget: `fish -i -c exit` < 40 ms. Nothing here spawns a process on the hot path: zoxide and starship are
# initialised from scripts cached in ~/.cache/ocarinashell/fish (regenerated only when their binary changes); the
# greeting reads ~/.cache/ocarinashell/daily.fish (bin/ocarina-daily, once a day).
status is-interactive; or return

set -l cache (set -q XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo ~/.cache)/ocarinashell
set -g __ocarina_cache $cache

# ── environment ─────────────────────────────────────────────────────────────────────────────────
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx PAGER less
set -gx LESS '-R --mouse --wheel-lines=3 -i -M -j.3'
set -gx BAT_PAGER 'less -RF'
set -gx MANROFFOPT -c
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
# less without bat (git, journalctl…): bold → accent, underline → accent2, standout → selection
set -gx GROFF_NO_SGR 1
set -gx LESS_TERMCAP_md (set_color -o $fish_color_keyword)
set -gx LESS_TERMCAP_us (set_color -u $fish_color_redirection)
set -gx LESS_TERMCAP_so (set_color -r)
set -gx LESS_TERMCAP_me (set_color normal)
set -gx LESS_TERMCAP_ue (set_color normal)
set -gx LESS_TERMCAP_se (set_color normal)
# fzf: files with fd (hidden, .gitignore respected); previews with bat / eza. Colours: theme/colors.fish
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
set -gx FZF_CTRL_T_OPTS "--preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || eza -1 --color=always --icons=always {}' --preview-window=right,60%,border-left"
set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
set -gx FZF_ALT_C_OPTS "--preview 'eza -T -L2 --color=always --icons=always {}' --preview-window=right,50%,border-left"
set -gx FZF_CTRL_R_OPTS "--layout=reverse --height=50% --preview-window=hidden"

# ── cached init scripts (zoxide, starship) ──────────────────────────────────────────────────────
function __ocarina_cached --argument-names name
    # __ocarina_cached <name> <command…>: source the cached output of <command>, regenerating it if the binary
    # is newer than the cache (or the cache is missing)
    set -l file $__ocarina_cache/fish/$name.fish
    set -l bin (command -s $argv[2]); or return
    if not test -s $file; or test (path mtime $bin) -gt (path mtime $file)
        mkdir -p $__ocarina_cache/fish
        $argv[2..] >$file.tmp 2>/dev/null; and mv -f $file.tmp $file
    end
    source $file
end

__ocarina_cached zoxide zoxide init fish
__ocarina_cached starship starship init fish --print-full-init

# transient prompt: past prompts collapse to «❯ command» (mockup 01)
function starship_transient_prompt_func
    set_color $fish_color_autosuggestion
    printf '❯ '
    set_color normal
end
functions -q enable_transience; and enable_transience

# fzf: Ctrl+R history · Ctrl+T files · Alt+C directories (function shipped by the fzf package)
functions -q fzf_key_bindings; and fzf_key_bindings

# ── window title: «command · dir» while something runs, «dir» at the prompt (Obi shows it) ───────
function fish_title
    set -q argv[1]; or set argv (status current-command)
    set -l dir (prompt_pwd -d 2)
    if test -n "$argv[1]" -a "$argv[1]" != fish
        echo (string split -f1 ' ' -- $argv[1]) · $dir
    else
        echo $dir
    end
end

# ── abbreviations ───────────────────────────────────────────────────────────────────────────────
# packages (AUR only with paru; «yay» is muscle memory)
abbr -a yay paru
abbr -a pi 'paru -S'
abbr -a pu 'paru -Syu'
abbr -a pss 'paru -Ss'
abbr -a pr 'sudo pacman -Rns'
abbr -a pq 'pacman -Qi'
abbr -a pfile 'pacman -Qo'
# git
abbr -a g git
abbr -a gs 'git status -sb'
abbr -a ga 'git add'
abbr -a gaa 'git add -A'
abbr -a gc 'git commit'
abbr -a gcm 'git commit -m'
abbr -a gca 'git commit --amend'
abbr -a gd 'git diff'
abbr -a gds 'git diff --staged'
abbr -a gl 'git log --oneline --graph --decorate -20'
abbr -a gp 'git push'
abbr -a gpl 'git pull --rebase'
abbr -a gsw 'git switch'
abbr -a gst 'git stash'
abbr -a lg lazygit
# niri · OcarinaShell
abbr -a nm 'niri msg'
abbr -a nmw 'niri msg windows'
abbr -a nmo 'niri msg outputs'
abbr -a nv 'niri validate'
abbr -a o ocarina
abbr -a ol 'ocarina logs -f'
abbr -a od 'ocarina doctor'
# everyday
abbr -a v nvim
abbr -a sv 'sudoedit'
abbr -a jf 'journalctl -f'
abbr -a ju 'journalctl --user -f -u'
abbr -a sc 'systemctl'
abbr -a scu 'systemctl --user'
abbr -a cat 'bat -pp'
abbr -a tree 'eza -T --icons=always --group-directories-first'
abbr -a ff fastfetch

# yazi: leave it in the directory you were browsing
function y --description 'yazi (cd on exit)'
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file=$tmp
    if read -z cwd <$tmp; and test -n "$cwd" -a "$cwd" != "$PWD"
        builtin cd -- $cwd
    end
    rm -f -- $tmp
end

# 蛇 Snake (phase 15): ask the local AI from the terminal; what you pipe in is its context
#   snake "¿cómo silencio el micro?"      journalctl -b -p warning | snake "¿qué falla?"
function snake --description '蛇 Snake: pregunta a la IA local'
    if not command -q ocarina-snake
        echo (set_color $fish_color_autosuggestion)'蛇 Snake no está instalado (~/ocarinashell/scripts/install.sh)'(set_color normal)
        return 1
    end
    if test (count $argv) -eq 0
        ocarina snake
        return
    end
    ocarina-snake ask -- (string join ' ' -- $argv)
end

# 本番 Honban: «ssh host» for a production host from a normal terminal opens it in its own red-ringed window
function ossh --description '本番 Honban: ssh en su propia ventana (anillo rojo si es producción)'
    ocarina ssh $argv
end
complete -c ossh -f -a '(ocarina-ssh-hosts | string split -f1 \t)'
complete -c ocarina -n '__fish_seen_subcommand_from ssh' -f -a '(ocarina-ssh-hosts | string split -f1 \t)'

# ── greeting (< 5 ms): こんばんは, Ayoub · 節気 · 候 / 諺 proverb of the day ─────────────────────────
# fish_greeting itself is redefined by CachyOS (fastfetch) after conf.d; config.fish's OcarinaShell block points it
# here (scripts/install.sh adds that block).
function __ocarina_greeting
    set -l now (date '+%F %H')
    set -l today (string split -f1 ' ' -- $now)
    set -l hour (string split -f2 ' ' -- $now)
    if test "$__ocarina_day" != "$today"
        command -q ocarina-daily; and begin
            ocarina-daily --quiet &
            disown
        end
    end
    # fastfetch only the first terminal of the day (or with «ff»)
    set -l stamp $__ocarina_cache/fastfetch-day
    if test "$__ocarina_fastfetch_daily" = 1; and command -q fastfetch
        set -l last
        test -r $stamp; and read last <$stamp
        if test "$last" != "$today"
            mkdir -p $__ocarina_cache
            echo $today >$stamp
            fastfetch
            return
        end
    end
    test "$__ocarina_greeting_on" = 0; and return
    set -q __ocarina_greet[1]; or return
    set -l greet $__ocarina_greet[(math $hour + 1)]
    set -l dim (set_color $fish_color_autosuggestion)
    set -l n (set_color normal)
    printf '%s%s%s、%s%s  %s%s · %s%s\n' (set_color $fish_color_keyword) $greet $n $__ocarina_name $dim \
        $OCARINA_SEKKI $__ocarina_ko $__ocarina_ko_es $n
    test -n "$__ocarina_proverb_jp"; and printf '%s諺 %s — %s%s\n' $dim $__ocarina_proverb_jp $__ocarina_proverb_es $n
end

# 節気 for starship even before the greeting runs (and in shells without a greeting)
test -r $cache/daily.fish; and source $cache/daily.fish
