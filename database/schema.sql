DROP TABLE IF EXISTS reserva_asientos, tokens, reservas, vuelos, rol_permisos, permisos, usuarios, roles CASCADE;

CREATE TABLE roles (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(30)  NOT NULL UNIQUE,
    descripcion VARCHAR(150)
);

CREATE TABLE permisos (
    id          SERIAL PRIMARY KEY,
    codigo      VARCHAR(50)  NOT NULL UNIQUE,
    descripcion VARCHAR(150)
);

CREATE TABLE rol_permisos (
    rol_id     INT NOT NULL REFERENCES roles(id)    ON DELETE CASCADE,
    permiso_id INT NOT NULL REFERENCES permisos(id) ON DELETE CASCADE,
    PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE usuarios (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    correo          VARCHAR(150) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    rol_id          INT          NOT NULL REFERENCES roles(id),
    activo          BOOLEAN      NOT NULL DEFAULT TRUE,
    fecha_registro  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE tokens (
    id              SERIAL PRIMARY KEY,
    usuario_id      INT          NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token           TEXT         NOT NULL UNIQUE,
    fecha_creacion  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expiracion      TIMESTAMPTZ  NOT NULL,
    estado          VARCHAR(20)  NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo','revocado'))
);

CREATE TABLE vuelos (
    id                   SERIAL PRIMARY KEY,
    origen               VARCHAR(80)   NOT NULL,
    destino              VARCHAR(80)   NOT NULL,
    fecha                DATE          NOT NULL,
    hora_salida          TIME          NOT NULL,
    hora_llegada         TIME          NOT NULL,
    precio               NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    filas                INT           NOT NULL DEFAULT 20 CHECK (filas BETWEEN 1 AND 40),
    asientos_disponibles INT           NOT NULL CHECK (asientos_disponibles >= 0),
    version              INT           NOT NULL DEFAULT 1
);

CREATE TABLE reservas (
    id                SERIAL PRIMARY KEY,
    usuario_id        INT NOT NULL REFERENCES usuarios(id),
    vuelo_id          INT NOT NULL REFERENCES vuelos(id),
    cantidad_asientos INT NOT NULL CHECK (cantidad_asientos > 0),
    total             NUMERIC(10,2) NOT NULL,
    estado            VARCHAR(20) NOT NULL DEFAULT 'confirmada' CHECK (estado IN ('confirmada','cancelada')),
    fecha_reserva     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version           INT NOT NULL DEFAULT 1
);

CREATE TABLE reserva_asientos (
    id          SERIAL PRIMARY KEY,
    reserva_id  INT           NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
    vuelo_id    INT           NOT NULL REFERENCES vuelos(id),
    asiento     VARCHAR(4)    NOT NULL,
    tipo        VARCHAR(10)   NOT NULL CHECK (tipo IN ('ventana','medio','pasillo')),
    precio      NUMERIC(10,2) NOT NULL,
    estado      VARCHAR(10)   NOT NULL DEFAULT 'ocupado' CHECK (estado IN ('ocupado','liberado'))
);

CREATE INDEX idx_usuarios_rol     ON usuarios(rol_id);
CREATE INDEX idx_tokens_usuario   ON tokens(usuario_id);
CREATE INDEX idx_vuelos_busqueda  ON vuelos(origen, destino, fecha);
CREATE INDEX idx_reservas_usuario ON reservas(usuario_id);
CREATE INDEX idx_reservas_vuelo   ON reservas(vuelo_id);
CREATE INDEX idx_reserva_asientos_reserva ON reserva_asientos(reserva_id);
CREATE UNIQUE INDEX uq_asiento_ocupado ON reserva_asientos(vuelo_id, asiento) WHERE estado = 'ocupado';

INSERT INTO roles (nombre, descripcion) VALUES
('admin',   'Administrador: gestiona vuelos, reservas y usuarios'),
('cliente', 'Usuario general: busca vuelos, elige asientos y gestiona sus reservas');

INSERT INTO permisos (codigo, descripcion) VALUES
('vuelos.ver',                'Buscar y consultar vuelos'),
('vuelos.crear',              'Registrar vuelos nuevos'),
('vuelos.editar',             'Modificar datos de un vuelo'),
('vuelos.eliminar',           'Eliminar vuelos sin reservas'),
('reservas.crear',            'Reservar asientos de un vuelo'),
('reservas.ver_propias',      'Ver sus propias reservas'),
('reservas.ver_todas',        'Ver las reservas de todos los usuarios'),
('reservas.cancelar_propias', 'Cancelar sus propias reservas'),
('reservas.cancelar_todas',   'Cancelar cualquier reserva'),
('usuarios.ver',              'Listar usuarios'),
('usuarios.gestionar',        'Activar y desactivar usuarios');

INSERT INTO rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r JOIN permisos p ON p.codigo IN (
    'vuelos.ver','vuelos.crear','vuelos.editar','vuelos.eliminar',
    'reservas.ver_todas','reservas.cancelar_todas',
    'usuarios.ver','usuarios.gestionar')
WHERE r.nombre = 'admin';

INSERT INTO rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r JOIN permisos p ON p.codigo IN (
    'vuelos.ver','reservas.crear','reservas.ver_propias','reservas.cancelar_propias')
WHERE r.nombre = 'cliente';

INSERT INTO vuelos (origen, destino, fecha, hora_salida, hora_llegada, precio, filas, asientos_disponibles) VALUES
('Quito','Guayaquil','2026-12-10','09:45','10:40', 89.00, 20, 120),
('Quito','Cuenca',   '2026-12-10','12:20','13:15', 99.00, 20, 120),
('Quito','Manta',    '2026-12-10','14:50','15:40', 79.00, 20, 120),
('Guayaquil','Quito','2026-12-11','07:30','08:25', 89.00, 20, 120),
('Cuenca','Quito',   '2026-12-11','18:00','18:55', 99.00, 20, 120),
('Quito','Galápagos','2026-12-12','06:00','08:30',320.00, 25, 150),
('Guayaquil','Galápagos','2026-12-12','10:00','11:45',280.00, 25, 150),
('Manta','Quito',    '2026-12-13','16:10','17:00', 79.00, 20, 120),
('Quito','Loja',     '2026-12-14','11:00','12:05',109.00, 20, 120),
('Quito','Guayaquil','2026-12-15','20:00','20:55', 95.00,  2,  12);

ALTER TABLE roles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE permisos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE rol_permisos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios         ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens           ENABLE ROW LEVEL SECURITY;
ALTER TABLE vuelos           ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservas         ENABLE ROW LEVEL SECURITY;
ALTER TABLE reserva_asientos ENABLE ROW LEVEL SECURITY;
