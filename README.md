# 💎 Fix Sims 3 Linux 🐧 (v2.2)

¡Hola! Si juegas a **Los Sims 3 en Linux o Steam Deck** (mediante **Steam, Lutris, Bottles, Heroic o Wine**), sabes que hacer funcionar las expansiones, el launcher oficial, lograr que el juego reconozca tu tarjeta gráfica moderna y eliminar los tirones o lag suele ser un verdadero reto.

**Fix Sims 3 Linux** es una herramienta automatizada todo-en-uno diseñada para instalar, activar, diagnosticar y optimizar **Los Sims 3** en cualquier distribución de Linux o consola Steam Deck.

---

## 🚀 Instalación y Uso Rápido (1 solo comando)

Abre tu terminal favorita en Linux o el modo escritorio de tu Steam Deck y ejecuta:

```bash
curl -sSL https://tinyurl.com/fixsims3linux -o fix_ts3.sh && bash fix_ts3.sh
```

> **💡 Consejo:** También puedes ejecutarlo directamente en memoria con:
> ```bash
> curl -sSL https://tinyurl.com/fixsims3linux | bash
> ```

---

## ✨ Funciones Principales (v2.2)

* ⚡ **Optimización Inteligente de Gráficos & Hardware:**
  * **Detección Directa del Kernel:** Detecta físicamente tu GPU real (AMD Radeon, NVIDIA GeForce, Intel Arc/Iris) y procesador sin requerir emuladores ni capas de Windows.
  * **VRAM Dinámica:** Analiza la memoria RAM física de tu equipo y calibra la memoria de texturas a 1024 MB, 2048 MB o 4096 MB (`textureMemorySizeOK true`) en `GraphicsRules.sgr`.
  * **Fix de Sombras en GPUs Modernas:** Desactiva automáticamente el bug clásico de sombras negras cuadradas pixeladas en Sims (`shadowMapDisabled false`).
  * **Resolución 1080p Nativa @ 60 FPS:** Configuración precalibrada en `Options.ini` a pantalla completa.
  * **Smooth Patch (LazyDuchess) + Wine DllOverrides:** Inyecta automáticamente las librerías del parche de fluidez (`TS3Patch.asi`, `ddraw.dll`, `wininet.dll`) y registra los overrides obligatorios en `user.reg` (`dinput8`, `ddraw`, `wininet` = `native,builtin`) para que Proton realmente las cargue.

* 📂 **Acceso Directo a la Carpeta Mods:**
  * Localiza la carpeta `Electronic Arts/The Sims 3/Mods` dentro del prefijo de tu juego y la abre con 1 clic en tu explorador de archivos nativo (Dolphin, Nautilus, Thunar, etc.). Crea automáticamente la estructura `Packages/` y `Overrides/` si no existen.

* 📦 **Instalador Inteligente de DLCs & Mundos Store:**
  * Soporta archivos únicos **All-in-One (.zip, .rar, .7z)**, **paquetes sueltos** y carpetas anidadas (`The Sims 3/`, `all in one/`).
  * **Soporte Worlds & Store Updates:** Extrae automáticamente los 442 `.Sims3Pack` a la carpeta `Downloads/` del juego para el Launcher y los parches `.package` a `Mods/Packages/`.
  * **Parche Anti-Lag Isla Paradiso:** Si tienes el archivo de corrección de Isla Paradiso, reemplaza el mundo por la versión sin atascos ni congelamientos.
  * Muestra barra de progreso visual con porcentaje en tiempo real.

* 🔓 **Activación Universal de DLCs (Wine/Proton + EA App):**
  * Inyección nativa en el registro de Wine/Proton (`system.reg` y `user.reg`) bajo las claves oficiales `Software\Sims(Steam)` y `Wow6432Node`.
  * El lanzador oficial y el juego reconocen todas las 11 expansiones y 9 accesorios como compras legítimas.
  * Vinculación automática de los 11 Mundos de la Store (`Monte Vista`, `Aurora Skies`, `Roaring Heights`, `Dragon Valley`, etc.) directamente en `InstalledWorlds` y en la base del juego.
  * Compatibilidad dual con EA DLC Unlocker v3.5.0 si ejecutas el juego mediante EA Desktop.

* 🔍 **Diagnóstico & Health Check de Integridad:**
  * Escanea tu instalación y lista de forma clara los 20 DLCs oficiales (EP01 a EP11 y SP01 a SP09), indicando su estado en disco y la validez del registro en Wine/Proton.

* 🧹 **Limpiador de Caché del Juego:**
  * Resuelve problemas de pantallas de carga infinita o Sims corruptos purgando de forma segura los archivos temporales (`CASPartCache.package`, `compositorCache.package`, `scriptCache.package`, `simCompositorCache.package`, `socialCache.package` y miniaturas), **sin tocar tus partidas guardadas (`Saves`), Mundos ni Mods**.

* 🌐 **Auto-Descargador del EA DLC Unlocker:**
  * Descarga y valida mediante hash SHA-256 los binarios oficiales más recientes de Anadius / Tiesas Archives.

* 🖥️ **Creador de Acceso Directo (.desktop):**
  * Crea un lanzador temático con icono oficial de Plumbob verde en tu menú de aplicaciones y en el Escritorio.

* 🔪 **Forzar Cierre de Procesos Colgados:**
  * Mata al instante procesos zombies (`TS3W.exe`, `Sims3Launcher.exe`, `steam-runtime-reaper`, `EADesktop.exe`) cuando Steam se queda trabado en "Detener" o "Ejecutando".

* 🎮 **Soporte Multi-Lanzador:**
  * Detección y compatibilidad con **Steam** (Nativo, Flatpak, Snap, MicroSD en Steam Deck), **Heroic Games Launcher**, **Lutris**, **Bottles** y Wine personalizado.

---

## 📋 Requisitos

1. **Los Sims 3** instalado en Steam, Lutris, Bottles, Heroic o Wine.
2. **Herramienta 7z / p7zip**:
   * **Arch / Manjaro / SteamOS / CachyOS:** `sudo pacman -S p7zip`
   * **Ubuntu / Debian / Linux Mint:** `sudo apt install p7zip-full`
   * **Fedora:** `sudo dnf install p7zip p7zip-plugins`

---

## 🖥️ Menú del Gestor

```text
╭──────────────────────────────────────────────────────────────╮
│         💎 GESTOR DE LOS SIMS 3 (LINUX EDITION) v2.2         │
│       Steam • Steam Deck • Lutris • Bottles • Heroic         │
╰──────────────────────────────────────────────────────────────╯

  [1] 📦  Instalar / Mover DLCs al juego (ZIP All-in-One, Sueltos, Lotes)
  [2] 🔓  Activar DLCs (Inyección Wine/Proton y EA App)
  [3] ⚡  Optimización de Gráficos & GPU (Auto-detectar Hardware & VRAM)
  [4] 📂  Abrir carpeta Mods del juego (Packages / CC / Mods)
  [5] 🔍  Diagnóstico de DLCs e Integridad (Health Check)
  [6] 🧹  Limpiar Caché del Juego (Solución Carga Infinita)
  [7] 🌐  Descargar / Actualizar EA DLC Unlocker (Auto)
  [8] 🖥️   Crear Acceso Directo (.desktop / Steam Deck)
  [9] 🔪  Forzar cierre de procesos colgados (Fix Sims 3 / Steam / EA)
  [10] ⚙️   Reconfigurar rutas del script / Lanzador
  [11] ℹ️  Acerca de & Changelog
  [0] 🚪  Salir
```

---

## 💡 PRO-TIP: Crea un atajo rápido (Alias) ⚡

Para abrir el gestor desde cualquier terminal escribiendo simplemente `fixsims3`:

### 🐧 Para Bash o Zsh (La mayoría de distros y Steam Deck)
1. Abre tu archivo de configuración:
   ```bash
   nano ~/.bashrc   # o nano ~/.zshrc si usas Zsh
   ```
2. Añade al final:
   ```bash
   alias fixsims3='bash /ruta/hacia/tu/fix_sims_3_linux.sh'
   ```
3. Guarda los cambios y recarga tu terminal:
   ```bash
   source ~/.bashrc   # o source ~/.zshrc
   ```

### 🐟 Para Fish Shell
```bash
alias fixsims3 "bash /ruta/hacia/tu/fix_sims_3_linux.sh"
funcsave fixsims3
```

---

## 📋 Catálogo Oficial Soportado (20 DLCs)

### 🌟 Expansiones (11)
* **EP01:** Trotamundos *(World Adventures)*
* **EP02:** Triunfadores *(Ambitions)*
* **EP03:** Al Caer la Noche *(Late Night)*
* **EP04:** ¡Menuda Familia! *(Generations)*
* **EP05:** ¡Vaya Fauna! *(Pets)*
* **EP06:** Salto a la Fama *(Showtime)*
* **EP07:** Criaturas Sobrenaturales *(Supernatural)*
* **EP08:** Y las Cuatro Estaciones *(Seasons)*
* **EP09:** Movida en la Facultad *(University Life)*
* **EP10:** Aventura en la Isla *(Island Paradise)*
* **EP11:** Hacia el Futuro *(Into the Future)*

### 🎨 Packs de Accesorios (9)
* **SP01:** Diseño y Tecnología *(High-End Loft)*
* **SP02:** ¡Quemando Rueda! *(Fast Lane)*
* **SP03:** Patios y Jardines *(Outdoor Living)*
* **SP04:** Vida en la Ciudad *(Town Life)*
* **SP05:** Suite de Ensueño *(Master Suite)*
* **SP06:** Katy Perry Dulce Tentación *(Sweet Treats)*
* **SP07:** Diesel *(Diesel Stuff)*
* **SP08:** Los 70, 80 y 90 *(70s, 80s, & 90s Stuff)*
* **SP09:** De Cine *(Movie Stuff)*

---

## 📜 Historial de Cambios (Changelog)

### 🚀 Versión 2.2 (Actual)
* **📂 Abrir Carpeta Mods:** Acceso directo e instantáneo a la carpeta `Mods/Packages` mediante `xdg-open` en el gestor de archivos nativo.
* **🏛️ Soporte Worlds & Store Updates:** Auto-extracción de los 442 archivos `.Sims3Pack` a `Downloads/` y fixes `.package` a `Mods/Packages/`.
* **🌐 TinyURL Oficial:** Comando rápido de instalación y ejecución en una sola línea.

### 🚀 Versión 2.1
* **🌐 EA DLC Unlocker Auto-Downloader:** Descarga oficial verificada v3.5.0 con generación de `g_LOS SIMS 3.ini`.
* **🔓 Soporte Dual:** Inyección nativa en Wine/Proton (`system.reg`) y soporte opcional para EA Desktop.
* **🌍 Rutas Dinámicas:** Soporte multi-entorno para Steam Deck (MicroSD), Lutris, Bottles y Heroic.

### 🚀 Versión 2.0
* **🎮 Detección de Hardware & VRAM Dinámica:** Calibración automática de `GraphicsRules.sgr` con perfiles de 1GB, 2GB y 4GB de VRAM.
* **🏝️ Isla Paradiso Fix:** Reemplazo automático del mundo corregido anti-lag.
* **📦 Smooth Patch & CleanUI:** Despliegue de parches de fluidez y registro de Wine DllOverrides.
* **🎨 Interfaz TUI:** Menús centrados con colores estéticos.
* **🖥️ Acceso Directo:** Creación de `.desktop` e icono de Plumbob.

### 📦 Versión 1.0
* Primera versión comunitaria con inyección básica de claves de registro para las 11 expansiones y 9 accesorios.

---

## 🤝 Créditos y Agradecimientos

* **Desarrollo:** Jeff Cortez ([GitHub](https://github.com/JeffCortez23))
* **Smooth Patch & Mejoras de Rendimiento:** LazyDuchess
* **EA DLC Unlocker:** Anadius & Tiesas Archives
* **Comunidad Jardinera:** A todos los jugadores que disfrutan de Los Sims en Linux y Steam Deck.
