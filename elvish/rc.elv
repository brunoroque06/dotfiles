use file
use math
use path
use readline-binding
use str

set paths = [
  /opt/homebrew/bin
  /usr/local/bin
  /usr/bin
  /bin
  /usr/sbin
  /sbin
  $E:HOME/go/bin
  /usr/local/share/dotnet
  $E:HOME/.dotnet/tools
]
var _paths = $nil

set E:BAT_STYLE = plain
set E:BAT_THEME = ansi
# set E:DOCKER_DEFAULT_PLATFORM = linux/amd64
set E:EDITOR = /opt/homebrew/bin/hx
set E:JAVA_HOME = /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
set E:LESS = '-i --incsearch -M'
set E:PAGER = /opt/homebrew/bin/less
set E:RIPGREP_CONFIG_PATH = $E:HOME/.config/ripgreprc
set E:VISUAL = $E:EDITOR
# set E:REQUESTS_CA_BUNDLE = $E:HOME/.proxyman/proxyman-ca.pem # proxyman with python

var _dur = 0
var _err = $false

set edit:after-command = [
  { |m| set _dur = $m[duration] }
  { |m| set _err = (not-eq $m[error] $nil) }
]

fn osc { |c| print "\e]"$c"\a" }

fn send-title { |t| osc '0;'$t }

fn send-pwd {
  send-title (tilde-abbr $pwd | path:base (one))
  osc '7;'(put $pwd)
}

set edit:before-readline = [
  { send-pwd }
  { osc '133;A' }
]

set edit:after-readline = [
  { |c| send-title (str:split ' ' $c | take 1) }
  { |c| osc '133;C' }
]

set after-chdir = [
  { |_| send-pwd }
]

set edit:prompt = {
  var err = (if (put $_err) { put red } else { put blue })
  styled ' ' $err inverse

  if (not-eq $_paths $nil) { put ' *' }

  fn abbr { |dirs|
    each { |d|
      if (eq $d '') {
        put /$d
      } elif (eq $d[0] '.') {
        put $d[0..2]
      } else {
        put $d[0]
      }
    } $dirs[0..-1]
    put $dirs[-1]
  }

  tilde-abbr $pwd ^
    | str:split $path:separator (one) ^
    | abbr [(all)] ^
    | path:join (all) ^
    | styled ' '(one) blue

  if (> $_dur 5) {
    var m = (/ $_dur 60 | math:floor (one))
    if (> $m 0) {
      printf ' %.0fm' $m | styled (one) yellow
    }
    var s = (math:floor $_dur | printf '%.0f' (one) | % (one) 60)
    printf ' %.0fs' $s | styled (one) yellow
  }

  styled ' ~> ' magenta
}
set edit:rprompt = (constantly (whoami)@(hostname))

eval (carapace _carapace | slurp)

# Azure
fn az-act-set { |n| az account set -n $n }
set edit:completion:arg-completer[az-act-set] = { |@args|
  az account list ^
    | from-json ^
    | all (one) ^
    | each { |s| edit:complex-candidate $s[name] &display=(if (put $s[isDefault]) { styled $s[name] green } else { put $s[name] }) }
}

# Bazel
fn bzl-su {
  var dir = /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
  mkdir -p $dir
  ln -s /Library/Developer/CommandLineTools/SDKs/MacOSX11.3.sdk $dir
}

# Command
fn cmd-edit {
  var tmp = (path:temp-file '*.elv')
  print $edit:current-command > $tmp
  try {
    # https://github.com/helix-editor/helix/pull/5468
    # $E:EDITOR
    nvim $tmp[name] <$path:dev-tty >$path:dev-tty 2>&1
    set edit:current-command = (slurp < $tmp[name] | str:trim-right (one) "\n")
  } catch {
    file:close $tmp
  }
  rm $tmp[name]
}

# Docker
fn doc-clean {
  docker rmi -f (docker images -aq)
  docker system prune --volumes -f
}
fn doc-cnt-rm {
  docker stop (docker ps -aq); docker rm (docker ps -aq)
}
fn doc-exec { |cnt| docker exec -it $cnt bash }
set edit:completion:arg-completer[doc-exec] = { |@args|
  docker ps --format '{{.Image}} {{.Names}}' ^
    | from-lines ^
    | each { |cnt| var c = (str:split ' ' $cnt | put [(all)]); put [&img=$c[0] &name=$c[1]] } ^
    | each { |cnt| edit:complex-candidate &display=$cnt[name]' ('$cnt[img]')' $cnt[name] }
}
fn doc-su {
  var cfg = $E:HOME/.docker/config.json
  var kc = (cat $cfg | from-json)
  assoc $kc credsStore osxkeychain | to-json > $cfg
}

# Dotnet
fn dot-csi { csharprepl -t themes/VisualStudio_Light.json }
fn dot-up { dotnet outdated --upgrade }

# File System
fn p { |f|
  if (str:has-suffix $f .md) {
    glow $f
  } else {
    bat $f
  }
}
fn dir-size { dust -d 1 }
fn e { |@a| $E:EDITOR $@a }
fn fd { |@a| e:fd -c never $@a }
fn rmr { |f| rm -fr $f }
set edit:completion:arg-completer[rmr] = { |@args|
  fd . -H -d 1 --no-ignore --strip-cwd-prefix ^
    | from-lines
}
fn file-yank { |f| pbcopy < $f }
set edit:completion:arg-completer[file-yank] = { |@args|
  rg --files ^
    | from-lines
}
fn l { |@a| exa -al --git --no-permissions $@a }
fn t { |&l=2 @d|
  exa -al --git --level $l --no-permissions --tree $@d
}

# Git
fn git-cfg { git config --list --show-origin }
fn gd { git diff }
fn gs { git status -s }
fn gl { |&c=10| git log --all --decorate --graph --format=format:'%Cblue%h %Creset- %Cgreen%ar %Creset%s %C(dim)- %an%C(auto)%d' -$c }

# Go
fn go-up { go get -u; go mod tidy }

# Java
fn java-su {
  sudo ln -s /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk
}

# JetBrains
fn jb-rm { |a|
  var dirs = ['Application Support/JetBrains' 'Caches/JetBrains' 'Logs/JetBrains']
  for d $dirs {
    rm -fr $E:HOME/Library/$d/$a
  }
}
set edit:completion:arg-completer[jb-rm] = { |@args|
  ls $E:HOME/Library/Caches/JetBrains | from-lines
}

# Network
fn ntw-scan { nmap -sP 192.168.1.0/24 }

# Node.js
fn npm-up { npm-check-updates --deep -i }
fn node-clean {
  fd -HI --prune node_modules ^
    | from-lines ^
    | peach { |d| rm -fr $d }
}

# Packages
fn brew-dump { brew bundle dump --file $E:HOME/Projects/dots/brew/brewfile --force }
fn brew-up {
  brew update
  brew upgrade --fetch-HEAD --ignore-pinned
  brew cleanup
  brew doctor
}
fn pkg-su {
  put csharprepl dotnet-outdated-tool dotnet-fsharplint fantomas-tool ^
    | each { |p| try { dotnet tool install -g $p } catch { } }

  npm install -g ^
    dockerfile-language-server-nodejs ^
    npm ^
    npm-check-updates ^
    paperspace-node ^
    typescript ^
    typescript-language-server ^
    vscode-langservers-extracted
}
fn pkg-up {
  brew-up

  dotnet tool list -g ^
    | from-lines ^
    | drop 2 ^
    | each { |l| str:split ' ' $l | take 1 } ^
    | each { |p| dotnet tool update -g $p }

  npm-check-updates -g
}

# PostgreSQL
fn pg-up { postgres -D /usr/local/var/postgres }
fn pg-reset { brew uninstall --ignore-dependencies postgresql; rm -fr /usr/local/var/postgres; brew install postgresql; /usr/local/bin/timescaledb_move.sh }
fn pg-upgrade { brew postgresql-upgrade-database }

# Python
fn py-act {
  if (not-eq $_paths $nil) {
    fail 'A venv is already active'
  }
  var venv = $pwd/venv/bin
  if (path:is-dir $venv | not (one)) {
    fail 'No venv found'
  }
  set _paths = $paths
  set paths = [$venv $@paths]
}
fn py-dea {
  if (eq $_paths $nil) {
    fail 'No venv is active'
  }
  set paths = $_paths
  set _paths = $nil
}
fn py-su {
  python3 -m venv venv
  py-act
  pip install --upgrade pip
  pip install -r requirements.txt
}
fn py-up {
  py-act
  pip install --upgrade pip pur
  pur
  pip install -r requirements.txt
  py-dea
}

# Pulumi
fn pu-res { |@args|
  pulumi stack export ^
    | from-json ^
    | put (one)[deployment][resources] ^
    | each { |r| put $r[urn] } (one)
}

fn pu-des-t { |r| pulumi destroy -t $r }
set edit:completion:arg-completer[pu-des-t] = $pu-res~

fn pu-stk-sel { |s| pulumi stack select $s }
set edit:completion:arg-completer[pu-stk-sel] = { |@args|
  pulumi stack ls --json ^
    | from-json ^
    | all (one) ^
    | each { |s| edit:complex-candidate $s[name] &display=(if (put $s[current]) { styled $s[name] green } else { put $s[name] }) }
}

fn pu-sta-del { |r| pulumi state delete $r }
set edit:completion:arg-completer[pu-sta-del] = $pu-res~

fn pu-up-t { |t| pulumi up -t $t }
set edit:completion:arg-completer[pu-up-t] = $pu-res~

# Shell
fn env-ls {
  env -0 ^
    | from-terminated "\x00" ^
    | each { |e| var k v = (str:split &max=2 = $e); put [$k $v] } ^
    | order
}
fn colortest { curl -s https://raw.githubusercontent.com/pablopunk/colortest/master/colortest | bash }
fn re { exec elvish }

# SSH
fn ssh-trust { |@a| ssh-copy-id -i $E:HOME/.ssh/id_rsa.pub $@a }

# VSCode
fn code-ext-dump { code --list-extensions > $E:HOME'/Library/Application Support/Code/User/extensions.txt' }
fn code-ext-install {
  from-lines < $E:HOME'/Library/Application Support/Code/User/extensions.txt' ^
    | each { |e| code --force --install-extension $e } [(all)]
}

# Web Browser
fn webbrowser { rm -fr $E:TMPDIR/webbrowser; '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --user-data-dir=$E:TMPDIR/webbrowser --disable-web-security --incognito --no-first-run --new-window http://localhost:4200 }

# Taken: a, b, f, e, i, n, p
set edit:insert:binding[Ctrl-d] = $edit:navigation:start~
set edit:insert:binding[Ctrl-l] = $edit:location:start~
set edit:insert:binding[Ctrl-o] = $edit:lastcmd:start~
set edit:insert:binding[Ctrl-r] = $edit:histlist:start~
set edit:insert:binding[Ctrl-t] = $cmd-edit~
set edit:insert:binding[Ctrl-y] = {
  fd -H --strip-cwd-prefix . ^
    | from-lines ^
    | each { |f| put [&to-accept=$f &to-filter=$f &to-show=$f] } ^
    | edit:listing:start-custom &caption='Files' &accept={ |f| edit:insert-at-dot $f } [(all)]
}
set edit:insert:binding[Ctrl-w] = $edit:kill-small-word-left~
set edit:insert:binding[Alt-Backspace] = $edit:kill-small-word-left~
