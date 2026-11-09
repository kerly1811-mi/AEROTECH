import os
import time


class ReservaService:
    CONSULTA = """
        SELECT r.id, r.usuario_id, u.nombre AS cliente, u.correo, r.vuelo_id,
               v.origen, v.destino, v.fecha AS fecha_vuelo, v.hora_salida, v.precio,
               r.cantidad_asientos, r.total, r.estado, r.fecha_reserva, r.version
        FROM reservas r
        JOIN vuelos v ON v.id = r.vuelo_id
        JOIN usuarios u ON u.id = r.usuario_id
    """

    def __init__(self, db, factura):
        self.db = db
        self.factura = factura
        self.demora = int(os.getenv("DEMORA_SEGUNDOS", 0))

    def crear(self, usuario_id, data):
        if not data:
            return {"error": "Debe enviar un JSON"}, 400
        if data.get("vuelo_id") is None or data.get("cantidad") is None or data.get("version") is None:
            return {"error": "vuelo_id, cantidad y version son obligatorios"}, 400
        try:
            vuelo_id = int(data["vuelo_id"])
            cantidad = int(data["cantidad"])
            version = int(data["version"])
        except (TypeError, ValueError):
            return {"error": "vuelo_id, cantidad y version deben ser enteros"}, 400
        if cantidad <= 0:
            return {"error": "La cantidad debe ser mayor a 0"}, 400

        conn = self.db.get_connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SELECT * FROM vuelos WHERE id = %s", (vuelo_id,))
                vuelo = cursor.fetchone()
                if not vuelo:
                    return {"error": "Vuelo no encontrado"}, 404
                if vuelo["asientos_disponibles"] < cantidad:
                    return {
                        "error": "Asientos insuficientes",
                        "asientos_disponibles": vuelo["asientos_disponibles"]
                    }, 409

                if self.demora:
                    time.sleep(self.demora)

                cursor.execute("""
                    UPDATE vuelos
                    SET asientos_disponibles = asientos_disponibles - %s, version = version + 1
                    WHERE id = %s AND version = %s AND asientos_disponibles >= %s
                """, (cantidad, vuelo_id, version, cantidad))

                if cursor.rowcount == 0:
                    conn.rollback()
                    cursor.execute("SELECT * FROM vuelos WHERE id = %s", (vuelo_id,))
                    return {
                        "error": "Conflicto de concurrencia",
                        "mensaje": "El vuelo fue modificado por otro usuario, consulte nuevamente",
                        "vuelo_actual": cursor.fetchone()
                    }, 409

                subtotal, iva, total = self.factura.calcular(vuelo["precio"], cantidad)
                cursor.execute("""
                    INSERT INTO reservas (usuario_id, vuelo_id, cantidad_asientos, total)
                    VALUES (%s, %s, %s, %s)
                    RETURNING *
                """, (usuario_id, vuelo_id, cantidad, total))
                reserva = cursor.fetchone()
            conn.commit()
            return {
                "mensaje": "Reserva creada",
                "reserva_id": reserva["id"],
                "subtotal": subtotal,
                "iva": iva,
                "total": total,
                "estado": reserva["estado"],
                "version": reserva["version"]
            }, 201
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