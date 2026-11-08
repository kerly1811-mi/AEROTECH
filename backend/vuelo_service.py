from datetime import datetime


class VueloService:
    CAMPOS = ["origen", "destino", "fecha", "hora_salida", "hora_llegada", "precio", "asientos_disponibles"]

    def __init__(self, db):
        self.db = db

    def validar(self, data):
        errores = []
        for campo in self.CAMPOS:
            if data.get(campo) in (None, ""):
                errores.append({"campo": campo, "error": "Campo obligatorio"})
        if errores:
            return errores

        try:
            datetime.strptime(str(data["fecha"]), "%Y-%m-%d")
        except ValueError:
            errores.append({"campo": "fecha", "error": "Formato YYYY-MM-DD"})
        for campo in ["hora_salida", "hora_llegada"]:
            try:
                datetime.strptime(str(data[campo])[:5], "%H:%M")
            except ValueError:
                errores.append({"campo": campo, "error": "Formato HH:MM"})
        try:
            if float(data["precio"]) <= 0:
                errores.append({"campo": "precio", "error": "Debe ser mayor a 0"})
        except (TypeError, ValueError):
            errores.append({"campo": "precio", "error": "Debe ser numérico"})
        try:
            if int(data["asientos_disponibles"]) < 0:
                errores.append({"campo": "asientos_disponibles", "error": "No puede ser negativo"})
        except (TypeError, ValueError):
            errores.append({"campo": "asientos_disponibles", "error": "Debe ser entero"})
        if str(data["origen"]).strip().lower() == str(data["destino"]).strip().lower():
            errores.append({"campo": "destino", "error": "Debe ser distinto al origen"})
        return errores

    def listar(self, origen=None, destino=None, fecha=None):
        sql = "SELECT * FROM vuelos WHERE 1=1"
        params = []
        if origen:
            sql += " AND origen ILIKE %s"
            params.append(origen)
        if destino:
            sql += " AND destino ILIKE %s"
            params.append(destino)
        if fecha:
            sql += " AND fecha = %s"
            params.append(fecha)
        sql += " ORDER BY fecha, hora_salida"
        vuelos = self.db.fetch_all(sql, params)
        return {"total": len(vuelos), "vuelos": vuelos}, 200

    def obtener(self, vuelo_id):
        vuelo = self.db.fetch_one("SELECT * FROM vuelos WHERE id = %s", (vuelo_id,))
        if not vuelo:
            return {"error": "Vuelo no encontrado"}, 404
        return vuelo, 200

    def crear(self, data):
        if not data:
            return {"error": "Debe enviar un JSON"}, 400
        errores = self.validar(data)
        if errores:
            return {"error": "Datos inválidos", "errores": errores}, 400

        vuelo = self.db.execute("""
            INSERT INTO vuelos (origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """, tuple(data[c] for c in self.CAMPOS), returning=True)
        return {"mensaje": "Vuelo creado", "vuelo": vuelo}, 201

    def actualizar(self, vuelo_id, data):
        if not data:
            return {"error": "Debe enviar un JSON"}, 400
        if data.get("version") is None:
            return {"error": "La version es obligatoria"}, 400
        errores = self.validar(data)
        if errores:
            return {"error": "Datos inválidos", "errores": errores}, 400

        vuelo = self.db.execute("""
            UPDATE vuelos
            SET origen = %s, destino = %s, fecha = %s, hora_salida = %s, hora_llegada = %s,
                precio = %s, asientos_disponibles = %s, version = version + 1
            WHERE id = %s AND version = %s
            RETURNING *
        """, tuple(data[c] for c in self.CAMPOS) + (vuelo_id, data["version"]), returning=True)

        if vuelo:
            return {"mensaje": "Vuelo actualizado", "vuelo": vuelo}, 200

        actual = self.db.fetch_one("SELECT * FROM vuelos WHERE id = %s", (vuelo_id,))
        if not actual:
            return {"error": "Vuelo no encontrado"}, 404
        return {
            "error": "Conflicto de concurrencia",
            "mensaje": "Otro usuario modificó el vuelo antes que usted",
            "vuelo_actual": actual
        }, 409

    def eliminar(self, vuelo_id):
        if self.db.fetch_one("SELECT id FROM reservas WHERE vuelo_id = %s LIMIT 1", (vuelo_id,)):
            return {"error": "No se puede eliminar un vuelo con reservas"}, 409
        if self.db.execute("DELETE FROM vuelos WHERE id = %s", (vuelo_id,)) == 0:
            return {"error": "Vuelo no encontrado"}, 404
        return {"mensaje": "Vuelo eliminado"}, 200