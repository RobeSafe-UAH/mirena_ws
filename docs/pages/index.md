# Instalación

**Mirena Workspace** es un entorno de ROS 2 Jazzy para desarrollar sistemas de
Formula Student Driverless. Incluye **MirenaSim**, un simulador en Godot 4 con
vehículo, circuitos de conos, LiDAR, cámaras, IMU y GNSS, los mensajes
`mirena_common` y sus visualizadores de RViz 2.

![MirenaSim en un circuito de conos](assets/images/sim_banner.png)

## Requisitos

El flujo del repositorio utiliza **Linux con una GPU NVIDIA**, controlador
NVIDIA, **Docker Engine**, NVIDIA Container Toolkit y una sesión gráfica
**X11 o XWayland**. El contenedor incluye Ubuntu 24.04, ROS 2 Jazzy y
`ros-jazzy-rclgd`, que proporciona la integración con Godot.

La configuración de `make run` solicita el runtime NVIDIA y comparte el socket
X11 del equipo. Godot utiliza **Forward+ y Vulkan**; el LiDAR y la profundidad
dependen de shaders de cómputo. Esta guía cubre anfitriones Ubuntu y Debian.

## Preparar el sistema

=== "Ubuntu"

    1. Instalar las herramientas básicas:

        ```bash
        sudo apt update
        sudo apt install -y git make x11-xserver-utils
        ```

    2. Instalar **Docker Engine y Buildx** siguiendo la
       [guía oficial para Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

=== "Debian"

    1. Instalar las herramientas básicas:

        ```bash
        sudo apt update
        sudo apt install -y git make x11-xserver-utils
        ```

    2. Instalar **Docker Engine y Buildx** siguiendo la
       [guía oficial para Debian](https://docs.docker.com/engine/install/debian/).

Habilitar Docker y permitir su uso desde la cuenta de trabajo:

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Cerrar la sesión y volver a entrar para aplicar el grupo. Comprobar:

```bash
docker run --rm hello-world
make --version
```

Ejecutar los comandos `make` del proyecto como usuario habitual.

## Preparar la GPU y la pantalla

1. Instalar el controlador NVIDIA apropiado para la distribución y comprobarlo:

    ```bash
    nvidia-smi
    ```

2. Instalar **NVIDIA Container Toolkit** según su
   [guía oficial](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).
   Configurar su integración con Docker:

    ```bash
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ```

3. Abrir una terminal en la sesión gráfica y comprobar `DISPLAY`:

    ```bash
    echo "$DISPLAY"
    ```

    Debe aparecer un valor como `:0` o `:1`. En escritorios Wayland se utiliza
    XWayland. El `Makefile` monta `/tmp/.X11-unix` y autoriza al usuario local
    mediante `xhost` cuando está disponible.

## Obtener y construir el proyecto

1. Clonar el repositorio y entrar en su carpeta:

    ```bash
    git clone https://github.com/RobeSafe-UAH/mirena_ws.git
    cd mirena_ws
    ```

2. Construir la imagen Docker:

    ```bash
    make build
    ```

3. Continuar en [Ejecución](ejecucion.md). `make run` compila el workspace y abre
   una terminal; el simulador se inicia con un comando dentro del contenedor.

Para ajustar el vehículo o los sensores, consultar [Simulador](simulador.md),
[Vehículo](vehiculo.md) y [Sensores](sensores.md). El flujo de desarrollo y la
publicación de esta guía están en [Repositorio](repositorio.md).
