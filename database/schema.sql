DROP VIEW IF EXISTS vuelos_detalle;
DROP TABLE IF EXISTS reserva_asientos, tokens, reservas, vuelos, aeropuertos, paises, rol_permisos, permisos, usuarios, roles CASCADE;

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

CREATE TABLE paises (
    id      SERIAL PRIMARY KEY,
    codigo  CHAR(2)     NOT NULL UNIQUE,
    nombre  VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE aeropuertos (
    id      SERIAL PRIMARY KEY,
    codigo  CHAR(3)      NOT NULL UNIQUE,
    ciudad  VARCHAR(80)  NOT NULL,
    nombre  VARCHAR(120) NOT NULL,
    pais_id INT          NOT NULL REFERENCES paises(id),
    latitud  NUMERIC(8,4) NOT NULL,
    longitud NUMERIC(8,4) NOT NULL
);

CREATE INDEX idx_aeropuertos_pais ON aeropuertos(pais_id);

CREATE TABLE vuelos (
    id                   SERIAL PRIMARY KEY,
    origen_id            INT           NOT NULL REFERENCES aeropuertos(id),
    destino_id           INT           NOT NULL REFERENCES aeropuertos(id),
    fecha                DATE          NOT NULL,
    hora_salida          TIME          NOT NULL,
    hora_llegada         TIME          NOT NULL,
    precio               NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    filas                INT           NOT NULL DEFAULT 20 CHECK (filas BETWEEN 1 AND 40),
    asientos_disponibles INT           NOT NULL CHECK (asientos_disponibles >= 0),
    filas_ejecutiva      INT           NOT NULL,
    precio_ejecutiva     NUMERIC(10,2) NOT NULL CHECK (precio_ejecutiva > 0),
    version              INT           NOT NULL DEFAULT 1,
    CONSTRAINT vuelos_ruta_distinta CHECK (origen_id <> destino_id),
    CONSTRAINT vuelos_filas_ejecutiva_valida CHECK (filas_ejecutiva BETWEEN 0 AND filas)
);

CREATE TABLE reservas (
    id                SERIAL PRIMARY KEY,
    usuario_id        INT NOT NULL REFERENCES usuarios(id),
    vuelo_id          INT NOT NULL REFERENCES vuelos(id),
    cantidad_asientos INT NOT NULL CHECK (cantidad_asientos > 0),
    total             NUMERIC(10,2) NOT NULL,
    estado            VARCHAR(20) NOT NULL DEFAULT 'confirmada' CHECK (estado IN ('confirmada','cancelada')),
    fecha_reserva     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    viaje_id          INT NOT NULL,
    version           INT NOT NULL DEFAULT 1
);

CREATE TABLE reserva_asientos (
    id          SERIAL PRIMARY KEY,
    reserva_id  INT           NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
    vuelo_id    INT           NOT NULL REFERENCES vuelos(id),
    asiento     VARCHAR(4)    NOT NULL,
    tipo        VARCHAR(10)   NOT NULL CHECK (tipo IN ('ventana','medio','pasillo')),
    clase       VARCHAR(10)   NOT NULL CHECK (clase IN ('economica','ejecutiva')),
    precio      NUMERIC(10,2) NOT NULL,
    equipaje_extra  INT           NOT NULL DEFAULT 0 CHECK (equipaje_extra BETWEEN 0 AND 2),
    precio_equipaje NUMERIC(10,2) NOT NULL DEFAULT 0,
    estado      VARCHAR(10)   NOT NULL DEFAULT 'ocupado' CHECK (estado IN ('ocupado','liberado'))
);

CREATE INDEX idx_usuarios_rol     ON usuarios(rol_id);
CREATE INDEX idx_tokens_usuario   ON tokens(usuario_id);
CREATE INDEX idx_vuelos_busqueda  ON vuelos(origen_id, destino_id, fecha);
CREATE INDEX idx_reservas_usuario ON reservas(usuario_id);
CREATE INDEX idx_reservas_vuelo   ON reservas(vuelo_id);
CREATE INDEX idx_reservas_viaje   ON reservas(viaje_id);
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

INSERT INTO paises (codigo, nombre) VALUES
('EC', 'Ecuador'),
('CO', 'Colombia'),
('PE', 'Perú'),
('PA', 'Panamá'),
('US', 'Estados Unidos'),
('CA', 'Canadá'),
('MX', 'México'),
('ES', 'España'),
('BR', 'Brasil'),
('AR', 'Argentina'),
('CL', 'Chile');

INSERT INTO aeropuertos (codigo, ciudad, nombre, pais_id, latitud, longitud)
SELECT a.codigo, a.ciudad, a.nombre, p.id, a.latitud, a.longitud
FROM (VALUES
    ('UIO', 'Quito',           'Aeropuerto Internacional Mariscal Sucre',          'EC', -0.1292, -78.3575),
    ('GYE', 'Guayaquil',       'Aeropuerto Internacional José Joaquín de Olmedo',  'EC', -2.1574, -79.8836),
    ('CUE', 'Cuenca',          'Aeropuerto Mariscal Lamar',                        'EC', -2.8895, -78.9844),
    ('MEC', 'Manta',           'Aeropuerto Internacional Eloy Alfaro',             'EC', -0.9461, -80.6788),
    ('LOH', 'Loja',            'Aeropuerto Camilo Ponce Enríquez',                 'EC', -3.9959, -79.3719),
    ('GPS', 'Galápagos',       'Aeropuerto Seymour (Baltra)',                      'EC', -0.4538, -90.2659),
    ('BOG', 'Bogotá',          'Aeropuerto Internacional El Dorado',               'CO', 4.7016, -74.1469),
    ('LIM', 'Lima',            'Aeropuerto Internacional Jorge Chávez',            'PE', -12.0219, -77.1143),
    ('PTY', 'Ciudad de Panamá','Aeropuerto Internacional de Tocumen',              'PA', 9.0714, -79.3835),
    ('MIA', 'Miami',           'Aeropuerto Internacional de Miami',                'US', 25.7959, -80.287),
    ('JFK', 'Nueva York',      'Aeropuerto Internacional John F. Kennedy',         'US', 40.6413, -73.7781),
    ('YYZ', 'Toronto',         'Aeropuerto Internacional Toronto Pearson',         'CA', 43.6777, -79.6248),
    ('MEX', 'Ciudad de México','Aeropuerto Internacional Benito Juárez',           'MX', 19.4363, -99.0721),
    ('MAD', 'Madrid',          'Aeropuerto Adolfo Suárez Madrid-Barajas',          'ES', 40.4983, -3.5676),
    ('GRU', 'São Paulo',       'Aeropuerto Internacional de Guarulhos',            'BR', -23.4356, -46.4731),
    ('EZE', 'Buenos Aires',    'Aeropuerto Internacional Ministro Pistarini',      'AR', -34.8222, -58.5358),
    ('SCL', 'Santiago',        'Aeropuerto Internacional Arturo Merino Benítez',   'CL', -33.393, -70.7858)
) AS a(codigo, ciudad, nombre, pais, latitud, longitud)
JOIN paises p ON p.codigo = a.pais;

-- Rutas de ejemplo: se generan desde el 16/11/2026 hasta el 15/12/2026.
-- "cada" = cada cuántos días sale el vuelo (1 = diario, 2 = día por medio).
INSERT INTO vuelos (origen_id, destino_id, fecha, hora_salida, hora_llegada, precio, filas, asientos_disponibles, filas_ejecutiva, precio_ejecutiva)
SELECT ao.id, ad.id, d::date, r.salida::time, r.llegada::time, r.precio, r.filas, r.filas * 6,
       CASE WHEN r.filas >= 25 THEN 4 WHEN r.filas >= 10 THEN 3 ELSE 1 END, ROUND(r.precio * 2.5, 2)
FROM (VALUES
    -- Nacionales
    ('UIO', 'GYE', '09:45', '10:40',  89.00, 20, 1),
    ('UIO', 'GYE', '18:30', '19:25',  95.00, 20, 1),
    ('GYE', 'UIO', '07:30', '08:25',  89.00, 20, 1),
    ('GYE', 'UIO', '20:00', '20:55',  95.00, 20, 1),
    ('UIO', 'CUE', '12:20', '13:15',  99.00, 20, 1),
    ('CUE', 'UIO', '18:00', '18:55',  99.00, 20, 1),
    ('UIO', 'MEC', '14:50', '15:40',  79.00, 20, 1),
    ('MEC', 'UIO', '16:10', '17:00',  79.00, 20, 1),
    ('UIO', 'LOH', '11:00', '12:05', 109.00, 20, 2),
    ('LOH', 'UIO', '14:00', '15:05', 109.00, 20, 2),
    ('UIO', 'GPS', '06:00', '08:30', 320.00, 25, 2),
    ('GPS', 'UIO', '10:30', '13:00', 320.00, 25, 2),
    ('GYE', 'GPS', '10:00', '11:45', 280.00, 25, 2),
    ('GPS', 'GYE', '13:00', '14:45', 280.00, 25, 2),
    -- Internacionales
    ('UIO', 'BOG', '08:00', '09:25', 189.00, 25, 1),
    ('BOG', 'UIO', '10:30', '11:55', 189.00, 25, 1),
    ('UIO', 'LIM', '13:00', '15:10', 215.00, 25, 1),
    ('LIM', 'UIO', '16:00', '18:10', 215.00, 25, 1),
    ('UIO', 'PTY', '06:15', '08:35', 259.00, 28, 1),
    ('PTY', 'UIO', '09:30', '11:50', 259.00, 28, 1),
    ('UIO', 'MIA', '07:00', '11:30', 389.00, 30, 1),
    ('MIA', 'UIO', '12:30', '17:00', 389.00, 30, 1),
    ('UIO', 'JFK', '09:15', '15:00', 459.00, 30, 2),
    ('JFK', 'UIO', '17:30', '23:00', 459.00, 30, 2),
    ('UIO', 'YYZ', '08:30', '15:30', 599.00, 30, 2),
    ('YYZ', 'UIO', '09:00', '17:00', 599.00, 30, 2),
    ('UIO', 'MEX', '09:00', '13:20', 399.00, 28, 2),
    ('MEX', 'UIO', '15:00', '22:30', 399.00, 28, 2),
    ('UIO', 'MAD', '22:00', '15:30', 849.00, 35, 2),
    ('MAD', 'UIO', '12:00', '16:30', 849.00, 35, 2)
) AS r(origen, destino, salida, llegada, precio, filas, cada)
JOIN aeropuertos ao ON ao.codigo = r.origen
JOIN aeropuertos ad ON ad.codigo = r.destino
CROSS JOIN generate_series(date '2026-11-16', date '2026-12-15', interval '1 day') AS d
WHERE (d::date - date '2026-11-16') % r.cada = 0;

-- Vuelo pequeño (2 filas, 12 asientos) para probar concurrencia y vuelo agotado.
INSERT INTO vuelos (origen_id, destino_id, fecha, hora_salida, hora_llegada, precio, filas, asientos_disponibles, filas_ejecutiva, precio_ejecutiva)
SELECT ao.id, ad.id, DATE '2026-12-15', TIME '20:00', TIME '20:55', 95.00, 2, 12, 1, 237.50
FROM aeropuertos ao, aeropuertos ad
WHERE ao.codigo = 'UIO' AND ad.codigo = 'GYE';

CREATE VIEW vuelos_detalle WITH (security_invoker = true) AS
SELECT v.*,
       ao.ciudad AS origen,  ao.codigo AS origen_codigo,  po.nombre AS origen_pais,
       ao.latitud AS origen_latitud,  ao.longitud AS origen_longitud,
       ad.ciudad AS destino, ad.codigo AS destino_codigo, pd.nombre AS destino_pais,
       ad.latitud AS destino_latitud, ad.longitud AS destino_longitud,
       (SELECT COUNT(*)::int FROM reserva_asientos ra
         WHERE ra.vuelo_id = v.id AND ra.estado = 'ocupado' AND ra.clase = 'ejecutiva') AS ocupados_ejecutiva
FROM vuelos v
JOIN aeropuertos ao ON ao.id = v.origen_id
JOIN paises po      ON po.id = ao.pais_id
JOIN aeropuertos ad ON ad.id = v.destino_id
JOIN paises pd      ON pd.id = ad.pais_id;

ALTER TABLE roles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE paises           ENABLE ROW LEVEL SECURITY;
ALTER TABLE aeropuertos      ENABLE ROW LEVEL SECURITY;
ALTER TABLE permisos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE rol_permisos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios         ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens           ENABLE ROW LEVEL SECURITY;
ALTER TABLE vuelos           ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservas         ENABLE ROW LEVEL SECURITY;
ALTER TABLE reserva_asientos ENABLE ROW LEVEL SECURITY;
