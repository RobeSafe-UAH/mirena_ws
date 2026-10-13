#!/usr/bin/env bash
set -eo pipefail

# Match the host user without changing ownership of the mounted workspace.
if [ "$(id -u)" -eq 0 ]; then
  host_uid="${HOST_UID:-$(id -u mirena)}"
  host_gid="${HOST_GID:-$(id -g mirena)}"
  if [ "$host_uid" -eq 0 ]; then
    echo "Run make as your normal host user, without sudo." >&2
    exit 1
  fi
  if [ "$(id -g mirena)" != "$host_gid" ]; then
    groupmod -o -g "$host_gid" mirena
  fi
  if [ "$(id -u mirena)" != "$host_uid" ]; then
    usermod -o -u "$host_uid" mirena
  fi
  chown -R mirena:mirena /home/mirena
  export HOME=/home/mirena USER=mirena
  exec setpriv --reuid=mirena --regid=mirena --init-groups "$0" "$@"
fi

source /opt/ros/jazzy/setup.bash
build_status=skipped
if [ "${AUTO_BUILD:-0}" = "1" ]; then
  cd /ros2_ws
  mkdir -p log
  if ! colcon build --symlink-install --base-paths /ros2_ws/src 2>&1 | tee log/startup-build.log; then
    printf '\n✗ Compilation failed. See /ros2_ws/log/startup-build.log\n' >&2
    exit 1
  fi
  build_status=built
fi
if [ -f /ros2_ws/install/local_setup.bash ]; then
  source /ros2_ws/install/local_setup.bash
fi

/usr/local/bin/mirena-welcome "$build_status"
exec "$@"
