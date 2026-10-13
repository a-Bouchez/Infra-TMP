### Lab: Conceptos de Ansible
**Objetivo:** comprobar que entiendes qué es Ansible, para qué se usa y sus conceptos principales.
En este lab **no se ejecuta ningún comando**. Responde con tus palabras.

--------------------------------------------------------------------------------

#### Pregunta 1 — ¿Qué es Ansible y para qué se usa?
Explica en dos o three frases qué es Ansible.
Escribe **tres tareas** que automatizarías con Ansible en un servidor.

**Respuesta:**
Ansible es una herramienta open source de automatización de IT desarrollada por Red Hat que sirve para configurar servidores, desplegar aplicaciones y orquestar tareas de forma repetible. Permite describir el estado deseado de la infraestructura utilizando archivos de texto legibles en formato YAML y ejecutar comandos en uno o cientos de servidores simultáneamente.

| # | Tarea que automatizaría |
| :--- | :--- |
| **1** | **Instalar y actualizar paquetes de software** (por ejemplo, `httpd`, `git` o Apache). |
| **2** | **Copiar y gestionar archivos o plantillas de configuración**. |
| **3** | **Gestionar e iniciar servicios del sistema** (como iniciar o reiniciar el servicio de un servidor web). |

--------------------------------------------------------------------------------

#### Pregunta 2 — ¿Qué significa que Ansible sea "sin agentes"?
¿Qué hay que instalar en los servidores que Ansible gestiona? ¿Cómo se conecta Ansible a ellos?

**Respuesta:**
Que Ansible sea **"sin agentes" (agentless)** significa que no requiere instalar, actualizar ni mantener ningún programa, servicio en segundo plano (daemon) o agente especial en los servidores gestionados para poder administrarlos.

En los servidores que Ansible gestiona no hay que instalar ningún software propio de Ansible; únicamente se requiere contar con un entorno **Python** funcional y acceso **SSH** configurado con un usuario que tenga permisos administrativos.

Ansible se conecta a los nodos gestionados mediante protocolos de comunicación estándar como **SSH** para sistemas Linux/macOS o **WinRM** para entornos Windows.

--------------------------------------------------------------------------------

#### Pregunta 3 — Inventario y playbook
¿Qué es un **inventario**? ¿Qué es un **playbook**? ¿En qué se diferencian?

**Respuesta:**

| Concepto | ¿Qué es? | ¿Qué contiene? |
| :--- | :--- | :--- |
| **Inventario** | Es el archivo de registro u organización de los servidores objetivo. | Contiene la lista de **direcciones IP o nombres de host** estructurados en grupos (por ejemplo, `[web]` o `[db]`), definiendo **DÓNDE** actuar |
| **Playbook** | Es el archivo de automatización principal que define los flujos de trabajo. | Contiene archivos escritos en **YAML** con una lista ordenada de **tareas, módulos, variables y plantillas**, definiendo **QUÉ** hacer. |

**Diferencia principal:** El inventario especifica los destinos o máquinas sobre las que se operará (**DÓNDE**), mientras que el playbook especifica la serie de instrucciones, módulos y estado final que se aplicará sobre dichas máquinas (**QUÉ**).

--------------------------------------------------------------------------------

#### Pregunta 4 — ¿Qué es la idempotencia?
Ejecutas el **mismo playbook dos veces seguidas** sobre el mismo servidor. ¿Qué pasa la segunda vez? ¿Por qué es útil?

**Respuesta:**
La **idempotencia** es la propiedad de Ansible según la cual ejecutar una automatización una o cien veces sobre el mismo servidor produce exactamente el mismo resultado final, modificando únicamente aquello que sea necesario.

Al ejecutar el **mismo playbook por segunda vez seguidas**:
Ansible comprueba el estado actual del servidor, detecta que la máquina ya se encuentra en el estado deseado definido en el playbook y **no realiza ningún cambio**. En el resumen final (`PLAY RECAP`), todas las tareas se mostrarán como `ok` y el contador de modificaciones marcará `changed=0`.

**Por qué es útil:**
Garantiza que la ejecución repetida sea completamente segura y no rompa configuraciones existentes ni introduzca inconsistencias. Permite mantener la infraestructura en un estado homogéneo y predecible, devolviendo el servidor a su estado correcto si alguien realiza un cambio manual no autorizado.

--------------------------------------------------------------------------------

#### Pregunta 5 — Terraform y Ansible
¿En qué se diferencian Terraform y Ansible? ¿Cómo se pueden usar **juntos**?

**Respuesta:**

| | Terraform | Ansible |
| :--- | :--- | :--- |
| **¿Para qué se usa?** | Aprovisionamiento de Infraestructura como Código (IaC); **crea y destruye componentes de infraestructura** (máquinas virtuales, redes, firewalls) y guarda su estado en un archivo `.tfstate`. | Gestión de configuración e integración de software; **configura el contenido interno del servidor** (paquetes, archivos, servicios) y opera comprobando directamente el sistema sin guardar archivo de estado. |
| **Ejemplo de tarea** | Crear una máquina virtual o instancia en un hipervisor o proveedor en la nube. | Instalar Apache, configurar el archivo de servidor web e iniciar el servicio. |

**¿Cómo se usan juntos?**
Trabajan de manera complementaria en un pipeline o flujo continuo: **Terraform aprovisiona la infraestructura base** (crea la VM o red) → se extrae la dirección IP del resultado → **esa IP se añade al inventario** de Ansible → **Ansible se conecta por SSH y realiza la configuración interna del sistema operativo y aplicaciones**.
