from datetime import datetime


class VueloService:
    CAMPOS = ["origen", "destino", "fecha", "hora_salida", "hora_llegada", "precio", "filas"]
    ASIENTOS_POR_FILA = 6
    MAXIMO_FILAS = 40

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
        if str(data["hora_salida"])[:5] == str(data["hora_llegada"])[:5]:
            errores.append({"campo": "hora_llegada", "error": "Debe ser distinta a la hora de salida"})
        try:
            if float(data["precio"]) <= 0:
                errores.append({"campo": "precio", "error": "Debe ser mayor a 0"})
        except (TypeError, ValueError):
            errores.append({"campo": "precio", "error": "Debe ser numérico"})
        try:
            filas = int(data["filas"])
            if filas < 1 or filas > self.MAXIMO_FILAS:
                errores.append({"campo": "filas", "error": f"Debe estar entre 1 y {self.MAXIMO_FILAS}"})
        except (TypeError, ValueError):
            errores.append({"campo": "filas", "error": "Debe ser entero"})
        if str(data["origen"]).strip().lower() == str(data["destino"]).strip().lower():
            errores.append({"campo": "destino", "error": "Debe ser distinto al origen"})
        return errores

    def valores(self, data):
        return (
            str(data["origen"]).strip(),
            str(data["destino"]).strip(),
            data["fecha"],
            str(data["hora_salida"])[:5],
            str(data["hora_llegada"])[:5],
            data["precio"],
            int(data["filas"])
        )

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

        valores = self.valores(data)
        vuelo = self.db.execute("""
            INSERT INTO vuelos (origen, destino, fecha, hora_salida, hora_llegada, precio, filas, asientos_disponibles)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """, valores + (valores[-1] * self.ASIENTOS_POR_FILA,), returning=True)
        return {"mensaje": "Vuelo creado", "vuelo": vuelo}, 201

    def actualizar(self, vuelo_id, data):
        if not data:
            return {"error": "Debe enviar un JSON"}, 400
        if data.get("version") is None:
            return {"error": "La version es obligatoria"}, 400
        errores = self.validar(data)
        if errores:
            return {"error": "Datos inválidos", "errores": errores}, 400

        valores = self.valores(data)
        ocupados = self.db.fetch_all("""
            SELECT asiento FROM reserva_asientos
            WHERE vuelo_id = %s AND estado = 'ocupado'
        """, (vuelo_id,))
        fila_maxima = max((int(o["asiento"][:-1]) for o in ocupados), default=0)
        if valores[-1] < fila_maxima:
            return {
                "error": "Datos inválidos",
                "errores": [{"campo": "filas", "error": f"Hay asientos reservados hasta la fila {fila_maxima}"}]
            }, 400

        disponibles = valores[-1] * self.ASIENTOS_POR_FILA - len(ocupados)
        vuelo = self.db.execute("""
            UPDATE vuelos
            SET origen = %s, destino = %s, fecha = %s, hora_salida = %s, hora_llegada = %s,
                precio = %s, filas = %s, asientos_disponibles = %s, version = version + 1
            WHERE id = %s AND version = %s
            RETURNING *
        """, valores + (disponibles, vuelo_id, data["version"]), returning=True)

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
