# MR SOS · Actualización visual

Alcance: interfaz móvil y compatibilidad del entorno Android. Se conserva el login, los contratos PHP y la lógica de negocio existente.

Dirección: azul marino, superficies claras, acentos turquesa, tipografía Manrope, contenido prioritario y navegación accesible.

## Qué cambió

- Inicio reconstruido: resumen, accesos para crear tickets y revisiones, seguimiento y sedes. Los indicadores reciben datos del servicio existente; no hay cifras de demostración en la app.
- Navegación de cinco pestañas: Inicio, Tickets, Equipos, Archivos y Personas. Cada pestaña conserva su estado y se crea cuando se visita.
- Equipos con tarjetas verticales compactas, número de serie, sede y cobertura. Las pólizas vencidas ya no se presentan visualmente como vigentes.
- Tickets con acceso directo para crear, búsqueda y acciones existentes. El detalle destaca la etapa actual sin un porcentaje de avance inferido.
- Documentos y personas con búsquedas más claras y tarjetas con respuesta visual al tocar. La búsqueda de documentos utiliza el texto introducido.
- Perfil con datos agrupados, edición visible y alternativa visual cuando la fotografía no carga.
- Formularios de soporte y Health Check con encabezados simplificados, selectores adaptables y adjuntos sin recortes con letra grande.
- Componentes compartidos: encabezados, tarjetas Material, estados vacíos, búsqueda y etiquetas. Las animaciones de carga se detienen al terminar y respetan la preferencia de reducir movimiento.

Se conserva el diseño del login. No se cambiaron PHP, BD, contratos de sesión, permisos de negocio ni la integración push en esta entrega.

## Vistas previas

Son capturas de widgets Flutter reales con **datos ficticios**, no información de producción. Las imágenes de equipos usan el icono alternativo porque las pruebas bloquean la red.

- [Inicio y navegación](design/previews/inicio-navegacion.png)
- [Tickets](design/previews/tickets.png) y [detalle](design/previews/detalle-ticket.png)
- [Equipos](design/previews/equipos.png)
- [Documentos](design/previews/documentos.png) y [personas](design/previews/personas.png)
- [Perfil](design/previews/perfil.png)
- [Nuevo ticket](design/previews/nuevo-ticket.png) y [Health Check](design/previews/health-check.png)

## Entorno Android

Flutter está configurado con JDK 21 en esta computadora:

```powershell
flutter config --jdk-dir="C:\Users\darwi\AppData\Local\Programs\MRSoS\jdk-21"
flutter build apk --debug
flutter run
```

Esta preferencia de Flutter es global para el usuario. No se modificó JAVA_HOME ni el Java de Android Studio. Conviene reiniciar VS Code/Android Studio para que sus procesos lean la configuración.

El proyecto usa Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20 y bytecode JVM 17. La [matriz oficial de Gradle](https://docs.gradle.org/current/userguide/compatibility.html) indica que Java 21 puede ejecutar Gradle desde 8.5, mientras que Java 25 necesita Gradle 9.1 o posterior. No se migró todo el proyecto a AGP 9 para resolver este fallo. Flutter aún emite avisos de actualización futura de Gradle/AGP/Kotlin; no impiden esta compilación.

## Validación

```powershell
flutter test
flutter test --dart-define=CAPTURE_DESIGN=true --timeout 40s
```

- 31 pruebas aprobadas: pruebas existentes, acciones del inicio, estados de carga/error/vacío, navegación, consulta de documentos, formularios, perfil y detalle.
- Inicio probado a 320, 390 y 768 píxeles, con escalas de texto 1.0, 1.6 y 2.0. Pestañas a 320/390 píxeles y escalas 1.0/1.6. Formularios, detalle y perfil a 390/1.0 y 320/1.6.
- APK debug generado en `build/app/outputs/flutter-apk/app-debug.apk`.
- Sin errores de análisis en las pantallas modificadas. Se conservan avisos informativos anteriores. El análisis global también detecta un archivo Firebase heredado no utilizado (`lib/firebase_options.dart`) que referencia una dependencia ausente; no se reactivó Firebase dentro de un cambio limitado al diseño.
- La instalación de prueba en SM S928B fue rechazada por Android con `INSTALL_FAILED_UPDATE_INCOMPATIBLE`: la app instalada tiene otra firma. **No se desinstaló ni se borraron datos**. Se necesita la clave original o autorización para desinstalar la versión existente antes de probar este APK.
- No se verificó iOS en Xcode ni en un dispositivo Apple. Tampoco se enviaron solicitudes o notificaciones de prueba a producción.
