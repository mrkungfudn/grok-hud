# Shared PATH bootstrap. Sourced by launch.sh / status-line.sh.
# Do not exec this file. Comments in this repo are English.

export PATH="${HOME}/.local/bin:${HOME}/.grok/bin:${PATH}"

if ! command -v node >/dev/null 2>&1; then
  _nvm_bin=$(ls -d "${HOME}/.nvm/versions/node/"*/bin 2>/dev/null | tail -1 || true)
  if [ -n "${_nvm_bin}" ] && [ -x "${_nvm_bin}/node" ]; then
    export PATH="${_nvm_bin}:${PATH}"
  fi
fi
unset _nvm_bin
