INSTALADOR DE NIXOS
===================

Script para particionar un disco y comenzar la instalación de NixOS desde
la ISO live.

ADVERTENCIA
-----------
El disco seleccionado se borrará por completo. Verifica cuidadosamente el
dispositivo antes de continuar.

REQUISITOS
----------
- Iniciar desde la ISO live de NixOS.
- Tener disponible el script install.sh.
- Usar un disco con espacio suficiente.

DESCARGAR
---------
Cambia NOMBRE_REPO y RAMA por el nombre real del repositorio y su rama:

```bash
curl -fsSL https://raw.githubusercontent.com/Jalvcl/nixos_vm_firstboot/refs/heads/main/bootstrap_utm_vm.sh -o install.sh
```

Revisa el script antes de ejecutarlo:

```bash
less install.sh
```

EJECUTAR
--------
Identifica el disco# INSTALADOR DE NIXOS

Instalador automatizado para preparar un disco e iniciar la instalación de NixOS desde la ISO Live.

El proyecto utiliza dos scripts:

- `install.sh`: descarga y ejecuta automáticamente el instalador.
- `bootstrap_utm_vm.sh`: realiza el particionado, formateo y montaje del disco, y genera la configuración inicial de NixOS.

## ADVERTENCIA

**El disco seleccionado se borrará por completo.**

Verifica cuidadosamente el dispositivo antes de continuar. No ejecutes el instalador sobre un disco que contenga información importante.

## REQUISITOS

- Máquina virtual o equipo iniciado desde la ISO Live de NixOS.
- Conexión a Internet.
- Herramienta `curl` disponible.
- Un disco de destino de al menos 16 GiB.
- Firmware UEFI habilitado en la máquina virtual.

## INSTALACIÓN

No es necesario descargar manualmente los scripts ni utilizar `chmod`.

Desde la terminal de NixOS Live, ejecuta:

```bash
curl -fsSL https://raw.githubusercontent.com/Jalvcl/nixos_vm_firstboot/refs/heads/main/install.sh | bash
```

El instalador realizará automáticamente las siguientes operaciones:

1. Descargará `bootstrap_utm_vm.sh`.
2. Comprobará que la descarga se haya completado correctamente.
3. Solicitará privilegios de administrador.
4. Identificará los discos disponibles.
5. Solicitará seleccionar el disco de destino.
6. Pedirá una confirmación explícita antes de borrar el disco.
7. Preparará las particiones y generará la configuración inicial de NixOS.

**No es necesario ejecutar `chmod +x`**, ya que ambos scripts se ejecutan directamente mediante Bash.

## CONFIRMACIÓN DEL DISCO

Antes de modificar el disco, el instalador mostrará el dispositivo seleccionado y solicitará escribir una confirmación específica.

Por ejemplo:

```text
WARNING: ALL DATA ON THIS DISK WILL BE DESTROYED

NAME     SIZE  MODEL
/dev/vda  32G  Virtual Disk

To confirm, type exactly 'ERASE /dev/vda':
```

Para continuar, escribe:

```text
ERASE /dev/vda
```

Si no deseas continuar, cancela la operación.

## PARTICIONES

El instalador crea una tabla de particiones GPT con la siguiente distribución:

| Partición | Tamaño aproximado | Formato | Etiqueta |
|---|---|---|---|
| Sistema | Espacio disponible menos EFI y Swap | ext4 | nixos |
| Swap | 8 GiB | Linux Swap | swap |
| EFI | 511 MiB | FAT32 | boot |

Las particiones se montan automáticamente en `/mnt`:

- Sistema: `/mnt`
- EFI: `/mnt/boot`
- Swap: activada mediante `swapon`.

## CONFIGURACIÓN DE NIXOS

Una vez finalizado el particionado y montaje, el instalador ejecuta:

```bash
nixos-generate-config --root /mnt
```

Se generan los siguientes archivos:

```text
/mnt/etc/nixos/
├── configuration.nix
└── hardware-configuration.nix
```

## COMPLETAR LA INSTALACIÓN

Antes de instalar NixOS, revisa el archivo:

```bash
nano /mnt/etc/nixos/configuration.nix
```

Configura los parámetros necesarios, por ejemplo:

- Nombre del equipo (`hostname`).
- Usuario principal.
- Contraseña.
- Acceso SSH.
- Configuración de red.
- Bootloader.
- Zona horaria y configuración regional.

Cuando la configuración esté lista, ejecuta:

```bash
nixos-install
```

Al finalizar:

1. Establece la contraseña de root si corresponde.
2. Apaga la máquina virtual.
3. Retira la ISO Live de NixOS.
4. Inicia desde el disco instalado.

## NOTAS

- Diseñado inicialmente para instalaciones de NixOS en máquinas virtuales UTM.
- También puede utilizarse en otros equipos compatibles con UEFI.
- El instalador requiere conexión a Internet para descargar el script.
- La operación de particionado es destructiva.
- La instalación de NixOS no se ejecuta automáticamente: permite revisar y personalizar la configuración antes de continuar.
- Los scripts se ejecutan mediante Bash, sin necesidad de permisos de ejecución adicionales.
- 
