import os
import time
from psycopg2 import errors


class ReservaService:
    CONSULTA = """
        SELECT r.id, r.usuario_id, u.nombre AS cliente, u.correo, r.vuelo_id,
               ao.ciudad AS origen, ad.ciudad AS destino,
               ao.codigo AS origen_codigo, ad.codigo AS destino_codigo,
               v.fecha AS fecha_vuelo, v.hora_salida, v.precio,
               r.cantidad_asientos, r.total, r.estado, r.fecha_reserva, r.version,
               COALESCE((
                   SELECT json_agg(json_build_object(
                              'asiento', ra.asiento, 'tipo', ra.tipo, 'precio', ra.precio
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

    def __init__(self, db, factura, asiento):
        self.db = db
        self.factura = factura
        self.asiento = asiento
        self.demora = int(os.getenv("DEMORA_SEGUNDOS", 0))

    def crear(self, usuario_id, data):
        if not data:
            return {"error": "Debe enviar un JSON"}, 400
        if data.get("vuelo_id") is None or data.get("asientos") is None or data.get("version") is None:
            return {"error": "vuelo_id, asientos y version son obligatorios"}, 400
        try:
            vuelo_id = int(data["vuelo_id"])
            version = int(data["version"])
        except (TypeError, ValueError):
            return {"error": "vuelo_id y version deben ser enteros"}, 400

        conn = self.db.get_connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SELECT * FROM vuelos_detalle WHERE id = %s", (vuelo_id,))
                vuelo = cursor.fetchone()
                if not vuelo:
                    return {"error": "Vuelo no encontrado"}, 404

                error, asientos = self.asiento.validar(data["asientos"], vuelo["filas"])
                if error:
                    return {"error": error}, 400

                ocupados = set(self.asiento.ocupados(vuelo_id, cursor))
                tomados = [a for a in asientos if a in ocupados]
                if tomados:
                    return {
                        "error": "Asientos no disponibles",
                        "mensaje": f"Los asientos {', '.join(tomados)} ya fueron reservados",
                        "asientos_ocupados": tomados,
                        "vuelo_actual": vuelo
                    }, 409

                if self.demora:
                    time.sleep(self.demora)

                cantidad = len(asientos)
                cursor.execute("""
                    UPDATE vuelos
                    SET asientos_disponibles = asientos_disponibles - %s, version = version + 1
                    WHERE id = %s AND version = %s AND asientos_disponibles >= %s
                """, (cantidad, vuelo_id, version, cantidad))

                if cursor.rowcount == 0:
                    conn.rollback()
                    cursor.execute("SELECT * FROM vuelos_detalle WHERE id = %s", (vuelo_id,))
                    return {
                        "error": "Conflicto de concurrencia",
                        "mensaje": "Otro usuario reservó en este vuelo mientras usted elegía, revise el mapa nuevamente",
                        "vuelo_actual": cursor.fetchone()
                    }, 409

                detalle = [(a, self.asiento.tipo(a), self.asiento.precio(a, vuelo["precio"])) for a in asientos]
                subtotal, iva, total = self.factura.calcular([precio for _, _, precio in detalle])

                cursor.execute("""
                    INSERT INTO reservas (usuario_id, vuelo_id, cantidad_asientos, total)
                    VALUES (%s, %s, %s, %s)
                    RETURNING *
                """, (usuario_id, vuelo_id, cantidad, total))
                reserva = cursor.fetchone()

                for asiento, tipo, precio in detalle:
                    cursor.execute("""
                        INSERT INTO reserva_asientos (reserva_id, vuelo_id, asiento, tipo, precio)
                        VALUES (%s, %s, %s, %s, %s)
                    """, (reserva["id"], vuelo_id, asiento, tipo, precio))
            conn.commit()
            return {
                "mensaje": "Reserva creada",
                "reserva_id": reserva["id"],
                "asientos": asientos,
                "subtotal": subtotal,
                "iva": iva,
                "total": total,
                "estado": reserva["estado"]
            }, 201
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

                cursor.execute("""
                    UPDATE reserva_asientos SET estado = 'liberado'
                    WHERE reserva_id = %s AND estado = 'ocupado'
                """, (reserva_id,))

                cursor.execute("""
                    UPDATE vuelos
                    SET asientos_disponibles = asientos_disponibles + %s, version = version + 1
                    WHERE id = %s
                """, (reserva["cantidad_asientos"], reserva["vuelo_id"]))
            conn.commit()
            return {
                "mensaje": "Reserva cancelada",
                "reserva_id": reserva_id,
                "asientos_liberados": reserva["cantidad_asientos"]
            }, 200
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
