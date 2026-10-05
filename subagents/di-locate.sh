# Sourced by the di-*.sh launchers. Finds the code checkout on whichever
# machine this runs on, so no launcher hardcodes one disk layout.
# Override any lookup with CODE_DIR, DI or DI_AGENT_RUNNER.

di_code_roots() {
  local root
  for root in ${CODE_DIR:-} "$HOME/code" /d/code /vfast/data/code /media/pcd/code /nvme0n1-disk/code; do
    [[ -n $root && -d $root ]] && printf '%s\n' "$root"
  done
}

# Print the first existing <root>/<relative path>; fail when none exists.
di_find() {
  local root
  while IFS= read -r root; do
    [[ -e $root/$1 ]] && { printf '%s\n' "$root/$1"; return 0; }
  done < <(di_code_roots)
  return 1
}

# Print the built binary NAME (di or fx), preferring one that runs here.
di_bin() {
  local name=$1 root path
  while IFS= read -r root; do
    for path in "$root/di/zig-out/bin/$name.exe" "$root/di/zig-out/bin/$name"; do
      [[ -x $path ]] && { printf '%s\n' "$path"; return 0; }
    done
  done < <(di_code_roots)
  # Nothing runnable: name the first checkout so the error points somewhere real.
  printf '%s\n' "$(di_find di || printf '%s' "$HOME/code/di")/zig-out/bin/$name"
}

di_python() {
  local py
  for py in python3 python; do
    "$py" -c 'import sys; sys.exit(sys.version_info < (3, 8))' 2>/dev/null && { printf '%s\n' "$py"; return 0; }
  done
  printf '%s\n' python3
}
