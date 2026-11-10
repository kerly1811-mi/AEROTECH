UPDATE usuarios
SET rol_id = (SELECT id FROM roles WHERE nombre = 'cliente')
WHERE rol_id IN (SELECT id FROM roles WHERE nombre NOT IN ('admin', 'cliente'));

DELETE FROM roles WHERE nombre NOT IN ('admin', 'cliente');

DELETE FROM rol_permisos
WHERE rol_id = (SELECT id FROM roles WHERE nombre = 'admin')
  AND permiso_id IN (
      SELECT id FROM permisos
      WHERE codigo IN ('reservas.crear', 'reservas.ver_propias', 'reservas.cancelar_propias')
  );

UPDATE permisos SET descripcion = 'Activar y desactivar usuarios' WHERE codigo = 'usuarios.gestionar';

DELETE FROM reservas;
DELETE FROM tokens;

ALTER TABLE vuelos
ADD COLUMN IF NOT EXISTS filas INT NOT NULL DEFAULT 20 CHECK (filas BETWEEN 1 AND 40);

CREATE TABLE IF NOT EXISTS reserva_asientos (
    id          SERIAL PRIMARY KEY,
    reserva_id  INT          NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
    vuelo_id    INT          NOT NULL REFERENCES vuelos(id),
    asiento     VARCHAR(4)   NOT NULL,
    tipo        VARCHAR(10)  NOT NULL CHECK (tipo IN ('ventana','medio','pasillo')),
    precio      NUMERIC(10,2) NOT NULL,
    estado      VARCHAR(10)  NOT NULL DEFAULT 'ocupado' CHECK (estado IN ('ocupado','liberado'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_asiento_ocupado
    ON reserva_asientos (vuelo_id, asiento) WHERE estado = 'ocupado';
CREATE INDEX IF NOT EXISTS idx_reserva_asientos_reserva ON reserva_asientos (reserva_id);

ALTER TABLE reserva_asientos ENABLE ROW LEVEL SECURITY;

UPDATE vuelos SET filas = 20, asientos_disponibles = 120, version = 1;
UPDATE vuelos SET filas = 2, asientos_disponibles = 12 WHERE id = 10;

SELECT r.nombre AS rol, COUNT(*) AS permisos
FROM rol_permisos rp JOIN roles r ON r.id = rp.rol_id
GROUP BY r.nombre;
