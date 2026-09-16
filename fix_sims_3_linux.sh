#!/usr/bin/env bash

# ==============================================================================
#   💎 Fix Sims 3 Linux (Edición Comunitaria) v2.0
#   Soporta Steam, Steam Deck, Lutris, Bottles, Heroic & Wine
#   Compatible con Juego Base Steam, EA App y versiones Standalone
#   Desarrollado por Jeff Cortez (github.com/JeffCortez23)
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="$HOME/.config/sims3_gestor.conf"
ICON_PATH="$HOME/.local/share/icons/fix-sims-3.svg"
VERSION="2.0"

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

# Resolver carpeta raíz del juego
if [ -d "$STEAM_LIBRARY/steamapps/common/The Sims 3" ]; then
    SIMS_DIR="$STEAM_LIBRARY/steamapps/common/The Sims 3"
elif [ -d "$STEAM_LIBRARY" ] && [[ "$STEAM_LIBRARY" =~ (The Sims 3|Los Sims 3) ]]; then
    SIMS_DIR="$STEAM_LIBRARY"
else
    SIMS_DIR="$STEAM_LIBRARY/steamapps/common/The Sims 3"
fi

# Resolver prefijo Proton/Wine de forma segura
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

# --- ORGANIZADOR / APLANADOR DE DLCS PARA LOS SIMS 3 ---
arreglar_estructura_dlcs_ts3() {
    local target_dir="$1"
    local P
    P=$(obtener_padding)
    
    # 1. Si los DLCs se descomprimieron dentro de una subcarpeta "The Sims 3" o "Los Sims 3" o "All in One"
    for sub in "$target_dir/The Sims 3" "$target_dir/Los Sims 3" "$target_dir/all in one" "$target_dir/All in One" "$target_dir/DLCs"; do
        if [ -d "$sub" ]; then
            echo -e "${P}Moviendo contenidos desde subcarpeta '$sub' a la raíz del juego..."
            cp -rn "$sub/"* "$target_dir/" 2>/dev/null || mv -n "$sub/"* "$target_dir/" 2>/dev/null
            rm -rf "$sub" 2>/dev/null || true
        fi
    done

    # 2. Comprobar si el usuario descargó el parche de Isla Paradiso de Luva
    local isla_zip
    isla_zip=$(find "$HOME/Downloads" -maxdepth 2 -type f -iname "*isla*paradiso*.zip" 2>/dev/null | head -n1)
    if [ -n "$isla_zip" ] && [ -d "$target_dir/EP10" ]; then
        local worlds_dir="$target_dir/EP10/GameData/Shared/NonPackaged/Worlds"
        if [ -d "$worlds_dir" ]; then
            echo -e "${P}Instalando Parche de Mundo 'Isla Paradiso' corregido..."
            7z e "$isla_zip" -o"$worlds_dir" "*.world" -y > /dev/null 2>&1
            echo -e "${P}  \e[1;32m✔\e[0m IslaParadiso.world reemplazado por la versión sin lag ni congelamientos."
        fi
    fi

    # 3. Comprobar si el usuario descargó Mods.zip de Luva (CleanUI, SmoothPatch, Store Packages)
    local mods_zip
    mods_zip=$(find "$HOME/Downloads" -maxdepth 2 -type f -iname "Mods.zip" 2>/dev/null | head -n1)
    local doc_ts3="$PREFIX/drive_c/users/steamuser/Documents/Electronic Arts/The Sims 3"
    if [ -n "$mods_zip" ] && [ -d "$doc_ts3" ]; then
        echo -e "${P}Instalando paquete de Mods y Store esenciales de Luva..."
        mkdir -p "$doc_ts3/Mods"
        7z x "$mods_zip" -o"$doc_ts3" -y -bsp1
        echo -e "${P}  \e[1;32m✔\e[0m Mods de estabilidad (CleanUI, ld_SmoothPatch, Store) instalados en Documentos."
    fi
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

    echo -e "${P}Inyectando claves de activación para todas las expansiones y accesorios..."
    
    # Backup preventivo
    cp "$SYSTEM_REG" "$SYSTEM_REG.bak_$(date +%s)"

    local packs_data=(
        "EP01|The Sims 3 World Adventures|1002|EP01"
        "EP02|The Sims 3 Ambitions|1003|EP02"
        "EP03|The Sims 3 Late Night|1004|EP03"
        "EP04|The Sims 3 Generations|1005|EP04"
        "EP05|The Sims 3 Pets|1006|EP05"
        "EP06|The Sims 3 Showtime|1007|EP06"
        "EP07|The Sims 3 Supernatural|1008|EP07"
        "EP08|The Sims 3 Seasons|1009|EP08"
        "EP09|The Sims 3 University Life|1010|EP09"
        "EP10|The Sims 3 Island Paradise|1011|EP10"
        "EP11|The Sims 3 Into the Future|1012|EP11"
        "SP01|The Sims 3 High-End Loft Stuff|1051|SP01"
        "SP02|The Sims 3 Fast Lane Stuff|1052|SP02"
        "SP03|The Sims 3 Outdoor Living Stuff|1053|SP03"
        "SP04|The Sims 3 Town Life Stuff|1054|SP04"
        "SP05|The Sims 3 Master Suite Stuff|1055|SP05"
        "SP06|The Sims 3 Sweet Treats|1056|SP06"
        "SP07|The Sims 3 Diesel Stuff|1057|SP07"
        "SP08|The Sims 3 70s, 80s, & 90s Stuff|1058|SP08"
        "SP09|The Sims 3 Movie Stuff|1059|SP09"
    )

    local ts
    ts=$(date +%s)
    local win_game_dir
    win_game_dir=$(winepath -w "$SIMS_DIR" 2>/dev/null || echo "C:\\Program Files (x86)\\Steam\\steamapps\\common\\The Sims 3")
    win_game_dir_esc="${win_game_dir//\\/\\\\}"

    for item in "${packs_data[@]}"; do
        IFS="|" read -r code name prod_id folder <<< "$item"
        
        # Clave en Sims(Steam)
        if ! grep -q "\[Software\\\\Sims(Steam)\\\\$name\]" "$SYSTEM_REG" 2>/dev/null; then
            cat <<EOF >> "$SYSTEM_REG"

[Software\\\\Sims(Steam)\\\\$name] $ts
"DisplayName"="$name"
"ExePath"="$win_game_dir_esc\\\\$folder\\\\Game\\\\Bin\\\\TS3$code.exe"
"Install Dir"="$win_game_dir_esc\\\\$folder"
"Locale"="es-es"
"Country"="ES"
"ProductID"=dword:$(printf "%08x" "$prod_id")
"SKU"=dword:00000007
"Telemetry"=dword:00000000
EOF
        fi

        # Clave en Wow6432Node
        if ! grep -q "\[Software\\\\Wow6432Node\\\\Sims\\\\$name\]" "$SYSTEM_REG" 2>/dev/null; then
            cat <<EOF >> "$SYSTEM_REG"

[Software\\\\Wow6432Node\\\\Sims\\\\$name] $ts
"DisplayName"="$name"
"ExePath"="$win_game_dir_esc\\\\$folder\\\\Game\\\\Bin\\\\TS3$code.exe"
"Install Dir"="$win_game_dir_esc\\\\$folder"
"Locale"="es-es"
"Country"="ES"
"ProductID"=dword:$(printf "%08x" "$prod_id")
"SKU"=dword:00000007
"Telemetry"=dword:00000000
EOF
        fi
    done

    echo -e "${P}\e[1;32m✔ Claves de registro inyectadas exitosamente en Wine/Proton.\e[0m"
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
    local doc_options="$PREFIX/drive_c/users/steamuser/Documents/Electronic Arts/The Sims 3/Options.ini"
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
    estabilidad_zip=$(find "$HOME/Downloads" -maxdepth 2 -type f -iname "*estabilidad*sims*3*.zip" 2>/dev/null | head -n1)
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
    if [ -f "$SYSTEM_REG" ] && grep -q "Software\\\\Sims(Steam)" "$SYSTEM_REG" 2>/dev/null; then
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

    local doc_dir="$PREFIX/drive_c/users/steamuser/Documents/Electronic Arts/The Sims 3"
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
    echo -e "${P}  \e[1;32m[v2.0] - Detección de Hardware, Gráficos VRAM, Menús TS4 & Luva Pack\e[0m"
    echo -e "${P}    • 🎮 \e[1;37mDetección de Hardware:\e[0m Auto-detecta AMD, NVIDIA, Intel y RAM."
    echo -e "${P}    • ⚡ \e[1;37mGraphicsRules Dinámico:\e[0m Asigna VRAM óptima (1GB, 2GB o 4GB)."
    echo -e "${P}    • 🏝️  \e[1;37mIsla Paradiso Fix:\e[0m Parche anti-lag automático de mundo."
    echo -e "${P}    • 📦 \e[1;37mMods.zip Auto-deploy:\e[0m CleanUI y SmoothPatch a Documentos."
    echo -e "${P}    • 🎨 \e[1;37mMenús Idénticos a TS4:\e[0m Estilo TUI centrado con 9 opciones."
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
    echo -e "${P}  \e[1;33m[2]\e[0m 🔓  \e[1;37mActivar DLCs\e[0m \e[2;37m(Inyección de Registro Wine/Proton)\e[0m"
    echo -e "${P}  \e[1;33m[3]\e[0m ⚡  \e[1;37mOptimización de Gráficos & GPU\e[0m \e[2;37m(Auto-detectar Hardware & VRAM)\e[0m"
    echo -e "${P}  \e[1;33m[4]\e[0m 🔍  \e[1;37mDiagnóstico de DLCs e Integridad\e[0m \e[2;37m(Health Check)\e[0m"
    echo -e "${P}  \e[1;33m[5]\e[0m 🧹  \e[1;37mLimpiar Caché del Juego\e[0m \e[2;37m(Solución Carga Infinita)\e[0m"
    echo -e "${P}  \e[1;33m[6]\e[0m 🖥️   \e[1;37mCrear Acceso Directo\e[0m \e[2;37m(.desktop / Steam Deck)\e[0m"
    echo -e "${P}  \e[1;33m[7]\e[0m 🔪  \e[1;37mForzar cierre de procesos colgados\e[0m \e[2;37m(Fix Sims 3 / Steam)\e[0m"
    echo -e "${P}  \e[1;33m[8]\e[0m ⚙️   \e[1;37mReconfigurar rutas del script / Lanzador\e[0m"
    echo -e "${P}  \e[1;33m[9]\e[0m ℹ️   \e[1;37mAcerca de & Changelog\e[0m"
    echo -e "${P}  \e[1;31m[0]\e[0m 🚪  \e[1;37mSalir\e[0m"
    echo ""
    echo -e "${P}\e[1;36m────────────────────────────────────────────────────────────────\e[0m"
    echo -ne "${P}\e[1;33m👉 Elige una opción (0-9):\e[0m "
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
            diagnosticar_dlcs_ts3
            ;;

        5)
            limpiar_cache_ts3
            ;;

        6)
            crear_acceso_directo_ts3
            ;;

        7)
            matar_procesos_colgados_ts3
            ;;

        8)
            configurar_rutas
            source "$CONFIG_FILE"
            if [ -d "$STEAM_LIBRARY/steamapps/common/The Sims 3" ]; then
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
            ;;

        9)
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
