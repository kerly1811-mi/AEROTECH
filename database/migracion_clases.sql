-- Migración: clases (Económica/Ejecutiva), equipaje adicional, viajes de ida y vuelta con un solo
-- comprobante y coordenadas de los aeropuertos (para el mapa animado de la app).
-- Requiere haber ejecutado antes migracion_aeropuertos.sql. No borra datos.
--
-- * Las primeras `filas_ejecutiva` filas de cada vuelo son clase Ejecutiva; el resto, Económica.
--   `precio` es la tarifa Económica y `precio_ejecutiva` la Ejecutiva (por asiento).
-- * Cada asiento reservado guarda su clase y el equipaje adicional que compró el pasajero.
-- * `reservas.viaje_id` agrupa las reservas de un mismo viaje (ida y vuelta comparten comprobante).

BEGIN;

DROP VIEW IF EXISTS vuelos_detalle;

-- Coordenadas de los aeropuertos
ALTER TABLE aeropuertos
    ADD COLUMN latitud  NUMERIC(8,4),
    ADD COLUMN longitud NUMERIC(8,4);

UPDATE aeropuertos a
SET latitud = c.lat, longitud = c.lon
FROM (VALUES
    ('UIO', -0.1292, -78.3575),
    ('GYE', -2.1574, -79.8836),
    ('CUE', -2.8895, -78.9844),
    ('MEC', -0.9461, -80.6788),
    ('LOH', -3.9959, -79.3719),
    ('GPS', -0.4538, -90.2659),
    ('BOG', 4.7016, -74.1469),
    ('LIM', -12.0219, -77.1143),
    ('PTY', 9.0714, -79.3835),
    ('MIA', 25.7959, -80.287),
    ('JFK', 40.6413, -73.7781),
    ('YYZ', 43.6777, -79.6248),
    ('MEX', 19.4363, -99.0721),
    ('MAD', 40.4983, -3.5676),
    ('GRU', -23.4356, -46.4731),
    ('EZE', -34.8222, -58.5358),
    ('SCL', -33.393, -70.7858)
) AS c(codigo, lat, lon)
WHERE a.codigo = c.codigo;

ALTER TABLE aeropuertos
    ALTER COLUMN latitud  SET NOT NULL,
    ALTER COLUMN longitud SET NOT NULL;

-- Clases en los vuelos
ALTER TABLE vuelos
    ADD COLUMN filas_ejecutiva  INT NOT NULL DEFAULT 0,
    ADD COLUMN precio_ejecutiva NUMERIC(10,2);

UPDATE vuelos
SET filas_ejecutiva  = CASE WHEN filas >= 25 THEN 4 WHEN filas >= 10 THEN 3 ELSE 1 END,
    precio_ejecutiva = ROUND(precio * 2.5, 2);

ALTER TABLE vuelos
    ALTER COLUMN filas_ejecutiva  DROP DEFAULT,
    ALTER COLUMN precio_ejecutiva SET NOT NULL,
    ADD CONSTRAINT vuelos_filas_ejecutiva_valida  CHECK (filas_ejecutiva BETWEEN 0 AND filas),
    ADD CONSTRAINT vuelos_precio_ejecutiva_valido CHECK (precio_ejecutiva > 0);

-- Clase y equipaje por asiento reservado
ALTER TABLE reserva_asientos
    ADD COLUMN clase            VARCHAR(10)   NOT NULL DEFAULT 'economica'
        CHECK (clase IN ('economica', 'ejecutiva')),
    ADD COLUMN equipaje_extra   INT           NOT NULL DEFAULT 0
        CHECK (equipaje_extra BETWEEN 0 AND 2),
    ADD COLUMN precio_equipaje  NUMERIC(10,2) NOT NULL DEFAULT 0;

ALTER TABLE reserva_asientos ALTER COLUMN clase DROP DEFAULT;

UPDATE reserva_asientos ra
SET clase = 'ejecutiva'
FROM vuelos v
WHERE v.id = ra.vuelo_id
  AND regexp_replace(ra.asiento, '[A-Z]$', '')::int <= v.filas_ejecutiva;

-- Viajes: reservas que comparten comprobante
ALTER TABLE reservas ADD COLUMN viaje_id INT;
UPDATE reservas SET viaje_id = id;
ALTER TABLE reservas ALTER COLUMN viaje_id SET NOT NULL;
CREATE INDEX idx_reservas_viaje ON reservas(viaje_id);

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

COMMIT;

SELECT COUNT(*) AS aeropuertos_con_coordenadas FROM aeropuertos WHERE latitud IS NOT NULL;
SELECT COUNT(*) AS vuelos, MIN(filas_ejecutiva) AS min_filas_ejecutiva, MAX(filas_ejecutiva) AS max_filas_ejecutiva FROM vuelos;
