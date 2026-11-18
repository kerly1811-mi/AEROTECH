-- Migración: aviones precargados. Cada vuelo usa un modelo de avión del catálogo y de ahí salen
-- sus filas (y las de clase Ejecutiva); ya no se escribe el número de asientos a mano.
-- Requiere haber ejecutado antes migracion_aeropuertos.sql y migracion_clases.sql. No borra datos.
-- Los vuelos existentes se enlazan al avión que coincide con sus filas; si ninguno coincide
-- (vuelos creados a mano con otra cantidad de filas) quedan sin avión hasta que se editen.

BEGIN;

DROP VIEW IF EXISTS vuelos_detalle;

CREATE TABLE aviones (
    id              SERIAL PRIMARY KEY,
    modelo          VARCHAR(60) NOT NULL UNIQUE,
    filas           INT         NOT NULL CHECK (filas BETWEEN 1 AND 40),
    filas_ejecutiva INT         NOT NULL,
    CONSTRAINT aviones_filas_ejecutiva_valida CHECK (filas_ejecutiva BETWEEN 0 AND filas)
);

ALTER TABLE aviones ENABLE ROW LEVEL SECURITY;

INSERT INTO aviones (modelo, filas, filas_ejecutiva) VALUES
('ATR 72-600', 12, 0),
('Avioneta de pruebas', 2, 1),
('Embraer E190', 20, 3),
('Airbus A320', 25, 4),
('Boeing 737-800', 28, 4),
('Airbus A321', 30, 4),
('Boeing 787-8', 35, 4),
('Boeing 787-9', 40, 6);

ALTER TABLE vuelos ADD COLUMN avion_id INT REFERENCES aviones(id);

UPDATE vuelos v
SET avion_id = a.id
FROM aviones a
WHERE a.filas = v.filas AND a.filas_ejecutiva = v.filas_ejecutiva;

CREATE INDEX idx_vuelos_avion ON vuelos(avion_id);

CREATE VIEW vuelos_detalle WITH (security_invoker = true) AS
SELECT v.*,
       ao.ciudad AS origen,  ao.codigo AS origen_codigo,  po.nombre AS origen_pais,
       ao.latitud AS origen_latitud,  ao.longitud AS origen_longitud,
       ad.ciudad AS destino, ad.codigo AS destino_codigo, pd.nombre AS destino_pais,
       ad.latitud AS destino_latitud, ad.longitud AS destino_longitud,
       av.modelo AS avion,
       (SELECT COUNT(*)::int FROM reserva_asientos ra
         WHERE ra.vuelo_id = v.id AND ra.estado = 'ocupado' AND ra.clase = 'ejecutiva') AS ocupados_ejecutiva
FROM vuelos v
JOIN aeropuertos ao ON ao.id = v.origen_id
JOIN paises po      ON po.id = ao.pais_id
JOIN aeropuertos ad ON ad.id = v.destino_id
JOIN paises pd      ON pd.id = ad.pais_id
LEFT JOIN aviones av ON av.id = v.avion_id;

COMMIT;

SELECT a.modelo, a.filas, a.filas_ejecutiva, a.filas * 6 AS asientos, COUNT(v.id) AS vuelos
FROM aviones a LEFT JOIN vuelos v ON v.avion_id = a.id
GROUP BY a.id ORDER BY a.filas;
SELECT COUNT(*) AS vuelos_sin_avion FROM vuelos WHERE avion_id IS NULL;
