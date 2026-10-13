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

Requires Docker, Make, an NVIDIA GPU with
[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
configured, and an X11/XWayland display.

From the repository root on the host:

```bash
make build   # Build the Docker image
make run     # Start the container, compile the workspace and open a shell
```

Inside the container, start the simulator:

```bash
ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=random
```

Use `make attach` in another host terminal to open a second container shell.
The repository is shared at `/ros2_ws`; edits and build outputs persist.

## RViz

With the simulator running, open another shell with `make attach`, then run:

```bash
rviz2 -d /ros2_ws/src/mirena_sim/mirena_sim.rviz
```

The configuration shows lidar, RGB camera, sensor frames, car state, track and cones.
Depth visualization is optional and disabled by default.

## Documentation

See [`docs/`](docs) for host setup, simulator architecture, vehicle configuration and sensor
models. To build the docs locally:

```bash
pip install -r docs/requirements.txt
make -C docs html
```

## License

MIT, see [LICENSE](LICENSE).
