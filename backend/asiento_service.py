import os
import re
from decimal import Decimal


class AsientoService:
    COLUMNAS = ["A", "B", "C", "D", "E", "F"]
    TIPOS = {
        "A": "ventana",
        "B": "medio",
        "C": "pasillo",
        "D": "pasillo",
        "E": "medio",
        "F": "ventana"
    }
    PATRON = re.compile(r"^([1-9][0-9]?)([A-F])$")
    MAXIMO_POR_RESERVA = 9

    def __init__(self, db):
        self.db = db
        self.recargo_ventana = Decimal(os.getenv("RECARGO_VENTANA", "10.00"))

    def tipo(self, asiento):
        return self.TIPOS[asiento[-1]]

    def clase(self, asiento, filas_ejecutiva):
        return "ejecutiva" if int(asiento[:-1]) <= filas_ejecutiva else "economica"

    def precio(self, asiento, vuelo):
        """Tarifa del asiento según su clase (por fila) más el recargo de ventana."""
        if self.clase(asiento, vuelo["filas_ejecutiva"]) == "ejecutiva":
            base = Decimal(str(vuelo["precio_ejecutiva"]))
        else:
            base = Decimal(str(vuelo["precio"]))
        if self.tipo(asiento) == "ventana":
            return base + self.recargo_ventana
        return base

    def ordenar(self, asientos):
        return sorted(asientos, key=lambda a: (int(a[:-1]), a[-1]))

    def ocupados(self, vuelo_id, cursor=None):
        sql = "SELECT asiento FROM reserva_asientos WHERE vuelo_id = %s AND estado = 'ocupado'"
        if cursor:
            cursor.execute(sql, (vuelo_id,))
            filas = cursor.fetchall()
        else:
            filas = self.db.fetch_all(sql, (vuelo_id,))
        return self.ordenar([f["asiento"] for f in filas])

    def validar(self, asientos, filas):
        if not isinstance(asientos, list) or not asientos:
            return "Debe seleccionar al menos un asiento", []
        if len(asientos) > self.MAXIMO_POR_RESERVA:
            return f"Máximo {self.MAXIMO_POR_RESERVA} asientos por reserva", []

        normalizados = [str(a).strip().upper() for a in asientos]
        if len(set(normalizados)) != len(normalizados):
            return "Hay asientos repetidos en la selección", []

        for asiento in normalizados:
            coincidencia = self.PATRON.match(asiento)
            if not coincidencia or int(coincidencia.group(1)) > filas:
                return f"El asiento {asiento} no existe en este vuelo", []

        return None, self.ordenar(normalizados)

    def mapa(self, vuelo_id):
        vuelo = self.db.fetch_one("SELECT * FROM vuelos_detalle WHERE id = %s", (vuelo_id,))
        if not vuelo:
            return {"error": "Vuelo no encontrado"}, 404
        return {
            "vuelo": vuelo,
            "filas": vuelo["filas"],
            "filas_ejecutiva": vuelo["filas_ejecutiva"],
            "columnas": self.COLUMNAS,
            "tipos": self.TIPOS,
            "recargo_ventana": self.recargo_ventana,
            "ocupados": self.ocupados(vuelo_id)
        }, 200
