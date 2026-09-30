# Panel administrativo — MUÉVETE MÁS

## 1. Supabase
Ejecuta `admin-schema.sql` en Supabase > SQL Editor.

## 2. Autorizar al administrador
Primero crea/verifica una cuenta permanente con correo y contraseña en la app de participante.
Luego, en Supabase > SQL Editor, ejecuta (reemplazando el correo):

```sql
insert into public.admin_users(user_id)
select id from auth.users
where lower(email) = lower('TU_CORREO_ADMINISTRADOR@DOMINIO.COM')
on conflict (user_id) do nothing;
```

## 3. Panel
Después de publicar el paquete en Netlify, abre:

`https://TU-SITIO.netlify.app/admin.html`

Usa el mismo correo y contraseña de la cuenta autorizada.

## Seguridad
- No colocar `service_role` ni claves secretas en el navegador.
- El panel consulta estadísticas mediante funciones `security definer` que comprueban `admin_users`.
- Diagnósticos de salud no se devuelven en el panel ni en CSV.
