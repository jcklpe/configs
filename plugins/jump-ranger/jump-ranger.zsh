# Add a `r` function to zsh that opens ranger either at the given directory or
# at the one jump suggests
r() {
  if [ "$1" != "" ]; then
    if [ -d "$1" ]; then
      ranger "$1"
    else
      ranger $(jump cd $@)
    fi
  else
    ranger
  fi
  return $?
}