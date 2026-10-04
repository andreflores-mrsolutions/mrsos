# Integración MRSoS app / PHP / Firebase / iOS

Actualizado: 8 de septiembre de 2026.

> Actualización del 11 de septiembre: el despliegue con gateway cambió las rutas
> expuestas. Consulta [Compatibilidad con Hostinger seguro](hostinger-security-compatibility.md)
> para el estado vigente; las referencias antiguas a getIndexData ya no aplican.

## Alcance y estado

Se conserva el diseño aprobado y se adapta Flutter a los contratos del código web
local de `MRSOS/mrsos-project`. No se editaron ni desplegaron PHP, no se importó
la base y no se realizaron escrituras ni envíos de prueba a producción.
El SQL `u140302554_mrsos2 (3).sql` se usó exclusivamente como referencia de esquema.

Esto es una integración local verificada con pruebas simuladas y compilación
Android debug, no una certificación de funcionamiento de producción.
La configuración del hosting, la entrega FCM/APNs, permisos por cuenta y la
compilación iOS requieren la validación manual descrita abajo.

## Sesión y contratos principales

Toda solicitud privada utiliza el mismo Dio, la cookie PHP y las cabeceras
`X-Requested-With: XMLHttpRequest` y `X-CSRF-Token` cuando corresponde.
El usuario y su alcance salen de `me.php`, no del usuario escrito en el login.
Los tokens CSRF, los tokens FCM y el identificador del dispositivo son conceptos
distintos; ninguno sustituye la autorización PHP.

| Área | Endpoint usado | Adaptación en Flutter |
| --- | --- | --- |
| Login | php/login.php + php/me.php | Formulario web y perfil/alcance canónicos; cambio obligatorio de contraseña |
| Dashboard | dashboard/api/tickets_list.php | Métricas meta.abiertos/accion/curso; acciones según rol |
| Detalle de ticket | dashboard/api/ticket_detail.php | accionActual, hojaServicio y datos actuales |
| Agenda Health Check | php/getIndexData.php | Sólo complemento; un fallo no bloquea los tickets |
| Catálogo de sedes/equipos | dashboard/api/ticket_catalog_sedes.php y ticket_catalog_equipos.php | Alcance del servidor; selección física por peId, no sólo eqId |
| Crear ticket | dashboard/api/ticket_create.php | csId, peId, eqId, criticidad, descripción y contacto; multipart |
| Health Check | dashboard/api/health_create.php | JSON con items de peId/eqId y duración/fecha/contacto |
| Logs | dashboard/api/logs_upload.php | files[]; hasta 10 archivos de máximo 25 MB; sin reenvío de archivos ya confirmados |
| Reuniones | dashboard/api/meet_get.php, meet_create.php, meet_accept.php | Tres alternativas; aceptar por mpId |
| Visitas | dashboard/api/visita_get.php, visita_create.php, visita_accept.php | Tres alternativas; aceptar por vpId |
| Propuestas internas | backend/api/meet_create.php y visita_propose.php | Contrato opciones; campos link/plataforma según rol |
| Folio | dashboard/api/visita_folio_upload.php | tiFolioEntrada, comentario, folioFile; máximo 10 MB |
| Encuesta | dashboard/api/encuesta_save.php / encuesta_skip.php | Calificación 1–5; omitir/cerrar con confirmación explícita |
| Pólizas/equipos | php/mis_equipos_resumen.php / mis_equipos_poliza.php | Total completo, no tamaño de la muestra de seis equipos |
| Hojas de servicio | backend/admin/api/hoja_servicio_list.php | Lista unificada y búsqueda local sobre hasta 500 hojas |
| PDF de hoja | backend/admin/api/hoja_servicio_download.php | Descarga autenticada y apertura nativa |
| PDF de póliza | php/policy_file.php | Sólo enlaces documents devueltos por el servidor; factura según permisos |
| Perfil | php/actualizar_perfil.php | Multipart y lectura posterior de me.php |
| Preferencias | php/me.php / guardar_preferencias.php | Conserva tema y todas las categorías compartidas |
| Bandeja | php/notifications_list.php / notification_read.php | Hasta 80 recientes, lecturas y contador global en la BD |
| Diagnóstico push | php/notification_status.php | Estado del servidor y del registro móvil |
| Dispositivo FCM | php/notif_token_guardar.php / notif_token_eliminar.php | token, platform, deviceId; el usuario lo determina PHP |

Las mutaciones no se repiten automáticamente tras timeout/419, para evitar tickets
o propuestas duplicados. Un 419 renueva la protección al siguiente intento.
Un 401 privado limpia la sesión y lleva al login; un login incorrecto muestra
el error de credenciales. Las respuestas de una sesión anterior se descartan.
Los PDF temporales propios se limpian al salir. No se envían cookies ni CSRF a
orígenes externos ni se abre una descarga privada en un navegador sin sesión.

Los horarios de propuestas se envían como fecha/hora sin zona, como la web:
capturar la hora acordada con la sede. No hay conversión automática de zona.

## Notificaciones: qué está preparado

- Firebase del proyecto mrsos-31341, con los identificadores ya existentes.
- Android: plugin Google Services, google-services.json, POST_NOTIFICATIONS,
  canal mrsos_alerts y un icono monocromático.
- iOS: GoogleService-Info.plist incluido en Resources, remote-notification,
  capacidad Push, entitlements y delegado de Firebase Messaging.
- Registro por UUID persistente del dispositivo. Se conserva ese UUID al salir
  y se envía el token nuevo al renovarse; no se manda un usId elegido por Flutter.
- Permiso después del acceso a la cuenta; si está denegado se indica cómo
  habilitarlo. iOS espera el token APNs antes de solicitar el token FCM.
- Foreground: presentación local. Background/cerrada: presentación del sistema
  para mensajes notification. El manejador background no duplica la alerta ni
  abre otra sesión PHP.
- Tocar una alerta abre la bandeja sólo después de iniciar/desbloquear la sesión.
  El PHP existente envía avisos genéricos; el detalle se consulta autenticado.
- Lecturas y preferencias usan la BD compartida. La bandeja no se inventa a partir
  de los mensajes FCM. El contador se consulta al volver y periódicamente cuando
  la app está activa. No es un servicio de sondeo permanente en background.
- Salir elimina primero el registro de este dispositivo con la sesión PHP aún
  vigente. Si esa baja no se puede confirmar, se muestra error y se permite
  reintentar el cierre; no se da una confirmación falsa de baja.

## Hosting / Firebase: validación pendiente

El JSON de cliente NO es una cuenta de servicio y NO habilita por sí solo el
envío del servidor. El PHP existente ya soporta Firebase HTTP v1 mediante:

- MRS_FCM_PROJECT_ID = mrsos-31341.
- MRS_FCM_SERVICE_ACCOUNT = ruta privada a la cuenta de servicio correspondiente.
- Extensiones PHP cURL/OpenSSL y permisos de envío adecuados en Firebase.

No se abrieron, copiaron ni incorporaron claves privadas del servidor a la app.
La existencia y validez de esa configuración en producción NO se verificó.
El usuario/administrador debe revisar, con su sesión, el estado en la bandeja:

- mobileConfigured debe ser true.
- mobileDatabaseReady y databaseReady deben ser true.
- El estado local debe indicar que el dispositivo está registrado.
- mobileDevices es un total de la cuenta, no una prueba de entrega al teléfono.
- Un envío aceptado por Firebase tampoco confirma que el sistema operativo
  haya mostrado la alerta.

La configuración APNs de Firebase necesita una clave/certificado Apple válido
para la aplicación iOS. Ver [configuración oficial FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
No pegar claves .p8, service accounts ni contraseñas en el chat ni en el repositorio.

## Preparación iOS en una Mac

El código queda preparado para iOS 15 o superior (mínimo de firebase_core 4.14).
Windows no permite ejecutar Xcode, CocoaPods ni firmar/verificar el binario iOS.

1. Llevar el proyecto completo y pubspec.lock a una Mac con Flutter, Xcode y CocoaPods.
2. Ejecutar desde la raíz de la app:

   ```sh
   flutter pub get
   cd ios
   pod install
   open Runner.xcworkspace
   ```

3. En Runner / Signing & Capabilities seleccionar el Apple Development Team del
   propietario y comprobar Push Notifications y Background Modes / Remote notifications.
4. Confirmar el bundle ID. Se conservó com.example.mrsos porque es el de la
   configuración existente. Antes de publicar, confirmar el identificador propio
   registrado en Apple y Firebase; si cambia, regenerar conjuntamente los archivos
   de Firebase y los identificadores nativos. No cambiar sólo uno.
5. Comprobar en Firebase la clave APNs y su Team ID/Key ID, sin exponer la clave.
6. Conectar un iPhone físico, confiar en el desarrollador/habilitar Developer Mode
   cuando corresponda y ejecutar `flutter run` desde la raíz.
7. Permitir notificaciones, iniciar sesión y verificar el registro.
8. Para distribución, probar un archive/TestFlight firmado por el propietario.

Debug usa aps-environment=development; Release/Profile usa production.
Xcode y el perfil de aprovisionamiento deben incluir esa capacidad.
La compilación, firma y entrega real APNs permanecen pendientes.
Ver también [recepción y estados de la app](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

## Android y firma de distribución

Se generó un APK de depuración, no un paquete publicable en Play Store:

`build/app/outputs/flutter-apk/app-debug.apk`

El entorno probado usa Flutter 3.47.2, Java 21, Gradle 8.14.3, AGP 8.11.1 y
Kotlin 2.2.20. Flutter avisa que esas versiones Gradle/AGP/Kotlin tendrán que
actualizarse próximamente; no se omitieron las validaciones del build.

Release ya no recurre silenciosamente a la firma debug.
Configurar android/key.properties a partir de android/key.properties.example,
usando el keystore del propietario, fuera del control de versiones. Las rutas
relativas de storeFile se resuelven desde android/app; puede usarse una ruta
absoluta con barras normales. La validación falla claramente si falta la firma.
No se creó ni reemplazó el certificado de una app ya distribuida.
Guía: [firma y publicación Android](https://docs.flutter.dev/deployment/android).

Después de configurar y verificar la identidad/firma:
`flutter build appbundle --release`.

No se instaló ni desinstaló ninguna app del teléfono durante este trabajo.
Si aparece INSTALL_FAILED_UPDATE_INCOMPATIBLE, usar el certificado de la
instalación anterior o acordar una instalación separada. Desinstalar borra datos
locales y requiere decisión explícita del usuario.

## Límites del servidor detectados (sin modificar PHP)

- php/equipo_detalle.php calcula sedes permitidas pero no aplica ese conjunto al
  WHERE, y el JOIN clientes es tautológico (cl.clId = cl.clId). Flutter ahora
  comprueba antes que peId pertenezca al catálogo autorizado de la póliza y toma
  de éste el nombre correcto. Esto NO repara la autorización del servidor:
  requiere revisión del backend antes de considerar la solución endurecida.
- La lista moderna de hojas filtra clientes CLI por clId, no por sede/zona.
  La app no debe inventar que ese filtro sea más restrictivo. Acordar con el dueño
  si esa visibilidad coincide con las reglas de negocio; corregir PHP requeriría
  autorización aparte.
- El catálogo de creación requiere clId en la sesión incluso para roles MR.
  Las cuentas internas sin cliente seleccionado reciben “Sesión sin cliente”.
  No se implementó un cambio arbitrario de cliente ni se eleva el alcance local.
- El resumen de pólizas devuelve seis equipos y hasta diez tickets de muestra.
  El total de equipos se consulta completo; los tickets de cada tarjeta siguen
  siendo una vista previa, no una métrica histórica.
- El listado actual de tickets no expone csId. Los filtros visuales usan una
  clave estable por cliente/zona/nombre de sede; nunca se manda como autorización.
- Las hojas actuales no exponen una clasificación confiable HS-T/HS-HC:
  se presentan juntas y no se etiquetan por una suposición.
- El SQL compartido no incluye pcHealthCheck en polizascliente. El helper
  policy_health.php del servidor contempla preparar ese campo al atender el
  catálogo. No se ejecutó ese helper ni se aplicó una migración desde aquí.
- Pantallas/servicios legacy sin acceso desde los flujos principales se conservan
  para no borrar trabajo. No se certifica paridad de todo el panel administrativo.

## Pruebas ejecutadas y aceptación pendiente

Automatizadas: 67 pruebas aprobadas con respuestas simuladas, sin producción.
Incluyen login/cookies/CSRF, 401/419, respuesta tardía después del logout,
scope almacenado, rechazo de origen externo, catálogo por peId, métricas meta,
contratos de propuestas/confirmación/encuesta, documentos, registro Android/iOS,
rotación del token por deviceId y diseño con fuentes ampliadas.
No son pruebas de entrega Firebase ni ejecutan los PHP o MySQL reales.

También: compilación APK debug, análisis Dart sin errores de compilación,
validación XML de plist/manifest y comprobación de whitespace del diff.
Persisten avisos de lint/deprecaciones del proyecto; el análisis no es “cero avisos”.

Antes de usar con clientes, ejecutar con cuentas/dispositivos de prueba autorizados:

| Caso | Resultado esperado |
| --- | --- |
| ADMIN_GLOBAL, ADMIN_ZONA, ADMIN_SEDE | Mismo alcance/métricas que la web para esa cuenta |
| Crear ticket y HC con equipos del mismo modelo | Se conserva el peId/serie correcta; una creación por acción |
| Logs/folio, tamaño inválido y desconexión | Error visible, sin afirmar una carga que no ocurrió |
| Proponer en web / confirmar en app y viceversa | Misma propuesta y estado; enlace de reunión accesible |
| Encuesta y documentos | Cierre persistido; PDF real accesible sólo con sesión válida |
| Permiso concedido/denegado | Registro o mensaje accionable, sin bloqueo del resto de la app |
| Aviso con app abierta, en background y cerrada | Una presentación; tap pasa por sesión y abre bandeja |
| Lectura desde web y desde app | Misma marca leída y contador global al refrescar |
| Preferencias y categorías | Cambio compartido y sólo eventos habilitados |
| Dos teléfonos / renovación token | Dispositivos independientes, sin duplicar filas del mismo UUID |
| Logout A / login B en un teléfono | Ningún aviso de A en B; baja y reasignación verificadas |
| Sesión vencida / red ausente | Error y reautenticación; ninguna acción se reenvía automáticamente |
| Android release e iOS TestFlight | Firma del propietario y push en entorno de distribución |

En iOS tras forzar el cierre y en Android tras forzar detención desde Ajustes,
el sistema puede exigir volver a abrir la app para reanudar ciertos mensajes.
No prometer recepción garantizada en estados restringidos por el sistema operativo.
