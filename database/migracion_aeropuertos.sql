-- Migración: catálogo de países y aeropuertos; los vuelos pasan a referenciar aeropuertos.
-- ATENCIÓN: borra TODAS las reservas y vuelos actuales y carga vuelos de ejemplo nuevos.
-- No toca usuarios, roles, permisos ni tokens.

BEGIN;

DROP VIEW IF EXISTS vuelos_detalle;
TRUNCATE reservas, vuelos RESTART IDENTITY CASCADE;

DROP TABLE IF EXISTS aeropuertos, paises CASCADE;

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
    pais_id INT          NOT NULL REFERENCES paises(id)
);

CREATE INDEX idx_aeropuertos_pais ON aeropuertos(pais_id);

DROP INDEX IF EXISTS idx_vuelos_busqueda;

ALTER TABLE vuelos
    DROP COLUMN origen,
    DROP COLUMN destino,
    ADD COLUMN origen_id  INT NOT NULL REFERENCES aeropuertos(id),
    ADD COLUMN destino_id INT NOT NULL REFERENCES aeropuertos(id),
    ADD CONSTRAINT vuelos_ruta_distinta CHECK (origen_id <> destino_id);

CREATE INDEX idx_vuelos_busqueda ON vuelos(origen_id, destino_id, fecha);

CREATE VIEW vuelos_detalle WITH (security_invoker = true) AS
SELECT v.*,
       ao.ciudad AS origen,  ao.codigo AS origen_codigo,  po.nombre AS origen_pais,
       ad.ciudad AS destino, ad.codigo AS destino_codigo, pd.nombre AS destino_pais
FROM vuelos v
JOIN aeropuertos ao ON ao.id = v.origen_id
JOIN paises po      ON po.id = ao.pais_id
JOIN aeropuertos ad ON ad.id = v.destino_id
JOIN paises pd      ON pd.id = ad.pais_id;

ALTER TABLE paises      ENABLE ROW LEVEL SECURITY;
ALTER TABLE aeropuertos ENABLE ROW LEVEL SECURITY;

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

INSERT INTO aeropuertos (codigo, ciudad, nombre, pais_id)
SELECT a.codigo, a.ciudad, a.nombre, p.id
FROM (VALUES
    ('UIO', 'Quito',           'Aeropuerto Internacional Mariscal Sucre',          'EC'),
    ('GYE', 'Guayaquil',       'Aeropuerto Internacional José Joaquín de Olmedo',  'EC'),
    ('CUE', 'Cuenca',          'Aeropuerto Mariscal Lamar',                        'EC'),
    ('MEC', 'Manta',           'Aeropuerto Internacional Eloy Alfaro',             'EC'),
    ('LOH', 'Loja',            'Aeropuerto Camilo Ponce Enríquez',                 'EC'),
    ('GPS', 'Galápagos',       'Aeropuerto Seymour (Baltra)',                      'EC'),
    ('BOG', 'Bogotá',          'Aeropuerto Internacional El Dorado',               'CO'),
    ('LIM', 'Lima',            'Aeropuerto Internacional Jorge Chávez',            'PE'),
    ('PTY', 'Ciudad de Panamá','Aeropuerto Internacional de Tocumen',              'PA'),
    ('MIA', 'Miami',           'Aeropuerto Internacional de Miami',                'US'),
    ('JFK', 'Nueva York',      'Aeropuerto Internacional John F. Kennedy',         'US'),
    ('YYZ', 'Toronto',         'Aeropuerto Internacional Toronto Pearson',         'CA'),
    ('MEX', 'Ciudad de México','Aeropuerto Internacional Benito Juárez',           'MX'),
    ('MAD', 'Madrid',          'Aeropuerto Adolfo Suárez Madrid-Barajas',          'ES'),
    ('GRU', 'São Paulo',       'Aeropuerto Internacional de Guarulhos',            'BR'),
    ('EZE', 'Buenos Aires',    'Aeropuerto Internacional Ministro Pistarini',      'AR'),
    ('SCL', 'Santiago',        'Aeropuerto Internacional Arturo Merino Benítez',   'CL')
) AS a(codigo, ciudad, nombre, pais)
JOIN paises p ON p.codigo = a.pais;

-- Rutas de ejemplo: se generan desde el 16/11/2026 hasta el 15/12/2026.
-- "cada" = cada cuántos días sale el vuelo (1 = diario, 2 = día por medio).
INSERT INTO vuelos (origen_id, destino_id, fecha, hora_salida, hora_llegada, precio, filas, asientos_disponibles)
SELECT ao.id, ad.id, d::date, r.salida::time, r.llegada::time, r.precio, r.filas, r.filas * 6
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
INSERT INTO vuelos (origen_id, destino_id, fecha, hora_salida, hora_llegada, precio, filas, asientos_disponibles)
SELECT ao.id, ad.id, DATE '2026-12-15', TIME '20:00', TIME '20:55', 95.00, 2, 12
FROM aeropuertos ao, aeropuertos ad
WHERE ao.codigo = 'UIO' AND ad.codigo = 'GYE';

COMMIT;

SELECT p.nombre AS pais, COUNT(*) AS aeropuertos FROM aeropuertos a JOIN paises p ON p.id = a.pais_id GROUP BY p.nombre ORDER BY 1;
SELECT COUNT(*) AS vuelos FROM vuelos;
