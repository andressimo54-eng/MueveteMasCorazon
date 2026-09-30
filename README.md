# ❤️ MUÉVETE MÁS POR TU CORAZÓN — v12

Reto institucional de actividad física de 30 días, con cuenta individual y validación por correo.

## Cambios principales v12
- Se elimina por completo la **sesión temporal/anónima**.
- Se elimina **Cambiar de participante**.
- Cada persona realiza una única inscripción vinculada a su cuenta de correo.
- La inscripción exige: nombre, grupo, nivel, condición opcional, correo y contraseña.
- La persona debe confirmar su correo y luego iniciar sesión para entrar al reto.
- No se permite acceder al reto sin una cuenta autenticada y una inscripción asociada.
- Se mantiene el acceso de participantes que ya tienen cuenta mediante correo/contraseña.
- Reto de **30 días de actividad: 1 al 30 de octubre de 2026**.
- **31 de octubre de 2026** queda como fecha de cierre y consolidación de resultados.
- Se bloquea el registro de actividad antes del 1 de octubre y después del 30 de octubre.
- Se mantiene un solo bloque principal de actividad por día.
- Se evita sumar minutos si la actividad no pudo guardarse en Supabase.
- Se corrige el manejo de fechas para usar la fecha local de Bogotá y evitar desfases por UTC.
- Se mantiene el diagnóstico privado y fuera del ranking público/exportación.
- El panel administrativo puede consultar la condición crónica únicamente para administradores autorizados.
- Se añade una restricción de una inscripción por cuenta.

## Supabase
1. Ejecuta `supabase-schema.sql` en el SQL Editor.
2. Ejecuta `v12-migration.sql` una vez.
3. Mantén **Confirm email** activado.
4. Ya no es necesario activar **Anonymous Sign-Ins** para la app participante. Se recomienda desactivarlo.
5. Configura Site URL y Redirect URL con la URL de Netlify de la aplicación.
6. La cuenta administradora sigue usando `admin.html` y `admin-schema.sql`.

## Importante sobre fechas
Octubre tiene 31 días. Para conservar el concepto de **reto de 30 días** y, al mismo tiempo, tener cierre el 31 de octubre, la actividad puntuable va del 1 al 30 de octubre y el 31 es día de cierre/consolidación.

## Publicación
Sube esta versión a Netlify después de ejecutar los SQL correspondientes en Supabase.
