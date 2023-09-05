h1() {
  declare border padding text
  border='\033[38;5;27m'"$(printf '⛌%.0s' $(seq 1 "$term_width"))"'\e[0m'
  padding="$(printf ' %.0s' $(seq 1 $(((term_width - $(wc -m <<<"$*")) / 2))))"
  text="\\e[1m$*\\e[0m"
  echo -e "$border"
  echo -e "${padding}${text}${padding}"
  echo -e "$border"
}

h2() {
  printf '\e[38;5;57m==>\e[37;1m %s\e[0m\n' "$(echo -e "\033[36m$(date "+%H:%M:%S")\033[39m $*")"
}

find-dirs() {
  find "$1" -mindepth 1 -maxdepth 1 -type d > /dev/null 2>&1
}

link-paths() {
  source_dir=$1
  dest_dir=$2

  mkdir -p "$dest_dir"

  if find-dirs "$source_dir"; then
    for path in "$source_dir"/*/; do
      dest_path="$dest_dir/$(basename "$path")"

      # Ignore if path is not a directory.
      [ -d "${path}" ] || continue
      # Overwrite existing symlinks.
      unlink "$dest_path" 2> /dev/null

      h2 "Linking $path => $dest_path"
      ln -sf "$path" "$dest_path"
    done
  else
    h2 "No folders found in $source_dir"
  fi
}

reset-permissions() {
  h2 "Resetting permissions"
  sudo chown -R www-data:www-data "${ROOT_DIR}"
}
