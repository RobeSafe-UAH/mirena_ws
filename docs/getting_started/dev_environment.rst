Development environment
=======================

The workspace runs in a **Docker container** managed by the root ``Makefile``,
using the same workflow as ``rbsf-racing``. The image includes Ubuntu 24.04,
ROS 2 Jazzy, ``rclgd`` with Godot, and zsh. The host needs Docker, Make, an
NVIDIA GPU and driver, NVIDIA Container Toolkit, and an X11/XWayland display.

This guide covers **Ubuntu 22.04/24.04** and **Debian 12/13** hosts.

.. contents:: On this page
   :local:
   :depth: 2

How the pieces fit
------------------

.. mermaid::

   flowchart LR
     subgraph Host["Host (Ubuntu / Debian)"]
       MK[Makefile]
       X[X server / XWayland]
       GPU[NVIDIA GPU]
       SRC[(~/mirena_ws)]
     end
     subgraph C["Container: mirena_ws (ubuntu:24.04)"]
       ROS[ROS 2 Jazzy]
       GD[rclgd + Godot]
       WS[/ros2_ws/]
     end
     MK -- docker run --> C
     SRC -- bind mount --> WS
     X -- /tmp/.X11-unix --> GD
     GPU -- NVIDIA Container Toolkit --> GD

The relevant files are:

``Makefile``
   Builds and runs the image with NVIDIA GPU access, host networking and IPC,
   and the repository mounted at ``/ros2_ws``. Only the X11 socket directory
   is shared from ``/tmp``.

``docker/Dockerfile``
   Installs ROS 2 Jazzy, ``ros-dev-tools``, ``ros-jazzy-rclgd`` and Vulkan tools.
   NVIDIA Container Toolkit supplies the graphics drivers at runtime.

``docker/entrypoint.sh``
   Matches the ``mirena`` user's UID/GID to the host, loads ROS, builds the
   shared workspace when ``AUTO_BUILD=1``, and runs the requested command
   as ``mirena``. It does not change ownership of the mounted repository.

1. Install Docker Engine
------------------------

Install Docker from Docker's own apt repository. Distribution packages such as ``docker.io`` are
often too old for BuildKit features the Dockerfile uses (``RUN --mount=type=cache``).

Remove conflicting packages, if any:

.. code-block:: bash

   for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
     sudo apt-get remove -y $pkg
   done

Add the repository that matches your host:

**Ubuntu**

.. code-block:: bash

   sudo apt-get update
   sudo apt-get install -y ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
     https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
     | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

**Debian**

.. code-block:: bash

   sudo apt-get update
   sudo apt-get install -y ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
     https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
     | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

Then install the engine and Buildx:

.. code-block:: bash

   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
     docker-buildx-plugin make x11-xserver-utils

Let your user run Docker without ``sudo``. Log out and
back in afterwards, or run ``newgrp docker`` in the current shell:

.. code-block:: bash

   sudo usermod -aG docker $USER

Check the installation:

.. code-block:: console

   $ docker run --rm hello-world
   $ make --version

.. tip::

   ``make run`` uses ``xhost`` on the host. If it is missing, install it with
   ``sudo apt-get install -y x11-xserver-utils``.

2. Configure NVIDIA and the display
------------------------------------

The simulator uses Godot's **Forward+** renderer and Vulkan compute shaders
for lidar and depth cameras. Install the host's NVIDIA driver and
`NVIDIA Container Toolkit <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>`_.
Configure the runtime on the host:

.. code-block:: bash

   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   nvidia-smi

``make run`` requests all NVIDIA GPUs and the ``compute,utility,graphics,display``
driver capabilities. Driver libraries and Vulkan manifests are injected by the
NVIDIA runtime; host Vulkan manifest directories are not mounted.

Programs use the host X server through ``/tmp/.X11-unix`` and ``DISPLAY``.
On Wayland desktops, this uses XWayland. Start ``make run`` from a terminal
where ``echo $DISPLAY`` prints a value such as ``:0``. The Makefile grants
X server access to your local user with ``xhost +SI:localuser:$(id -un)``.

3. Build and start the container
--------------------------------

On the host:

.. code-block:: bash

   git clone <repository-url> ~/mirena_ws
   cd ~/mirena_ws
   make build
   make run

``make build`` builds the image. ``make run`` mounts the repository, compiles
all packages, and opens zsh at ``/ros2_ws`` with ROS and the overlay loaded.
Files created in the container belong to the host user and persist after exit.
Edit the repository with your preferred editor on the host.

Use these commands on the host:

.. code-block:: bash

   make attach                  # Another zsh in the running container
   make stop                    # Stop the container
   make run AUTO_BUILD=0        # Skip automatic compilation
   make build                   # Rebuild the image after Dockerfile changes
   make help                    # List commands

``IMAGE``, ``TAG``, ``CONTAINER``, ``ROS_DOMAIN_ID`` (default ``42``),
``AUTO_BUILD`` and ``CMD`` can be overridden on the Make command line.
For example, start the simulator directly with:

.. code-block:: bash

   make run CMD="ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=random"

4. Build the workspace
----------------------

To rebuild after editing code, inside the container, without ``sudo``:

.. code-block:: zsh

   cd /ros2_ws
   colcon build --symlink-install --base-paths "$PWD/src"
   source install/local_setup.zsh

New zsh shells load the installed overlay automatically once it exists.

``mirena_sim`` is built by the ``rclgd`` colcon build type. It installs the Godot project under
``install/mirena_sim/share/mirena_sim`` together with a launcher. When ``rclgd`` loads the
project, it generates typed GDScript wrappers for every message package listed in
``src/mirena_sim/package.xml`` (for example ``RosSensorMsgsImu`` or ``RosMirenaCommonCar``) into
``addons/rclgd/gen``.

5. Run and edit the simulator
-----------------------------

Run the installed simulator as a ROS 2 executable:

.. code-block:: bash

   ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=random

``track`` takes ``random`` for a generated Trackdrive layout, or a path to a track ``.json`` file
(see :ref:`simulator/overview:Tracks`).

To edit the simulator, open your source copy in the Godot editor that ships with ``rclgd``:

.. code-block:: bash

   ros2 run rclgd godot --display-driver x11 --editor --path src/mirena_sim

The main scene is ``res://Scenes/Sim/Sim.tscn``, and the car is
``res://Scenes/Vehicle/mirena_car.tscn`` (see :doc:`../simulator/overview` and
:doc:`../simulator/vehicle`).

From the editor, **Run Project** (:kbd:`F5`) starts the simulator straight from ``src/``, with no
rebuild. Run ``colcon build`` again before using ``ros2 run mirena_sim mirena_sim``, so the
installed copy picks up your changes.

To check that everything works, run ``make attach`` in a second host terminal
and list the topics inside the container:

.. code-block:: console

   $ ros2 topic list
   /as_status
   /camera/camera_info
   /camera/image_raw
   /control
   /debug/state/car
   /lidar/lidar
   /ros_imu/data
   /sensors/wheel_speeds
   /tf
   /tf_static
   /track_manager/full_map
   /track_manager/track
   ...

Then start RViz with the bundled configuration:

.. code-block:: bash

   rviz2 -d src/mirena_sim/mirena_sim.rviz

.. important::

   Sensor topics use **best-effort** QoS (see :ref:`sensors/index:Quality of service`). In RViz,
   set the display's *Reliability Policy* to *Best Effort*. With ``ros2 topic echo``, pass
   ``--qos-reliability best_effort``. Otherwise you will see no data.

Troubleshooting
---------------

``Authorization required, but no authorization protocol specified`` / ``cannot open display``
   Check ``DISPLAY`` on the host, run ``xhost +SI:localuser:$(id -un)``,
   and restart with ``make stop`` followed by ``make run``.

Godot reports no Vulkan device or cannot create a Vulkan swapchain
   Run ``nvidia-smi`` and ``vulkaninfo --summary`` inside the container.
   Both should identify the NVIDIA GPU. Check the host driver and NVIDIA
   Container Toolkit configuration, then restart the container.

``Permission denied`` when creating build files
   Run Make as your normal host user. ``HOST_UID`` and ``HOST_GID`` are passed
   automatically to the entrypoint. Build inside the container without ``sudo``.
   Existing files created by previous root builds may need ownership repaired
   separately on the host.

No topics visible from the host
   The container sets ``ROS_DOMAIN_ID=42``. Export the same value on the host,
   or override it with ``make run ROS_DOMAIN_ID=0``.

``Package 'mirena_sim' not found``
   Build the workspace and run ``source /ros2_ws/install/local_setup.zsh``.
