# Guía de Resolución: Trabajo Final Integrador - Red Protegida por Firewall

## Conceptos Clave Necesarios
*   **Virtualización en Linux:** Creación y administración de máquinas virtuales utilizando KVM/QEMU y libvirt.
*   **Redes Virtuales:** Uso de Linux Bridge para actuar como switches virtuales. Se requieren cinco dominios Ethernet independientes (WAN, USUARIOS, ADMINISTRACIÓN, SERVIDORES A y SERVIDORES B).
*   **Routing y Firewall (pfSense):** pfSense actúa como enrutador central y firewall, evaluando las reglas en la interfaz por la que ingresa el tráfico.
*   **Restricción importante:** Todo el enrutamiento y NAT debe ser manejado por pfSense; está prohibido usar mecanismos adicionales de NAT provistos por libvirt para resolver la conectividad solicitada.

---

## Entregable 1: Diagrama de la topología lógica

                                  [ RED EXTERNA (WAN) ]
                                            |
                                        (br-wan)
                                            |
                                +-----------------------+
                                |                       |
                                |      pfSense (VM)     |
                                |                       |
                                +---+---+-------+---+---+
                                    |   |       |   |
                +-------------------+   |       |   +-------------------+
                |                       |       |                       |
          (br-usuarios)       (br-admin)|       |(br-srv-a)         (br-srv-b)
                |                       |       |                       |
           [USUARIOS]         [ADMINISTRACIÓN] [SERVIDORES A]      [SERVIDORES B]
         192.168.10.0/24      192.168.30.0/24  192.168.20.0/24      44.0.10.0/24
                |                       |       |                       |
            (vm-user)               (vm-admin) (vm-portfw)         (vm-ruteada)
          192.168.10.10           192.168.30.10 192.168.20.10        44.0.10.10

---

## Entregable 2: Tabla de Direccionamiento

| Dispositivo / VM | Red conectada | Dirección IP Propuesta | Gateway (Puerta de enlace) |
| :--- | :--- | :--- | :--- |
| **pfSense (Interfaz 1)** | WAN | *DHCP (Provista por Lab)* | *Provisto por Lab* |
| **pfSense (Interfaz 2)** | USUARIOS | 192.168.10.254 | N/A (Es el gateway) |
| **pfSense (Interfaz 3)** | SERVIDORES A | 192.168.20.254 | N/A (Es el gateway) |
| **pfSense (Interfaz 4)** | ADMINISTRACIÓN | 192.168.30.254 | N/A (Es el gateway) |
| **pfSense (Interfaz 5)** | SERVIDORES B | 44.0.10.254 | N/A (Es el gateway) |
| **VM Linux (Usuario)** | USUARIOS | 192.168.10.10 | 192.168.10.254 |
| **VM Linux (Admin)** | ADMINISTRACIÓN | 192.168.30.10 | 192.168.30.254 |
| **VM Linux (Srv A)** | SERVIDORES A | 192.168.20.10 | 192.168.20.254 |
| **VM Linux (Srv B)** | SERVIDORES B | 44.0.10.10 | 44.0.10.254 |

---

## Entregable 3: Matriz de Comunicaciones

| Origen (Interfaz donde se evalúa) | Destino / Servicio | Requerimiento (Acción) | Observación / Mecanismo |
| :--- | :--- | :--- | :--- |
| **USUARIOS** | Red externa / Internet | Permitido | Requiere salir utilizando la dirección WAN del firewall (NAT). |
| **USUARIOS** | ADMINISTRACIÓN | Bloqueado | Restricción explícita de seguridad. |
| **ADMINISTRACIÓN** | pfSense GUI | Permitido | Para operación del enrutador. |
| **ADMINISTRACIÓN** | Servidores A y B (ej. puerto SSH) | Permitido | Para mantenimiento de los servidores internos. |
| **ADMINISTRACIÓN** | Red externa / Internet | Permitido | Para actualización o diagnóstico. |
| **SERVIDORES A** | Red externa / Internet | Permitido inicialmente | Salida a Internet. |
| **SERVIDORES A** | USUARIOS / ADMINISTRACIÓN | Bloqueado | Bloqueado para conexiones nuevas. |
| **SERVIDORES B** | Red externa / Internet | Permitido | Permitido sin NAT. |
| **SERVIDORES B** | USUARIOS / ADMINISTRACIÓN | Bloqueado | Bloqueado para conexiones nuevas. |
| **Red externa (WAN)** | vm-portfw:8000 (Servidores A) | Permitido | Permitido mediante publicación del servicio. |
| **Red externa (WAN)** | vm-ruteada:8000 (Servidores B) | Permitido | Permitido mediante routing + firewall. |
| **Red externa (WAN)** | ADMINISTRACIÓN | Bloqueado | Se bloquean las conexiones entrantes por defecto desde Internet. |

---

## Entregable 4: Descripción de las políticas de firewall y justificación

**1. Interfaz WAN (Red Externa)**
*   **Política General:** Bloquear conexiones entrantes por defecto y agregar sólo publicaciones necesarias.
*   **Regla (Permitir hacia Servidores B):** Se permite el tráfico entrante hacia `vm-ruteada:8000`. **Justificación:** Al ser una red con direccionamiento enrutable, se debe permitir el acceso mediante routing y firewall sin utilizar NAT.
*   **Regla (Permitir hacia Servidores A):** Se permite el tráfico entrante hacia `vm-portfw:8000`. **Justificación:** El servidor tiene direccionamiento privado; se publica su servicio mediante traducción de direcciones (Port Forward).
*   **Regla (Bloqueo a Administración):** Acceso bloqueado hacia la red de ADMINISTRACIÓN. **Justificación:** No debe ser accesible desde la WAN por seguridad.

**2. Interfaz LAN (USUARIOS)**
*   **Regla (Permitir a WAN):** Se permite la salida hacia la red externa. **Justificación:** Los clientes necesitan salida a Internet.
*   **Regla (Bloqueo a Administración):** Tráfico bloqueado hacia ADMINISTRACIÓN. **Justificación:** Separación de redes para proteger la gestión.

**3. Interfaz ADMINISTRACIÓN**
*   **Regla (Permitir a pfSense):** Acceso permitido a la GUI. **Justificación:** Red destinada a gestionar el firewall.
*   **Regla (Permitir a Servidores):** Acceso permitido a Servidores A y B. **Justificación:** Para mantenimiento y administración de servidores internos según los servicios definidos.
*   **Regla (Permitir a WAN):** Salida a Internet permitida. **Justificación:** Para actualizaciones y diagnóstico.

**4. Interfaz SERVIDORES A (DMZ Port Forward)**
*   **Regla (Permitir a WAN):** Salida a Internet permitida inicialmente. **Justificación:** Los servidores deben poder iniciar conexiones hacia el exterior.
*   **Regla (Bloqueo Interno):** Conexiones nuevas hacia USUARIOS y ADMINISTRACIÓN bloqueadas. **Justificación:** Aislamiento de red; no deben alcanzar la gestión.

**5. Interfaz SERVIDORES B (DMZ Ruteada)**
*   **Regla (Permitir a WAN):** Salida a Internet permitida sin NAT. **Justificación:** Acceden a la WAN con direccionamiento enrutable.
*   **Regla (Bloqueo Interno):** Conexiones nuevas hacia USUARIOS y ADMINISTRACIÓN bloqueadas. **Justificación:** Principio de aislamiento.

---

## Entregable 5: Descripción de los mecanismos de routing y NAT

### 1. Mecanismos de Routing
*   **pfSense como Gateway:** pfSense actúa como puerta de enlace central. Al tener una interfaz conectada a cada bridge, conoce las rutas hacia todas las subredes y enruta el tráfico entre ellas basándose en su tabla de ruteo.

### 2. Dónde SÍ existe NAT
*   **Outbound NAT (Salida a Internet):** Se aplica NAT de origen para que las máquinas de USUARIOS, ADMINISTRACIÓN y SERVIDORES A puedan acceder a la red externa, enmascarando sus IP privadas tras la IP de la WAN de pfSense.
*   **Port Forwarding (Inbound NAT):** Se aplica NAT de destino para la red SERVIDORES A, publicando el servicio del servidor `vm-portfw` (IP privada) en el puerto 8000 de la dirección WAN del firewall.

### 3. Dónde NO existe NAT
*   **Red SERVIDORES B (DMZ Ruteada):** NO se aplica NAT. El tráfico fluye mediante routing puro, permitiendo el acceso desde el exterior ya que el direccionamiento es enrutable.
*   **Tráfico interno entre zonas:** El tráfico entre las redes internas (ej. de ADMINISTRACIÓN a SERVIDORES A) utiliza ruteo directo, conservando las IP originales.

---
## Entregable 6: Implementación y Verificación de la Infraestructura

A continuación, se detallan los comandos paso a paso para implementar la red solicitada en el Trabajo Práctico, asumiendo un entorno host Linux base, y las instrucciones para verificar su correcto funcionamiento.

### Paso 1: Preparación del Entorno
Antes de comenzar, validaremos que nuestro usuario tiene los permisos correctos y el host soporta virtualización.

1.  **Validar permisos y estado del host:**
    ```bash
    groups
    virsh uri
    virsh list --all
    virt-host-validate
    ```

### Paso 2: Creación de los Dominios Ethernet (Bridges)
Se requiere la creación de 5 bridges aislados (excepto el de WAN que deberá estar asociado a la NIC física si aplica, pero aquí se muestra la creación lógica base).

1.  **Crear el bridge WAN:**
    ```bash
    nmcli connection add type bridge ifname br-wan con-name perfil-br-wan
    ```
    *Nota:* Si es necesario atar este bridge a la NIC física del laboratorio, se requerirán pasos adicionales para migrar la conectividad.

2.  **Crear el bridge LAN (Usuarios):**
    ```bash
    nmcli connection add type bridge ifname br-usuarios con-name perfil-br-usuarios
    nmcli connection modify perfil-br-usuarios bridge.stp no
    nmcli connection modify perfil-br-usuarios ipv4.method disabled ipv6.method disabled
    nmcli connection modify perfil-br-usuarios connection.autoconnect yes
    ```

3.  **Crear el bridge Administración:**
    ```bash
    nmcli connection add type bridge ifname br-admin con-name perfil-br-admin
    nmcli connection modify perfil-br-admin bridge.stp no
    nmcli connection modify perfil-br-admin ipv4.method disabled ipv6.method disabled
    nmcli connection modify perfil-br-admin connection.autoconnect yes
    ```

4.  **Crear el bridge Servidores A (DMZ Port Forward):**
    ```bash
    nmcli connection add type bridge ifname br-srv-a con-name perfil-br-srv-a
    nmcli connection modify perfil-br-srv-a bridge.stp no
    nmcli connection modify perfil-br-srv-a ipv4.method disabled ipv6.method disabled
    nmcli connection modify perfil-br-srv-a connection.autoconnect yes
    ```

5.  **Crear el bridge Servidores B (DMZ Ruteada):**
    ```bash
    nmcli connection add type bridge ifname br-srv-b con-name perfil-br-srv-b
    nmcli connection modify perfil-br-srv-b bridge.stp no
    nmcli connection modify perfil-br-srv-b ipv4.method disabled ipv6.method disabled
    nmcli connection modify perfil-br-srv-b connection.autoconnect yes
    ```

### Paso 3: Despliegue de la VM pfSense
Ahora crearemos la máquina virtual que actuará como firewall y enrutador, asignándole una interfaz de red (virtio) por cada bridge creado.

1.  **Crear e iniciar la VM pfSense:**
    *(Asegúrate de que la ruta del disco y el ISO correspondan a tu laboratorio)*
    ```bash
    virt-install \
      --name pfsense \
      --ram 2048 \
      --vcpus 2 \
      --cpu host-model \
      --osinfo freebsd14.2 \
      --disk path=/var/lib/libvirt/images/pfsense.qcow2,size=20,format=qcow2,bus=virtio \
      --cdrom /var/lib/libvirt/isos/pfSense.iso \
      --network bridge=br-wan,model=virtio \
      --network bridge=br-usuarios,model=virtio \
      --network bridge=br-admin,model=virtio \
      --network bridge=br-srv-a,model=virtio \
      --network bridge=br-srv-b,model=virtio \
      --graphics spice
    ```

### Paso 4: Conexión de las VMs Linux a la topología
Se asume que las VMs ya están definidas en libvirt. Debemos asegurar que estén conectadas al bridge correcto e iniciarlas.

1.  **Iniciar las máquinas virtuales:**
    ```bash
    virsh start vm-user
    virsh start vm-admin
    virsh start vm-portfw
    virsh start vm-ruteada
    ```
    *(Nota: Si las VMs no estaban asignadas a los bridges correctos al momento de su creación, se deberá usar `virsh attach-interface` o modificar su XML con `virsh edit` para enchufarlas al bridge correspondiente).*

2.  **Configurar Agente QEMU (Ejecutar DENTRO de cada VM Linux):**
    Una vez iniciadas, ingresar a la consola de cada VM (`vm-user`, `vm-admin`, etc.) e instalar el agente para que el host pueda gestionarlas correctamente.
    ```bash
    apt update
    apt install qemu-guest-agent
    systemctl enable --now qemu-guest-agent
    ```

### Paso 5: Configuración de Direccionamiento IP (DENTRO de cada VM Linux)
Debes configurar la IP estática y la puerta de enlace en cada una de las 4 máquinas virtuales Linux de acuerdo con la Tabla de Direccionamiento (Entregable 2). Esto se puede hacer mediante `nmcli` o editando los archivos de red correspondientes dentro del sistema operativo invitado (guest).

*   **vm-user:** IP: 192.168.10.10/24 | GW: 192.168.10.254
*   **vm-admin:** IP: 192.168.30.10/24 | GW: 192.168.30.254
*   **vm-portfw:** IP: 192.168.20.10/24 | GW: 192.168.20.254
*   **vm-ruteada:** IP: 44.0.10.10/24 | GW: 44.0.10.254

---

### Verificación de la Infraestructura

Una vez configurado todo el entorno en el host y las políticas dentro de pfSense, puedes realizar las siguientes comprobaciones para garantizar que la red funciona como se solicita:

#### Verificaciones desde el Host (Capa 2)
1.  **Verificar el estado general de las conexiones activas:**
    ```bash
    nmcli connection show --active
    ```
2.  **Verificar las interfaces y sus IPs en el host:**
    ```bash
    ip -br a
    ```
3.  **Verificar las rutas del host:**
    ```bash
    ip route
    ```
4.  **Verificar los enlaces de los bridges (Qué interfaz virtual está conectada a qué bridge):**
    ```bash
    bridge link
    ```
5.  **Verificar que pfSense tenga sus 5 interfaces conectadas:**
    ```bash
    virsh domiflist pfsense
    ```

#### Verificaciones desde las VMs (Capa 3 / Capa 4)
Para confirmar que pfSense está enrutando y filtrando correctamente, ingresa a la consola de las VMs Linux y ejecuta pruebas de conectividad (ej. `ping` o `curl`):

1.  **Desde `vm-user`:**
    *   `ping 8.8.8.8` (Debe funcionar - NAT de salida).
    *   `ping 192.168.30.10` (Debe fallar - Bloqueo hacia red Administración).
2.  **Desde `vm-admin`:**
    *   `ping 192.168.20.10` (Debe funcionar - Acceso a servidores).
3.  **Desde una máquina externa a la WAN:**
    *   `curl http://<IP-WAN-PFSENSE>:8000` (Debe responder el Servidor A mediante Port Forward).

---

## Entregable 7: Archivo de configuración exportado de pfSense

*   *(Deberás adjuntar el archivo `.xml` descargado desde la interfaz web de pfSense siguiendo la ruta: Diagnostics > Backup & Restore > Download configuration as XML)*.

---

## Entregable 8: Procedimiento de recuperación de la infraestructura

Ante la pérdida total de la máquina virtual del firewall (pfSense), el procedimiento de recuperación se basa en restaurar el archivo de configuración exportado en el Entregable 7 sobre una nueva instalación limpia.

**Pasos para la recuperación:**

1.  **Recrear la Máquina Virtual (Host Linux):**
    Ejecutar el comando de instalación original para crear una nueva VM de pfSense, asegurando que las interfaces de red se conecten a los *bridges* en el mismo orden exacto que la instalación original para mantener la coherencia de los nombres (vtnet0 a vtnet3).

    ```bash
    virt-install \
      --name pfsense \
      --ram 2048 \
      --vcpus 2 \
      --cpu host-model \
      --osinfo freebsd14.2 \
      --disk path=/var/lib/libvirt/images/pfsense.qcow2,size=20,format=qcow2,bus=virtio \
      --cdrom /var/lib/libvirt/isos/pfSense.iso \
      --network bridge=br-wan,model=virtio \
      --network bridge=br-usuarios,model=virtio \
      --network bridge=br-admin,model=virtio \
      --network bridge=br-srv-a,model=virtio \
      --network bridge=br-srv-b,model=virtio \
      --graphics spice
    ```

2.  **Instalación Base:**
    Completar el asistente de instalación básico de pfSense desde la consola gráfica (spice/noVNC) y configurar la IP LAN temporalmente si es necesario para acceder a la GUI.

3.  **Restauración de la Configuración:**
    *   Ingresar a la interfaz web (GUI) de la nueva instalación de pfSense.
    *   Navegar al menú **Diagnostics > Backup & Restore**.
    *   En la sección *Restore Configuration*, seleccionar el archivo `.xml` de respaldo.
    *   Hacer clic en **Restore Configuration**.
    *   El firewall se reiniciará automáticamente y aplicará todas las IPs, reglas de NAT, políticas de firewall y asignación de interfaces previas.