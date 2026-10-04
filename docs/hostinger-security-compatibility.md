# App MRSoS y gateway seguro de Hostinger

> Para MFA, consentimiento legal y chat del paquete de octubre, consulta
> [deployment-2026-10-security.md](deployment-2026-10-security.md).
> Los resultados siguientes describen la integración de septiembre.

Actualización local: 11 de septiembre de 2026.

Referencia: documentación adjunta y código web local; lista de 189 rutas del
paquete `output/hostinger-9TfApG/mrsos-private/http-routes.php`.
No se modificaron PHP, permisos del hosting, credenciales, reglas de Firebase ni BD.
No se efectuaron solicitudes de prueba ni escrituras a producción.

## Qué se adaptó

- Se conserva `https://mrsos.com.mx/php`. Las rutas públicas siguen siendo
  `/php/...`, `/dashboard/api/...` y `/backend/...`; no se usa
  `/mrsos-private` ni `gateway.php?path=...`.
- Las imágenes de perfiles, clientes, equipos y marcas utilizan el mismo Dio y
  CookieJar que la sesión PHP. Antes se descargaban con un cliente sin cookies.
  Se normalizan prefijos heredados, se respetan las rutas de imágenes entregadas
  por PHP y no se envían credenciales a otros dominios.
- Las claves de caché de imágenes incluyen sesión y servidor; al cambiar de
  cuenta o salir se limpia la caché. No se guardan imágenes privadas en disco.
- CSRF se envía como cabecera y también como `csrf_token` en JSON, formulario
  y multipart. Las lecturas de APIs backend que verifican CSRF también llevan
  cabecera. Las cookies se adjuntan después de renovar la sesión, para usar el
  PHPSESSID vigente. Las respuestas tardías no restauran cookies de otra sesión.
- Respuestas 401, 419, 404, 503, HTML o JSON con error se tratan como errores,
  no como listas vacías. No se repiten automáticamente las mutaciones.
- Los PDF siguen descargándose con sesión a través de sus endpoints autorizados,
  nunca mediante rutas físicas de uploads o documentos privados.

| Función | Contrato vigente |
| --- | --- |
| Tickets y métricas | dashboard/api/tickets_list.php y ticket_detail.php |
| Detalle básico de equipo | php/mis_equipos_poliza.php; equipo por peId dentro del catálogo autorizado |
| Guías de logs | dashboard/api/log_guides_list.php y log_guides_download.php |
| Personas de la cuenta | backend/api/clientes/usuario_cli_list.php |
| Editar datos / contraseña temporal | backend/api/clientes/usuario_cli_update.php |
| Activar / desactivar persona | backend/api/clientes/usuario_cli_toggle.php |
| Primer cambio de contraseña | php/usuario_password_primera_vez.php; password y password2 |
| Perfil y avatar | php/actualizar_perfil.php; multipart y usAvatar |
| Registro / baja Firebase | php/notif_token_guardar.php y notif_token_eliminar.php, con CSRF |
| Bandeja de notificaciones | php/notifications_list.php y notification_read.php |

El cliente de Personas obtiene clId y permisos desde me.php y conserva la
autorización del servidor. No asigna roles ni filtros por sede/notificaciones que
la nueva lista no devuelve. Los estados mostrados son los publicados por PHP.
La desactivación requiere confirmación. No se convierte una desactivación en
eliminación.

El onboarding consulta el estado del servidor en cada intento: si la contraseña
ya se guardó, no intenta cambiarla otra vez al reintentar el guardado del perfil.

## Limitaciones que no puede resolver Flutter por sí solo

- El paquete publica health_create, pero no una API de agenda/detalle de Health
  Checks. Se conserva la creación y se informa que la consulta no está publicada.
- El catálogo de equipo publicado no entrega CPU/RAM/SO detallado ni el historial
  por equipo. Se presentan los datos reales disponibles y se remite a Tickets
  para los casos; no se consulta el endpoint legado no publicado.
- La lista de personas exige una cuenta administradora de cliente. Un usuario
  sin ese permiso recibe un estado explícito, no una falsa lista vacía.
- SVG privados y rutas físicas de documentos están bloqueados por el gateway.
  Las imágenes no disponibles muestran el respaldo de la interfaz.
- Un 503 causado por falta de configuración del hosting debe resolverlo su
  administrador. Cambiar la app no crea secretos ni habilita PHP.
- La entrega real de FCM/APNs depende del servidor, permisos del teléfono y
  credenciales correctas. Las pruebas locales no demuestran entrega push.
- Quedan archivos de pantallas/servicios legados fuera de la navegación actual;
  no deben reconectarse sin migrar primero sus contratos.

## Validación y prueba manual

Resultado de esta revisión: 84 pruebas aprobadas; APK Android debug compilado.
El analizador no reporta errores; permanecen 5 advertencias de elementos sin uso
y avisos de estilo/deprecación (145 observaciones en total). Gradle, AGP y Kotlin
también muestran avisos de compatibilidad futura, pero la compilación no se bloquea.

Las pruebas de contrato son simuladas: sesión renovada, CSRF en cuerpos y
cabeceras, aislamiento entre cuentas, errores del gateway, catálogo, guías,
usuarios y onboarding parcial. Las pruebas de pantallas incluyen móvil estrecho
y texto ampliado.

Ejecutar desde la carpeta de la app:

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --debug --no-pub
```

En un dispositivo de prueba:

1. Actualizar la app con la misma firma de la instalación existente e iniciar
   sesión. No desinstalar sin guardar los datos locales que se quieran conservar.
2. Verificar métricas, tickets, catálogo, imágenes y PDF con una cuenta real.
3. Probar una operación autorizada y una sin permisos: no debe ampliarse el acceso.
4. Abrir las guías, actualizar perfil/avatar y verificar el primer acceso con una
   cuenta de prueba marcada NewPass.
5. Salir de la cuenta A y entrar a B; comprobar que no aparecen imágenes/datos de A.
6. Confirmar estado del registro móvil en Notificaciones y hacer un envío
   controlado desde el sistema para verificar bandeja y push en Android.
7. En iOS, compilar y validar en Mac/Xcode/dispositivo; este entorno Windows no
   permite certificar esa compilación ni la entrega APNs.

El APK debug es sólo para pruebas; no equivale a un release firmado para tiendas.
