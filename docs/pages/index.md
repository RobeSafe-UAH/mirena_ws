---
hide:
  - toc
---
# Instalación

Esta página prepara el equipo y construye **Mirena Workspace** desde cero.
Seguir los pasos en orden; al terminar, continuar en [Ejecución](ejecucion.md).

## Preparar el sistema

El entorno del repositorio utiliza **Linux, una GPU NVIDIA compatible con Vulkan
y una sesión gráfica X11 o XWayland**. Elegir Ubuntu o Debian en las pestañas de
instalación. Todos los comandos de esta sección se ejecutan **en el equipo**.

La imagen instala Ubuntu 24.04, ROS 2 Jazzy y Godot con `rclgd`: no hace falta
instalar ROS 2 ni Godot en el anfitrión. El `Makefile` actual utiliza el runtime
NVIDIA y el socket X11 de Linux; Windows/WSL y macOS requieren adaptar ese flujo.

### 1. Instalar las herramientas y Docker

Si ya se utiliza Docker Engine con Buildx, instalar las herramientas del equipo
con estos comandos y continuar en el paso 2:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg git make x11-xserver-utils
```

Para una instalación nueva, seguir la pestaña correspondiente. Si hay paquetes
previos de `docker.io`, Podman u otros que entren en conflicto, consultar
**Uninstall old versions** en la guía oficial de la distribución antes de
configurar el repositorio.

=== "Ubuntu"

    1. Instalar las herramientas y descargar la clave de Docker:

        ```bash
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg git make x11-xserver-utils
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        ```

    2. Añadir el repositorio de Docker para la versión instalada:

        ```bash
        sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
        Types: deb
        URIs: https://download.docker.com/linux/ubuntu
        Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
        Components: stable
        Architectures: $(dpkg --print-architecture)
        Signed-By: /etc/apt/keyrings/docker.asc
        EOF
        ```

    3. Instalar Docker Engine, Buildx y Compose:

        ```bash
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ```

    Referencia: [Docker Engine en Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

=== "Debian"

    1. Instalar las herramientas y descargar la clave de Docker:

        ```bash
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg git make x11-xserver-utils
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        ```

    2. Añadir el repositorio de Docker para la versión instalada:

        ```bash
        sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
        Types: deb
        URIs: https://download.docker.com/linux/debian
        Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
        Components: stable
        Architectures: $(dpkg --print-architecture)
        Signed-By: /etc/apt/keyrings/docker.asc
        EOF
        ```

    3. Instalar Docker Engine, Buildx y Compose:

        ```bash
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ```

    Referencia: [Docker Engine en Debian](https://docs.docker.com/engine/install/debian/).

Buildx se utiliza para construir la imagen. Compose queda instalado como
herramienta de Docker; los comandos de este proyecto se ejecutan con Make.

### 2. Habilitar Docker para el usuario

1. Iniciar Docker y dar acceso a la cuenta de trabajo:

    ```bash
    sudo systemctl enable --now docker
    sudo groupadd --force docker
    sudo usermod -aG docker "$USER"
    ```

2. **Cerrar la sesión del escritorio y volver a entrar** para aplicar el grupo.
3. Abrir otra terminal y comprobar Docker sin `sudo`:

    ```bash
    docker version
    docker buildx version
    docker run --rm hello-world
    ```

    Debe aparecer el mensaje de confirmación de `hello-world`. Si hay un error de
    permisos, comprobar con `id -nG` que la nueva sesión incluye el grupo `docker`.
    Si el servicio no responde, revisar `sudo systemctl status docker`.

Ejecutar los comandos `make` del proyecto con la cuenta de trabajo, sin `sudo`.

### 3. Instalar el controlador NVIDIA

Si `nvidia-smi` ya muestra la GPU y su controlador, continuar en el paso 4.
En una instalación nueva:

=== "Ubuntu"

    1. Instalar la herramienta de selección del controlador:

        ```bash
        sudo apt update
        sudo apt install -y ubuntu-drivers-common
        ubuntu-drivers list
        ```

    2. Instalar el controlador recomendado para la GPU:

        ```bash
        sudo ubuntu-drivers install
        ```

    3. Reiniciar el equipo desde el escritorio. Tras volver a entrar, comprobar:

        ```bash
        nvidia-smi
        ```

    Referencia: [controladores NVIDIA en Ubuntu](https://ubuntu.com/server/docs/how-to/graphics/install-nvidia-drivers/).

=== "Debian"

    1. Activar `contrib`, `non-free` y `non-free-firmware` en los repositorios de
       Debian que ya utiliza el equipo. Si se usa el formato `.sources`, editar
       el archivo de Debian, normalmente `/etc/apt/sources.list.d/debian.sources`,
       y completar su campo de componentes:

        ```text
        Components: main contrib non-free non-free-firmware
        ```

        Si se usa `/etc/apt/sources.list`, añadir esos componentes al final de
        las líneas de los repositorios Debian existentes. Conservar su versión
        y direcciones; el repositorio de Docker del paso 1 es independiente.

    2. Instalar las cabeceras del kernel y detectar el controlador adecuado:

        ```bash
        sudo apt update
        sudo apt install -y "linux-headers-$(uname -r)" nvidia-detect
        nvidia-detect
        ```

    3. Si la detección recomienda `nvidia-driver`, instalarlo:

        ```bash
        sudo apt install -y nvidia-driver firmware-misc-nonfree
        ```

        Si recomienda otra rama o la GPU necesita un controlador más reciente,
        seguir la selección de la [guía de NVIDIA para Debian](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/debian.html)
        para ese modelo.

    4. Reiniciar el equipo desde el escritorio y comprobar:

        ```bash
        nvidia-smi
        ```

    Referencia: [controladores NVIDIA en Debian](https://wiki.debian.org/NvidiaGraphicsDrivers).

La comprobación debe reconocer la GPU antes de configurar Docker para utilizarla.

### 4. Instalar NVIDIA Container Toolkit

Estos comandos son comunes a Ubuntu y Debian. El Toolkit permite que los
contenedores utilicen el controlador instalado en el equipo.

1. Preparar la clave y el repositorio de NVIDIA:

    ```bash
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    ```

2. Instalar el Toolkit y configurar el runtime de Docker:

    ```bash
    sudo apt update
    sudo apt install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ```

3. Comprobar el acceso a la GPU desde un contenedor:

    ```bash
    docker run --rm --runtime=nvidia --gpus all ubuntu:24.04 nvidia-smi
    ```

    Debe aparecer la GPU también dentro del contenedor. Esta prueba comprueba el
    acceso al dispositivo; Vulkan se comprueba con la imagen del proyecto al
    terminar la instalación.

Referencia: [instalación oficial de NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
y [prueba de GPU en Docker](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/sample-workload.html).

### 5. Preparar la pantalla

1. Abrir una terminal en la sesión gráfica del equipo y comprobar:

    ```bash
    echo "$DISPLAY"
    ls /tmp/.X11-unix
    ```

    `DISPLAY` debe contener un valor como `:0` o `:1`, y el directorio debe
    contener el socket de la sesión. En un escritorio Wayland se utiliza
    XWayland para abrir las ventanas del simulador y RViz.

2. Conceder acceso al usuario local al servidor X:

    ```bash
    xhost +SI:localuser:$(id -un)
    ```

    `make run` también ejecuta este comando y comparte el socket X11 con el
    contenedor. Utilizar esa misma sesión gráfica para los pasos siguientes.

## Obtener y construir el proyecto

1. En el equipo, clonar el repositorio y entrar en su carpeta:

    ```bash
    git clone https://github.com/RobeSafe-UAH/mirena_ws.git
    cd mirena_ws
    ```

2. Construir la imagen del entorno:

    ```bash
    make build
    ```

    Este paso instala ROS 2 Jazzy, Godot/rclgd y las herramientas del contenedor.
    La compilación de los paquetes del workspace se realiza al arrancarlo.

3. Elegir el dominio ROS 2 y arrancar el contenedor. El valor por defecto es `42`:

    ```bash
    make run ROS_DOMAIN_ID=42
    ```

    Usar el mismo dominio en los nodos externos y en las siguientes ejecuciones.
    Para cambiarlo, sustituir `42` por el valor elegido.

4. Esperar a que termine la primera compilación y aparezca la terminal **zsh**.
   El repositorio se comparte en `/ros2_ws`; el arranque ejecuta `colcon build`
   y carga ROS y los paquetes instalados. El registro queda en
   `log/startup-build.log` en el repositorio del equipo.

5. Desde esa terminal **dentro del contenedor**, comprobar:

    ```bash
    echo "$ROS_DISTRO"
    echo "$ROS_DOMAIN_ID"
    ros2 pkg prefix mirena_sim
    nvidia-smi
    vulkaninfo --summary
    ```

    Deben aparecer `jazzy`, el dominio elegido, una ruta de instalación de
    `mirena_sim` y la GPU NVIDIA. En la salida de Vulkan debe figurar un dispositivo
    NVIDIA. Si falla alguna comprobación, consultar [Resolver problemas](ejecucion.md#resolver-problemas)
    antes de lanzar la simulación.

6. Continuar en [Ejecución](ejecucion.md) para abrir MirenaSim y RViz.
   Si se acaba de completar este paso y el contenedor sigue abierto, empezar
   por el comando del simulador del paso 3 de esa página. Para cerrar ahora el
   contenedor, escribir `exit`; después se puede abrir de nuevo con `make run`.
