import os
from decimal import Decimal


class EquipajeService:
    """Equipaje de bodega adicional que el pasajero compra por vuelo.

    Cada pasajero puede agregar hasta MAXIMO_EXTRA maletas. La primera cuesta `primero` y la segunda
    `segundo`. La tarifa Ejecutiva ya incluye 2 maletas de bodega; la Económica no incluye ninguna.
    """

    MAXIMO_EXTRA = 2
    INCLUIDAS = {"economica": 0, "ejecutiva": 2}

    def __init__(self):
        self.primero = Decimal(os.getenv("EQUIPAJE_PRIMERO", "85.00"))
        self.segundo = Decimal(os.getenv("EQUIPAJE_SEGUNDO", "135.00"))

    def costo(self, cantidad):
        if cantidad <= 0:
            return Decimal("0.00")
        if cantidad == 1:
            return self.primero
        return self.primero + self.segundo

    def tarifas(self):
        return {
            "primer_extra": self.primero,
            "segundo_extra": self.segundo,
            "maximo_extra": self.MAXIMO_EXTRA,
            "incluidas": self.INCLUIDAS,
            "mano_kg": 10,
            "bodega_kg": 23
        }

    def validar(self, equipaje, asientos):
        """equipaje: {"3A": 1, ...} con las maletas extra de cada pasajero (por asiento)."""
        if equipaje in (None, {}):
            return None, {}
        if not isinstance(equipaje, dict):
            return "equipaje debe ser un objeto {asiento: cantidad}", {}

        resultado = {}
        for asiento, cantidad in equipaje.items():
            clave = str(asiento).strip().upper()
            if clave not in asientos:
                return f"El equipaje indica el asiento {clave}, que no está en la reserva", {}
            try:
                cantidad = int(cantidad)
            except (TypeError, ValueError):
                return "La cantidad de equipaje debe ser un entero", {}
            if cantidad < 0 or cantidad > self.MAXIMO_EXTRA:
                return f"Cada pasajero puede agregar de 0 a {self.MAXIMO_EXTRA} maletas", {}
            resultado[clave] = cantidad
        return None, resultado
