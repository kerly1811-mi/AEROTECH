import datetime
import xml.etree.ElementTree as ET
from decimal import Decimal

ZONA_ECUADOR = datetime.timezone(datetime.timedelta(hours=-5))
NOMBRES_CLASE = {"economica": "Económica", "ejecutiva": "Ejecutiva"}


class FacturaService:
    def __init__(self):
        self.iva = Decimal("0.15")

    def calcular(self, precios):
        subtotal = sum((Decimal(str(p)) for p in precios), Decimal("0")).quantize(Decimal("0.01"))
        iva = (subtotal * self.iva).quantize(Decimal("0.01"))
        return subtotal, iva, subtotal + iva

    def detalle(self, reserva, prefijo=""):
        if reserva.get("asientos"):
            lineas = []
            for a in reserva["asientos"]:
                nombre = f"Asiento {a['asiento']} - {a['tipo'].capitalize()}"
                if a.get("clase"):
                    nombre += f" - {NOMBRES_CLASE.get(a['clase'], a['clase'].capitalize())}"
                lineas.append((prefijo + nombre, Decimal(str(a["precio"]))))
                extra = int(a.get("equipaje_extra") or 0)
                if extra:
                    lineas.append((
                        f"{prefijo}Equipaje adicional x{extra} - Asiento {a['asiento']}",
                        Decimal(str(a["precio_equipaje"]))
                    ))
            return lineas
        return [
            (f"{prefijo}Boleto {reserva['origen']} - {reserva['destino']}", Decimal(str(reserva["precio"])))
            for _ in range(reserva["cantidad_asientos"])
        ]

    def fecha_emision(self, reserva):
        fecha = reserva["fecha_reserva"]
        if isinstance(fecha, datetime.datetime) and fecha.tzinfo:
            fecha = fecha.astimezone(ZONA_ECUADOR)
        return fecha.date().isoformat() if isinstance(fecha, datetime.datetime) else fecha.isoformat()

    def generar_xml(self, reservas):
        """Un solo comprobante para todas las reservas del viaje (1 vuelo de ida, o ida y vuelta)."""
        if isinstance(reservas, dict):
            reservas = [reservas]
        primera = reservas[0]
        varias = len(reservas) > 1
        etiquetas = ["Ida", "Regreso"] + [f"Tramo {i}" for i in range(3, len(reservas) + 1)]

        lineas = []
        for reserva, etiqueta in zip(reservas, etiquetas):
            lineas += self.detalle(reserva, f"{etiqueta} - " if varias else "")
        subtotal, iva, total = self.calcular([precio for _, precio in lineas])
        numero = f"001-001-{primera['viaje_id']:09d}"

        factura = ET.Element("factura")

        cabecera = ET.SubElement(factura, "cabecera")
        ET.SubElement(cabecera, "Numero").text = numero
        ET.SubElement(cabecera, "Fecha").text = self.fecha_emision(primera)

        cliente = ET.SubElement(factura, "cliente")
        ET.SubElement(cliente, "Nombre").text = primera["cliente"]
        ET.SubElement(cliente, "Correo").text = primera["correo"]

        for reserva, etiqueta in zip(reservas, etiquetas):
            vuelo = ET.SubElement(factura, "vuelo")
            if varias:
                vuelo.set("tramo", etiqueta)
            ET.SubElement(vuelo, "Origen").text = reserva["origen"]
            ET.SubElement(vuelo, "Destino").text = reserva["destino"]
            ET.SubElement(vuelo, "Fecha").text = reserva["fecha_vuelo"].isoformat()
            ET.SubElement(vuelo, "HoraSalida").text = reserva["hora_salida"].strftime("%H:%M")

        detalle = ET.SubElement(factura, "detalle")
        for nombre, precio in lineas:
            producto = ET.SubElement(detalle, "producto")
            ET.SubElement(producto, "Nombre").text = nombre
            ET.SubElement(producto, "Cantidad").text = "1"
            ET.SubElement(producto, "PrecioUnitario").text = f"{precio:.2f}"
            ET.SubElement(producto, "SubTotal").text = f"{precio:.2f}"

        totales = ET.SubElement(factura, "totales")
        ET.SubElement(totales, "SubTotal").text = f"{subtotal:.2f}"
        ET.SubElement(totales, "IVA").text = f"{iva:.2f}"
        ET.SubElement(totales, "Total").text = f"{total:.2f}"

        activa = any(r["estado"] == "confirmada" for r in reservas)
        ET.SubElement(factura, "Estado").text = "Generada" if activa else "Anulada"

        ET.indent(factura, space="  ", level=0)
        xml = ET.tostring(factura, encoding="utf-8", xml_declaration=True).decode("utf-8")
        return numero, xml
