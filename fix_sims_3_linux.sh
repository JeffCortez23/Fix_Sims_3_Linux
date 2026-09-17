#!/usr/bin/env bash

# ==============================================================================
#   💎 Fix Sims 3 Linux (Edición Comunitaria) v2.0
#   Soporta Steam, Steam Deck, Lutris, Bottles, Heroic & Wine
#   Compatible con Juego Base Steam, EA App y versiones Standalone
#   Desarrollado por Jeff Cortez (github.com/JeffCortez23)
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="$HOME/.config/sims3_gestor.conf"
UNLOCKER_STORE="$HOME/.local/share/sims3_unlocker"
ICON_PATH="$HOME/.local/share/icons/fix-sims-3.svg"
VERSION="2.2"

# --- UTILIDADES DE CENTRADO Y ESTILO TUI ---
WIDTH=64

obtener_padding() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    [ "$cols" -lt "$WIDTH" ] && cols="$WIDTH"
    local pad=$(( (cols - WIDTH) / 2 ))
    printf '%*s' "$pad" ''
}

# --- RUTAS CANDIDATAS PREDETERMINADAS ---
STEAM_PATHS=(
    "$HOME/.local/share/Steam"
    "$HOME/.steam/steam"
    "$HOME/.steam/root"
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
    "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
)

LUTRIS_PATHS=(
    "$HOME/Games"
    "$HOME/Games/lutris"
    "$HOME/.var/app/net.lutris.Lutris/data/lutris/runners/wine"
)

BOTTLES_PATHS=(
    "$HOME/.local/share/bottles/bottles"
    "$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles"
)

HEROIC_PATHS=(
    "$HOME/Games/Heroic/Prefixes"
    "$HOME/.var/app/com.heroicgameslauncher.hgl/config/heroic/Prefixes"
)

# --- BASE DE DATOS OFICIAL DE DLCS (LOS SIMS 3) ---
obtener_nombre_dlc() {
    local code="$1"
    case "$code" in
        # Expansiones (EP)
        EP01) echo "Trotamundos (World Adventures)" ;;
        EP02) echo "Triunfadores (Ambitions)" ;;
        EP03) echo "Al Caer la Noche (Late Night)" ;;
        EP04) echo "¡Menuda Familia! (Generations)" ;;
        EP05) echo "¡Vaya Fauna! (Pets)" ;;
        EP06) echo "Salto a la Fama (Showtime)" ;;
        EP07) echo "Criaturas Sobrenaturales (Supernatural)" ;;
        EP08) echo "Y las Cuatro Estaciones (Seasons)" ;;
        EP09) echo "Movida en la Facultad (University Life)" ;;
        EP10) echo "Aventura en la Isla (Island Paradise)" ;;
        EP11) echo "Hacia el Futuro (Into the Future)" ;;
        # Packs de Accesorios (SP)
        SP01) echo "Diseño y Tecnología (High-End Loft)" ;;
        SP02) echo "¡Quemando Rueda! (Fast Lane)" ;;
        SP03) echo "Patios y Jardines (Outdoor Living)" ;;
        SP04) echo "Vida en la Ciudad (Town Life)" ;;
        SP05) echo "Suite de Ensueño (Master Suite)" ;;
        SP06) echo "Katy Perry Dulce Tentación (Sweet Treats)" ;;
        SP07) echo "Diesel (Diesel Stuff)" ;;
        SP08) echo "Los 70, 80 y 90 (70s, 80s, & 90s Stuff)" ;;
        SP09) echo "De Cine (Movie Stuff)" ;;
        *) echo "Pack desconocido ($code)" ;;
    esac
}

LISTA_EP=(EP01 EP02 EP03 EP04 EP05 EP06 EP07 EP08 EP09 EP10 EP11)
LISTA_SP=(SP01 SP02 SP03 SP04 SP05 SP06 SP07 SP08 SP09)

# --- DETECTOR INTELIGENTE DE HARDWARE (GPU / VRAM / CPU) ---
detectar_hardware() {
    DETECT_GPU_VENDOR="UNKNOWN"
    DETECT_GPU_MODEL="Gráfica Genérica"
    DETECT_GPU_DEVICE_ID=""
    DETECT_VRAM_MB=2048
    DETECT_RAM_MB=4096
    DETECT_CPU_MODEL="Procesador Genérico"
    DETECT_CPU_CORES=4

    # 1. Detección de CPU
    if [ -f /proc/cpuinfo ]; then
        DETECT_CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | awk -F: '{print $2}' | sed -e 's/^[ \t]*//')
        DETECT_CPU_CORES=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo 4)
    fi

    # 2. Detección de RAM Total del Sistema
    if [ -f /proc/meminfo ]; then
        local mem_kb
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        DETECT_RAM_MB=$(( mem_kb / 1024 ))
    fi

    # 3. Detección de GPU vía lspci
    local lspci_out
    lspci_out=$(lspci -nn 2>/dev/null | grep -E -i "vga|3d|display" | head -n1)
    
    if [[ "$lspci_out" =~ (AMD|ATI|Advanced\ Micro|1002) ]]; then
        DETECT_GPU_VENDOR="AMD"
        DETECT_GPU_MODEL=$(echo "$lspci_out" | sed -E 's/.*controller.*: //')
        DETECT_GPU_DEVICE_ID=$(echo "$lspci_out" | grep -o -E '1002:[0-9a-fA-F]{4}' | cut -d: -f2)
    elif [[ "$lspci_out" =~ (NVIDIA|GeForce|10de) ]]; then
        DETECT_GPU_VENDOR="NVIDIA"
        DETECT_GPU_MODEL=$(echo "$lspci_out" | sed -E 's/.*controller.*: //')
        DETECT_GPU_DEVICE_ID=$(echo "$lspci_out" | grep -o -E '10de:[0-9a-fA-F]{4}' | cut -d: -f2)
    elif [[ "$lspci_out" =~ (Intel|8086) ]]; then
        DETECT_GPU_VENDOR="Intel"
        DETECT_GPU_MODEL=$(echo "$lspci_out" | sed -E 's/.*controller.*: //')
        DETECT_GPU_DEVICE_ID=$(echo "$lspci_out" | grep -o -E '8086:[0-9a-fA-F]{4}' | cut -d: -f2)
    fi

    # 4. Cálculo de VRAM recomendada según la RAM del sistema y tipo de GPU
    if [ "$DETECT_RAM_MB" -ge 12000 ]; then
        DETECT_VRAM_MB=4096
    elif [ "$DETECT_RAM_MB" -ge 6000 ]; then
        DETECT_VRAM_MB=2048
    else
        DETECT_VRAM_MB=1024
    fi
}

# --- DETECCIÓN DE ENTORNOS Y PREFIJOS ---
detectar_entornos() {
    DETECTED_ENTORNOS_NOMBRES=()
    DETECTED_ENTORNOS_LIBS=()
    DETECTED_ENTORNOS_PFX=()

    # 1. Steam (AppID 47890)
    for base_steam in "${STEAM_PATHS[@]}"; do
        vdf="$base_steam/steamapps/libraryfolders.vdf"
        if [ -f "$vdf" ]; then
            while read -r path; do
                if [ -d "$path" ]; then
                    pfx="$path/steamapps/compatdata/47890/pfx"
                    if [ ! -d "$pfx" ] && [ -d "$base_steam/steamapps/compatdata/47890/pfx" ]; then
                        pfx="$base_steam/steamapps/compatdata/47890/pfx"
                    fi
                    
                    nombre="Steam ($path)"
                    if [ -d "$path/steamapps/common/The Sims 3" ]; then
                        nombre="Steam (Los Sims 3 detectado)"
                    fi
                    
                    if [[ ! " ${DETECTED_ENTORNOS_LIBS[*]} " =~ " ${path} " ]]; then
                        DETECTED_ENTORNOS_NOMBRES+=("$nombre")
                        DETECTED_ENTORNOS_LIBS+=("$path")
                        DETECTED_ENTORNOS_PFX+=("$pfx")
                    fi
                fi
            done < <(grep -i '"path"' "$vdf" | awk -F '"' '{print $4}')
        fi
    done

    # 2. Heroic Games
    for h_base in "${HEROIC_PATHS[@]}"; do
        if [ -d "$h_base" ]; then
            for p in "$h_base"/*sims*3* "$h_base"/*Sims*3* "$h_base"/*The*Sims*3*; do
                if [ -d "$p" ]; then
                    bname="$(basename "$p")"
                    DETECTED_ENTORNOS_NOMBRES+=("Heroic Games ($bname)")
                    DETECTED_ENTORNOS_LIBS+=("$p/drive_c/Program Files/The Sims 3")
                    DETECTED_ENTORNOS_PFX+=("$p")
                fi
            done
        fi
    done

    # 3. Lutris
    for l_base in "${LUTRIS_PATHS[@]}"; do
        if [ -d "$l_base" ]; then
            for p in "$l_base"/*sims*3* "$l_base"/*Sims*3*; do
                if [ -d "$p" ]; then
                    bname="$(basename "$p")"
                    DETECTED_ENTORNOS_NOMBRES+=("Lutris ($bname)")
                    DETECTED_ENTORNOS_LIBS+=("$p/drive_c/Program Files/The Sims 3")
                    DETECTED_ENTORNOS_PFX+=("$p")
                fi
            done
        fi
    done

    # 4. Bottles
    for b_base in "${BOTTLES_PATHS[@]}"; do
        if [ -d "$b_base" ]; then
            for p in "$b_base"/*; do
                if [ -d "$p" ]; then
                    bname="$(basename "$p")"
                    DETECTED_ENTORNOS_NOMBRES+=("Bottles ($bname)")
                    DETECTED_ENTORNOS_LIBS+=("$p/drive_c/Program Files/The Sims 3")
                    DETECTED_ENTORNOS_PFX+=("$p")
                fi
            done
        fi
    done
}

# --- CONFIGURACIÓN DE RUTAS ---
configurar_rutas() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m            \e[1;33m⚙️  CONFIGURACIÓN DE RUTAS / LANZADOR\e[0m              \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"
    echo -e "${P}Buscando instalaciones de Steam, Lutris, Bottles y Heroic..."
    detectar_entornos

    if [ ${#DETECTED_ENTORNOS_NOMBRES[@]} -gt 0 ]; then
        echo -e "\n${P}\e[1;32m¡Instalaciones detectadas en tu sistema!\e[0m"
        for i in "${!DETECTED_ENTORNOS_NOMBRES[@]}"; do
            echo -e "${P}  \e[1;33m$((i+1))\e[0m) ${DETECTED_ENTORNOS_NOMBRES[$i]}"
        done
        echo -e "${P}  \e[1;33m$(( ${#DETECTED_ENTORNOS_NOMBRES[@]} + 1 ))\e[0m) Introducir rutas manualmente"
        
        echo -ne "\n${P}\e[1;37mElige una opción (1-$(( ${#DETECTED_ENTORNOS_NOMBRES[@]} + 1 ))):\e[0m "
        read -r opcion_env
        
        if [ "$opcion_env" -ge 1 ] && [ "$opcion_env" -le "${#DETECTED_ENTORNOS_NOMBRES[@]}" ] 2>/dev/null; then
            STEAM_LIBRARY="${DETECTED_ENTORNOS_LIBS[$((opcion_env-1))]}"
            STEAM_COMPATDATA="${DETECTED_ENTORNOS_PFX[$((opcion_env-1))]}"
        fi
    fi

    if [ -z "$STEAM_LIBRARY" ]; then
        echo -e "\n${P}\e[1;34m💡 PRO-TIP:\e[0m Arrastra la carpeta donde instalaste Los Sims 3"
        echo -ne "${P}Ruta del juego o biblioteca: "
        read -r input_lib
        STEAM_LIBRARY="${input_lib//\'/}"
        STEAM_LIBRARY="${STEAM_LIBRARY%"${STEAM_LIBRARY##*[![:space:]]}"}"
    fi

    if [ -z "$STEAM_COMPATDATA" ]; then
        STEAM_COMPATDATA="$STEAM_LIBRARY"
    fi

    echo -e "\n${P}\e[1;32mExcelente.\e[0m Ahora necesitamos la ruta donde guardas tus DLCs de Los Sims 3."
    echo -e "${P}\e[1;34m💡 PRO-TIP:\e[0m Arrastra la carpeta o archivo (.zip/.rar/.7z) de tus DLCs."
    echo -ne "${P}> "
    read -r input_dlc
    input_dlc="${input_dlc//\'/}"
    input_dlc="${input_dlc%"${input_dlc##*[![:space:]]}"}"
    DLC_SOURCE="${input_dlc}"

    mkdir -p "$HOME/.config"
    cat <<EOF > "$CONFIG_FILE"
STEAM_LIBRARY="$STEAM_LIBRARY"
STEAM_COMPATDATA="$STEAM_COMPATDATA"
DLC_SOURCE="$DLC_SOURCE"
EOF

    echo -e "\n${P}\e[1;32m✔ ¡Configuración guardada con éxito en $CONFIG_FILE!\e[0m"
    sleep 1
}

# Cargar configuración o iniciar asistente
if [ ! -f "$CONFIG_FILE" ]; then
    configurar_rutas
fi

source "$CONFIG_FILE"

# --- RESOLUCIÓN Y DETECCIÓN GLOBAL DE RUTAS ---
resolver_rutas_efectivas() {
    if [ -f "$STEAM_LIBRARY/Game/Bin/TS3.exe" ] || [ -f "$STEAM_LIBRARY/Game/Bin/TS3W.exe" ]; then
        SIMS_DIR="$STEAM_LIBRARY"
    elif [ -d "$STEAM_LIBRARY/steamapps/common/The Sims 3" ]; then
        SIMS_DIR="$STEAM_LIBRARY/steamapps/common/The Sims 3"
    elif [ -d "$STEAM_LIBRARY" ] && [[ "$STEAM_LIBRARY" =~ (The Sims 3|Los Sims 3) ]]; then
        SIMS_DIR="$STEAM_LIBRARY"
    else
        SIMS_DIR="$STEAM_LIBRARY/steamapps/common/The Sims 3"
    fi

    if [ -f "$STEAM_COMPATDATA/system.reg" ] || [ -f "$STEAM_COMPATDATA/user.reg" ] || [ -d "$STEAM_COMPATDATA/drive_c" ]; then
        PREFIX="$STEAM_COMPATDATA"
    elif [ -d "$STEAM_COMPATDATA/pfx" ]; then
        PREFIX="$STEAM_COMPATDATA/pfx"
    elif [ -d "$STEAM_COMPATDATA/steamapps/compatdata/47890/pfx" ]; then
        PREFIX="$STEAM_COMPATDATA/steamapps/compatdata/47890/pfx"
    else
        PREFIX="$STEAM_COMPATDATA"
    fi

    SYSTEM_REG="$PREFIX/system.reg"
    USER_REG="$PREFIX/user.reg"
}

resolver_rutas_efectivas

# Obtener ruta de Documentos/Electronic Arts/The Sims 3 dentro del prefijo Wine (Universal)
obtener_ruta_documentos_ts3() {
    local target_dir=""
    if [ -d "$PREFIX/drive_c/users" ]; then
        for u in "$PREFIX/drive_c/users/"*; do
            [ -d "$u" ] || continue
            local bname
            bname=$(basename "$u")
            [[ "$bname" =~ ^(Public|Default|default)$ ]] && continue
            for sub in "Documents/Electronic Arts/The Sims 3" "My Documents/Electronic Arts/The Sims 3" "Documentos/Electronic Arts/The Sims 3"; do
                if [ -d "$u/$sub" ]; then
                    target_dir="$u/$sub"
                    break 2
                fi
            done
        done
        
        if [ -z "$target_dir" ]; then
            for u in "$PREFIX/drive_c/users/"*; do
                [ -d "$u" ] || continue
                local bname
                bname=$(basename "$u")
                [[ "$bname" =~ ^(Public|Default|default)$ ]] && continue
                if [ -d "$u/Documents" ]; then
                    target_dir="$u/Documents/Electronic Arts/The Sims 3"
                    break
                fi
            done
        fi
    fi
    
    if [ -z "$target_dir" ]; then
        target_dir="$PREFIX/drive_c/users/steamuser/Documents/Electronic Arts/The Sims 3"
    fi
    mkdir -p "$target_dir"
    echo "$target_dir"
}

# Asegurar mapeo de unidades virtuales y enlaces necesarios en Wine/Proton
asegurar_enlaces_wine_drives() {
    local P
    P=$(obtener_padding)
    mkdir -p "$PREFIX/dosdevices"
    
    # 1. Enlazar unidad s: hacia la biblioteca de Steam / juego si no existe
    if [ ! -e "$PREFIX/dosdevices/s:" ]; then
        local steam_root="$STEAM_LIBRARY"
        if [ -d "$steam_root" ]; then
            ln -snf "$steam_root" "$PREFIX/dosdevices/s:" 2>/dev/null || true
            echo -e "${P}  \e[1;32m✔\e[0m Unidad virtual Wine S: enlazada a $steam_root"
        fi
    fi
    
    # 2. Enlazar carpeta steamapps/common dentro de drive_c de Steam si aplica
    local c_steam_apps="$PREFIX/drive_c/Program Files (x86)/Steam/steamapps"
    if [ -d "$STEAM_LIBRARY/steamapps/common" ]; then
        mkdir -p "$c_steam_apps"
        if [ ! -e "$c_steam_apps/common" ]; then
            ln -snf "$STEAM_LIBRARY/steamapps/common" "$c_steam_apps/common" 2>/dev/null || true
            echo -e "${P}  \e[1;32m✔\e[0m Enlace C:\\Program Files (x86)\\Steam\\steamapps\\common configurado"
        fi
    fi
}

# Reparación de archivos esenciales en paquetes de expansiones (Default.ini, ejecutables, mayúsculas/minúsculas)
reparar_archivos_arranque_packs() {
    local target_dir="$1"
    local P
    P=$(obtener_padding)
    
    # Fix mayúsculas/minúsculas en EP07
    if [ -f "$target_dir/EP07/Game/Bin/default.ini" ] && [ ! -f "$target_dir/EP07/Game/Bin/Default.ini" ]; then
        cp -p "$target_dir/EP07/Game/Bin/default.ini" "$target_dir/EP07/Game/Bin/Default.ini" 2>/dev/null || true
    fi

    # Fix EP03 (Al Caer la Noche) si falta Default.ini
    if [ -d "$target_dir/EP03" ] && [ ! -f "$target_dir/EP03/Game/Bin/Default.ini" ]; then
        mkdir -p "$target_dir/EP03/Game/Bin"
        cat << 'EOF_DEF' > "$target_dir/EP03/Game/Bin/Default.ini"
[Input]
MouseWheelThreshold=0.14
MouseWheelHysteresis=0.06

[Script]
Multithreaded=1
HeapSize = 30720

[Resources]
CacheBudget=209715200

[FrameDatabase]
BlockSize=30720

[CAS]
CompositorCacheSize = 104857600
SimCompositorCacheSize = 524288000
WorldCompositorCacheSize = 524288000
SimWorldCompositorCacheSize = 524288000

[Config:Win32]

[Config]
DBCacheSubdirName = DCCache
DBCacheMaxSizeMB = 200
CrashDumpLocation = \\cerberus\CrashDumps\Sims3
ExportBinSubdirName = Library
InstalledWorldsSubdirName = InstalledWorlds
Security = 0

[CustomContent]
EnableCustomContent = true
ExportsFolderName = Exports
ImportsFolderName = Downloads
BackupFolderName  = DCBackup
PackageThumbnails = false
PackageThumbnailsInSims3Pac = true
DeleteTempExportFolder = true
EOF_DEF
    fi

    # Asegurar que cada EP y SP tenga un ejecutable en Game/Bin al que apuntar en el registro
    local base_exe=""
    if [ -f "$target_dir/Game/Bin/TS3W.exe" ]; then
        base_exe="$target_dir/Game/Bin/TS3W.exe"
    elif [ -f "$target_dir/Game/Bin/TS3.exe" ]; then
        base_exe="$target_dir/Game/Bin/TS3.exe"
    fi

    if [ -n "$base_exe" ]; then
        for pack in "${LISTA_EP[@]}" "${LISTA_SP[@]}"; do
            if [ -d "$target_dir/$pack" ]; then
                mkdir -p "$target_dir/$pack/Game/Bin"
                local pack_exe="$target_dir/$pack/Game/Bin/TS3$pack.exe"
                if [ ! -f "$pack_exe" ]; then
                    ln -sf "$base_exe" "$pack_exe" 2>/dev/null || cp -p "$base_exe" "$pack_exe" 2>/dev/null || true
                fi
            fi
        done
    fi
}

# Búsqueda universal de archivos de parches o descargas
buscar_archivo_descarga() {
    local pattern="$1"
    local found=""
    if [ -d "$DLC_SOURCE" ]; then
        found=$(find "$DLC_SOURCE" -maxdepth 2 -type f -iname "$pattern" 2>/dev/null | head -n1)
    elif [ -f "$DLC_SOURCE" ]; then
        local pdir
        pdir=$(dirname "$DLC_SOURCE")
        found=$(find "$pdir" -maxdepth 2 -type f -iname "$pattern" 2>/dev/null | head -n1)
    fi
    if [ -z "$found" ] && [ -d "$HOME/Downloads" ]; then
        found=$(find "$HOME/Downloads" -maxdepth 2 -type f -iname "$pattern" 2>/dev/null | head -n1)
    fi
    echo "$found"
}

# --- ORGANIZADOR / APLANADOR DE DLCS PARA LOS SIMS 3 ---
arreglar_estructura_dlcs_ts3() {
    local target_dir="$1"
    local P
    P=$(obtener_padding)
    local doc_ts3
    doc_ts3=$(obtener_ruta_documentos_ts3)
    
    # 1. Si los DLCs se descomprimieron dentro de una subcarpeta "The Sims 3" o "Los Sims 3" o "All in One"
    for sub in "$target_dir/The Sims 3" "$target_dir/Los Sims 3" "$target_dir/all in one" "$target_dir/All in One" "$target_dir/DLCs"; do
        if [ -d "$sub" ]; then
            echo -e "${P}Moviendo contenidos desde subcarpeta '$sub' a la raíz del juego..."
            cp -rn "$sub/"* "$target_dir/" 2>/dev/null || mv -n "$sub/"* "$target_dir/" 2>/dev/null
            rm -rf "$sub" 2>/dev/null || true
        fi
    done

    # 2. Reparar archivos esenciales de packs (Default.ini, exes)
    reparar_archivos_arranque_packs "$target_dir"

    # 3. Comprobar si el usuario descargó el parche de Isla Paradiso de Luva
    local isla_zip
    isla_zip=$(buscar_archivo_descarga "*isla*paradiso*.zip")
    if [ -n "$isla_zip" ] && [ -d "$target_dir/EP10" ]; then
        local worlds_dir="$target_dir/EP10/GameData/Shared/NonPackaged/Worlds"
        if [ -d "$worlds_dir" ]; then
            echo -e "${P}Instalando Parche de Mundo 'Isla Paradiso' corregido..."
            7z e "$isla_zip" -o"$worlds_dir" "*.world" -y > /dev/null 2>&1
            echo -e "${P}  \e[1;32m✔\e[0m IslaParadiso.world reemplazado por la versión sin lag ni congelamientos."
        fi
    fi

    # 4. Comprobar si el usuario descargó Mods.zip de Luva (CleanUI, SmoothPatch, Store Packages)
    local mods_zip
    mods_zip=$(buscar_archivo_descarga "Mods.zip")
    if [ -n "$mods_zip" ] && [ -d "$doc_ts3" ]; then
        echo -e "${P}Instalando paquete de Mods y Store esenciales de Luva..."
        mkdir -p "$doc_ts3/Mods"
        7z x "$mods_zip" -o"$doc_ts3" -y -bsp1
        echo -e "${P}  \e[1;32m✔\e[0m Mods de estabilidad (CleanUI, ld_SmoothPatch, Store) instalados en Documentos."
    fi

    # 5. Comprobar si el usuario descargó Worlds & Store Updates (Sims3Packs y Packages de Store)
    local store_zip
    store_zip=$(buscar_archivo_descarga "*Worlds*Store*Updates*.zip")
    if [ -n "$store_zip" ] && [ -d "$doc_ts3" ]; then
        echo -e "${P}Instalando Worlds & Store Updates (Sims3Packs y Fixes de Store)..."
        mkdir -p "$doc_ts3/Downloads" "$doc_ts3/Mods/Packages"
        
        # Extraer .Sims3Pack a la carpeta Downloads del Launcher
        echo -e "${P}  📦 Extrayendo Sims3Packs a: \e[36m$doc_ts3/Downloads\e[0m..."
        7z e "$store_zip" -o"$doc_ts3/Downloads" "*.Sims3Pack" -r -y > /dev/null 2>&1
        
        # Extraer .package (como DV_BabyDragon_Fixes) a Mods/Packages
        echo -e "${P}  📦 Extrayendo paquetes (.package) a: \e[36m$doc_ts3/Mods/Packages\e[0m..."
        7z e "$store_zip" -o"$doc_ts3/Mods/Packages" "*.package" -r -y > /dev/null 2>&1
        
        echo -e "${P}  \e[1;32m✔\e[0m Worlds y Store Updates listos en Downloads y Mods/Packages."
    fi
}

# --- AUTO-DESCARGADOR DE EA DLC UNLOCKER (CON HEADERS Y VERIFICACIÓN SHA-256) ---
descargar_unlocker_auto() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m          \e[1;32m🌐 DESCARGA AUTOMÁTICA DEL EA DLC UNLOCKER\e[0m          \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"
    echo -e "${P}Conectando con el servidor oficial (Tiesas Archives / Anadius)..."
    mkdir -p "$UNLOCKER_STORE/ea_app"
    
    PAD_LEN=${#P} python3 -c '
import urllib.request, json, ssl, hashlib, os, sys, uuid
from pathlib import Path

pad = " " * int(os.environ.get("PAD_LEN", "0"))
store = Path(os.path.expanduser("~/.local/share/sims3_unlocker"))
manifest_url = "https://access.tiesasarchives.uk/api/unlocker/manifest?channel=stable&platform=linux&architecture=x64"
device_id = str(uuid.uuid4())
headers = {
    "X-Web-Jardinera-Device-Id": device_id,
    "X-Web-Jardinera-Bootstrap-Version": "1.0.1",
    "User-Agent": "WebJardineraSecureBootstrap/1.0.1"
}

try:
    ctx = ssl.create_default_context()
    req = urllib.request.Request(manifest_url, headers=headers)
    with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
        data = json.load(resp)
    
    version = data.get("version", "3.5.0")
    print(f"{pad}  ✔ Publicación oficial encontrada: v{version}")
    
    for art in data.get("artifacts", []):
        rel_path = art["path"]
        dest = store / rel_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        print(f"{pad}  ⬇ Descargando: {rel_path}...")
        
        art_req = urllib.request.Request(art["downloadUrl"], headers=headers)
        with urllib.request.urlopen(art_req, context=ctx, timeout=30) as d_resp:
            content = d_resp.read()
        
        if hashlib.sha256(content).hexdigest().lower() != art["sha256"].lower():
            raise ValueError(f"Error de integridad en {rel_path}")
        
        dest.write_bytes(content)
        
    print(f"\n{pad}  \033[1;32m✔ ¡Archivos del Unlocker descargados y verificados con éxito!\033[0m")
except Exception as e:
    print(f"\n{pad}  \033[1;31m❌ Error al descargar automáticamente: {e}\033[0m")
    sys.exit(1)
'

    if [ $? -eq 0 ]; then
        echo -e "\n${P}\e[1;32mArchivos guardados en:\e[0m $UNLOCKER_STORE"
        UNLOCKER_DLL="$UNLOCKER_STORE/ea_app/version.dll"
        UNLOCKER_INI="$UNLOCKER_STORE/config.ini"
        UNLOCKER_GAME_INI="$UNLOCKER_STORE/g_LOS SIMS 3.ini"
    else
        echo -e "\n${P}\e[33mSi prefieres descargarlo manualmente: https://anadius.hermietkreeft.site/dlc-unlockers\e[0m"
    fi
    echo -ne "\n${P}Presiona Enter para continuar..."
    read -r
}

# --- BÚSQUEDA Y LOCALIZACIÓN DE ARCHIVOS DEL UNLOCKER ---
localizar_archivos_unlocker() {
    UNLOCKER_DLL=""
    UNLOCKER_INI=""
    UNLOCKER_GAME_INI=""

    if [ -f "$UNLOCKER_STORE/ea_app/version.dll" ]; then
        UNLOCKER_DLL="$UNLOCKER_STORE/ea_app/version.dll"
    elif [ -f "$UNLOCKER_STORE/version.dll" ]; then
        UNLOCKER_DLL="$UNLOCKER_STORE/version.dll"
    fi
    [ -f "$UNLOCKER_STORE/config.ini" ] && UNLOCKER_INI="$UNLOCKER_STORE/config.ini"
    [ -f "$UNLOCKER_STORE/g_LOS SIMS 3.ini" ] && UNLOCKER_GAME_INI="$UNLOCKER_STORE/g_LOS SIMS 3.ini"

    if [ -n "$UNLOCKER_DLL" ] && [ -n "$UNLOCKER_INI" ] && [ -n "$UNLOCKER_GAME_INI" ]; then
        return 0
    fi

    # Buscar en descargas o rutas alternativas
    local dl_dll dl_ini dl_game_ini
    dl_dll=$(find "$HOME/Downloads" -maxdepth 3 -type f -name "version.dll" 2>/dev/null | head -n1)
    dl_ini=$(find "$HOME/Downloads" -maxdepth 3 -type f -name "config.ini" 2>/dev/null | head -n1)
    dl_game_ini=$(find "$HOME/Downloads" -maxdepth 3 -type f -iname "*LOS*SIMS*3*.ini" 2>/dev/null | head -n1)

    if [ -n "$dl_dll" ] && [ -n "$dl_ini" ] && [ -n "$dl_game_ini" ]; then
        UNLOCKER_DLL="$dl_dll"
        UNLOCKER_INI="$dl_ini"
        UNLOCKER_GAME_INI="$dl_game_ini"
        return 0
    fi

    # Si no se encuentra, invocar la descarga automática
    local P
    P=$(obtener_padding)
    echo -e "${P}\e[1;33mNo se detectaron los archivos del Unlocker localmente.\e[0m"
    echo -ne "${P}¿Deseas descargarlos automáticamente ahora? (S/n): "
    read -r resp_down
    if [[ "$resp_down" =~ ^[Nn]$ ]]; then
        return 1
    fi

    descargar_unlocker_auto
    if [ -f "$UNLOCKER_STORE/ea_app/version.dll" ] && [ -f "$UNLOCKER_STORE/config.ini" ] && [ -f "$UNLOCKER_STORE/g_LOS SIMS 3.ini" ]; then
        UNLOCKER_DLL="$UNLOCKER_STORE/ea_app/version.dll"
        UNLOCKER_INI="$UNLOCKER_STORE/config.ini"
        UNLOCKER_GAME_INI="$UNLOCKER_STORE/g_LOS SIMS 3.ini"
        return 0
    fi
    return 1
}

# --- INYECTOR DE EA DLC UNLOCKER EN EA APP / EA DESKTOP ---
inyectar_ea_app_unlocker_ts3() {
    local P
    P=$(obtener_padding)
    echo -e "${P}Inyectando archivos de EA DLC Unlocker en EA App..."

    local ea_base="$PREFIX/drive_c/Program Files/Electronic Arts/EA Desktop"
    local injected_count=0

    if [ -d "$ea_base" ]; then
        cp -p "$UNLOCKER_DLL" "$ea_base/version.dll" 2>/dev/null && ((injected_count++))
        while read -r target_dir; do
            if [ -d "$target_dir" ]; then
                cp -p "$UNLOCKER_DLL" "$target_dir/version.dll" 2>/dev/null
                ((injected_count++))
            fi
        done < <(find "$ea_base" -type f \( -iname "EADesktop.exe" -o -iname "EABackgroundService.exe" \) -exec dirname {} \; 2>/dev/null | sort -u)
    fi

    while read -r target_dir; do
        cp -p "$UNLOCKER_DLL" "$target_dir/version.dll" 2>/dev/null
        ((injected_count++))
    done < <(find "$PREFIX/drive_c" -type f \( -iname "EADesktop.exe" -o -iname "EABackgroundService.exe" \) -exec dirname {} \; 2>/dev/null | sort -u)

    echo -e "${P}  \e[1;32m✔\e[0m version.dll inyectado en $injected_count ubicaciones de EA App."

    # Configuración en AppData de Wine
    local users_dir="$PREFIX/drive_c/users"
    if [ -d "$users_dir" ]; then
        for u in "$users_dir"/*; do
            if [ -d "$u" ] && [ "$(basename "$u")" != "Public" ]; then
                local target_conf="$u/AppData/Roaming/anadius/EA DLC Unlocker v2"
                mkdir -p "$target_conf"
                cp -p "$UNLOCKER_INI" "$target_conf/config.ini" 2>/dev/null
                cp -p "$UNLOCKER_GAME_INI" "$target_conf/g_LOS SIMS 3.ini" 2>/dev/null
                cp -p "$UNLOCKER_GAME_INI" "$target_conf/g_The Sims 3.ini" 2>/dev/null
                cp -p "$UNLOCKER_GAME_INI" "$target_conf/g_THE SIMS 3.ini" 2>/dev/null
                sed -i 's/replaceDLCs=0/replaceDLCs=1/' "$target_conf/config.ini" 2>/dev/null
            fi
        done
    fi
    echo -e "${P}  \e[1;32m✔\e[0m Configuraciones g_LOS SIMS 3.ini registradas en AppData."

    # Wine DllOverride en user.reg
    if [ -f "$USER_REG" ]; then
        local ts=$(date +%s)
        if ! grep -q '"version"="native,builtin"' "$USER_REG" 2>/dev/null; then
            cat <<EOF >> "$USER_REG"

[Software\\\\Wine\\\\DllOverrides] $ts
"version"="native,builtin"
EOF
            echo -e "${P}  \e[1;32m✔\e[0m Override de version.dll añadido a user.reg."
        else
            echo -e "${P}  \e[1;32m✔\e[0m Override de version.dll ya estaba activo."
        fi
    fi

    # Purgar cachés temporales de EA App
    rm -rf "$PREFIX/drive_c/users"/*/AppData/Local/Electronic\ Arts/EA\ Desktop 2>/dev/null
    rm -rf "$PREFIX/drive_c/users"/*/AppData/Local/EADesktop 2>/dev/null
    rm -rf "$PREFIX/drive_c/users"/*/AppData/Local/Origin 2>/dev/null
    echo -e "${P}  \e[1;32m✔\e[0m Caché de EA App purgada."
}

# --- ACTIVADOR / INYECTOR DE REGISTRO PARA LOS SIMS 3 ---
activar_registro_dlcs_ts3() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m        \e[1;33m🔓 INYECCIÓN DE REGISTRO WINE / PROTON (SIMS 3)\e[0m        \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"

    if [ ! -f "$SYSTEM_REG" ]; then
        echo -e "${P}\e[1;31m¡Error! No se encontró el registro de Wine en:\e[0m $SYSTEM_REG"
        echo -e "${P}Inicia el juego al menos una vez desde Steam/Heroic para generar el prefijo."
        echo -ne "\n${P}Presiona Enter para continuar..."
        read -r
        return 1
    fi

    echo -e "${P}Configurando unidades virtuales y validando estructura de packs..."
    asegurar_enlaces_wine_drives
    reparar_archivos_arranque_packs "$SIMS_DIR"

    local doc_ts3
    doc_ts3=$(obtener_ruta_documentos_ts3)

    echo -e "${P}Inyectando claves maestras de activación (11 Expansiones & 9 Accesorios)..."
    
    # Backup preventivo
    cp "$SYSTEM_REG" "$SYSTEM_REG.bak_$(date +%s)"
    [ -f "$USER_REG" ] && cp "$USER_REG" "$USER_REG.bak_$(date +%s)"

    python3 - << 'PYEOF' "$SYSTEM_REG" "$USER_REG" "$SIMS_DIR" "$PREFIX" "$doc_ts3"
import os, sys, re, time, glob

system_reg = sys.argv[1]
user_reg = sys.argv[2]
sims_dir = sys.argv[3]
prefix = sys.argv[4]
doc_ts3 = sys.argv[5]

dlcs = [
    ("EP01", "The Sims 3 World Adventures", 0x3ea, "sims3_ep01_sku7", "4V77-74X8-P96F-CP93-HRLD"),
    ("EP02", "The Sims 3 Ambitions", 0x3eb, "sims3_ep02_sku7", "VJ66-ZW9P-B7V8-WB7S-BRLD"),
    ("EP03", "The Sims 3 Late Night", 0x3ec, "sims3_ep03_sku7", "3W22-DU2D-J25W-7J23-ZRLD"),
    ("EP04", "The Sims 3 Generations", 0x3ed, "sims3_ep04_sku7", "4CLL-V8U2-6UFV-555D-W848"),
    ("EP05", "The Sims 3 Pets", 0x3ee, "sims3_ep05_sku7", "6R22-QY3Z-3Z98-Q3Z6-ARLD"),
    ("EP06", "The Sims 3 Showtime", 0x3ef, "sims3_ep06_sku7", "8799-H82A-C2N6-NC2K-9RLD"),
    ("EP07", "The Sims 3 Supernatural", 0x3f0, "sims3_ep07_sku7", "8V88-HMYN-C9W4-TC95-7RLD"),
    ("EP08", "The Sims 3 Seasons", 0x3f1, "sims3_ep08_sku7", "5W66-8X78-G276-8G25-9RLD"),
    ("EP09", "The Sims 3 University Life", 0x3f2, "sims3_ep09_sku7", "6U77-T345-2JND-A2JM-GRLD"),
    ("EP10", "The Sims 3 Island Paradise", 0x3f3, "sims3_ep10_sku7", "8U22-QW4L-4N5Q-54N2-TRLD"),
    ("EP11", "The Sims 3 Into the Future", 0x3f4, "sims3_ep11_sku7", "4R44-D25U-J6F6-GJ6B-ARLD"),
    ("SP01", "The Sims 3 High-End Loft Stuff", 0x41b, "sims3_sp01_sku7", "M4DD-Y6XW-Z2T7-4Z2S-9RLD"),
    ("SP02", "The Sims 3 Fast Lane Stuff", 0x41c, "sims3_sp02_sku7", "V677-Y586-W68F-NW64-JRLD"),
    ("SP03", "The Sims 3 Outdoor Living Stuff", 0x41d, "sims3_sp03_sku7", "8V22-9NKL-C7S9-AC7R-DRLD"),
    ("SP04", "The Sims 3 Town Life Stuff", 0x41e, "sims3_sp04_sku7", "7766-3Q75-N5M2-4N5J-6RLD"),
    ("SP05", "The Sims 3 Master Suite Stuff", 0x41f, "sims3_sp05_sku7", "6M99-KMYV-C68P-UC65-SRLD"),
    ("SP06", "The Sims 3 Sweet Treats", 0x420, "sims3_sp06_sku7", "Q944-R33N-S6M8-US6K-BRLD"),
    ("SP07", "The Sims 3 Diesel Stuff", 0x421, "sims3_sp07_sku7", "Q7GG-BMTU-C984-VC95-7RLD"),
    ("SP08", "The Sims 3 70s, 80s, & 90s Stuff", 0x422, "sims3_sp08_sku7", "9F77-9436-Z7J7-PZ7E-BRLD"),
    ("SP09", "The Sims 3 Movie Stuff", 0x423, "sims3_sp09_sku7", "M7SS-S6H6-H3C8-W5X5-Y7R6"),
]

# 1. Determinar ruta de instalación de Windows del juego base
base_win_dir = ""
if os.path.isfile(system_reg):
    with open(system_reg, "r", encoding="utf-8", errors="ignore") as f:
        in_base = False
        for line in f:
            if re.match(r"^\[Software\\\\(?:Wow6432Node\\\\)?(?:Electronic Arts\\\\)?Sims(?:\(Steam\))?\\\\The Sims 3\]", line.strip()):
                in_base = True
            elif line.startswith("["):
                in_base = False
            elif in_base and '"Install Dir"=' in line:
                m = re.search(r'"Install Dir"="([^"]+)"', line)
                if m:
                    base_win_dir = m.group(1)
                    break

if not base_win_dir:
    base_win_dir = "C:\\\\Program Files (x86)\\\\Steam\\\\steamapps\\\\common\\\\The Sims 3"

base_win_dir = base_win_dir.replace("\\\\", "\\").rstrip("\\")
win_esc = base_win_dir.replace("\\", "\\\\")

def clean_and_inject(reg_path, is_system=True):
    if not os.path.isfile(reg_path):
        return
    with open(reg_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    filtered = []
    skip = False
    for line in lines:
        if line.startswith("["):
            is_dlc_key = False
            for pat in [
                r"^\[Software\\\\(?:Wow6432Node\\\\)?(?:Electronic Arts\\\\)?Sims(?:\(Steam\))?\\\\The Sims 3 .+",
                r"^\[Software\\\\(?:Wow6432Node\\\\)?Electronic Arts\\\\(?:Sims\(Steam\)\\\\)?The Sims 3 .+"
            ]:
                if re.match(pat, line.strip()):
                    is_dlc_key = True
                    break
            skip = is_dlc_key
        if not skip:
            filtered.append(line)
            
    content = "".join(filtered).rstrip() + "\n\n"
    ts = int(time.time())
    
    pfx_list = ["Software\\\\Sims(Steam)", "Software\\\\Wow6432Node\\\\Sims(Steam)"]
    if is_system:
        pfx_list += ["Software\\\\Sims", "Software\\\\Wow6432Node\\\\Sims"]
        
    for code, name, prod_id, content_id, serial in dlcs:
        pack_dir = os.path.join(sims_dir, code)
        exe_file = f"TS3{code}.exe"
        pack_exe_path = os.path.join(pack_dir, "Game", "Bin", exe_file)
        if not os.path.isfile(pack_exe_path):
            exe_target = f"{win_esc}\\\\Game\\\\Bin\\\\TS3.exe"
        else:
            exe_target = f"{win_esc}\\\\{code}\\\\Game\\\\Bin\\\\{exe_file}"

        for pfx in pfx_list:
            content += f"""[{pfx}\\\\{name}] {ts}
"ContentId"="{content_id}"
"Country"="ES"
"DisplayName"="{name}"
"ErgcRegPath"="Electronic Arts\\\\Sims(Steam)\\\\{name}\\\\ergc"
"ExePath"="{exe_target}"
"Install Dir"="{win_esc}\\\\{code}"
"Locale"="es-es"
"ProductID"=dword:{prod_id:08x}
"SKU"=dword:00000007
"Telemetry"=dword:00000000

"""
        if is_system:
            for ergc_pfx in [
                "Software\\\\Electronic Arts\\\\Sims(Steam)",
                "Software\\\\Wow6432Node\\\\Electronic Arts\\\\Sims(Steam)",
                "Software\\\\Electronic Arts",
                "Software\\\\Wow6432Node\\\\Electronic Arts"
            ]:
                content += f"""[{ergc_pfx}\\\\{name}\\\\ergc] {ts}
@="{serial}"

"""

    if is_system:
        for appid in list(range(47891, 47911)) + [249180]:
            for s_pfx in ["Software\\\\Valve\\\\Steam\\\\Apps", "Software\\\\Wow6432Node\\\\Valve\\\\Steam\\\\Apps"]:
                content += f"""[{s_pfx}\\\\{appid}] {ts}
"Installed"=dword:00000001

"""

    with open(reg_path, "w", encoding="utf-8") as f:
        f.write(content)

clean_and_inject(system_reg, is_system=True)
clean_and_inject(user_reg, is_system=False)

# Enlace de mundos de expansiones (.world) y mundos de la Store (Mundos Especiales)
base_worlds = os.path.join(sims_dir, "GameData", "Shared", "NonPackaged", "Worlds")
installed_worlds = os.path.join(doc_ts3, "InstalledWorlds")
os.makedirs(installed_worlds, exist_ok=True)
os.makedirs(base_worlds, exist_ok=True)

all_worlds = glob.glob(os.path.join(sims_dir, "EP*", "GameData", "Shared", "NonPackaged", "Worlds", "*.world"))
all_worlds += glob.glob(os.path.join(doc_ts3, "Mods", "Mundos Especiales", "*.world"))
all_worlds += glob.glob(os.path.join(doc_ts3, "Mods", "Packages", "*.world"))

for w in all_worlds:
    bname = os.path.basename(w)
    dest1 = os.path.join(base_worlds, bname)
    dest2 = os.path.join(installed_worlds, bname)
    if not os.path.exists(dest1):
        try: os.symlink(w, dest1)
        except Exception: pass
    if not os.path.exists(dest2):
        try: os.symlink(w, dest2)
        except Exception: pass

# Inyección de paquetes EP y SP en Resource.cfg
for cfg_rel in ["GameData/Shared/Resource.cfg", "Game/Bin/Resource.cfg"]:
    cfg_path = os.path.join(sims_dir, cfg_rel)
    if os.path.isfile(cfg_path):
        with open(cfg_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
        if not any("EP01" in l for l in lines):
            new_packed = []
            for i in range(1, 12):
                ep = f"EP{i:02d}"
                new_packed.append(f"PackedFile ../../{ep}/GameData/Shared/Packages/FullBuild*.package\n")
                new_packed.append(f"PackedFile ../../{ep}/GameData/Shared/Packages/DeltaBuild*.package\n")
            for i in range(1, 10):
                sp = f"SP{i:02d}"
                new_packed.append(f"PackedFile ../../{sp}/GameData/Shared/Packages/FullBuild*.package\n")
                new_packed.append(f"PackedFile ../../{sp}/GameData/Shared/Packages/DeltaBuild*.package\n")
            out = []
            inserted = False
            for line in lines:
                if "Thumbnails" in line and not inserted:
                    out.extend(new_packed)
                    inserted = True
                out.append(line)
            if not inserted:
                out.extend(new_packed)
            with open(cfg_path, "w", encoding="utf-8") as f:
                f.writelines(out)
PYEOF

    # Desbloqueo en el archivo appmanifest_47890.acf de Steam
    local acf_file="$STEAM_LIBRARY/steamapps/appmanifest_47890.acf"
    if [ -f "$acf_file" ] && ! grep -q '"dlcappid"' "$acf_file" 2>/dev/null; then
        echo -e "${P}Actualizando manifiesto de DLCs en Steam ($acf_file)..."
        python3 -c '
import sys, re
acf = sys.argv[1]
with open(acf, "r", encoding="utf-8") as f:
    c = f.read()
depots = "	\"InstalledDepots\"\n	{\n"
for i in range(47891, 47911):
    depots += f"""		"{i}"\n		{{\n			"manifest"		"1000000000000000000"\n			"size"		"1000000"\n			"dlcappid"		"{i}"\n		}}\n"""
depots += "	}"
if "InstalledDepots" in c:
    c = re.sub(r"\"InstalledDepots\"\s*\{[^}]*\}", depots, c)
    with open(acf, "w", encoding="utf-8") as f:
        f.write(c)
' "$acf_file" 2>/dev/null || true
    fi

    # Desbloqueo en EA Desktop si está presente en el prefijo
    if [ -d "$PREFIX/drive_c" ] && find "$PREFIX/drive_c" -type f \( -iname "EADesktop.exe" -o -iname "EABackgroundService.exe" \) 2>/dev/null | grep -q .; then
        echo -e "\n${P}\e[1;34mDetectada instalación de EA App en el prefijo. Inyectando EA DLC Unlocker...\e[0m"
        if localizar_archivos_unlocker 2>/dev/null; then
            inyectar_ea_app_unlocker_ts3
        fi
    fi

    echo -e "${P}\e[1;32m✔ Claves completas, mundos y paquetes inyectados exitosamente.\e[0m"
    echo -e "${P}Los Sims 3 Launcher y el motor del juego reconocerán todas las expansiones."
    echo -ne "\n${P}Presiona Enter para continuar..."
    read -r
}

# --- OPTIMIZACIÓN INTELIGENTE DE GRÁFICOS Y RENDIMIENTO SEGÚN HARDWARE ---
optimizar_rendimiento_ts3() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m     \e[1;32m⚡ OPTIMIZACIÓN INTELIGENTE DE GRÁFICOS & HARDWARE (TS3)\e[0m   \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"

    local bin_dir="$SIMS_DIR/Game/Bin"
    local gr_file="$bin_dir/GraphicsRules.sgr"
    local gc_file="$bin_dir/GraphicsCards.sgr"

    if [ ! -f "$gr_file" ]; then
        echo -e "${P}\e[1;31m¡Error! No se encontró GraphicsRules.sgr en:\e[0m $bin_dir"
        echo -ne "\n${P}Presiona Enter para continuar..."
        read -r
        return 1
    fi

    detectar_hardware

    echo -e "${P}\e[1;37m• Hardware detectado en tu equipo:\e[0m"
    echo -e "${P}  - CPU:   \e[1;33m$DETECT_CPU_MODEL ($DETECT_CPU_CORES núcleos)\e[0m"
    echo -e "${P}  - GPU:   \e[1;32m$DETECT_GPU_MODEL [$DETECT_GPU_VENDOR]\e[0m"
    echo -e "${P}  - RAM:   \e[1;36m$DETECT_RAM_MB MB\e[0m"
    echo -e "${P}  - VRAM Óptima Calculada: \e[1;35m$DETECT_VRAM_MB MB\e[0m\n"

    echo -e "${P}\e[1;34m[1/4] Calibrando GraphicsRules.sgr con el perfil de tu GPU...\e[0m"
    cp "$gr_file" "$gr_file.bak_$(date +%s)"
    
    # 1. Inyección de VRAM ajustada al hardware real
    sed -i "s/seti setiParam 128/seti setiParam $DETECT_VRAM_MB/g" "$gr_file" 2>/dev/null || true
    sed -i "s/seti setiParam 256/seti setiParam $DETECT_VRAM_MB/g" "$gr_file" 2>/dev/null || true
    sed -i "s/seti setiParam 512/seti setiParam $DETECT_VRAM_MB/g" "$gr_file" 2>/dev/null || true
    sed -i "s/seti setiParam 2048/seti setiParam $DETECT_VRAM_MB/g" "$gr_file" 2>/dev/null || true
    sed -i 's/setb textureMemorySizeOK false/setb textureMemorySizeOK true/g' "$gr_file" 2>/dev/null || true

    # 2. Asignar perfil gráfico Uber (5) a GPUs modernas reconocidas
    if [ "$DETECT_GPU_VENDOR" = "AMD" ]; then
        sed -i 's/match("${cardVendor}", "ATI")/match("${cardVendor}", "ATI") or match("${cardVendor}", "AMD")/g' "$gr_file" 2>/dev/null || true
    elif [ "$DETECT_GPU_VENDOR" = "NVIDIA" ]; then
        sed -i 's/setb shadowMapDisabled true/setb shadowMapDisabled false/g' "$gr_file" 2>/dev/null || true
    fi
    
    # Desactivar bug de sombras en tarjetas modernas
    sed -i 's/setb shadowMapDisabled true/setb shadowMapDisabled false/g' "$gr_file" 2>/dev/null || true

    echo -e "${P}  \e[1;32m✔\e[0m Memoria de texturas configurada a $DETECT_VRAM_MB MB ($DETECT_GPU_VENDOR)."

    # 3. Configuración de pantalla nativa
    echo -e "\n${P}\e[1;34m[2/4] Configurando opciones del juego a 1080p Nativo @ 60 FPS...\e[0m"
    local doc_dir
    doc_dir=$(obtener_ruta_documentos_ts3)
    local doc_options="$doc_dir/Options.ini"
    if [ -f "$doc_options" ]; then
        sed -i 's/^resolution = .*/resolution = 1920 1080 60/g' "$doc_options" 2>/dev/null || echo "resolution = 1920 1080 60" >> "$doc_options"
        sed -i 's/^fullscreen = .*/fullscreen = 1/g' "$doc_options" 2>/dev/null || echo "fullscreen = 1" >> "$doc_options"
        echo -e "${P}  \e[1;32m✔\e[0m Resolución fijada a 1920x1080 @ 60Hz en Options.ini."
    else
        echo -e "${P}  \e[2;37m(El archivo Options.ini se creará al iniciar el juego por primera vez)\e[0m"
    fi

    # 4. Auto-instalación de Parche de Estabilidad de Luva (Smooth Patch / wininet / ddraw)
    echo -e "\n${P}\e[1;34m[3/4] Comprobando Parche de Estabilidad (Smooth Patch / LazyDuchess)...\e[0m"
    local estabilidad_zip
    estabilidad_zip=$(buscar_archivo_descarga "*estabilidad*sims*3*.zip")
    if [ -z "$estabilidad_zip" ]; then
        estabilidad_zip=$(buscar_archivo_descarga "*Smooth*Patch*.zip")
    fi
    if [ -n "$estabilidad_zip" ]; then
        echo -e "${P}  Detectado '$estabilidad_zip'. Instalando en Game/Bin..."
        7z e "$estabilidad_zip" -o"$bin_dir" -y > /dev/null 2>&1
        echo -e "${P}  \e[1;32m✔\e[0m Archivos ddraw.dll, wininet.dll y TS3Patch.asi copiados a Game/Bin."
    fi

    # 5. Inyección de DllOverrides para Smooth Patch (dinput8, ddraw, wininet)
    echo -e "\n${P}\e[1;34m[4/4] Configurando Wine DllOverrides (dinput8, ddraw, wininet)...\e[0m"
    if [ -f "$USER_REG" ]; then
        local ts=$(date +%s)
        for dll_ov in "dinput8" "ddraw" "wininet"; do
            if ! grep -q "\"$dll_ov\"=\"native,builtin\"" "$USER_REG" 2>/dev/null; then
                cat <<EOF >> "$USER_REG"

[Software\\\\Wine\\\\DllOverrides] $ts
"$dll_ov"="native,builtin"
EOF
                echo -e "${P}  \e[1;32m✔\e[0m Override de $dll_ov añadido a user.reg."
            else
                echo -e "${P}  \e[1;32m✔\e[0m Override de $dll_ov ya estaba activo."
            fi
        done
    fi

    echo -e "\n${P}\e[1;32m¡Optimización personalizada completada con éxito!\e[0m"
    echo -ne "\n${P}Presiona Enter para continuar..."
    read -r
}

# --- ABRIR CARPETA MODS DE LOS SIMS 3 ---
abrir_carpeta_mods_ts3() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m            \e[1;33m📂 ABRIR CARPETA MODS (LOS SIMS 3)\e[0m                \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"

    local doc_ts3
    doc_ts3=$(obtener_ruta_documentos_ts3)
    local mods_dir="$doc_ts3/Mods"
    mkdir -p "$mods_dir/Packages" "$mods_dir/Overrides"

    echo -e "${P}Abriendo carpeta de Mods en el gestor de archivos..."
    echo -e "${P}Ruta: \e[36m$mods_dir\e[0m\n"

    if command -v xdg-open &> /dev/null; then
        xdg-open "$mods_dir" >/dev/null 2>&1 &
        echo -e "${P}\e[1;32m✔ ¡Carpeta de Mods abierta con éxito!\e[0m"
    else
        echo -e "${P}\e[1;33mNo se detectó xdg-open. Puedes acceder manualmente a la ruta:\e[0m"
        echo -e "${P}\e[36m$mods_dir\e[0m"
    fi

    echo -ne "\n${P}Presiona Enter para volver al menú principal..."
    read -r
}

# --- DIAGNÓSTICO DE DLCS E INTEGRIDAD ---
diagnosticar_dlcs_ts3() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m        \e[1;33m🔍 DIAGNÓSTICO DE DLCS E INTEGRIDAD (SIMS 3)\e[0m           \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"
    echo -e "${P}  \e[1;37m• Juego:\e[0m   \e[36m$SIMS_DIR\e[0m"
    echo -e "${P}  \e[1;37m• Prefijo:\e[0m \e[36m$PREFIX\e[0m\n"

    local total_instalados=0
    local total_faltantes=0

    echo -e "${P}\e[1;34m[Expansiones - EP01 a EP11]\e[0m"
    for code in "${LISTA_EP[@]}"; do
        local name
        name=$(obtener_nombre_dlc "$code")
        if [ -d "$SIMS_DIR/$code" ] || [ -d "$SIMS_DIR/The Sims 3 $name" ] 2>/dev/null; then
            echo -e "${P}  • \e[1;32m[INSTALADO]\e[0m $code: $name"
            ((total_instalados++))
        else
            echo -e "${P}  • \e[1;31m[FALTANTE]\e[0m  $code: $name"
            ((total_faltantes++))
        fi
    done

    echo -e "\n${P}\e[1;34m[Packs de Accesorios - SP01 a SP09]\e[0m"
    for code in "${LISTA_SP[@]}"; do
        local name
        name=$(obtener_nombre_dlc "$code")
        if [ -d "$SIMS_DIR/$code" ] || [ -d "$SIMS_DIR/The Sims 3 $name" ] 2>/dev/null; then
            echo -e "${P}  • \e[1;32m[INSTALADO]\e[0m $code: $name"
            ((total_instalados++))
        else
            echo -e "${P}  • \e[1;31m[FALTANTE]\e[0m  $code: $name"
            ((total_faltantes++))
        fi
    done

    echo -e "\n${P}\e[1;36m────────────────────────────────────────────────────────────────\e[0m"
    echo -e "${P}\e[1;37mResumen del catálogo:\e[0m"
    echo -e "${P}  • DLCs instalados en disco: \e[1;32m$total_instalados / 20\e[0m"
    echo -e "${P}  • DLCs faltantes:           \e[1;33m$total_faltantes\e[0m"

    local reg_active=0
    if [ -f "$SYSTEM_REG" ] && grep -F -q 'Software\\Sims(Steam)' "$SYSTEM_REG" 2>/dev/null; then
        reg_active=1
    fi

    if [ "$reg_active" -eq 1 ]; then
        echo -e "${P}  • Registro Wine / Proton:   \e[1;32m[✔ INYECTADO Y ACTIVO]\e[0m"
    else
        echo -e "${P}  • Registro Wine / Proton:   \e[1;31m[❌ PENDIENTE DE ACTIVAR (Opción 2)]\e[0m"
    fi

    echo -ne "\n${P}Presiona Enter para continuar..."
    read -r
}

# --- LIMPIADOR DE CACHÉ DE LOS SIMS 3 ---
limpiar_cache_ts3() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m          \e[1;33m🧹 LIMPIADOR DE CACHÉ DE LOS SIMS 3\e[0m                  \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"

    local doc_dir
    doc_dir=$(obtener_ruta_documentos_ts3)
    if [ ! -d "$doc_dir" ]; then
        echo -e "${P}\e[1;33mAviso:\e[0m No se encontró la carpeta de documentos en:\n${P}$doc_dir\n"
        echo -ne "${P}Presiona Enter para continuar..."
        read -r
        return 0
    fi

    echo -e "${P}Borrando archivos de caché temporales y corruptos..."
    local eliminados=0

    for cache_file in "CASPartCache.package" "compositorCache.package" "scriptCache.package" "simCompositorCache.package" "socialCache.package"; do
        if [ -f "$doc_dir/$cache_file" ]; then
            rm -f "$doc_dir/$cache_file"
            echo -e "${P}  \e[1;32m✔\e[0m Eliminado: $cache_file"
            ((eliminados++))
        fi
    done

    if [ -d "$doc_dir/Thumbnails" ]; then
        rm -rf "$doc_dir/Thumbnails"/* 2>/dev/null
        echo -e "${P}  \e[1;32m✔\e[0m Vaciada carpeta de miniaturas (Thumbnails/)"
        ((eliminados++))
    fi

    echo -e "\n${P}\e[1;32m¡Limpieza terminada! Se purgaron $eliminados elementos de caché.\e[0m"
    echo -e "${P}Esto resuelve problemas de carga infinita, sims invisibles y texturas lentas."
    echo -ne "\n${P}Presiona Enter para continuar..."
    read -r
}

# --- ACCESO DIRECTO EN ESCRITORIO Y MENÚ DE APLICACIONES ---
crear_acceso_directo_ts3() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m         \e[1;33m🖥️  CREAR ACCESO DIRECTO (.DESKTOP)\e[0m                   \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"

    mkdir -p "$HOME/.local/share/icons"
    cat <<'EOF_SVG' > "$ICON_PATH"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <defs>
    <linearGradient id="plumbobTop" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38bdf8"/>
      <stop offset="100%" stop-color="#0284c7"/>
    </linearGradient>
    <linearGradient id="plumbobHighlight" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#e0f2fe"/>
      <stop offset="100%" stop-color="#38bdf8"/>
    </linearGradient>
    <linearGradient id="plumbobBottom" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0284c7"/>
      <stop offset="100%" stop-color="#0369a1"/>
    </linearGradient>
  </defs>
  <polygon points="64,12 100,56 64,68" fill="url(#plumbobTop)"/>
  <polygon points="64,12 28,56 64,68" fill="url(#plumbobHighlight)"/>
  <polygon points="64,68 100,56 64,116" fill="url(#plumbobBottom)"/>
  <polygon points="64,68 28,56 64,116" fill="url(#plumbobTop)"/>
  <line x1="64" y1="12" x2="64" y2="116" stroke="#bae6fd" stroke-width="1.5" opacity="0.8"/>
</svg>
EOF_SVG

    DESKTOP_ENTRY="$HOME/.local/share/applications/fix-sims-3.desktop"
    mkdir -p "$HOME/.local/share/applications"

    cat <<EOF_DESK > "$DESKTOP_ENTRY"
[Desktop Entry]
Name=Fix Sims 3 Linux
Comment=Gestor, Optimizador y Activador de DLCs para Los Sims 3 en Linux
Exec=bash -c 'bash "$SCRIPT_DIR/fix_sims_3_linux.sh"'
Icon=$ICON_PATH
Terminal=true
Type=Application
Categories=Game;Utility;
Keywords=Sims;Sims3;DLC;Optimizacion;Proton;
EOF_DESK
    chmod +x "$DESKTOP_ENTRY"

    if [ -d "$HOME/Desktop" ]; then
        cp "$DESKTOP_ENTRY" "$HOME/Desktop/Fix Sims 3.desktop"
        chmod +x "$HOME/Desktop/Fix Sims 3.desktop"
    fi

    echo -e "${P}\e[1;32m✔ Acceso directo creado en tu menú de aplicaciones y en el Escritorio.\e[0m"
    echo -ne "\n${P}Presiona Enter para continuar..."
    read -r
}

# --- ASESINO DE PROCESOS COLGADOS ---
matar_procesos_colgados_ts3() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m       \e[1;31m🔪 FORZAR CIERRE DE PROCESOS COLGADOS (TS3)\e[0m            \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"
    echo -e "${P}\e[1;31m[Aniquilando procesos fantasma de Los Sims 3 y Steam Proton...]\e[0m"
    pkill -9 -u "$USER" -f "steam-runtime-reaper" > /dev/null 2>&1
    pkill -9 -u "$USER" -f "steam-launch-wrapper" > /dev/null 2>&1
    pkill -9 -u "$USER" -f "TS3W.exe" > /dev/null 2>&1
    pkill -9 -u "$USER" -f "TS3.exe" > /dev/null 2>&1
    pkill -9 -u "$USER" -f "Sims3Launcher.exe" > /dev/null 2>&1
    pkill -9 -u "$USER" -f "Sims3LauncherW.exe" > /dev/null 2>&1
    pkill -9 -u "$USER" -f "TSLHelper.exe" > /dev/null 2>&1
    echo -e "${P}\e[1;32m✔ ¡Limpieza completada! El botón de Steam volverá a responder en verde.\e[0m"
    echo -ne "\n${P}Presiona Enter para continuar..."
    read -r
}

# --- SECCIÓN ACERCA DE & CHANGELOG ---
mostrar_acerca_de_ts3() {
    clear
    local P
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m            \e[1;32m💎 FIX SIMS 3 LINUX (EDICIÓN COMUNITARIA)\e[0m         \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m│\e[0m       \e[2;37mSteam • Steam Deck • Lutris • Bottles • Heroic\e[0m         \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m\n"
    echo -e "${P}  \e[1;37m• Versión:\e[0m        \e[1;32mv$VERSION\e[0m"
    echo -e "${P}  \e[1;37m• Autor:\e[0m          \e[1;36mJeff Cortez\e[0m"
    echo -e "${P}  \e[1;37m• Repositorio:\e[0m    \e[1;34mhttps://github.com/JeffCortez23/Fix_Sims_3_Linux\e[0m"
    echo -e "${P}  \e[1;37m• Compatibilidad:\e[0m \e[1;35mSteam, Steam Deck, Lutris, Bottles, Heroic, Wine\e[0m"
    echo -e "\n${P}\e[1;36m────────────────────────────────────────────────────────────────\e[0m"
    echo -e "${P}\e[1;33m📜 HISTORIAL DE CAMBIOS (CHANGELOG):\e[0m\n"
    echo -e "${P}  \e[1;32m[v2.2] - Gestión Directa de Mods & Worlds Store Updates\e[0m"
    echo -e "${P}    • 📂 \e[1;37mAbrir Carpeta Mods:\e[0m Acceso directo en el explorador de archivos nativo."
    echo -e "${P}    • 🏛️  \e[1;37mWorlds & Store Updates:\e[0m Auto-descompresión de Sims3Packs y Packages."
    echo -e "${P}  \e[1;32m[v2.1] - Descargador de EA DLC Unlocker & Universalización de Rutas\e[0m"
    echo -e "${P}    • 🌐 \e[1;37mEA DLC Unlocker Auto:\e[0m Descarga verificada v3.5.0 con g_LOS SIMS 3.ini."
    echo -e "${P}    • 🔓 \e[1;37mDoble Soporte:\e[0m Inyección nativa Wine/Proton y soporte EA App/Origin."
    echo -e "${P}    • 🌍 \e[1;37mRutas Dinámicas:\e[0m Compatibilidad total con Steam Deck, Wine, Lutris y Heroic.\n"
    echo -e "${P}  \e[1;32m[v2.0] - Detección de Hardware, Gráficos VRAM, Menús TS4 & Luva Pack\e[0m"
    echo -e "${P}    • 🎮 \e[1;37mDetección de Hardware:\e[0m Auto-detecta AMD, NVIDIA, Intel y RAM."
    echo -e "${P}    • ⚡ \e[1;37mGraphicsRules Dinámico:\e[0m Asigna VRAM óptima (1GB, 2GB o 4GB)."
    echo -e "${P}    • 🏝️  \e[1;37mIsla Paradiso Fix:\e[0m Parche anti-lag automático de mundo."
    echo -e "${P}    • 📦 \e[1;37mMods.zip Auto-deploy:\e[0m CleanUI y SmoothPatch a Documentos."
    echo -e "${P}    • 🎨 \e[1;37mMenús Idénticos a TS4:\e[0m Estilo TUI centrado con opciones organizadas."
    echo -e "${P}    • 🖥️  \e[1;37mAcceso Directo:\e[0m Creación de lanzador .desktop e icono Plumbob.\n"
    echo -e "${P}  \e[1;32m[v1.0] - Lanzamiento Inicial\e[0m"
    echo -e "${P}    • Inyección de registro de las 11 Expansiones y 9 Accesorios."
    echo -e "\n${P}\e[1;36m────────────────────────────────────────────────────────────────\e[0m"
    echo -ne "\n${P}Presiona Enter para volver al menú principal..."
    read -r
}

# --- MENÚ PRINCIPAL ---
while true; do
    clear
    P=$(obtener_padding)
    echo -e "\n\n"
    echo -e "${P}\e[1;36m╭──────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "${P}\e[1;36m│\e[0m         \e[1;32m💎 GESTOR DE LOS SIMS 3 (LINUX EDITION) v$VERSION\e[0m         \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m│\e[0m       \e[2;37mSteam • Steam Deck • Lutris • Bottles • Heroic\e[0m         \e[1;36m│\e[0m"
    echo -e "${P}\e[1;36m╰──────────────────────────────────────────────────────────────╯\e[0m"
    echo ""
    echo -e "${P}  \e[1;33m[1]\e[0m 📦  \e[1;37mInstalar / Mover DLCs al juego\e[0m \e[2;37m(ZIP All-in-One, Sueltos, Lotes)\e[0m"
    echo -e "${P}  \e[1;33m[2]\e[0m 🔓  \e[1;37mActivar DLCs\e[0m \e[2;37m(Inyección Wine/Proton y EA App)\e[0m"
    echo -e "${P}  \e[1;33m[3]\e[0m ⚡  \e[1;37mOptimización de Gráficos & GPU\e[0m \e[2;37m(Auto-detectar Hardware & VRAM)\e[0m"
    echo -e "${P}  \e[1;33m[4]\e[0m 📂  \e[1;37mAbrir carpeta Mods del juego\e[0m \e[2;37m(Packages / CC / Mods)\e[0m"
    echo -e "${P}  \e[1;33m[5]\e[0m 🔍  \e[1;37mDiagnóstico de DLCs e Integridad\e[0m \e[2;37m(Health Check)\e[0m"
    echo -e "${P}  \e[1;33m[6]\e[0m 🧹  \e[1;37mLimpiar Caché del Juego\e[0m \e[2;37m(Solución Carga Infinita)\e[0m"
    echo -e "${P}  \e[1;33m[7]\e[0m 🌐  \e[1;37mDescargar / Actualizar EA DLC Unlocker\e[0m \e[2;37m(Auto)\e[0m"
    echo -e "${P}  \e[1;33m[8]\e[0m 🖥️   \e[1;37mCrear Acceso Directo\e[0m \e[2;37m(.desktop / Steam Deck)\e[0m"
    echo -e "${P}  \e[1;33m[9]\e[0m 🔪  \e[1;37mForzar cierre de procesos colgados\e[0m \e[2;37m(Fix Sims 3 / Steam / EA)\e[0m"
    echo -e "${P}  \e[1;33m[10]\e[0m ⚙️   \e[1;37mReconfigurar rutas del script / Lanzador\e[0m"
    echo -e "${P}  \e[1;33m[11]\e[0m ℹ️  \e[1;37mAcerca de & Changelog\e[0m"
    echo -e "${P}  \e[1;31m[0]\e[0m 🚪  \e[1;37mSalir\e[0m"
    echo ""
    echo -e "${P}\e[1;36m────────────────────────────────────────────────────────────────\e[0m"
    echo -ne "${P}\e[1;33m👉 Elige una opción (0-11):\e[0m "
    read -r opcion

    case $opcion in
        1)
            echo -e "\n${P}\e[1;33m[Iniciando instalación / organización inteligente de DLCs de TS3...]\e[0m"
            mkdir -p "$SIMS_DIR"
            
            if [ -d "$DLC_SOURCE" ]; then
                mapfile -t ARCHIVOS_COMPRIMIDOS < <(find "$DLC_SOURCE" -maxdepth 1 -type f \( -iname "*.zip" -o -iname "*.rar" -o -iname "*.7z" \) | sort)
                
                if [ ${#ARCHIVOS_COMPRIMIDOS[@]} -gt 0 ]; then
                    echo -e "${P}\e[1;36mSe detectaron ${#ARCHIVOS_COMPRIMIDOS[@]} paquetes en la carpeta de descargas.\e[0m"
                    echo -e "${P}Analizando e instalando packs faltantes en: \e[36m$SIMS_DIR\e[0m\n"
                    
                    extraidos=0
                    omitidos=0
                    errores=0

                    for i in "${!ARCHIVOS_COMPRIMIDOS[@]}"; do
                        arch="${ARCHIVOS_COMPRIMIDOS[$i]}"
                        base_arch="$(basename "$arch")"

                        case "$base_arch" in
                            Mods.zip|*Parche*|*parche*|*Estabilidad*|*estabilidad*|*Worlds*|*worlds*)
                                continue
                                ;;
                        esac

                        arch_code=$(echo "$base_arch" | grep -o -E '(EP[0-9]{2}|SP[0-9]{2})' | head -n1 | tr '[:lower:]' '[:upper:]')
                        
                        if [ -n "$arch_code" ] && [ -d "$SIMS_DIR/$arch_code" ] && [ "$(ls -A "$SIMS_DIR/$arch_code" 2>/dev/null)" ]; then
                            echo -e "${P}[$((i+1))/${#ARCHIVOS_COMPRIMIDOS[@]}] \e[1;32m[✔ Ya instalado]\e[0m  \e[2;37m$base_arch\e[0m"
                            ((omitidos++))
                            continue
                        fi

                        if ! 7z t "$arch" > /dev/null 2>&1; then
                            echo -e "${P}[$((i+1))/${#ARCHIVOS_COMPRIMIDOS[@]}] \e[1;31m[❌ Archivo dañado/incompleto]\e[0m \e[1;37m$base_arch\e[0m (omitido)"
                            ((errores++))
                            continue
                        fi

                        echo -e "${P}[$((i+1))/${#ARCHIVOS_COMPRIMIDOS[@]}] \e[1;36m[📦 Extrayendo]\e[0m    \e[1;37m$base_arch\e[0m..."
                        7z x "$arch" -o"$SIMS_DIR" -y -bsp1
                        ((extraidos++))
                    done

                    echo -e "\n${P}\e[1;36m────────────────────────────────────────────────────────────────\e[0m"
                    echo -e "${P}\e[1;32mResumen de instalación:\e[0m"
                    echo -e "${P}  • Packs nuevos instalados:      \e[1;32m$extraidos\e[0m"
                    echo -e "${P}  • Packs ya presentes (omitidos): \e[1;33m$omitidos\e[0m"
                    [ "$errores" -gt 0 ] && echo -e "${P}  • Archivos dañados/incompletos:  \e[1;31m$errores\e[0m"
                fi

                # Copiar carpetas sueltas directas si las hay
                for item in "$DLC_SOURCE"/*; do
                    [ -e "$item" ] || continue
                    case "$item" in
                        *.zip|*.rar|*.7z|*.ZIP|*.RAR|*.7Z) ;;
                        *) cp -rn "$item" "$SIMS_DIR/" 2>/dev/null ;;
                    esac
                done

                arreglar_estructura_dlcs_ts3 "$SIMS_DIR"
                echo -e "\n${P}\e[1;32m¡Instalación y organización completada con éxito!\e[0m"
                
            elif [ -f "$DLC_SOURCE" ]; then
                if ! command -v 7z &> /dev/null; then
                    echo -e "\n${P}\e[31m¡Error! No tienes '7z' instalado en tu sistema.\e[0m"
                    echo -ne "\n${P}Presiona Enter para continuar..."
                    read -r
                    continue
                fi
                echo -e "${P}Modo Archivo único detectado. Descomprimiendo en: \e[36m$SIMS_DIR\e[0m\n"
                7z x "$DLC_SOURCE" -o"$SIMS_DIR" -y -bsp1
                arreglar_estructura_dlcs_ts3 "$SIMS_DIR"
                echo -e "\n${P}\e[1;32m¡Extracción y organización terminada!\e[0m"
                
            else
                echo -e "\n${P}\e[33mAviso: No se encontró archivo o carpeta en '$DLC_SOURCE'.\e[0m"
                echo -e "${P}Revisando y organizando DLCs ya presentes en la carpeta del juego..."
                arreglar_estructura_dlcs_ts3 "$SIMS_DIR"
            fi

            echo -ne "\n${P}Presiona Enter para continuar..."
            read -r
            ;;

        2)
            activar_registro_dlcs_ts3
            ;;

        3)
            optimizar_rendimiento_ts3
            ;;

        4)
            abrir_carpeta_mods_ts3
            ;;

        5)
            diagnosticar_dlcs_ts3
            ;;

        6)
            limpiar_cache_ts3
            ;;

        7)
            descargar_unlocker_auto
            ;;

        8)
            crear_acceso_directo_ts3
            ;;

        9)
            matar_procesos_colgados_ts3
            ;;

        10)
            configurar_rutas
            source "$CONFIG_FILE"
            resolver_rutas_efectivas
            ;;

        11)
            mostrar_acerca_de_ts3
            ;;

        0)
            clear
            P=$(obtener_padding)
            echo -e "\n\n"
            echo -e "${P}\e[1;32m💎 ¡Que disfrutes jugando Los Sims 3 en Linux!\e[0m\n"
            exit 0
            ;;

        *)
            echo -e "\n${P}\e[31mOpción no válida.\e[0m"
            sleep 1
            ;;
    esac
done
