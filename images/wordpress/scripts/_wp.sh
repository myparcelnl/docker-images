wp-install() {
  type=$1
  name=$2

  if sudo -u www-data -s wp "$type" is-installed "$name"; then
    h2 "[$type:$name] This $type is already installed"
  else
    h2 "[$type:$name] Installing..."
    sudo -u www-data -s wp "$type" install "$name"
  fi
}

wp-activate() {
  type=$1
  name=$2

  if sudo -u www-data -s wp "$type" is-active "$name"; then
    h2 "[$type:$name] This $type is already active"
  else
    wp-install "$type" "$name"
    h2 "[$type:$name] Activating..."
    sudo -u www-data -s wp "$type" activate "$name"
  fi
}
