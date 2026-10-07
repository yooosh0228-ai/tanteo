# Tanteo

Marcador de pádel para Apple Watch con app compañera de iPhone. Tocas la mitad del reloj del equipo que ganó el punto y listo: el iPhone muestra el marcador en vivo y guarda el historial.

## Qué hace

**En el reloj**
- Dos botones grandes, uno por equipo: toca el que ganó el punto.
- Vibra distinto al ganar un punto, un juego o un set.
- Deshacer el último punto (botón arriba a la izquierda).
- Puntito amarillo en el equipo que saca; se puede corregir desde "…".
- Al elegir las reglas: punto de oro o ventaja, a 1 set o al mejor de 3, y súper tie-break a 10 en el tercero.

**En el iPhone**
- Marcador en vivo estilo TV (sets, juegos y puntos) que se actualiza solo desde el reloj.
- Se puede sumar puntos también desde el teléfono.
- Nombres de los equipos (se escriben aquí y aparecen en el reloj).
- Historial con resultado, sets, puntos ganados y duración.

**Otros deportes:** el modo "Por puntos" sirve para vóleibol, ping-pong, bádminton o cualquier juego que se cuente hasta un número, con o sin diferencia de dos.

## Cómo está armado

| Carpeta | Qué hay |
|---|---|
| `ScoreKit/` | El motor de reglas (pádel y por puntos), con pruebas automáticas. Sin pantallas. |
| `Shared/` | Lo que usan las dos apps: sincronización reloj ↔ iPhone (WatchConnectivity) y guardado. |
| `WatchApp/` | Pantallas del reloj. |
| `iOSApp/` | Pantallas del iPhone. |
| `project.yml` | Descripción del proyecto de Xcode (se genera con XcodeGen). |

Cada vez que se sube un cambio, GitHub Actions corre las pruebas y compila las dos apps en una Mac en la nube (pestaña **Actions** del repo).

## Instalar en el reloj

Hace falta la cuenta de Apple Developer (US$99 al año). Con ella:
1. Poner el Team ID en `DEVELOPMENT_TEAM` dentro de `project.yml`.
2. Crear la app en App Store Connect con el identificador `com.visionstudios.tanteo`.
3. Activar la subida automática a TestFlight en GitHub Actions.
4. Instalar TestFlight en el iPhone, instalar Tanteo y, desde su página en TestFlight, instalarla en el Apple Watch.

Con una Mac a mano también se puede: `brew install xcodegen && xcodegen generate`, abrir `Tanteo.xcodeproj` y darle Run con el iPhone conectado.
