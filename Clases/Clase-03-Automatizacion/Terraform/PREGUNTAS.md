# Lab: Leer código Terraform

**Objetivo:** leer código Terraform e identificar qué crearía, con qué nombres y dónde.

> En este lab **no se ejecuta ningún comando**. Solo se lee el código.

## Instrucciones

1. Abre la carpeta `codigo/`. Contiene 4 archivos:
   - `providers.tf`
   - `variables.tf`
   - `main.tf`
   - `outputs.tf`
2. Lee los 4 archivos con atención. Fíjate sobre todo en los bloques que empiezan por `resource`, `data`, `variable` y `locals`.
3. Responde las 5 preguntas en este mismo documento. Usa los valores por defecto de las variables.

**Recuerda cómo se lee un bloque `resource`:**

```hcl
resource "TIPO" "NOMBRE_EN_TERRAFORM" {
  argumento = valor
}
```

---

## Pregunta 1 — ¿Qué recursos se crearían?

¿Cuántos recursos de AWS crearía este código? Escribe el **tipo** de cada uno y explica en una frase qué es.

¿El bloque `data "aws_ami"` crea algo en AWS? ¿Por qué?

**Respuesta:**

Este código crearía 3 recursos en AWS:

| # | Tipo de recurso | ¿Qué es? |
|---|-----------------|----------|
| 1 | `aws_key_pair` | Es un par de claves utilizado para configurar el acceso SSH a la instancia. |
| 2 | `aws_security_group` | Es un firewall a nivel de instancia que controla los puertos y el tráfico de red de entrada y salida. |
| 3 | `aws_instance` | Es una máquina virtual de Amazon EC2 que actúa como servidor. |

`data "aws_ami"`: No crea ningún recurso en AWS. Los bloques de tipo `data` solo se utilizan para consultar y extraer información sobre un recurso que ya existe (en este caso, busca el ID de la imagen más reciente de Amazon Linux 2023).

---

## Pregunta 2 — ¿Qué nombre recibe cada recurso?

Cada recurso tiene **dos nombres**:
- el nombre que usa **Terraform** dentro del código (por ejemplo `aws_xxx.yyy`);
- el nombre que se verá en la **consola de AWS**.

Completa la tabla. Pista: busca el bloque `locals` y las variables `proyecto` y `ambiente`.

**Respuesta:**

Basado en que las variables por defecto son `proyecto = "tienda"` y `ambiente = "lab"`, la variable `local.nombre` se calcula como `"tienda-lab"`:

| Recurso en Terraform | Nombre en AWS |
|----------------------|---------------|
| `aws_key_pair.acceso` | `tienda-lab-key` |
| `aws_security_group.web` | `tienda-lab-sg` |
| `aws_instance.servidor` | `tienda-lab-web` |

---

## Pregunta 3 — ¿En qué región y zona se crearía?

¿En qué **región** de AWS se crearían los recursos? ¿En qué **zona de disponibilidad** exacta se crearía la instancia?

Indica el archivo y la línea de donde sale cada dato.

**Respuesta:**

- **Región:** `us-west-2`. Este dato se define en el archivo `variables.tf` mediante el valor por defecto de la variable `aws_region`. El bloque `provider "aws"` en el archivo `providers.tf` hace uso de esta variable.
- **Zona de disponibilidad:** `us-west-2b`. Este dato se forma en el archivo `main.tf`, en la asignación `availability_zone = "${var.aws_region}${var.zona}"`. Se obtiene concatenando el valor por defecto de la región (`us-west-2`) y el valor por defecto de la variable zona (`b`) definidas en `variables.tf`.


---

## Pregunta 4 — ¿Cómo cambio el nombre de un recurso?

a) Quiero que la instancia se llame `tienda-lab-backend` en la consola de AWS. ¿Qué línea cambio?

**Respuesta:**

a) Debes cambiar el valor de la etiqueta `Name` dentro del recurso `aws_instance "servidor"` en el archivo `main.tf`. 
La línea actual dice `Name = "${local.nombre}-web"`. Para lograr el cambio, deberías modificarla por `Name = "${local.nombre}-backend"`.

---

## Pregunta 5 — ¿Qué puertos quedan abiertos?

¿Qué puertos permite el Security Group? ¿Para qué sirve cada uno?

**Respuesta:**

El recurso `aws_security_group "web"` permite las siguientes configuraciones de red:
*   **Puerto 22 (TCP):** Está abierto en la regla de entrada (ingress) desde cualquier IP (`0.0.0.0/0`) y sirve para habilitar el acceso SSH al servidor.
*   **Puerto 80 (TCP):** Está abierto en la regla de entrada (ingress) desde cualquier IP (`0.0.0.0/0`) y sirve para permitir el tráfico HTTP.
*   **Tráfico de salida:** La regla de salida (egress) permite tráfico hacia cualquier destino (`0.0.0.0/0`) en el puerto `0` usando el protocolo `-1`, lo que significa que el servidor puede iniciar conexiones de salida usando todos los puertos y protocolos.