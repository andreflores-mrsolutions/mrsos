# MRSoS móvil · Compatibilidad con hostinger-gHalkZ

Actualización local: 3 de octubre de 2026.

Referencia: paquete `output/hostinger-gHalkZ`, release creado el 3 de octubre,
191 rutas publicadas en `mrsos-private/http-routes.php`. Los PHP y la BD se
consultaron como referencia: **no se modificó ni desplegó el servidor**.
No se enviaron correos, chats, tickets ni notificaciones reales en estas pruebas.
Este documento complementa y actualiza la guía de compatibilidad de septiembre.

## Acceso y controles

1. Contraseña: POST de formulario a `/php/login.php`, con `usId`, `usPass`
   y la opción explícita `remember` (desactivada inicialmente).
2. Si PHP devuelve `mfaRequired`, se abre la pantalla de código. Se mantienen
   la cookie PHP y el CSRF del desafío; todavía no se consulta el panel ni se
   registra el dispositivo en Firebase. Código y contraseña no se persisten.
3. Código: POST al mismo login con `action=verify`, `code` y la cabecera
   `X-CSRF-Token` del desafío. No se reenvía la contraseña, ni se solicita
   automáticamente otro código. Caducidad y límite de intentos los aplica PHP.
4. Tras verificar se consulta `me.php`. Si exige contraseña nueva, se usa
   `usuario_password_primera_vez.php` antes de cualquier operación.
5. Si falta aceptación legal, se muestran los documentos y dos casillas sin
   marcar. `legal_accept.php` recibe la versión exacta, `terms:true` y
   `privacy:true`. Después se vuelve a consultar el estado del servidor.
6. Sólo entonces se abre Inicio y se permite sincronizar los dispositivos push.

Las respuestas 428 y el 403 de cambio obligatorio regresan al control de acceso.
El 401 conserva el cierre de sesión, y el 419 renueva la seguridad en el siguiente
intento sin repetir automáticamente la operación. Se conserva la defensa frente
a respuestas de cuentas anteriores, las cookies en peticiones autenticadas, el
CSRF en cabecera/cuerpo y el bloqueo de credenciales hacia otros orígenes.
No se deshabilita TLS ni se agregan secretos de servidor a la app.

La biometría local no sustituye la sesión del servidor ni el código de correo.
Se conserva la política existente de la pantalla de bienvenida: reabrir una sesión
guardada requiere tener activado el acceso biométrico en Perfil; de lo contrario
se muestra el acceso por contraseña.

## Documentos legales

- Versión integrada: `2026-10-02.1`.
- `assets/legal/portal.json` reproduce los términos y aviso del componente
  web `frontend/src/Legal.jsx`; la versión y los encabezados coinciden con
  el bundle del paquete suministrado.
- Se pueden consultar sin iniciar sesión y desde Perfil. El aviso de almacenamiento
  describe la app móvil por separado, sin atribuirle el almacenamiento del navegador.
- Una aceptación pendiente de una versión distinta queda bloqueada hasta actualizar
  los textos y la versión de la app. No se acepta una versión no mostrada.
- Esta integración no constituye revisión jurídica: el responsable debe validar
  el contenido y las declaraciones de privacidad de las tiendas antes de publicar.

## Chat compartido

| Uso | Ruta pública |
| --- | --- |
| Conversaciones activas | `dashboard/api/chats_list.php` |
| Historial autorizado de ticket | `dashboard/api/help_thread.php?tiId=...` |
| Iniciar conversación | `dashboard/api/help_message.php` |
| Responder como cliente | `dashboard/api/help_reply.php` |
| Responder como MRA/MRSA | `backend/api/help_reply.php` |

El historial conserva los IDs y el orden del servidor. El envío a un hilo existente
usa su `activeTaId`, como la web, y la respuesta de soporte es pública
(`tarEsInterno:0`). No se implementa una vía para publicar notas internas.

CLI/MRA/MRSA pueden enviar; MRV sólo consulta. El contenido se presenta como texto,
sin ejecutar HTML, con límite de 2,000 caracteres Unicode en el servicio.
La consulta se actualiza cada 20 segundos sólo con la conversación visible y la
app en primer plano. El indicador de respuesta pendiente viene de `needsAction`;
no se confunde con el contador de notificaciones sin leer.

Un envío de resultado incierto no se repite automáticamente. Se pide revisar el
historial antes de habilitar un nuevo intento. Si el POST tuvo éxito pero falla
la recarga, el texto ya enviado no se restaura como borrador.

Accesos: botón Mensajes de soporte en Inicio y botón Mensajes en el detalle del ticket.

## Tickets, catálogo y otros contratos

- Buscador de equipos por SN completo o fragmento, con modos “empieza con” y
  “termina con”, sin distinguir mayúsculas. También admite modelo/marca.
- Sólo busca en el catálogo autorizado de la sede actual. Conserva `peId` real,
  aunque varios equipos tengan el mismo `eqId`/modelo.
- No preselecciona silenciosamente el primer equipo. Cambiar cliente/sede limpia
  la selección y las respuestas de una carga anterior no reemplazan la actual.
- CLI crea mediante `dashboard/api/ticket_create.php`; no envía identidad ni
  cliente inventados. MRA/MRSA usan los catálogos y `ticket_create.php` de
  `backend/api`, seleccionando cliente, sede y responsable autorizado.
- Los contadores y SLA conservan los datos de `tickets_list.php` y su `meta`.
- Cambio de correo: `email_change.php`, primero contraseña actual y nuevo correo,
  después código. Ya no se intenta sustituir el correo con `actualizar_perfil.php`.
- Desactivar avisos o categorías muestra la advertencia de seguimiento/SLA.
  Cancelar la advertencia no guarda el cambio; MFA no depende de estos avisos.
- Confirmar reunión requiere plataforma y enlace HTTPS sin credenciales, o elegir
  entrega por correo. Esta última muestra los destinatarios entregados por PHP;
  abrir el correo crea un borrador, no envía una invitación por sí solo.
- MRV no dispone de acciones para enviar chat ni confirmar/proponer reuniones.

Se mantienen los nombres públicos de las rutas; nunca se solicita
`/mrsos-private` ni se construye un acceso directo al gateway.
Los límites de los endpoints existentes siguen aplicando, incluido el máximo
de 200 clientes del catálogo administrativo y de 500 conversaciones activas.
Las funciones de backoffice no existentes en la navegación móvil no se
convierten en un panel administrativo completo en esta actualización.

## Notificaciones y marca

El recurso `android/app/src/main/res/drawable/ic_notification.xml` ahora es
una versión vectorial monocromática del símbolo MR Solutions, basada en
`assets/icon/mr_icon.png`. Se conserva el mismo nombre de recurso que usan
Firebase en el manifiesto y las notificaciones locales, y el canal `mrsos_alerts`.

Android aplica el color/silueta del sistema al icono pequeño; no muestra un logo
multicolor en la barra de estado. Instala el APK completo actualizado, no sólo
hot reload, y comprueba una **notificación nueva**. No se modifica Google Services
ni se cambia el proyecto Firebase. El emisor del paquete no sobreescribe el icono
por defecto. La configuración de este recurso sigue el
[contrato oficial de Firebase](https://firebase.google.com/docs/cloud-messaging/android/receive-messages).

Las notificaciones de negocio siguen registrándose en la BD desde PHP y se leen
en la bandeja de la app; Flutter no inserta otra notificación por cada push recibido.
En iOS se utiliza el icono de la aplicación y la configuración APNs existente.

## Validación local

- Resultado: 118 pruebas aprobadas; APK Android debug compilado correctamente.
- Análisis estático: sin errores, 5 advertencias de elementos legados sin uso
  y avisos de estilo/deprecación (169 observaciones en la revisión).
- Las 22 rutas utilizadas por los flujos revisados están presentes en la lista
  de rutas públicas del paquete proporcionado.
- Pruebas de contratos simulados: MFA/cookies/CSRF, SMTP fallido, código inválido,
  consentimiento/versionado, contraseña obligatoria, 428/403/401, chat nuevo y
  respuestas por rol, envío incierto, correo verificado, reuniones y catálogo.
- Pruebas de interfaz: teléfono de 320/390 px y texto ampliado a 1.6; creación
  completa de ticket CLI/MRA con servidor simulado y selección del equipo real.
- APK de prueba: `build/app/outputs/flutter-apk/app-debug.apk`.
- El análisis estático mantiene advertencias de código legado y estilo;
  no debe confundirse “sin errores de compilación” con ausencia de deuda técnica.

No se ha demostrado entrega FCM/APNs ni envío SMTP real, ni se ha compilado iOS
en este equipo Windows.

## Antes de publicar

1. Instalar el APK de prueba en Android y usar una cuenta de prueba autorizada.
2. Probar contraseña → correo → código (correcto, incorrecto y caducado), cuenta
   NewPass, cierre de sesión, sesión revocada desde web y regreso desde biometría.
3. Revisar ambos documentos y aceptar. Comprobar en web que se registra la
   aceptación en la cuenta/versión correcta.
4. Crear un ticket buscando inicio/final de SN. Para administración, comprobar
   cliente/sede/responsable y confirmar que no se ofrecen equipos de otra sede.
5. Enviar y responder un chat desde app y web, revisar el mismo historial,
   las notificaciones de BD y que MRV no pueda escribir.
6. Probar push en primer plano, segundo plano y app terminada, permiso denegado,
   preferencias desactivadas y cambio de cuenta; revisar el símbolo MR Solutions.
7. Probar cambio de correo sin código/código erróneo y con código correcto;
   confirmar que el correo anterior no cambia antes de verificar.
8. Confirmar reunión con HTTPS y modalidad de invitación por correo. En esta
   última enviar realmente la invitación desde el cliente de correo.
9. Configurar el certificado de firma propio en `android/key.properties`
   (no está presente en esta revisión). Release rechaza usar firma debug.
   Incrementar versión/build para la tienda y generar un AAB firmado.
10. En macOS, ejecutar las pruebas/build de iOS con Xcode, firma del propietario,
    capacidad Push y APNs configurado en Firebase; probar en iPhone físico.
11. Revisar privacidad/Data Safety, ID definitivo de aplicación y textos legales
    con el responsable del producto. No cambiar el ID de paquete sin coordinar
    su registro correspondiente en Firebase.

No es necesario editar PHP para instalar esta actualización móvil. Si falla
SMTP, una migración, la configuración privada o las credenciales FCM/APNs,
la corrección pertenece al entorno servidor y debe coordinarse con su responsable.
