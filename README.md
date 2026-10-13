# Mirena Workspace

A ROS 2 (Jazzy) workspace for Formula Student Driverless development, built around **MirenaSim**, a
Godot 4 simulator that publishes the same interfaces as the real car.

![MirenaSim](docs/_static/images/sim_banner.png)

## Packages

| Package | Description |
|---------|-------------|
| [`mirena_sim`](src/mirena_sim) | Godot simulator with GPU lidar and camera, IMU, GNSS, and random track generation |
| [`mirena_common`](src/mirena_common) | Shared message definitions (`Car`, `CarControl`, `EntityList`, `Track`, ...) |
| [`mirena_rviz2_plugins`](src/mirena_rviz2_plugins) | RViz 2 displays for the `mirena_common` messages |

## Quick start

The workspace uses Docker, ROS 2 Jazzy and rclgd. The host needs Docker, Make,
an NVIDIA GPU with its driver, the
[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
configured for Docker, and an X11/XWayland display (`xhost` available).

From the repository root on the host:

```bash
make build
make run
```

`make run` mounts the repository at `/ros2_ws`, matches the container user's UID/GID
to the host, builds the workspace, and opens zsh with ROS loaded. After a successful
build, the terminal clears and shows ✓ checks for ROS, compilation, the shared
workspace, NVIDIA GPU/driver and Vulkan, followed by the **F1 Student / MirenaSim** banner.
Skipped builds and failed checks appear with `!`. Compilation errors remain on
screen, and the complete build output is saved in `log/startup-build.log`.

Inside the container, start the simulator:

```bash
ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=random
```

Use `make attach` on the host for another shell, `make stop` to stop the container,
and `make run AUTO_BUILD=0` to skip compilation. Edits and build outputs persist
in the shared repository. To rebuild from inside the container:

```zsh
colcon build --symlink-install --base-paths "$PWD/src"
source install/local_setup.zsh
```

Run `make help` for all commands. `IMAGE`, `TAG`, `CONTAINER`, `ROS_DOMAIN_ID`
(default `42`), `AUTO_BUILD` and `CMD` can be overridden, for example
`make run CMD="ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=random"`.

## Try ROS commands

With the simulator running, open a second host terminal in this repository:

```bash
make attach
```

Inside that container shell, list the active topics and read one IMU sample:

```zsh
ros2 topic list
ros2 topic echo /ros_imu/data --once --qos-reliability best_effort
```

Other useful checks:

```zsh
ros2 topic echo /ros_gps/fix --once --qos-reliability best_effort
ros2 topic echo /sensors/wheel_speeds --once --qos-reliability best_effort
ros2 topic info /lidar/lidar --verbose
```

Sensor topics use **Best Effort** QoS. Commands inside `make attach` share the
same ROS domain as the simulator; if you use ROS on the host, set
`export ROS_DOMAIN_ID=42` (or the value passed to `make run`).

## View the simulator in RViz

Keep the simulator running. From another container shell (`make attach`):

```zsh
rviz2 -d /ros2_ws/src/mirena_sim/mirena_sim.rviz
```

The included configuration uses `debug_map` as its fixed frame and displays:

| Display | Topic / frames |
|---------|----------------|
| Lidar point cloud | `/lidar/lidar`, Best Effort |
| RGB camera | `/camera/image_raw`, Best Effort |
| Sensor mounting frames | TF: `car/lidar`, `car/camera`, `car/imu`, `car/gps` |
| Car state, velocity and trail | `/debug/state/car` |
| Track and cones | `/track_manager/track`, `/track_manager/full_map` |
| Optional depth image (disabled initially) | `/camera/depth/image_raw`, Best Effort |

The car, track and cone displays use the included `mirena_rviz2_plugins`, built
automatically by `make run`. IMU and GNSS mounting frames are shown in TF;
read their numeric measurements with the ROS commands above.

The default vehicle does not publish depth images. To use the depth display,
enable `publish_depth` on the Camera node in `src/mirena_sim/Scenes/Vehicle/mirena_car.tscn`,
rebuild, restart the simulator, and enable **Depth Camera (optional)** in RViz.
If sensor displays receive no data, check **Reliability Policy → Best Effort**
and keep the simulator running.

## Documentation

See [`docs/`](docs) for host setup, simulator architecture, vehicle configuration and sensor
models. To build the docs locally:

```bash
pip install -r docs/requirements.txt
make -C docs html
```

## License

MIT, see [LICENSE](LICENSE).
