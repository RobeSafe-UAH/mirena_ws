#!/usr/bin/env bash
# Report actual startup checks; a missing optional check never claims success.
set -eo pipefail

green= yellow= cyan= reset=
if [ -t 1 ]; then
  green=$'\033[1;32m' yellow=$'\033[1;33m' cyan=$'\033[1;36m' reset=$'\033[0m'
fi
ok() { printf '  %s✓%s %s\n' "$green" "$reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$reset" "$*"; }

if [ -t 1 ]; then
  printf '\033[2J\033[H'
fi
printf '\n'

if command -v ros2 >/dev/null && [ "${ROS_DISTRO:-}" = jazzy ]; then
  ok "ROS 2 Jazzy loaded · ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-42}"
else
  warn "ROS environment is unavailable"
fi

if [ "${1:-skipped}" = built ]; then
  ok "Workspace compiled · log/startup-build.log"
  if grep -q 'package.*had stderr output' /ros2_ws/log/startup-build.log; then
    warn "Compilation produced warnings/errors on stderr; inspect the build log"
  fi
else
  warn "Compilation skipped (AUTO_BUILD=0)"
fi

if ros2 pkg prefix mirena_sim >/dev/null 2>&1; then
  ok "MirenaSim workspace overlay loaded"
else
  warn "MirenaSim is not installed; compile the workspace"
fi

if mountpoint -q /ros2_ws && [ -w /ros2_ws ]; then
  ok "Shared workspace writable · UID=$(id -u) GID=$(id -g)"
else
  warn "Shared workspace is missing or not writable"
fi

if gpu=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null); then
  ok "NVIDIA GPU / driver: $gpu"
else
  warn "NVIDIA GPU / driver is unavailable"
fi

if vulkan=$(timeout 10s vulkaninfo --summary 2>/dev/null) &&
   grep -q 'DRIVER_ID_NVIDIA_PROPRIETARY' <<< "$vulkan"; then
  ok "NVIDIA Vulkan driver detected"
else
  warn "NVIDIA Vulkan driver could not be verified"
fi

if [ -n "${DISPLAY:-}" ] && [ -d /tmp/.X11-unix ]; then
  ok "DISPLAY=$DISPLAY · X11 socket directory mounted"
else
  warn "DISPLAY or the X11 socket directory is missing"
fi

printf '\n  Simulator: ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=random\n'
printf '  RViz:      rviz2 -d /ros2_ws/src/mirena_sim/mirena_sim.rviz\n'
printf '  ROS:       ros2 topic list\n\n'

printf '%s' "$cyan"
cat <<'BANNER'
   ______ __     _____ __            __           __
  / ____// /    / ___// /___  ______/ /__  ____  / /_
 / /_   / /     \__ \/ __/ / / / __  / _ \/ __ \/ __/
/ __/  / /     ___/ / /_/ /_/ / /_/ /  __/ / / / /_
/_/   /_/     /____/\__/\__,_/\__,_/\___/_/ /_/\__/

                 F1 Student · MirenaSim
BANNER
printf '%s\n' "$reset"
