#!/usr/bin/env bash
set -euo pipefail

# Compila el proyecto usando el JDK/SDK de Linux guardados en
# ~/.android-build-tools, sin dejar roto el local.properties real
# (que debe apuntar siempre al SDK de Windows para que Android Studio
# lo siga encontrando).
#
# Uso:
#   ./scripts/compilar-y-verificar.sh                  -> compileDebugKotlin (rapido)
#   ./scripts/compilar-y-verificar.sh assembleDebug     -> APK completo
#
# El local.properties real se restaura solo, incluso si el build falla
# o el script se interrumpe a la mitad (trap en EXIT).

PROYECTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_PROPS="$PROYECTO_DIR/local.properties"
BACKUP="$PROYECTO_DIR/local.properties.backup-temporal"
JDK_DIR="$HOME/.android-build-tools/jdk-17/jdk-17.0.19+10"
SDK_DIR="$HOME/.android-build-tools/android-sdk"
TAREA="${1:-compileDebugKotlin}"

if [ ! -d "$JDK_DIR" ] || [ ! -d "$SDK_DIR" ]; then
    echo "ERROR: no se encontro el JDK/SDK persistente en ~/.android-build-tools/"
    echo "Hay que descargarlos primero (JDK 17 + Android SDK: platform-tools,"
    echo "platforms;android-34, build-tools;34.0.0) antes de usar este script."
    exit 1
fi

if [ ! -f "$LOCAL_PROPS" ]; then
    echo "ERROR: no se encontro $LOCAL_PROPS"
    exit 1
fi

if [ -f "$BACKUP" ]; then
    echo "ERROR: ya existe $BACKUP"
    echo "Esto indica que una corrida anterior se interrumpio antes de restaurar"
    echo "el local.properties real (ej. kill -9 o un crash de WSL a mitad del build)."
    echo "Revisa a mano cual de los dos archivos tiene tu sdk.dir real de Windows"
    echo "(local.properties o local.properties.backup-temporal) antes de continuar,"
    echo "para no perderlo. Cuando lo confirmes, borra el backup y vuelve a correr."
    exit 1
fi

echo "==> Respaldando local.properties real..."
cp "$LOCAL_PROPS" "$BACKUP"

restaurar() {
    echo "==> Restaurando local.properties real..."
    cp "$BACKUP" "$LOCAL_PROPS"
    rm -f "$BACKUP"
}
trap restaurar EXIT

echo "==> Apuntando local.properties al SDK de Linux (temporal, solo para este build)..."
SUPABASE_URL=$(grep '^SUPABASE_URL=' "$BACKUP" | cut -d'=' -f2-)
SUPABASE_ANON_KEY=$(grep '^SUPABASE_ANON_KEY=' "$BACKUP" | cut -d'=' -f2-)

cat > "$LOCAL_PROPS" <<EOF
sdk.dir=$SDK_DIR

SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
EOF

export JAVA_HOME="$JDK_DIR"
export PATH="$JAVA_HOME/bin:$PATH"

echo "==> Compilando ($TAREA)..."
cd "$PROYECTO_DIR"
./gradlew "$TAREA" --console=plain

echo "==> Listo. El local.properties real ya quedo restaurado."
