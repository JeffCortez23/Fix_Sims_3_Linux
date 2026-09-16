# 💎 Fix Sims 3 Linux (Edición Comunitaria)

Herramienta automatizada todo-en-uno para instalar expansiones/accesorios, activar registros y optimizar el rendimiento de **Los Sims 3 en Linux y Steam Deck** (compatible con Steam, Heroic, Lutris, Bottles y Wine).

Desarrollado con ❤️ por **Jeff Cortez** para la comunidad jardinera.

---

## 🚀 Instalación y Uso Rápido (1 solo comando)

Abre tu terminal en Linux y pega este comando:

```bash
curl -sSL https://raw.githubusercontent.com/JeffCortez23/Fix_Sims_3_Linux/main/fix_sims_3_linux.sh -o fix_ts3.sh && bash fix_ts3.sh
```

---

## ✨ Características Principales

* 📦 **Instalador Inteligente de DLCs:**
  * Soporta archivo único **All-in-One (.zip / .rar / .7z)**, **packs individuales** o carpetas extraídas.
  * Mueve y organiza automáticamente cada paquete en la raíz del juego (`EP01` a `EP11` y `SP01` a `SP09`).
  * Muestra barra y porcentaje de descompresión en tiempo real.
* 🔓 **Activador Universal de DLCs (Inyección Wine / Proton):**
  * Inyecta las claves de registro oficiales (`Sims(Steam)` y `Wow6432Node`) en `system.reg`.
  * El Launcher oficial y el juego reconocen todas las 11 expansiones y 9 accesorios como legítimos.
* ⚡ **Optimización Ultra-Smooth & Gráficos:**
  * **Parche de VRAM & GPUs Modernas:** Corrige `GraphicsRules.sgr` para desbloquear 2048 MB / 4096 MB de VRAM y corregir errores de sombras en AMD Radeon / NVIDIA RTX / Intel Arc.
  * **Resolución 1080p Nativa @ 60 FPS:** Configuración automática para pantallas modernas.
  * **Soporte Smooth Patch:** Inyección de DllOverride (`dinput8.dll`) para juego ultra-fluido sin saltos de cámara.
* 🔍 **Diagnóstico y Health Check:**
  * Verificador visual en tiempo real de los 20 DLCs instalados y estado del registro de Proton.
* 🧹 **Limpiador de Caché de Los Sims 3:**
  * Purga automática de `CASPartCache`, `compositorCache`, `simCompositorCache`, `scriptCache` y miniaturas para evitar cargas infinitas o sims invisibles.

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

## 🎮 Compatibilidad
* **Sistemas:** Arch Linux, SteamOS (Steam Deck), Ubuntu, Debian, Fedora, Manjaro, openSUSE.
* **Lanzadores:** Steam (AppID 47890), Heroic Games Launcher, Lutris, Bottles, Wine puro.
