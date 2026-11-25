export LANG="${LANG:-C.UTF-8}"
if [ -n "$BASH_VERSION" ]; then
  PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
  shopt -s checkwinsize
fi
