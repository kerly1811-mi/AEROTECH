import datetime
import xml.etree.ElementTree as ET
from decimal import Decimal


class FacturaService:
    def __init__(self):
        self.iva = Decimal("0.15")

    def calcular(self, precio, cantidad):
        subtotal = (Decimal(precio) * cantidad).quantize(Decimal("0.01"))
        iva = (subtotal * self.iva).quantize(Decimal("0.01"))
        return subtotal, iva, subtotal + iva

    def generar_xml(self, reserva):
        subtotal, iva, total = self.calcular(reserva["precio"], reserva["cantidad_asientos"])
        numero = f"001-001-{reserva['id']:09d}"

        factura = ET.Element("factura")

        cabecera = ET.SubElement(factura, "cabecera")
        ET.SubElement(cabecera, "Numero").text = numero
        ET.SubElement(cabecera, "Fecha").text = datetime.date.today().isoformat()

        cliente = ET.SubElement(factura, "cliente")
        ET.SubElement(cliente, "Nombre").text = reserva["cliente"]
        ET.SubElement(cliente, "Correo").text = reserva["correo"]

        vuelo = ET.SubElement(factura, "vuelo")
        ET.SubElement(vuelo, "Origen").text = reserva["origen"]
        ET.SubElement(vuelo, "Destino").text = reserva["destino"]
        ET.SubElement(vuelo, "Fecha").text = reserva["fecha_vuelo"].isoformat()
        ET.SubElement(vuelo, "HoraSalida").text = reserva["hora_salida"].strftime("%H:%M")

        detalle = ET.SubElement(factura, "detalle")
        producto = ET.SubElement(detalle, "producto")
        ET.SubElement(producto, "Nombre").text = f"Boleto {reserva['origen']} - {reserva['destino']}"
        ET.SubElement(producto, "Cantidad").text = str(reserva["cantidad_asientos"])
        ET.SubElement(producto, "PrecioUnitario").text = f"{reserva['precio']:.2f}"
        ET.SubElement(producto, "SubTotal").text = f"{subtotal:.2f}"

        totales = ET.SubElement(factura, "totales")
        ET.SubElement(totales, "SubTotal").text = f"{subtotal:.2f}"
        ET.SubElement(totales, "IVA").text = f"{iva:.2f}"
        ET.SubElement(totales, "Total").text = f"{total:.2f}"

        ET.SubElement(factura, "Estado").text = "Generada" if reserva["estado"] == "confirmada" else "Anulada"

        ET.indent(factura, space="  ", level=0)
        xml = ET.tostring(factura, encoding="utf-8", xml_declaration=True).decode("utf-8")
        return numero, xml