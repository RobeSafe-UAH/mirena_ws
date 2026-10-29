---
hide:
  - toc
---
# Instalar Docker

Ejecutar estos pasos **en una terminal del equipo**, antes de construir
`mirena_ws`. Elegir la pestaña de la distribución instalada. El contenedor
incluye ROS 2 y Godot; las herramientas de esta página se instalan en el anfitrión.

Si Docker Engine ya está instalado, instalar también `git`, `make` y
`x11-xserver-utils` con el primer comando `sudo apt install` de la pestaña elegida.
Después, pasar a [Habilitar Docker para el usuario](#habilitar-docker-para-el-usuario)
y comprobar las herramientas. Si hay paquetes de otra instalación, consultar
el apartado **Uninstall old versions** de la guía oficial de la distribución
antes de añadir el repositorio.

## Preparar el sistema e instalar Docker Engine

=== "Ubuntu"

    1. Instalar las herramientas del equipo y preparar la clave del repositorio:

        ```bash
        sudo apt update
        sudo apt install -y ca-certificates curl git make x11-xserver-utils
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        ```

    2. Añadir el repositorio oficial de Docker para la versión de Ubuntu instalada:

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

    3. Instalar Docker Engine, Buildx y el plugin de Compose:

        ```bash
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ```

    Referencia: [instalación oficial para Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

=== "Debian"

    1. Instalar las herramientas del equipo y preparar la clave del repositorio:

        ```bash
        sudo apt update
        sudo apt install -y ca-certificates curl git make x11-xserver-utils
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        ```

    2. Añadir el repositorio oficial de Docker para la versión de Debian instalada:

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

    3. Instalar Docker Engine, Buildx y el plugin de Compose:

        ```bash
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ```

    Referencia: [instalación oficial para Debian](https://docs.docker.com/engine/install/debian/).

Buildx permite construir la imagen del proyecto con BuildKit. Compose queda
disponible con `docker compose`; los comandos de Mirena utilizan el `Makefile`.

## Habilitar Docker para el usuario

1. Iniciar el servicio y añadir la cuenta de trabajo al grupo `docker`:

    ```bash
    sudo systemctl enable --now docker
    sudo groupadd --force docker
    sudo usermod -aG docker "$USER"
    ```

2. **Cerrar la sesión del escritorio y volver a entrar** para aplicar el grupo.

3. Abrir una nueva terminal y comprobar que se puede usar Docker sin `sudo`:

    ```bash
    docker version
    docker buildx version
    docker compose version
    docker run --rm hello-world
    make --version
    ```

    `hello-world` debe descargar la imagen y mostrar un mensaje de confirmación.
    Si aparece `permission denied`, comprobar con `id -nG` que la sesión incluye
    el grupo `docker`. Si el servicio no responde, revisar
    `sudo systemctl status docker`.

Estos pasos siguen la [configuración de Docker para Linux](https://docs.docker.com/engine/install/linux-postinstall/).

## Continuar con Mirena

Volver a [Preparar la GPU y la pantalla](index.md#preparar-la-gpu-y-la-pantalla)
para configurar NVIDIA Container Toolkit y el acceso gráfico. Después, clonar
el repositorio y construir la imagen con `make build`, como indica
[Obtener y construir el proyecto](index.md#obtener-y-construir-el-proyecto).
