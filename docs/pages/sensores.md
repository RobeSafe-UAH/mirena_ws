# Sensores

El complemento `rclgd-sensors`, en `src/mirena_sim/addons/rclgd-sensors`, proporciona sensores como nodos `Node3D` de Godot. Se colocan sobre el vehículo desde el editor y publican mensajes estándar de ROS 2. Consulta [Vehículo](vehiculo.md) para cambiar su montaje y [ROS 2](topics.md) para relacionar sus datos con el resto de interfaces del simulador.

| Sensor | Salida | Implementación | Modelo |
| --- | --- | --- | --- |
| [Lidar](sensores/lidar.md) | `sensor_msgs/msg/PointCloud2` organizada | Cubemap y shaders de cómputo en GPU | Rejilla angular, intensidad aproximada y ruido de distancia |
| [Cámara](sensores/camara.md) | `sensor_msgs/msg/Image` y `CameraInfo`; profundidad opcional | Renderizado y lectura asíncrona de GPU | Cámara pinhole ideal |
| [IMU](sensores/imu.md) | `sensor_msgs/msg/Imu` | Muestreo en cada paso de física | Aceleración propia, velocidad angular, orientación, ruido y deriva |
| [GNSS](sensores/gps.md) | `sensor_msgs/msg/NavSatFix` | Temporizador ROS | Aproximación geodésica local WGS-84 con error correlacionado |

La escena `src/mirena_sim/Scenes/Vehicle/mirena_car.tscn` monta estos cuatro sensores. Los valores indicados como **Mirena** en las páginas siguientes proceden de esa escena o, cuando no se sobrescriben, del script del sensor.

## Configuración común

Todos los sensores heredan de `RosSensor`, definido en `ros_sensor.gd`. Esta clase crea un nodo ROS con el nombre del nodo Godot en `snake_case`: `Lidar` crea `lidar`, mientras que `RosImu` crea `ros_imu`. Los topics privados se resuelven dentro del nodo: `~/data` de `RosImu`, sin namespace, se convierte en `/ros_imu/data`.

Los siguientes campos aparecen en **ROS 2 Settings** del Inspector de Godot. Son propiedades exportadas de la escena; no son parámetros que se configuren mediante `ros2 param set`.

| Propiedad | Valor del complemento | Función |
| --- | --- | --- |
| `ros_namespace` | `""` | Namespace del nodo ROS, sus topics y los frames con prefijo `~` |
| `frame_id` | `""` | Frame del sensor; vacío utiliza `~<nombre_del_nodo>` |
| `parent_frame_id` | `~base_link` | Frame padre de la transformación de montaje |
| `publish_rate` | Depende del sensor | Frecuencia solicitada de publicación, en Hz |

Un frame con `~` se resuelve dentro de `ros_namespace`; por ejemplo, `~lidar` bajo el namespace `car` da `car/lidar`. Un nombre explícito como `car/lidar` se mantiene como frame del sensor. En Mirena se usan frames explícitos bajo `car/`, pero `ros_namespace` queda vacío: por eso el lidar publica en `/lidar/lidar` y su `header.frame_id` es `car/lidar`.

## Montaje y TF

Al entrar en la escena, `RosSensor` publica una transformación estática desde `parent_frame_id` hasta `frame_id` en `/tf_static`. La transformación procede de la posición y orientación del nodo respecto a su padre en Godot. El montaje se considera rígido: moverlo durante la ejecución no actualiza esa transformación estática.

En el coche, los cuatro sensores tienen como padre TF `car/cog`:

```text
car/cog
├── car/lidar
├── car/camera
│   └── car/camera_optical
├── car/imu
└── car/gps
```

La conversión de vectores del complemento es:

$$
(x,y,z)_{\mathrm{ROS}}=(-z,-x,y)_{\mathrm{Godot}}.
$$

Así, los frames físicos de los sensores usan **x hacia delante, y hacia la izquierda y z hacia arriba**. Las imágenes usan un frame óptico adicional, con **z hacia delante, x hacia la derecha e y hacia abajo**.

## Calidad de servicio

Los publicadores creados por `RosSensor._advertise()` usan el perfil de datos de sensores:

| Política | Valor |
| --- | --- |
| Fiabilidad | `best_effort` |
| Historial | `keep_last` |
| Profundidad | `5` |
| Durabilidad | `volatile` |

Una suscripción `reliable` no es compatible con estos publicadores. Configura los displays de RViz como **Best Effort** y usa `rclpy.qos.qos_profile_sensor_data` o `rclcpp::SensorDataQoS()` en tus nodos.

Con el simulador en marcha, puedes revisar la configuración y recibir una muestra:

```bash
ros2 topic info /lidar/lidar --verbose
ros2 topic echo /ros_imu/data --qos-reliability best_effort --once
ros2 topic echo /ros_gps/fix --qos-reliability best_effort --once
```

## Muestreo y marcas de tiempo

Lidar, cámara, fisheye y GPS usan `RosTimer` mediante `_start_sampling(rate)`. Su arranque incorpora un retraso aleatorio de hasta un periodo para repartir la carga entre sensores. La IMU utiliza cada paso de física y decide cuándo publicar a partir de `publish_rate`.

Los sensores GPU guardan `header.stamp` **al solicitar la captura** y después leen los datos de forma asíncrona. La recepción por ROS puede producirse varios fotogramas más tarde. Usa esa marca de tiempo al buscar transformaciones o asociar una observación con la pose del coche. La captura queda limitada a una por fotograma renderizado; solicitar más Hz que los disponibles no garantiza esa tasa.

Cada flujo GPU publica desde un hilo de `PublishQueue`. La cola entrega las capturas por orden y conserva hasta tres pendientes; al llenarse, descarta la más antigua. La cámara tiene colas independientes para color y profundidad. Aunque comparten marca temporal, su orden de llegada relativo puede variar.

## Renderizado y visibilidad

Los sensores GPU tienen sus propias cámaras y renderizan las mallas de la escena. `cull_mask` selecciona las capas 3D visibles. Por defecto incluyen todas las capas, por lo que también pueden observar la carrocería del propio coche.

Para excluir una malla, colócala en una capa de renderizado que el sensor no incluya en `cull_mask`. Las capas visuales controlan lo que capturan estos sensores; el modelo de colisiones no determina por sí solo su salida.

## Cámara fisheye disponible en el complemento

`RosFisheyeCamera`, en `ros_fisheye_camera/ros_fisheye_camera.gd`, está implementada y registrada por el complemento, pero **no está montada en `mirena_car.tscn`**. Por tanto, la escena predeterminada no publica sus topics. Se puede añadir como otro sensor desde el editor.

Renderiza seis caras de un cubemap y `FisheyeStitch.glsl` las combina en una imagen `rgba8`. Publica `~/image_raw` y `~/camera_info` en `<frame_id>_optical`, con el mismo QoS y temporización descritos arriba. No publica profundidad.

| Propiedad | Valor inicial | Función |
| --- | --- | --- |
| `projection_type` | `CIRCULAR_FISHEYE` | Proyección circular o `EQUIRECTANGULAR` |
| `resolution` | 640 × 480 | Tamaño de la imagen final |
| `fov` | 180° | Apertura de la lente en el modo fisheye |
| `face_resolution` | 512 | Lado de cada cara del cubemap |
| `near` / `far` | 0.05 / 150 m | Planos de recorte |
| `publish_rate` | 15 Hz | Tasa de captura solicitada |
| `use_custom_calibration` | `false` | Activa intrínsecos y distorsión propios |

La proyección circular ideal ocupa un círculo ajustado a la altura de la imagen. Su `CameraInfo` usa `distortion_model = "equidistant"`, cuatro coeficientes nulos e intrínsecos calculados con $f_x=f_y=(h/2)/(\mathrm{fov}/2)$, con el ángulo en radianes. Al activar calibración propia se usan `custom_fx`, `custom_fy`, `custom_cx`, `custom_cy` y `k1` a `k4`; el shader invierte un polinomio angular de tipo Kannala–Brandt.

La proyección equirectangular ideal cubre 360° horizontales y 180° verticales. Su `CameraInfo` declara `distortion_model = "equirectangular"`, sin coeficientes de distorsión y con focales y centro principal a cero. Comprueba que el consumidor admite ese modelo; no se puede proyectar con la matriz pinhole de la [cámara convencional](sensores/camara.md). El camino de calibración propia aplica el modelo angular fisheye, por lo que debe configurarse junto a `CIRCULAR_FISHEYE`.

Las capacidades anteriores se describen a partir de la implementación; las imágenes existentes de esta documentación corresponden a los cuatro sensores montados en Mirena.
