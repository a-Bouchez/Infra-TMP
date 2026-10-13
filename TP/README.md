# Guía de Resolución (versión corregida): TP Final Integrador - Red Protegida por Firewall

> **Antes de empezar en el laboratorio, confirmar con el docente / el entorno:**
> 1. Valor de **XX** del prefijo `44.0.XX.0/24`. En esta guía se usa `XX = 10` (`44.0.10.0/24`). Si es otro, reemplazarlo en todos lados.
> 2. Qué provee el lab como **WAN**: ¿ya existe un bridge/red para conectar pfSense y `vm-wan`, o hay que asociar `br-wan` a la NIC física del host? ¿La WAN entrega DHCP? ¿Qué rango usa (privado o público)?
> 3. Que el rango de la WAN **no se superponga** con 192.168.10/20/30.0/24 ni con 44.0.10.0/24.
> 4. Dónde vive `vm-wan` (¿una VM más sobre `br-wan`, o es otro equipo del lab?) y qué IP tiene.
> 5. Sistema operativo de las VMs Linux (¿Debian/Ubuntu? ¿tienen entorno gráfico/navegador?) y nombres de sus NIC (`ip -br a`).

---

## 0. Conceptos clave (lo que hay que poder explicar en la defensa)

*   **pfSense es el único router** entre las 5 zonas. Cada zona es un bridge Linux independiente (switch virtual L2) con una NIC de pfSense conectada.
*   **Las reglas de firewall se evalúan en la interfaz de ENTRADA** del tráfico (donde "ingresa" al firewall), de arriba hacia abajo, primera coincidencia gana. Si ninguna coincide: **deny implícito** (en todas las interfaces salvo LAN, que trae una regla *allow any* por defecto que hay que borrar).
*   **El firewall es stateful**: "bloqueado" significa *no se aceptan conexiones NUEVAS* en ese sentido; las respuestas de conexiones permitidas vuelven sin regla adicional.
*   **NAT ≠ routing**. Hay NAT en: (a) salida de USUARIOS/ADMIN/SERV A hacia la WAN (SNAT/masquerade), (b) Port Forward hacia vm-portfw (DNAT). **No hay NAT** en SERVIDORES B ni entre zonas internas.
*   **Trampa principal del TP:** el *Automatic Outbound NAT* de pfSense NATea todas las subredes conectadas, **incluida SERVIDORES B**. Hay que pasarlo a **Hybrid** y excluir 44.0.10.0/24.
*   **Restricción:** no usar NAT de libvirt (red `default`/`virbr0`). Todas las NIC van a bridges propios.

---

## Entregable 1: Diagrama de la topología

```
                                 RED EXTERNA / LAB
                                         |
              vm-wan ---------------[ br-wan ]
                                         |
                                vtnet0 (WAN, DHCP)
                                         |
 +-------------------------------------------------------------------------------+
 |                                 pfSense (VM)                                  |
 |                               firewall + router                               |
 +---------+-------------------+-------------------+-------------------+---------+
           |                   |                   |                   |
     vtnet1 (LAN)        vtnet2 (OPT1)       vtnet3 (OPT2)       vtnet4 (OPT3)
    192.168.30.254      192.168.10.254      192.168.20.254        44.0.10.254
           |                   |                   |                   |
     [ br-admin ]       [ br-usuarios ]      [ br-srv-a ]        [ br-srv-b ]
           |                   |                   |                   |
    ADMINISTRACIÓN         USUARIOS          SERVIDORES A        SERVIDORES B
    192.168.30.0/24     192.168.10.0/24     192.168.20.0/24      44.0.10.0/24
           |                   |                   |                   |
       vm-admin             vm-user            vm-portfw          vm-ruteada
     192.168.30.10       192.168.10.10       192.168.20.10        44.0.10.10
```

> **Decisión de diseño:** ADMINISTRACIÓN es la interfaz **LAN** (`vtnet1`). pfSense asigna por defecto `vtnet1` a LAN y le aplica la regla *anti-lockout* (acceso a la GUI). Así la GUI queda alcanzable desde ADMIN desde el primer momento, y no desde USUARIOS.

---

## Entregable 2: Tabla de direccionamiento

| Dispositivo | NIC / Interfaz | Bridge | Red | IP | Gateway |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **pfSense** | vtnet0 (WAN) | br-wan | Externa | DHCP del lab → `<IP_WAN_PFSENSE>` | Provisto por lab |
| **pfSense** | vtnet1 (LAN) | br-admin | ADMINISTRACIÓN | 192.168.30.254/24 | - |
| **pfSense** | vtnet2 (OPT1) | br-usuarios | USUARIOS | 192.168.10.254/24 | - |
| **pfSense** | vtnet3 (OPT2) | br-srv-a | SERVIDORES A | 192.168.20.254/24 | - |
| **pfSense** | vtnet4 (OPT3) | br-srv-b | SERVIDORES B | 44.0.10.254/24 | - |
| **vm-wan** | (NIC única) | br-wan | Externa | `<IP_VM_WAN>` (lab o estática) | Lo que use el lab; **+ ruta** `44.0.10.0/24 via <IP_WAN_PFSENSE>` |
| **vm-user** | (NIC única) | br-usuarios | USUARIOS | 192.168.10.10/24 | 192.168.10.254 |
| **vm-admin** | (NIC única) | br-admin | ADMINISTRACIÓN | 192.168.30.10/24 | 192.168.30.254 |
| **vm-portfw** | (NIC única) | br-srv-a | SERVIDORES A | 192.168.20.10/24 | 192.168.20.254 |
| **vm-ruteada** | (NIC única) | br-srv-b | SERVIDORES B | 44.0.10.10/24 | 44.0.10.254 |

*(Completar `<IP_WAN_PFSENSE>` e `<IP_VM_WAN>` con los valores reales una vez levantado todo.)*

---

## Entregable 3: Matriz de comunicaciones (5 zonas)

Lectura: **fila = origen** que inicia la conexión, **columna = destino**. Cada celda indica si la conexión nueva está Permitida o Bloqueada.

| Origen \ Destino | WAN | USUARIOS | ADMIN | SERV A | SERV B |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **WAN** | - | Bloqueado | Bloqueado | Permitido: solo TCP/8000 a vm-portfw, vía **IP WAN de pfSense** (Port Forward / DNAT) | Permitido: solo TCP/8000 a vm-ruteada (**routing + firewall**, sin NAT) |
| **USUARIOS** | Permitido: con **SNAT** (IP WAN de pfSense) | - | Bloqueado | Bloqueado (mínimo privilegio) | Bloqueado (mínimo privilegio) |
| **ADMIN** | Permitido: con **SNAT** | Bloqueado | - | Permitido: SSH (22) + ICMP | Permitido: SSH (22) + ICMP |
| **SERV A** | Permitido: con **SNAT** (inicialmente) | Bloqueado | Bloqueado | - | Bloqueado |
| **SERV B** | Permitido: **sin NAT** (routing) | Bloqueado | Bloqueado | Bloqueado | - |

**Hacia el firewall mismo (pfSense):**

| Origen | Servicio en pfSense | Acción |
| :--- | :--- | :--- |
| ADMIN | GUI (HTTPS 443), ICMP, DNS (SSH opcional) | Permitido |
| USUARIOS / SERV A / SERV B | DNS (53) e ICMP echo | Permitido (solo lo necesario) |
| USUARIOS / SERV A / SERV B | GUI (80/443) y SSH | Bloqueado (incluye acceder a la GUI por la IP WAN) |
| WAN | cualquier cosa | Bloqueado |

**Justificación de las celdas no exigidas por el enunciado:** USUARIOS→SERVIDORES, ADMIN→USUARIOS y SERV A↔SERV B no se piden, así que se bloquean por *mínimo privilegio*. Si el docente pide abrir algo, es agregar una regla *pass* específica arriba del bloqueo.

---

## Entregable 4: Políticas de firewall (por interfaz, EN ORDEN)

**Paso previo:** crear el alias `INTERNAS` en *Firewall > Aliases > IP > Add* (tipo Network):
`192.168.10.0/24, 192.168.20.0/24, 192.168.30.0/24, 44.0.10.0/24`.
(No usar "not RFC1918": la WAN del lab puede ser privada y quedaría bloqueada.)

**Importante:** borrar las reglas por defecto *"Default allow LAN to any"* (IPv4 e IPv6) de LAN. Las reglas se leen de arriba hacia abajo: **los bloqueos van antes que el "pass any"**.

### 4.1 Interfaz WAN (vtnet0): entrada desde la red externa
| # | Acción | Proto | Origen | Destino | Puerto | Justificación |
| :-- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Pass | TCP | any | **192.168.20.10** | 8000 | Regla asociada al Port Forward. Se evalúa *después* del DNAT, por eso el destino es la IP **privada** y no la IP WAN. |
| 2 | Pass | TCP | any | **44.0.10.10** | 8000 | Acceso a vm-ruteada por routing puro. |
| - | (implícito) Block | any | any | any | - | Todo lo demás, incluido ADMIN y USUARIOS, queda bloqueado por defecto. |

En *Interfaces > WAN*: **desmarcar "Block private networks" y "Block bogon networks"** (si no, pfSense descarta tráfico del lab).

### 4.2 Interfaz ADMINISTRACIÓN / LAN (vtnet1)
| # | Acción | Proto | Origen | Destino | Puerto | Justificación |
| :-- | :--- | :--- | :--- | :--- | :--- | :--- |
| 0 | Pass (anti-lockout, automática) | TCP | any (en LAN) | This Firewall | 443/80(/22) | Evita quedarse sin GUI. |
| 1 | Pass | TCP/UDP | ADMIN net | This Firewall | 53 | DNS. |
| 2 | Pass | ICMP echo | ADMIN net | This Firewall | - | Diagnóstico. |
| 3 | Pass | TCP | ADMIN net | SERV A net, SERV B net | 22 | Administración (SSH) de servidores. |
| 4 | Pass | ICMP echo | ADMIN net | SERV A net, SERV B net | - | Diagnóstico. |
| 5 | Block (log) | any | ADMIN net | alias `INTERNAS` | - | No hay motivo para que ADMIN llegue a USUARIOS ni salga a otras redes internas fuera de lo explícito. |
| 6 | Pass | any | ADMIN net | any | - | Salida a la red externa (actualizaciones/diagnóstico). |

### 4.3 Interfaz USUARIOS (vtnet2)
| # | Acción | Proto | Origen | Destino | Puerto | Justificación |
| :-- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Pass | TCP/UDP | USUARIOS net | This Firewall | 53 | DNS. |
| 2 | Pass | ICMP echo | USUARIOS net | This Firewall | - | Diagnóstico. |
| 3 | Block (log) | any | USUARIOS net | This Firewall | - | Impide GUI/SSH desde USUARIOS (también vía IP WAN). |
| 4 | Block (log) | any | USUARIOS net | alias `INTERNAS` | - | **USUARIOS → ADMIN bloqueado** (y resto de zonas internas). |
| 5 | Pass | any | USUARIOS net | any | - | Salida a la red externa. |

### 4.4 Interfaz SERVIDORES A (vtnet3)
Mismas reglas 1 a 5 que USUARIOS (con origen `SERV A net`). La regla 4 cumple *"SERV A no inicia conexiones a USUARIOS/ADMIN"*; la 5 es la salida *"permitida inicialmente"* (candidata a ser quitada en un cambio de requerimiento).

### 4.5 Interfaz SERVIDORES B (vtnet4)
Mismas reglas 1 a 5 (origen `SERV B net`). La salida de la regla 5 va **sin NAT** (ver Entregable 5).

> Activar *Log* en las reglas de bloqueo: sirve como evidencia en *Status > System Logs > Firewall*.

---

## Entregable 5: Routing y NAT

### 5.1 Routing
*   pfSense tiene una interfaz en cada subred, por lo que conoce las 4 redes internas como *directamente conectadas* y enruta entre ellas. El gateway por defecto de pfSense es el de la WAN.
*   Cada VM interna usa como gateway la IP de pfSense en su subred.
*   **Ruta en la red externa hacia SERVIDORES B:** `vm-wan` (o el router del lab) necesita `44.0.10.0/24 via <IP_WAN_PFSENSE>`. Razón: al no haber NAT, vm-ruteada conserva su IP real `44.0.10.10`; el exterior no tiene forma de saber que ese prefijo está "detrás" de pfSense si no se lo dicen, y enviaría el paquete a su gateway por defecto (se pierde). La respuesta de vm-ruteada vuelve sin problemas porque pfSense es su gateway.
    ```bash
    # en vm-wan
    sudo ip route add 44.0.10.0/24 via <IP_WAN_PFSENSE>
    ```

### 5.2 Dónde SÍ hay NAT
1.  **Outbound NAT (SNAT/masquerade)** para `192.168.10.0/24`, `192.168.20.0/24` y `192.168.30.0/24` hacia la WAN: el origen se reescribe a `<IP_WAN_PFSENSE>`.
2.  **Port Forward (DNAT)** de `<IP_WAN_PFSENSE>:8000` → `192.168.20.10:8000`.

### 5.3 Dónde NO hay NAT
1.  **SERVIDORES B ↔ WAN** (en ambos sentidos): routing + firewall. Se logra con una regla *Do not NAT* (ver 5.4).
2.  **Entre zonas internas** (ej. ADMIN → SERV A por SSH): routing puro, conservan sus IP.

### 5.4 Configuración en pfSense
**Firewall > NAT > Outbound** → modo **Hybrid Outbound NAT** → agregar regla manual (queda por encima de las automáticas):

| Campo | Valor |
| :--- | :--- |
| Interface | WAN |
| Source | Network `44.0.10.0/24` |
| Destination | any |
| **Do not NAT** | Sí (marcado) |

Las reglas automáticas siguen NATeando las 192.168.x.

**Firewall > NAT > Port Forward > Add:**

| Campo | Valor |
| :--- | :--- |
| Interface | WAN |
| Protocol | TCP |
| Source | any |
| Destination | WAN address |
| Destination port | 8000 |
| Redirect target IP | 192.168.20.10 |
| Redirect target port | 8000 |
| Filter rule association | Add associated filter rule |

### 5.5 Qué se observa antes y después del firewall (Port Forward)
| Punto de captura | Origen | Destino |
| :--- | :--- | :--- |
| En `vm-wan` (sale) | `<IP_VM_WAN>:puerto_efímero` | `<IP_WAN_PFSENSE>:8000` |
| En `vm-portfw` (llega, tras DNAT) | `<IP_VM_WAN>:puerto_efímero` (origen sin cambiar) | `192.168.20.10:8000` (**destino traducido**) |
| Respuesta de vm-portfw | `192.168.20.10:8000` | `<IP_VM_WAN>` |
| Respuesta vista en vm-wan (pfSense des-traduce) | `<IP_WAN_PFSENSE>:8000` | `<IP_VM_WAN>` |

Para salida con SNAT (ej. vm-user → WAN): origen `192.168.10.10:p` dentro → `<IP_WAN_PFSENSE>:p'` afuera (el puerto puede cambiar).
Para vm-ruteada → WAN: origen `44.0.10.10` **en ambos lados** (no cambia).

---

## Entregable 6: Implementación y verificación

### Paso 1: Validar el host
```bash
groups
virsh uri            # debería ser qemu:///system
virsh list --all
virt-host-validate
```

### Paso 2: Bridges (dominios Ethernet)

**Bridges internos** (sin IP en el host, sin STP):
```bash
for b in usuarios admin srv-a srv-b; do
  nmcli connection add type bridge ifname br-$b con-name perfil-br-$b \
    bridge.stp no ipv4.method disabled ipv6.method disabled connection.autoconnect yes
  nmcli connection up perfil-br-$b
done
```

**Bridge WAN**, según lo que provea el lab (confirmar antes):
*   **Opción A:** el lab ya entrega un bridge/red hacia la WAN → usar ese nombre en lugar de `br-wan` en los `--network`.
*   **Opción B:** asociar la NIC física a `br-wan` (¡hacerlo desde consola local: se puede cortar la conectividad del host por esa NIC!):
    ```bash
    nmcli connection add type bridge ifname br-wan con-name perfil-br-wan \
      bridge.stp no ipv4.method disabled ipv6.method disabled connection.autoconnect yes
    nmcli connection add type ethernet ifname <NIC_FISICA> master br-wan con-name perfil-br-wan-port
    nmcli connection up perfil-br-wan-port
    nmcli connection up perfil-br-wan
    ```
    Si el host necesita su IP por esa NIC, dársela al bridge (`ipv4.method auto` en `perfil-br-wan`) en vez de `disabled`.

Verificar:
```bash
ip -br link | grep br-
bridge link
```

### Paso 3: Crear la VM pfSense
El **orden** de `--network` define `vtnet0..vtnet4` y debe coincidir con el diagrama. Se fijan las MAC para que una reinstalación (Entregable 8) conserve identidad (DHCP de la WAN).
```bash
virt-install \
  --name pfsense \
  --ram 2048 --vcpus 2 \
  --cpu host-model \
  --osinfo detect=on,require=off \
  --disk path=/var/lib/libvirt/images/pfsense.qcow2,size=20,format=qcow2,bus=virtio \
  --cdrom /var/lib/libvirt/isos/pfSense.iso \
  --network bridge=br-wan,model=virtio,mac=52:54:00:aa:00:01 \
  --network bridge=br-admin,model=virtio,mac=52:54:00:aa:00:02 \
  --network bridge=br-usuarios,model=virtio,mac=52:54:00:aa:00:03 \
  --network bridge=br-srv-a,model=virtio,mac=52:54:00:aa:00:04 \
  --network bridge=br-srv-b,model=virtio,mac=52:54:00:aa:00:05 \
  --graphics spice
```
*(Si preferís indicar el sistema: `virt-install --osinfo list | grep -i freebsd`.)*

Verificar y, al terminar la instalación, expulsar el ISO:
```bash
virsh domiflist pfsense          # 5 NICs, cada una en su bridge, en orden
virsh domblklist pfsense         # ver el target del cdrom (ej. sda)
virsh change-media pfsense sda --eject --config
```

### Paso 4: Configuración inicial de pfSense (consola)
1.  Instalar (Auto/ZFS o UFS) y reiniciar.
2.  **Opción 1 - Assign Interfaces** (sin VLANs): `WAN=vtnet0`, `LAN=vtnet1`, `OPT1=vtnet2`, `OPT2=vtnet3`, `OPT3=vtnet4`.
3.  **Opción 2 - Set interface IP:** LAN → `192.168.30.254/24` (sin DHCP). WAN queda en DHCP.
4.  Entrar a la GUI **desde vm-admin**: `https://192.168.30.254` (usuario `admin`, clave `pfsense`; cambiarla).
    *   Si vm-admin no tiene navegador: usar `curl -k -I https://192.168.30.254` como evidencia, o (solo para el setup) darle temporalmente una IP al host en `br-admin`: `sudo ip addr add 192.168.30.100/24 dev br-admin` y **quitarla después** (`ip addr del ...`).
5.  En el wizard / *Interfaces*: renombrar `LAN→ADMIN`, `OPT1→USUARIOS`, `OPT2→SRV_A`, `OPT3→SRV_B`; **habilitar** cada interfaz y poner su IP estática (`192.168.10.254/24`, `192.168.20.254/24`, `44.0.10.254/24`). En WAN, **desmarcar** *Block private networks* y *Block bogon networks*.
6.  Cargar alias, reglas (Entregable 4) y NAT (5.4). Borrar las reglas *allow LAN to any*.
7.  *System > Advanced > Networking*: si ping funciona pero TCP falla/se cuelga, tildar **Disable hardware checksum offloading** y reiniciar (problema conocido con virtio).

### Paso 5: Conectar las VMs Linux (SIN red `default` de libvirt)
Revisar a qué red está cada NIC:
```bash
virsh domiflist vm-user
```
Si la columna *Source* dice `default` (NAT de libvirt), **cambiarla** (VM apagada). Ejemplo para vm-user:
```bash
virsh detach-interface vm-user network --mac <MAC_ACTUAL> --config
virsh attach-interface vm-user bridge br-usuarios --model virtio --config
virsh start vm-user
virsh domiflist vm-user          # Source = br-usuarios
```
Repetir: `vm-admin→br-admin`, `vm-portfw→br-srv-a`, `vm-ruteada→br-srv-b`, `vm-wan→br-wan`.
(Alternativa: `virsh edit` y poner `<interface type='bridge'><source bridge='br-...'/><model type='virtio'/></interface>`.)

### Paso 6: IPs dentro de cada VM
Ejemplo (ajustar nombre de conexión/NIC con `nmcli con show` / `ip -br a`):
```bash
sudo nmcli con mod "Wired connection 1" ipv4.method manual \
  ipv4.addresses 192.168.10.10/24 ipv4.gateway 192.168.10.254 ipv4.dns 192.168.10.254
sudo nmcli con up "Wired connection 1"
```
Atajo temporal (no persistente) si se complica:
```bash
sudo ip addr add 192.168.10.10/24 dev enp1s0
sudo ip route add default via 192.168.10.254
```
Valores: ver tabla del Entregable 2. En **vm-wan** agregar la ruta a SERVIDORES B (5.1).

### Paso 7: Servicios (hacerlo cuando las VMs ya tengan salida a Internet)
En **vm-portfw** y **vm-ruteada** (página distinta en cada una, es lo que se verifica):
```bash
mkdir -p ~/web
echo "<h1>Hola desde vm-portfw (192.168.20.10)</h1>" > ~/web/index.html    # en vm-ruteada: "vm-ruteada (44.0.10.10)"
nohup python3 -m http.server 8000 --bind 0.0.0.0 --directory ~/web >/dev/null 2>&1 &
ss -tlnp | grep 8000
```
SSH en **vm-portfw**, **vm-ruteada** (y los que se quieran administrar):
```bash
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```
*(`qemu-guest-agent` es opcional y no hace falta para el TP.)*

### Pruebas de aceptación (guardar la salida de cada una como evidencia)

| # | Desde | Comando | Resultado esperado |
| :-- | :--- | :--- | :--- |
| 1 | vm-user | `ping -c3 <IP_VM_WAN>` (o 8.8.8.8 si hay Internet) | Permitido: responde. En vm-wan, `sudo tcpdump -ni any icmp` muestra origen = `<IP_WAN_PFSENSE>` (SNAT) |
| 2 | vm-user | `ping -c3 -W2 192.168.30.10` ; `nc -zv -w3 192.168.30.10 22` | Bloqueado: sin respuesta / timeout |
| 3 | vm-user | `curl -k -m3 https://192.168.10.254` | Bloqueado: GUI no accesible desde USUARIOS |
| 4 | vm-admin | `curl -k -I https://192.168.30.254` (o navegador) | Permitido: se abre la GUI de pfSense |
| 5 | vm-admin | `ssh <user>@192.168.20.10` y `ssh <user>@44.0.10.10` | Permitido: SSH funciona a ambos servidores |
| 6 | vm-admin | `ping -c3 <IP_VM_WAN>` | Permitido: hay salida |
| 7 | vm-portfw | `ping -c3 <IP_VM_WAN>` | Permitido: hay salida (con SNAT) |
| 8 | vm-portfw | `nc -zv -w3 192.168.10.10 22` ; `nc -zv -w3 192.168.30.10 22` | Bloqueado |
| 9 | vm-wan | `curl http://<IP_WAN_PFSENSE>:8000` | Permitido: devuelve la página de **vm-portfw** |
| 10 | vm-wan | `curl http://44.0.10.10:8000` | Permitido: devuelve la página de **vm-ruteada** (requiere la ruta del 5.1) |
| 11 | vm-wan | `sudo ip route add 192.168.30.0/24 via <IP_WAN_PFSENSE>` y luego `ping -c3 -W2 192.168.30.10` (idem con 192.168.10.10) ; después `sudo ip route del 192.168.30.0/24` | Bloqueado: Sin respuesta (el firewall lo descarta; si no agregás la ruta, ni siquiera hay camino) |
| 12 | vm-ruteada | `ping -c3 <IP_VM_WAN>` con `sudo tcpdump -ni any icmp` corriendo en vm-wan | Permitido: origen visto = `44.0.10.10` (**sin NAT**) |
| 13 | vm-ruteada | `nc -zv -w3 192.168.10.10 22` ; `nc -zv -w3 192.168.30.10 22` | Bloqueado |

**Evidencia adicional (host y pfSense):**
```bash
# en el host
virsh domiflist pfsense
bridge link
ip -br link | grep br-
# en vm-portfw durante la prueba 9
sudo tcpdump -ni any tcp port 8000     # muestra origen=<IP_VM_WAN>, destino=192.168.20.10:8000
```
*   pfSense: **Diagnostics > States** (filtrar por 44.0.10.10: sin traducción de origen; filtrar por 192.168.10.10: con traducción a la IP WAN).
*   pfSense: **Status > System Logs > Firewall** (bloqueos de las pruebas negativas).
*   pfSense: **Firewall > NAT > Outbound** (captura del modo Hybrid + regla *Do not NAT*).
*   pfSense: **Diagnostics > Packet Capture** en WAN y en SRV_A para mostrar el DNAT.

---

## Entregable 7: Configuración exportada de pfSense

*   GUI: **Diagnostics > Backup & Restore > Download configuration as XML**.
*   Si vm-admin no tiene navegador: habilitar SSH (*System > Advanced > Admin Access > Enable Secure Shell*; ya permitido desde ADMIN) y copiar:
    ```bash
    scp admin@192.168.30.254:/cf/conf/config.xml ./pfsense-config.xml
    ```
*   Guardar una copia **fuera de la VM** (en el host) y adjuntarla al entregable.
*   Tras el último cambio (incluyendo los de la defensa) exportar de nuevo.

---

## Entregable 8: Recuperación ante pérdida de la VM del firewall

**Respaldos previos (en el host, fuera de la VM de pfSense):**
```bash
virsh dumpxml pfsense > ~/backup/pfsense-domain.xml
cp pfsense-config.xml ~/backup/          # export del Entregable 7
```
Los **bridges viven en el host**, así que sobreviven a la pérdida de la VM; el resto de las VMs no se tocan.

**Procedimiento:**
1.  Verificar que los 5 bridges existen y están activos: `ip -br link | grep br-` / `bridge link`.
2.  Eliminar la VM dañada: `virsh destroy pfsense; virsh undefine pfsense --nvram` (y borrar el qcow2 corrupto si corresponde).
3.  Recrear la VM con el **mismo `virt-install`** (mismo orden de `--network` y mismas MAC → `vtnet0` WAN, `vtnet1` ADMIN/LAN, `vtnet2` USUARIOS, `vtnet3` SRV A, `vtnet4` SRV B). Verificar con `virsh domiflist pfsense`. (Alternativa: `virsh define ~/backup/pfsense-domain.xml` si el disco está sano.)
4.  Instalar pfSense limpio desde el ISO y expulsar el ISO.
5.  Desde la consola: asignar interfaces (WAN=vtnet0, LAN=vtnet1) y poner la IP de LAN `192.168.30.254/24` para que vm-admin llegue a la GUI.
6.  Desde vm-admin: **Diagnostics > Backup & Restore > Restore Configuration**, elegir el `.xml`, restaurar. pfSense reinicia y aplica interfaces, IPs, alias, reglas, NAT y port forward.
7.  Si las interfaces no coinciden tras restaurar (distinto orden), corregir en *Interfaces > Assignments* y reiniciar.
8.  Revalidar con la tabla de pruebas de aceptación. Si la IP WAN cambió (nueva MAC/lease), actualizar la ruta `44.0.10.0/24 via <IP_WAN_PFSENSE>` en vm-wan.

---

## Cambios de requerimiento probables en la defensa

| Pedido | Qué hacer |
| :--- | :--- |
| GUI de pfSense accesible **solo desde ADMIN** | Ya está: ADMIN es LAN (anti-lockout) y las reglas 3 de USUARIOS/SRV A/SRV B bloquean *This Firewall*. Mostrar el bloqueo en los logs. |
| SERVIDORES A **sin salida** a Internet | Deshabilitar la regla 5 de SRV_A (queda DNS/ICMP al firewall). Probar `ping` desde vm-portfw: debe quedar bloqueado. |
| Publicar otro servicio/puerto de vm-portfw | Nuevo Port Forward + regla asociada en WAN. |
| Permitir USUARIOS → servicio de un servidor | Regla *pass* específica (TCP/puerto) **arriba** del bloqueo a `INTERNAS`. |
| Restringir salida de SERV B | Cambiar la regla 5 por *pass* a destinos/puertos concretos. |

---

## Troubleshooting rápido

| Síntoma | Causa probable |
| :--- | :--- |
| Una VM no tiene red | `virsh domiflist <vm>` muestra red `default` o un bridge equivocado. |
| Desde WAN nada llega (ni siquiera lo permitido) | No se desmarcó *Block private/bogon networks* en la WAN. |
| `curl 44.0.10.10:8000` desde vm-wan se cuelga | Falta la ruta `44.0.10.0/24 via <IP_WAN_PFSENSE>` en vm-wan, o falta la regla 2 de la WAN. |
| Port Forward no responde | Regla WAN con destino la IP WAN en lugar de `192.168.20.10`; vm-portfw sin gateway 192.168.20.254; servicio no escuchando (`ss -tlnp`). |
| vm-ruteada sale con la IP WAN de pfSense | Outbound NAT en modo Automatic, o falta la regla *Do not NAT*. |
| `ping` anda pero TCP/HTTP no | Checksum offloading (ver Paso 4.7). |
| USUARIOS llega a ADMIN | El bloqueo a `INTERNAS` está **debajo** del *pass any*, o quedó la regla default *allow LAN to any*. |
| `nmcli` bridge sin estado | `nmcli connection up perfil-br-xxx` y revisar `ip -br link`. |
