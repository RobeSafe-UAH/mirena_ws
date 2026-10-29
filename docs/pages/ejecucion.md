# Ejecución

## Iniciar el contenedor y el simulador

1. Abrir una terminal del equipo en la carpeta `mirena_ws`, donde está el
   `Makefile`. Construir la imagen la primera vez o tras cambiar `docker/`:

    ```bash
    make build
    ```

2. Arrancar el contenedor:

    ```bash
    make run
    ```

    Se monta el repositorio en `/ros2_ws`, se adapta el usuario `mirena` al UID y
    GID del anfitrión, se compilan los paquetes con `colcon` y se abre **zsh** con
    ROS 2 y el workspace cargados. El resumen de bienvenida comprueba el entorno,
    la compilación, la GPU y la pantalla. El registro de compilación se guarda en
    `log/startup-build.log`.

3. Desde esa terminal del contenedor, lanzar el simulador:

    ```bash
    ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=random
    ```

    Se abre una ventana de Godot con un circuito Trackdrive aleatorio. Consultar
    los [controles y modos del simulador](simulador.md).

4. Para cerrar el simulador, utilizar su ventana o **Ctrl+C** en su terminal.
   Para cerrar también la terminal principal y retirar el contenedor, escribir
   `exit`. Los archivos del repositorio y la compilación permanecen en el equipo.

También se puede lanzar directamente desde el equipo:

```bash
make run CMD="ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=random"
```

En este caso, cuando finaliza el simulador también finaliza el contenedor.

## Elegir un circuito

El parámetro `track` acepta `random` o la ruta de un archivo JSON. Para utilizar
los circuitos incluidos, ejecutar dentro del contenedor:

=== "Trackdrive aleatorio"

    ```bash
    ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=random
    ```

=== "Aceleración"

    ```bash
    ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=/ros2_ws/src/mirena_sim/TrackFiles/acceleration.json
    ```

=== "Skidpad"

    ```bash
    ros2 run mirena_sim mirena_sim --display-driver x11 --ros-args -p track:=/ros2_ws/src/mirena_sim/TrackFiles/skidpad.json
    ```

Las rutas se resuelven **dentro del contenedor**. El formato de pistas y su
generación se describen en [Simulador](simulador.md).

## Abrir otra terminal y RViz

1. Mantener el simulador abierto y, desde otra terminal del equipo en `mirena_ws`,
   entrar en el contenedor:

    ```bash
    make attach
    ```

2. Comprobar las interfaces de ROS 2:

    ```bash
    echo "$ROS_DOMAIN_ID"
    ros2 topic list
    ```

3. Abrir la configuración de RViz incluida:

    ```bash
    rviz2 -d /ros2_ws/src/mirena_sim/mirena_sim.rviz
    ```

    Incluye el coche, conos, pista, frames, LiDAR y cámara RGB. La visualización de
    profundidad está desactivada por defecto. Los sensores utilizan **Best
    Effort**: comprobar la opción **Reliability Policy** si no aparece información.
    Ver [ROS2](topics.md) y [QoS de sensores](sensores.md).

4. Cerrar RViz y escribir `exit` para abandonar la terminal adicional. Esto no
   detiene el contenedor mientras siga abierta su terminal principal.

## Gestionar el entorno

Estos comandos se ejecutan **en el equipo, fuera del contenedor**:

| Comando | Uso |
|---|---|
| `make build` | Construir la imagen aprovechando la caché. |
| `make rebuild` | Actualizar la imagen base y reconstruir sin caché. |
| `make run` | Crear el contenedor, compilar y abrir zsh. |
| `make run AUTO_BUILD=0` | Omitir la compilación; requiere un workspace ya construido. |
| `make attach` | Abrir otra zsh en el contenedor activo. |
| `make stop` | Detener el contenedor; Docker lo elimina al haberse creado con `--rm`. |
| `make clean` | Eliminar `build/`, `install/` y `log/` del workspace. |
| `make help` | Mostrar los comandos disponibles. |

`make clean` borra los productos de compilación y sus registros. Usarlo con el
entorno detenido y volver a compilar antes de lanzar el simulador.

El contenedor se llama `mirena_ws`. Puede inspeccionarse con `docker ps` y
`docker ps -a`. Antes de lanzar otro contenedor con el mismo nombre, detener el
anterior con `make stop`.

### Variables del Makefile

| Variable | Valor por defecto | Uso |
|---|---|---|
| `IMAGE` | `mirena_ws` | Nombre de la imagen. |
| `TAG` | `jazzy` | Etiqueta de la imagen. |
| `CONTAINER` | `mirena_ws` | Nombre del contenedor. |
| `ROS_DOMAIN_ID` | `42` | Dominio de comunicación ROS 2. |
| `AUTO_BUILD` | `1` | Compilar al iniciar. |
| `CMD` | `zsh` | Comando principal del contenedor. |

Para utilizar un dominio diferente:

```bash
make run ROS_DOMAIN_ID=7
```

Los nodos externos deben utilizar el mismo `ROS_DOMAIN_ID`. El contenedor utiliza
la red del anfitrión (`--net host`). Si se cambia su nombre, pasar también
`CONTAINER` a los comandos posteriores, por ejemplo `make attach CONTAINER=otro`.

## Resolver problemas

| Síntoma | Comprobación |
|---|---|
| `cannot open display` o error de autorización X11 | Revisar `echo "$DISPLAY"` en el equipo, ejecutar `xhost +SI:localuser:$(id -un)` y recrear el contenedor con `make stop` y `make run`. |
| No se encuentra el runtime NVIDIA | Revisar la instalación de NVIDIA Container Toolkit y su configuración de Docker en [Instalación](index.md). |
| Godot no encuentra Vulkan o no puede crear la ventana | Ejecutar `nvidia-smi` y `vulkaninfo --summary` dentro del contenedor. Deben reconocer la GPU NVIDIA. Revisar el controlador y recrear el contenedor. |
| Falla la compilación al entrar | Leer `log/startup-build.log` en el repositorio. Corregir el error y volver a ejecutar `make run`. |
| `Package 'mirena_sim' not found` | Compilar siguiendo [Repositorio](repositorio.md) y cargar `source /ros2_ws/install/local_setup.zsh`. |
| Permisos insuficientes sobre los archivos | Ejecutar `make` y `colcon` con el usuario habitual. Revisar en el anfitrión la propiedad de los archivos que provengan de compilaciones antiguas con root. |
| Los sensores aparecen en la lista, pero no llegan datos | Usar QoS **Best Effort** en RViz, CLI o el suscriptor. Ver [Sensores](sensores.md). |
| No se ven los nodos desde otro entorno | Igualar `ROS_DOMAIN_ID` y revisar la conectividad DDS y el firewall de la red utilizada. |
| El nombre `mirena_ws` ya está en uso | Comprobar `docker ps -a` y detener el contenedor anterior antes de volver a lanzar `make run`. |
