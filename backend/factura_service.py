import datetime
import xml.etree.ElementTree as ET
from decimal import Decimal

ZONA_ECUADOR = datetime.timezone(datetime.timedelta(hours=-5))


class FacturaService:
    def __init__(self):
        self.iva = Decimal("0.15")

    def calcular(self, precios):
        subtotal = sum((Decimal(str(p)) for p in precios), Decimal("0")).quantize(Decimal("0.01"))
        iva = (subtotal * self.iva).quantize(Decimal("0.01"))
        return subtotal, iva, subtotal + iva

    def detalle(self, reserva):
        if reserva.get("asientos"):
            return [
                (f"Asiento {a['asiento']} - {a['tipo'].capitalize()}", Decimal(str(a["precio"])))
                for a in reserva["asientos"]
            ]
        return [
            (f"Boleto {reserva['origen']} - {reserva['destino']}", Decimal(str(reserva["precio"])))
            for _ in range(reserva["cantidad_asientos"])
        ]

    def fecha_emision(self, reserva):
        fecha = reserva["fecha_reserva"]
        if isinstance(fecha, datetime.datetime) and fecha.tzinfo:
            fecha = fecha.astimezone(ZONA_ECUADOR)
        return fecha.date().isoformat() if isinstance(fecha, datetime.datetime) else fecha.isoformat()

    def generar_xml(self, reserva):
        lineas = self.detalle(reserva)
        subtotal, iva, total = self.calcular([precio for _, precio in lineas])
        numero = f"001-001-{reserva['id']:09d}"

        factura = ET.Element("factura")

        cabecera = ET.SubElement(factura, "cabecera")
        ET.SubElement(cabecera, "Numero").text = numero
        ET.SubElement(cabecera, "Fecha").text = self.fecha_emision(reserva)

        cliente = ET.SubElement(factura, "cliente")
        ET.SubElement(cliente, "Nombre").text = reserva["cliente"]
        ET.SubElement(cliente, "Correo").text = reserva["correo"]

        vuelo = ET.SubElement(factura, "vuelo")
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

        ET.SubElement(factura, "Estado").text = "Generada" if reserva["estado"] == "confirmada" else "Anulada"

        ET.indent(factura, space="  ", level=0)
        xml = ET.tostring(factura, encoding="utf-8", xml_declaration=True).decode("utf-8")
        return numero, xml
