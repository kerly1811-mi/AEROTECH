# ✈️ AeroTech — Sistema Distribuido de Reservas de Vuelos

Aplicación distribuida basada en **Arquitectura Orientada a Servicios (SOA)** para la gestión de reservas de vuelos.
Desarrollada para la **APE 4 – Aplicaciones Distribuidas**, Universidad Técnica de Ambato (FISEI).

---

## 🏗️ Arquitectura

```
┌──────────────────┐   HTTPS / JSON-XML   ┌──────────────────────┐   PostgreSQL / SSL   ┌──────────────────────┐
│  Cliente móvil   │ ───────────────────▶ │  API REST (Flask)    │ ───────────────────▶ │ Supabase (PostgreSQL)│
│    (Flutter)     │ ◀─────────────────── │  Desplegada en Render│ ◀─────────────────── │   Base de datos nube │
└──────────────────┘     Bearer JWT       └──────────────────────┘                      └──────────────────────┘
```

| Capa | Tecnología |
|---|---|
| Cliente | Flutter |
| Servicios web | Python 3 + Flask |
| Base de datos | Supabase (PostgreSQL) |
| Despliegue | Render |
| Seguridad | JWT (PyJWT) + PBKDF2-SHA256 |

---

## 📁 Estructura

```
APE4-PRACTICA/
├── backend/
│   ├── app.py            # Endpoints de la API REST
│   ├── database.py       # Clase Database: conexión y consultas
│   ├── seguridad.py      # Clase Seguridad: hash, JWT, expiración, permisos
│   ├── vuelos.py         # Clase VueloService
│   ├── reservas.py       # Clase ReservaService (concurrencia + XML)
│   └── requirements.txt
└── README.md
```

---

## 🗄️ Modelo de datos

| Tabla | Descripción |
|---|---|
| `roles` | admin, empleado, cliente |
| `permisos` | Acciones permitidas en el sistema |
| `rol_permisos` | Asignación de permisos a cada rol |
| `usuarios` | Usuarios con contraseña encriptada y rol |
| `tokens` | Tokens JWT emitidos, con expiración y estado |
| `vuelos` | Vuelos disponibles (con columna `version`) |
| `reservas` | Reservas de los usuarios (con columna `version`) |

---

## 👥 Roles y permisos

| Permiso | Cliente | Empleado | Admin |
|---|:-:|:-:|:-:|
| `vuelos.ver` | ✅ | ✅ | ✅ |
| `vuelos.crear` | | ✅ | ✅ |
| `vuelos.editar` | | ✅ | ✅ |
| `vuelos.eliminar` | | | ✅ |
| `reservas.crear` | ✅ | ✅ | ✅ |
| `reservas.ver_propias` | ✅ | ✅ | ✅ |
| `reservas.ver_todas` | | ✅ | ✅ |
| `reservas.cancelar_propias` | ✅ | ✅ | ✅ |
| `reservas.cancelar_todas` | | ✅ | ✅ |
| `usuarios.ver` | | | ✅ |
| `usuarios.gestionar` | | | ✅ |

> El registro público siempre crea usuarios con rol **cliente**.

---

## 🔌 Servicios REST

### Usuarios y autenticación
| Método | Endpoint | Auth | Descripción |
|---|---|:-:|---|
| POST | `/api/usuarios/registro` | ❌ | Registro de usuario |
| POST | `/api/auth/login` | ❌ | Login y generación de JWT |
| POST | `/api/auth/logout` | ✅ | Revoca el token |
| GET | `/api/auth/perfil` | ✅ | Datos del usuario autenticado |

### Vuelos
| Método | Endpoint | Permiso |
|---|---|---|
| GET | `/api/vuelos?origen=&destino=&fecha=` | `vuelos.ver` |
| GET | `/api/vuelos/{id}` | `vuelos.ver` |
| POST | `/api/vuelos` | `vuelos.crear` |
| PUT | `/api/vuelos/{id}` | `vuelos.editar` |
| DELETE | `/api/vuelos/{id}` | `vuelos.eliminar` |

### Reservas
| Método | Endpoint | Permiso |
|---|---|---|
| POST | `/api/reservas` | `reservas.crear` |
| GET | `/api/reservas/mis-reservas` | `reservas.ver_propias` |
| GET | `/api/reservas` | `reservas.ver_todas` |
| GET | `/api/reservas/{id}` | Propietario o `reservas.ver_todas` |
| PUT | `/api/reservas/{id}/cancelar` | `reservas.cancelar_propias` / `reservas.cancelar_todas` |
| GET | `/api/reservas/{id}/comprobante` | Propietario o `reservas.ver_todas` — **responde XML** |

---

## 📨 Ejemplo de petición y respuesta

**POST** `/api/reservas`
`Authorization: Bearer <token>`
```json
{ "vuelo_id": 1, "cantidad": 2, "version": 1 }
```

**201 Created**
```json
{
  "mensaje": "Reserva creada",
  "reserva_id": 1,
  "subtotal": 178.0,
  "iva": 26.7,
  "total": 204.7,
  "estado": "confirmada",
  "version": 1
}
```

**GET** `/api/reservas/1/comprobante`
```xml
<factura>
  <numero>F001-000001</numero>
  <fecha>2026-11-08</fecha>
  <cliente>
    <nombre>Juan Pérez</nombre>
    <correo>juan@mail.com</correo>
  </cliente>
  <vuelo>
    <origen>Quito</origen>
    <destino>Guayaquil</destino>
    <fecha>2026-12-10</fecha>
    <hora_salida>09:45</hora_salida>
  </vuelo>
  <detalle>
    <pasajeros>2</pasajeros>
    <precio_unitario>89.00</precio_unitario>
  </detalle>
  <subtotal>178.00</subtotal>
  <iva>26.70</iva>
  <total>204.70</total>
  <estado>confirmada</estado>
</factura>
```

---

## 🔐 Seguridad

Cada petición protegida pasa por estas validaciones:

| # | Validación | Respuesta si falla |
|---|---|---|
| 1 | Header `Authorization: Bearer <token>` | 401 Token no enviado |
| 2 | Firma y expiración del JWT | 401 Token inválido / expirado |
| 3 | Token registrado y activo en la tabla `tokens` | 401 Token revocado o expirado |
| 4 | Usuario activo | 401 Usuario desactivado |
| 5 | Permiso del rol | 403 Sin permiso |

- Contraseñas almacenadas con **PBKDF2 + SHA256** (con salt).
- Tokens **JWT (HS256)** con expiración configurable.
- El logout **revoca** el token en la base de datos.
- Acceso directo a la base desde clientes de Supabase bloqueado mediante **RLS**; el único acceso a los datos es la API.

---

## ⚡ Control de concurrencia (optimista)

`vuelos` y `reservas` tienen una columna `version`. El cliente envía la versión que consultó, y el servidor solo actualiza si esa versión no ha cambiado:

```sql
UPDATE vuelos
SET asientos_disponibles = asientos_disponibles - %s,
    version = version + 1
WHERE id = %s AND version = %s AND asientos_disponibles >= %s;
```

Si otro usuario modificó el registro antes, no se actualiza ninguna fila y la API responde **409 Conflicto de concurrencia**. La reserva y el descuento de asientos se ejecutan en una **única transacción** (commit/rollback), lo que evita la **sobreventa**.

---

## 🚀 Ejecución local

```powershell
cd backend
pip install -r requirements.txt
py app.py
```

Crear `backend/.env` (no se sube al repositorio):
```env
DATABASE_URL=postgresql://postgres.<ref>:<password>@aws-1-us-west-2.pooler.supabase.com:6543/postgres
JWT_SECRET=<clave_secreta>
JWT_EXP_MINUTOS=30
DEMORA_SEGUNDOS=0
```

| Variable | Descripción |
|---|---|
| `DATABASE_URL` | Cadena de conexión de Supabase (Transaction pooler) |
| `JWT_SECRET` | Clave para firmar los tokens |
| `JWT_EXP_MINUTOS` | Minutos de validez del token |
| `DEMORA_SEGUNDOS` | Demora simulada para pruebas de concurrencia (0 en producción) |

Verificar: `http://127.0.0.1:5000/api/health`

---

## ☁️ Despliegue en Render

| Campo | Valor |
|---|---|
| Root Directory | `backend` |
| Build Command | `pip install -r requirements.txt` |
| Start Command | `gunicorn app:app` |
| Región | Oregon (US West) |

**URL de la API:** `https://aerotech-api.onrender.com`

> En el plan gratuito, el servicio se suspende por inactividad; la primera petición puede tardar ~50 s.

---

## 👩‍💻 Equipo

| Integrante | Responsabilidad |
|---|---|
| Kerly Chicaiza | Backend Flask, base de datos Supabase, seguridad y despliegue |
| _Compañera_ | Cliente Flutter, pruebas y documentación |

**Asignatura:** Aplicaciones Distribuidas · **Carrera:** Software · **UTA – FISEI** · 2026