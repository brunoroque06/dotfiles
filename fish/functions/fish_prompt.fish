function fish_prompt
  set -l last_status $status
  printf '\n'
  prompt::dir
  prompt::git
  prompt::status $last_status
  printf '\n'
  prompt::lambda
  set_color -b normal normal
end

function prompt::dir
  set_color -b blue black
  printf ' %s ' (pwd | sed "s,^$HOME,~,")
end

function prompt::git
  prompt::git::is_repo; or return
  if test -z (git status -s | head -n 1)
    set_color -b green black
  else
    set_color -b yellow black
  end
  printf ' ⎇ %s ' (git rev-parse --abbrev-ref HEAD)
end

function prompt::git::is_repo
  command git rev-parse --is-inside-work-tree ^/dev/null >/dev/null
end

function prompt::status
  set_color -b normal red
  if [ $argv[1] -ne 0 ]
    printf ' ✖'
  end
end

function prompt::lambda
  set_color -b normal magenta
  printf 'λ '
end
