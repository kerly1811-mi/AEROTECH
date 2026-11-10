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

    def listar(self):
        usuarios = self.db.fetch_all("""
            SELECT u.id, u.nombre, u.correo, r.nombre AS rol, u.activo, u.fecha_registro,
                   (SELECT COUNT(*) FROM reservas re WHERE re.usuario_id = u.id AND re.estado = 'confirmada') AS reservas_activas
            FROM usuarios u JOIN roles r ON r.id = u.rol_id
            ORDER BY r.nombre, u.nombre
        """)
        return {"total": len(usuarios), "usuarios": usuarios}, 200

    def cambiar_estado(self, usuario_id, data, usuario_actual):
        if data is None or not isinstance(data.get("activo"), bool):
            return {"error": "El campo activo es obligatorio (true o false)"}, 400
        if usuario_id == usuario_actual["id"]:
            return {"error": "No puede cambiar su propio estado"}, 409

        usuario = self.db.execute("""
            UPDATE usuarios SET activo = %s
            WHERE id = %s
            RETURNING id, nombre, correo, activo
        """, (data["activo"], usuario_id), returning=True)
        if not usuario:
            return {"error": "Usuario no encontrado"}, 404

        if not data["activo"]:
            self.db.execute("""
                UPDATE tokens SET estado = 'revocado'
                WHERE usuario_id = %s AND estado = 'activo'
            """, (usuario_id,))

        mensaje = "Usuario activado" if data["activo"] else "Usuario desactivado"
        return {"mensaje": mensaje, "usuario": usuario}, 200
