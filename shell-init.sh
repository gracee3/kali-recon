# ~/.bashrc for recon container

# Keep interactive sessions inside the mounted workspace when accessible.
if [ -d /workspace ] && [ -r /workspace ] && [ -x /workspace ]; then
  cd /workspace
fi

# Load shared config/environment when present.
if [ -f /workspace/config/shell.env ]; then
  set -a
  source /workspace/config/shell.env
  set +a
fi

# Useful shell defaults in short one-off recon sessions.
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
