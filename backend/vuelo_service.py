from datetime import datetime


class VueloService:
    CAMPOS = ["origen_id", "destino_id", "fecha", "hora_salida", "hora_llegada", "precio", "filas",
              "filas_ejecutiva", "precio_ejecutiva"]
    DETALLE = "SELECT * FROM vuelos_detalle"
    ASIENTOS_POR_FILA = 6
    IDX_FILAS = 6  # posición de "filas" en la tupla que devuelve valores()
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
        try:
            if float(data["precio_ejecutiva"]) <= 0:
                errores.append({"campo": "precio_ejecutiva", "error": "Debe ser mayor a 0"})
        except (TypeError, ValueError):
            errores.append({"campo": "precio_ejecutiva", "error": "Debe ser numérico"})
        try:
            filas_ejecutiva = int(data["filas_ejecutiva"])
            if filas_ejecutiva < 0:
                errores.append({"campo": "filas_ejecutiva", "error": "No puede ser negativo"})
            elif not any(e["campo"] == "filas" for e in errores) and filas_ejecutiva > int(data["filas"]):
                errores.append({"campo": "filas_ejecutiva", "error": "No puede superar el total de filas"})
        except (TypeError, ValueError):
            errores.append({"campo": "filas_ejecutiva", "error": "Debe ser entero"})
        ids = {}
        for campo in ["origen_id", "destino_id"]:
            try:
                ids[campo] = int(data[campo])
            except (TypeError, ValueError):
                errores.append({"campo": campo, "error": "Debe seleccionar un aeropuerto de la lista"})
        if len(ids) == 2:
            if ids["origen_id"] == ids["destino_id"]:
                errores.append({"campo": "destino_id", "error": "Debe ser distinto al origen"})
            else:
                existentes = {
                    f["id"] for f in self.db.fetch_all(
                        "SELECT id FROM aeropuertos WHERE id = ANY(%s)", (list(ids.values()),)
                    )
                }
                for campo, valor in ids.items():
                    if valor not in existentes:
                        errores.append({"campo": campo, "error": "El aeropuerto no existe"})
        return errores

    def valores(self, data):
        return (
            int(data["origen_id"]),
            int(data["destino_id"]),
            data["fecha"],
            str(data["hora_salida"])[:5],
            str(data["hora_llegada"])[:5],
            data["precio"],
            int(data["filas"]),
            int(data["filas_ejecutiva"]),
            data["precio_ejecutiva"]
        )

    def aeropuertos(self):
        aeropuertos = self.db.fetch_all("""
            SELECT a.id, a.codigo, a.ciudad, a.nombre, p.nombre AS pais, p.codigo AS pais_codigo
            FROM aeropuertos a JOIN paises p ON p.id = a.pais_id
            ORDER BY p.nombre, a.ciudad
        """)
        return {"total": len(aeropuertos), "aeropuertos": aeropuertos}, 200

    def listar(self, origen_id=None, destino_id=None, fecha=None):
        sql = self.DETALLE + " WHERE 1=1"
        params = []
        for columna, valor in (("origen_id", origen_id), ("destino_id", destino_id)):
            if valor:
                try:
                    params.append(int(valor))
                except ValueError:
                    return {"error": f"{columna} debe ser un entero"}, 400
                sql += f" AND {columna} = %s"
        if fecha:
            sql += " AND fecha = %s"
            params.append(fecha)
        sql += " ORDER BY fecha, hora_salida"
        vuelos = self.db.fetch_all(sql, params)
        return {"total": len(vuelos), "vuelos": vuelos}, 200

    def obtener(self, vuelo_id):
        vuelo = self.db.fetch_one(self.DETALLE + " WHERE id = %s", (vuelo_id,))
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
            INSERT INTO vuelos (origen_id, destino_id, fecha, hora_salida, hora_llegada, precio, filas,
                                filas_ejecutiva, precio_ejecutiva, asientos_disponibles)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, valores + (valores[self.IDX_FILAS] * self.ASIENTOS_POR_FILA,), returning=True)
        return {"mensaje": "Vuelo creado", "vuelo": self.obtener(vuelo["id"])[0]}, 201

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
        if valores[self.IDX_FILAS] < fila_maxima:
            return {
                "error": "Datos inválidos",
                "errores": [{"campo": "filas", "error": f"Hay asientos reservados hasta la fila {fila_maxima}"}]
            }, 400

        disponibles = valores[self.IDX_FILAS] * self.ASIENTOS_POR_FILA - len(ocupados)
        vuelo = self.db.execute("""
            UPDATE vuelos
            SET origen_id = %s, destino_id = %s, fecha = %s, hora_salida = %s, hora_llegada = %s,
                precio = %s, filas = %s, filas_ejecutiva = %s, precio_ejecutiva = %s,
                asientos_disponibles = %s, version = version + 1
            WHERE id = %s AND version = %s
            RETURNING id
        """, valores + (disponibles, vuelo_id, data["version"]), returning=True)

        if vuelo:
            return {"mensaje": "Vuelo actualizado", "vuelo": self.obtener(vuelo_id)[0]}, 200

        actual = self.db.fetch_one(self.DETALLE + " WHERE id = %s", (vuelo_id,))
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
