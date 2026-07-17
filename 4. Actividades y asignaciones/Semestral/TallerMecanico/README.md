# Taller Mecánico — App de Gestión

Proyecto Final, Desarrollo de Software para Plataforma Móvil — UTP, Grupo 1SF241.

## Descripción
App Android para talleres mecánicos. El mecánico hace check-in del vehículo con foto y checklist,
sigue el estado del servicio en una línea de tiempo (Recibido → Diagnóstico → Reparación → Listo →
Entregado), gestiona el presupuesto (repuestos y mano de obra con cálculo automático) y consulta
el historial de servicios por placa.

## Stack técnico
- **Android / Kotlin**, Jetpack Compose, Material 3
- **Arquitectura**: MVVM (ViewModel + StateFlow, sin lógica en las pantallas)
- **Backend**: Supabase (Postgres + Auth con JWT + Storage para fotos)
- **Sensor del dispositivo**: GPS (ubicación del check-in, vía FusedLocationProviderClient)
- **Networking**: cliente oficial de Supabase (Postgrest, GoTrue) + Retrofit disponible para
  endpoints propios adicionales
- **Hosting sugerido**: Vercel (si se agrega un backend propio aparte de Supabase)

## Cómo cumple las condiciones del proyecto
| Requisito | Dónde está |
|---|---|
| Login | `ui/login` |
| Registro (si no existe usuario) | `ui/register` |
| Seguridad JWT con expiración | Supabase Auth (`AuthRepository`) + `util/SessionManager.kt` |
| Logout | Botón en `DashboardScreen` |
| Funcionalidad del negocio | Check-in, timeline, presupuesto, historial |
| Dashboard con informes/gráficos | `ui/dashboard` (gráfico de barras propio con Canvas) |
| API con GET/POST/PUT/PATCH | Supabase Postgrest expone estos métodos sobre las tablas |
| Uso de un sensor | GPS en `sensor/LocationHelper.kt`, usado en el check-in |

## Configuración antes de correr el proyecto
1. Crear un proyecto en [supabase.com](https://supabase.com).
2. Ir a **SQL Editor** y ejecutar el archivo `supabase/schema.sql` de este repo.
3. Copiar `local.properties.example` a `local.properties` y llenar:
   ```
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu-anon-key
   sdk.dir=/ruta/a/tu/Android/Sdk
   ```
4. Abrir el proyecto en Android Studio (Koala o más reciente), sincronizar Gradle y correr.

## Estructura del proyecto
```
app/src/main/java/com/tallermecanico/app/
├── data/
│   ├── model/          # Cliente, Vehiculo, Orden, Presupuesto, ItemPresupuesto, Usuario
│   ├── repository/      # AuthRepository, VehiculoRepository, OrdenRepository, PresupuestoRepository
│   └── SupabaseClientProvider.kt
├── sensor/              # LocationHelper.kt (GPS)
├── util/                # SessionManager.kt (token JWT)
├── ui/
│   ├── theme/           # Colores, tipografía y formas propias
│   ├── navigation/      # NavGraph y rutas
│   ├── components/      # Botones, campos y tarjetas reutilizables
│   ├── login/ register/ dashboard/ checkin/ timeline/ presupuesto/ historial/
├── MainActivity.kt
└── TallerApplication.kt
```

## Sugerencia de reparto para 6 integrantes
1. **Auth y sesión** — Login, Registro, `AuthRepository`, `SessionManager`
2. **Check-in** — pantalla, cámara, sensor GPS, `VehiculoRepository`
3. **Timeline y estados** — `TimelineScreen`, `OrdenRepository`, trigger SQL de estados
4. **Presupuesto** — cálculo de repuestos/mano de obra, `PresupuestoRepository`
5. **Dashboard y gráficos** — `DashboardScreen`, `GraficoBarras`, vista SQL de conteo por estado
6. **Historial, base de datos y documentación** — `HistorialScreen`, `schema.sql`, README, apoyo en
   la presentación (bloque contractual: costo, público objetivo, arquitectura general)

## Notas
- El token JWT lo emite y valida Supabase Auth de forma nativa; `SessionManager` guarda la
  expiración localmente para cerrar sesión automáticamente si vence.
- El gráfico del dashboard está dibujado con `Canvas` propio (sin librería externa) para mantener
  el proyecto liviano.
- Falta conectar un flujo de subida real de la foto a Supabase Storage (`storage-kt`) — por ahora
  `onFotoTomada` guarda un marcador local; es buen punto de mejora para el sprint técnico.
