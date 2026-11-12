import os
import time
from psycopg2 import errors


class Rechazo(Exception):
    """Respuesta de error que cancela la transacción completa."""

    def __init__(self, cuerpo, codigo):
        super().__init__(cuerpo.get("error"))
        self.cuerpo = cuerpo
        self.codigo = codigo


class ReservaService:
    CONSULTA = """
        SELECT r.id, r.usuario_id, u.nombre AS cliente, u.correo, r.vuelo_id,
               ao.ciudad AS origen, ad.ciudad AS destino,
               ao.codigo AS origen_codigo, ad.codigo AS destino_codigo,
               v.fecha AS fecha_vuelo, v.hora_salida, v.precio,
               r.cantidad_asientos, r.total, r.estado, r.fecha_reserva, r.viaje_id, r.version,
               COALESCE((
                   SELECT json_agg(json_build_object(
                              'asiento', ra.asiento, 'tipo', ra.tipo, 'clase', ra.clase, 'precio', ra.precio,
                              'equipaje_extra', ra.equipaje_extra, 'precio_equipaje', ra.precio_equipaje
                          ) ORDER BY ra.id)
                   FROM reserva_asientos ra
                   WHERE ra.reserva_id = r.id
               ), '[]'::json) AS asientos
        FROM reservas r
        JOIN vuelos v ON v.id = r.vuelo_id
        JOIN aeropuertos ao ON ao.id = v.origen_id
        JOIN aeropuertos ad ON ad.id = v.destino_id
        JOIN usuarios u ON u.id = r.usuario_id
    """

    def __init__(self, db, factura, asiento, equipaje):
        self.db = db
        self.factura = factura
        self.asiento = asiento
        self.equipaje = equipaje
        self.demora = int(os.getenv("DEMORA_SEGUNDOS", 0))

    def crear(self, usuario_id, data):
        """Crea una reserva por cada tramo (1 para solo ida, 2 para ida y vuelta) en una sola transacción:
        si un tramo falla, no se guarda ninguno."""
        if not data:
            return {"error": "Debe enviar un JSON"}, 400

        tramos = data.get("tramos", [data])
        if not isinstance(tramos, list) or not 1 <= len(tramos) <= 2:
            return {"error": "Debe enviar uno o dos tramos"}, 400
        if not all(isinstance(t, dict) for t in tramos):
            return {"error": "Cada tramo debe ser un objeto JSON"}, 400
        if len({str(t.get("vuelo_id")) for t in tramos}) != len(tramos):
            return {"error": "Los tramos deben ser vuelos distintos"}, 400

        conn = self.db.get_connection()
        try:
            with conn.cursor() as cursor:
                reservas = []
                viaje_id = None
                for t in tramos:
                    reserva = self._crear_tramo(cursor, usuario_id, t, viaje_id)
                    viaje_id = reserva["viaje_id"]
                    reservas.append(reserva)
            conn.commit()
            return {
                "mensaje": "Reserva creada" if len(reservas) == 1 else "Reservas creadas",
                "reservas": reservas,
                "total": sum(r["total"] for r in reservas)
            }, 201
        except Rechazo as r:
            conn.rollback()
            return r.cuerpo, r.codigo
        except errors.UniqueViolation:
            conn.rollback()
            return {
                "error": "Asientos no disponibles",
                "mensaje": "Uno o más asientos acaban de ser reservados por otro usuario"
            }, 409
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def _crear_tramo(self, cursor, usuario_id, data, viaje_id=None):
        if data.get("vuelo_id") is None or data.get("asientos") is None or data.get("version") is None:
            raise Rechazo({"error": "vuelo_id, asientos y version son obligatorios"}, 400)
        try:
            vuelo_id = int(data["vuelo_id"])
            version = int(data["version"])
        except (TypeError, ValueError):
            raise Rechazo({"error": "vuelo_id y version deben ser enteros"}, 400)

        cursor.execute("SELECT * FROM vuelos_detalle WHERE id = %s", (vuelo_id,))
        vuelo = cursor.fetchone()
        if not vuelo:
            raise Rechazo({"error": "Vuelo no encontrado"}, 404)

        error, asientos = self.asiento.validar(data["asientos"], vuelo["filas"])
        if error:
            raise Rechazo({"error": error}, 400)

        error, maletas = self.equipaje.validar(data.get("equipaje"), asientos)
        if error:
            raise Rechazo({"error": error}, 400)

        ocupados = set(self.asiento.ocupados(vuelo_id, cursor))
        tomados = [a for a in asientos if a in ocupados]
        if tomados:
            raise Rechazo({
                "error": "Asientos no disponibles",
                "mensaje": f"Los asientos {', '.join(tomados)} ya fueron reservados",
                "asientos_ocupados": tomados,
                "vuelo_actual": vuelo
            }, 409)

        if self.demora:
            time.sleep(self.demora)

        cantidad = len(asientos)
        cursor.execute("""
            UPDATE vuelos
            SET asientos_disponibles = asientos_disponibles - %s, version = version + 1
            WHERE id = %s AND version = %s AND asientos_disponibles >= %s
        """, (cantidad, vuelo_id, version, cantidad))

        if cursor.rowcount == 0:
            cursor.execute("SELECT * FROM vuelos_detalle WHERE id = %s", (vuelo_id,))
            raise Rechazo({
                "error": "Conflicto de concurrencia",
                "mensaje": "Otro usuario reservó en este vuelo mientras usted elegía, revise el mapa nuevamente",
                "vuelo_actual": cursor.fetchone()
            }, 409)

        detalle = [
            (
                a,
                self.asiento.tipo(a),
                self.asiento.clase(a, vuelo["filas_ejecutiva"]),
                self.asiento.precio(a, vuelo),
                maletas.get(a, 0),
                self.equipaje.costo(maletas.get(a, 0)),
            )
            for a in asientos
        ]
        subtotal, iva, total = self.factura.calcular(
            [d[3] for d in detalle] + [d[5] for d in detalle]
        )

        # El primer tramo define el viaje: todas las reservas del viaje comparten comprobante.
        cursor.execute("SELECT nextval(pg_get_serial_sequence('reservas', 'id')) AS id")
        reserva_id = cursor.fetchone()["id"]
        if viaje_id is None:
            viaje_id = reserva_id

        cursor.execute("""
            INSERT INTO reservas (id, usuario_id, vuelo_id, cantidad_asientos, total, viaje_id)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING *
        """, (reserva_id, usuario_id, vuelo_id, cantidad, total, viaje_id))
        reserva = cursor.fetchone()

        for asiento, tipo, clase, precio, extra, costo_extra in detalle:
            cursor.execute("""
                INSERT INTO reserva_asientos
                    (reserva_id, vuelo_id, asiento, tipo, clase, precio, equipaje_extra, precio_equipaje)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (reserva["id"], vuelo_id, asiento, tipo, clase, precio, extra, costo_extra))

        return {
            "reserva_id": reserva["id"],
            "viaje_id": viaje_id,
            "vuelo_id": vuelo_id,
            "asientos": asientos,
            "subtotal": subtotal,
            "iva": iva,
            "total": total,
            "estado": reserva["estado"]
        }

    def listar_propias(self, usuario_id):
        reservas = self.db.fetch_all(self.CONSULTA + " WHERE r.usuario_id = %s ORDER BY r.fecha_reserva DESC", (usuario_id,))
        return {"total": len(reservas), "reservas": reservas}, 200

    def listar_todas(self):
        reservas = self.db.fetch_all(self.CONSULTA + " ORDER BY r.fecha_reserva DESC")
        return {"total": len(reservas), "reservas": reservas}, 200

    def obtener(self, reserva_id, usuario, permisos):
        reserva = self.db.fetch_one(self.CONSULTA + " WHERE r.id = %s", (reserva_id,))
        if not reserva:
            return {"error": "Reserva no encontrada"}, 404
        if reserva["usuario_id"] != usuario["id"] and "reservas.ver_todas" not in permisos:
            return {"error": "No tiene permiso para ver esta reserva"}, 403
        return reserva, 200

    def obtener_viaje(self, reserva_id, usuario, permisos):
        """Todas las reservas del mismo viaje que la reserva indicada (ida y vuelta), ordenadas por fecha."""
        reserva, codigo = self.obtener(reserva_id, usuario, permisos)
        if codigo != 200:
            return reserva, codigo
        reservas = self.db.fetch_all(
            self.CONSULTA + " WHERE r.viaje_id = %s ORDER BY v.fecha, v.hora_salida, r.id", (reserva["viaje_id"],)
        )
        return reservas, 200

    def cancelar(self, reserva_id, data, usuario, permisos):
        if not data or data.get("version") is None:
            return {"error": "La version es obligatoria"}, 400

        conn = self.db.get_connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SELECT * FROM reservas WHERE id = %s", (reserva_id,))
                reserva = cursor.fetchone()
                if not reserva:
                    return {"error": "Reserva no encontrada"}, 404

                propia = reserva["usuario_id"] == usuario["id"]
                if not (propia and "reservas.cancelar_propias" in permisos) and "reservas.cancelar_todas" not in permisos:
                    return {"error": "No tiene permiso para cancelar esta reserva"}, 403
                if reserva["estado"] == "cancelada":
                    return {"error": "La reserva ya está cancelada"}, 409

                if self.demora:
                    time.sleep(self.demora)

                cursor.execute("""
                    UPDATE reservas SET estado = 'cancelada', version = version + 1
                    WHERE id = %s AND version = %s AND estado = 'confirmada'
                """, (reserva_id, data["version"]))

                if cursor.rowcount == 0:
                    conn.rollback()
                    cursor.execute("SELECT * FROM reservas WHERE id = %s", (reserva_id,))
                    return {
                        "error": "Conflicto de concurrencia",
                        "mensaje": "La reserva fue modificada por otro usuario",
                        "reserva_actual": cursor.fetchone()
                    }, 409

                # Cancelar una reserva cancela todo el viaje (ida y vuelta comparten comprobante).
                cursor.execute("""
                    UPDATE reservas SET estado = 'cancelada', version = version + 1
                    WHERE viaje_id = %s AND id <> %s AND estado = 'confirmada'
                    RETURNING id, vuelo_id, cantidad_asientos
                """, (reserva["viaje_id"], reserva_id))
                canceladas = [(reserva_id, reserva["vuelo_id"], reserva["cantidad_asientos"])]
                canceladas += [(r["id"], r["vuelo_id"], r["cantidad_asientos"]) for r in cursor.fetchall()]

                for rid, vuelo_id, cantidad in canceladas:
                    cursor.execute("""
                        UPDATE reserva_asientos SET estado = 'liberado'
                        WHERE reserva_id = %s AND estado = 'ocupado'
                    """, (rid,))
                    cursor.execute("""
                        UPDATE vuelos
                        SET asientos_disponibles = asientos_disponibles + %s, version = version + 1
                        WHERE id = %s
                    """, (cantidad, vuelo_id))
            conn.commit()
            return {
                "mensaje": "Reserva cancelada" if len(canceladas) == 1 else "Viaje cancelado (ida y vuelta)",
                "reserva_id": reserva_id,
                "reservas_canceladas": [c[0] for c in canceladas],
                "asientos_liberados": sum(c[2] for c in canceladas)
            }, 200
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
