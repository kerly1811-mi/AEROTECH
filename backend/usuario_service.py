class UsuarioService:
    def __init__(self, db, autenticacion):
        self.db = db
        self.autenticacion = autenticacion

    def registrar(self, data):
        if not data:
            return {"error": "Debe enviar un JSON"}, 400
        if not data.get("nombre") or not data.get("correo") or not data.get("password"):
            return {"error": "nombre, correo y password son obligatorios"}, 400
        if len(data["password"]) < 6:
            return {"error": "La contraseña debe tener mínimo 6 caracteres"}, 400

        correo = data["correo"].strip().lower()
        if self.db.fetch_one("SELECT id FROM usuarios WHERE correo = %s", (correo,)):
            return {"error": "El correo ya está registrado"}, 409

        nuevo = self.db.execute("""
            INSERT INTO usuarios (nombre, correo, password_hash, rol_id)
            VALUES (%s, %s, %s, (SELECT id FROM roles WHERE nombre = 'cliente'))
            RETURNING id, nombre, correo
        """, (data["nombre"].strip(), correo, self.autenticacion.hash_password(data["password"])), returning=True)

        return {"mensaje": "Usuario registrado", "usuario": nuevo, "rol": "cliente"}, 201