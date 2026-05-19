#!/usr/bin/env bash
# lazy_case.sh
# Renomeia arquivos interativamente: pergunta upper/lower e extensão alvo.
#
# Uso: ./lazy_case.sh [opções] [diretório]
#
# Opções:
#   -r, --recursive   Processa subdiretórios (bottom-up)
#   -n, --dry-run     Simula sem renomear nada
#   -h, --help        Exibe esta ajuda

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  R='\033[0m' BOLD='\033[1m'
  GREEN='\033[0;32m' YELLOW='\033[0;33m' CYAN='\033[0;36m'
  BLUE='\033[0;34m' DIM='\033[2m' MAGENTA='\033[0;35m'
else
  R='' BOLD='' GREEN='' YELLOW='' CYAN='' BLUE='' DIM='' MAGENTA=''
fi

# ── Ajuda ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}Uso:${R} $(basename "$0") [opções] [diretório]

Renomeia arquivos para maiúsculo ou minúsculo, filtrando por extensão.

${BOLD}Opções:${R}
  -r, --recursive   Processa subdiretórios (bottom-up)
  -n, --dry-run     Simula as renomeações sem alterar nada
  -h, --help        Exibe esta ajuda

${BOLD}Exemplos:${R}
  $(basename "$0") ./fotos
  $(basename "$0") -r ./projeto
  $(basename "$0") -rn ./projeto
EOF
  exit 0
}

# ── Argumentos ────────────────────────────────────────────────────────────────
TARGET_DIR="."
RECURSIVE=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    -h|--help)     usage ;;
    -r|--recursive) RECURSIVE=true ;;
    -n|--dry-run)  DRY_RUN=true ;;
    -rn|-nr)       RECURSIVE=true; DRY_RUN=true ;;
    -*)            echo "Opção desconhecida: $arg" >&2; exit 1 ;;
    *)             TARGET_DIR="$arg" ;;
  esac
done

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Erro: '$TARGET_DIR' não é um diretório válido." >&2
  exit 1
fi

TARGET_DIR="$(realpath "$TARGET_DIR")"

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}╔═══════════════════════════════════════════╗${R}"
echo -e "${BOLD}${BLUE}║${R}         ${BOLD}lazy_case — renomeador${R}           ${BOLD}${BLUE}║${R}"
echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════╝${R}"
echo -e "  ${DIM}Diretório: $TARGET_DIR${R}"
$DRY_RUN && echo -e "  ${CYAN}⚑  DRY-RUN ativo — nada será alterado${R}"
echo ""

# ── Pergunta 1: upper ou lower ────────────────────────────────────────────────
echo -e "${BOLD}  Para qual caso deseja renomear?${R}"
echo -e "    ${MAGENTA}[1]${R}  lower  ${DIM}(ex: MinhaFoto.JPG → minhafoto.jpg)${R}"
echo -e "    ${MAGENTA}[2]${R}  UPPER  ${DIM}(ex: minha-foto.jpg → MINHA-FOTO.JPG)${R}"
echo ""
while true; do
  read -rp "  Escolha [1/2]: " CASE_CHOICE
  case "$CASE_CHOICE" in
    1) MODE="lower"; break ;;
    2) MODE="upper"; break ;;
    *) echo -e "  ${YELLOW}Por favor, digite 1 ou 2.${R}" ;;
  esac
done

# ── Descobre extensões disponíveis no diretório ───────────────────────────────
mapfile -t EXTENSIONS < <(
  find "$TARGET_DIR" \
    $( $RECURSIVE && echo "" || echo "-maxdepth 1" ) \
    -type f -name '*.*' \
  | sed 's/.*\.//' \
  | tr '[:upper:]' '[:lower:]' \
  | sort -u
)

echo ""
echo -e "${BOLD}  Quais arquivos deseja renomear?${R}"
echo -e "    ${DIM}(diretórios são sempre incluídos)${R}"
echo -e "    ${MAGENTA}[0]${R}  ${BOLD}Todos${R} os arquivos"

if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
  echo -e "    ${DIM}(nenhuma extensão encontrada — apenas a opção 0 disponível)${R}"
else
  i=1
  for ext in "${EXTENSIONS[@]}"; do
    count=$(find "$TARGET_DIR" \
      $( $RECURSIVE && echo "" || echo "-maxdepth 1" ) \
      -type f -iname "*.${ext}" | wc -l | tr -d ' ')
    echo -e "    ${MAGENTA}[$i]${R}  .${ext}  ${DIM}(${count} arquivo(s))${R}"
    ((i++)) || true
  done
fi

echo ""
while true; do
  read -rp "  Escolha: " EXT_CHOICE
  if [[ "$EXT_CHOICE" == "0" ]]; then
    FILTER_EXT=""
    break
  elif [[ "$EXT_CHOICE" =~ ^[0-9]+$ ]] && \
       [[ "$EXT_CHOICE" -ge 1 ]] && \
       [[ "$EXT_CHOICE" -le ${#EXTENSIONS[@]} ]]; then
    FILTER_EXT="${EXTENSIONS[$((EXT_CHOICE - 1))]}"
    break
  else
    echo -e "  ${YELLOW}Opção inválida. Tente novamente.${R}"
  fi
done

# ── Confirmação ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ┌─ Resumo ───────────────────────────────────┐${R}"
echo -e "  │  Diretório : $TARGET_DIR"
echo -e "  │  Caso      : ${BOLD}$MODE${R}"
[[ -n "$FILTER_EXT" ]] \
  && echo -e "  │  Arquivos  : ${BOLD}.${FILTER_EXT}${R} + todos os diretórios" \
  || echo -e "  │  Arquivos  : ${BOLD}todos${R} (arquivos e diretórios)"
$RECURSIVE \
  && echo "  │  Modo      : recursivo" \
  || echo "  │  Modo      : apenas nível raiz"
$DRY_RUN && echo -e "  │  ${CYAN}Dry-run ativo — nada será alterado${R}"
echo -e "${BOLD}  └────────────────────────────────────────────┘${R}"
echo ""
read -rp "  Continuar? [s/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[sS]$ ]] || { echo "  Cancelado."; exit 0; }
echo ""

# ── Contadores globais ────────────────────────────────────────────────────────
TOTAL_RENAMED=0
TOTAL_SKIPPED=0
TOTAL_CONFLICTS=0
TOTAL_SYMLINKS=0

# ── Função de conversão de nome ───────────────────────────────────────────────
convert_name() {
  if [[ "$MODE" == "lower" ]]; then
    echo "$1" | tr '[:upper:]' '[:lower:]'
  else
    echo "$1" | tr '[:lower:]' '[:upper:]'
  fi
}

# ── Função de renomeação de uma entrada ───────────────────────────────────────
rename_one() {
  local entry="$1"
  local parent base new_base new_path

  parent="$(dirname "$entry")"
  base="$(basename "$entry")"

  # Symlinks: avisar e pular
  if [[ -L "$entry" ]]; then
    echo -e "  ${CYAN}⤷  SYMLINK ignorado:${R} '$base'"
    ((TOTAL_SYMLINKS++)) || true
    return
  fi

  new_base="$(convert_name "$base")"

  if [[ "$base" == "$new_base" ]]; then
    ((TOTAL_SKIPPED++)) || true
    return
  fi

  new_path="$parent/$new_base"

  if [[ -e "$new_path" && "$entry" != "$new_path" ]]; then
    echo -e "  ${YELLOW}⚠  CONFLITO:${R} '$base'  →  '$new_base' já existe"
    ((TOTAL_CONFLICTS++)) || true
    return
  fi

  if $DRY_RUN; then
    echo -e "  ${CYAN}~${R}  '$base'  →  '$new_base'"
  else
    mv -- "$entry" "$new_path"
    echo -e "  ${GREEN}✔${R}  '$base'  →  '$new_base'"
  fi
  ((TOTAL_RENAMED++)) || true
}

# ── Execução ──────────────────────────────────────────────────────────────────
# Arquivos primeiro (com filtro de extensão se definido), depois diretórios
# bottom-up para não quebrar caminhos ao renomear pais antes dos filhos.

if $RECURSIVE; then
  # Arquivos em todos os subdiretórios
  while IFS= read -r -d '' entry; do
    rename_one "$entry"
  done < <(
    find "$TARGET_DIR" -type f \
      ${FILTER_EXT:+-iname "*.${FILTER_EXT}"} \
      -print0 | sort -rz
  )
  # Diretórios bottom-up (excluindo o próprio TARGET_DIR)
  while IFS= read -r -d '' entry; do
    [[ "$entry" == "$TARGET_DIR" ]] && continue
    rename_one "$entry"
  done < <(find "$TARGET_DIR" -mindepth 1 -type d -print0 | sort -rz)
else
  # Arquivos no nível raiz
  while IFS= read -r -d '' entry; do
    rename_one "$entry"
  done < <(
    find "$TARGET_DIR" -maxdepth 1 -mindepth 1 -type f \
      ${FILTER_EXT:+-iname "*.${FILTER_EXT}"} \
      -print0 | sort -rz
  )
  # Diretórios no nível raiz
  while IFS= read -r -d '' entry; do
    rename_one "$entry"
  done < <(find "$TARGET_DIR" -maxdepth 1 -mindepth 1 -type d -print0 | sort -rz)
fi

# ── Sumário ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ────────────────────────────────────────────${R}"
$DRY_RUN \
  && echo -e "  ${CYAN}Simulação concluída — nada foi alterado${R}" \
  || echo -e "  ${GREEN}✅ Concluído${R}"
echo -e "  Renomeados : ${BOLD}$TOTAL_RENAMED${R}"
echo    "  Sem mudança: $TOTAL_SKIPPED"
[[ $TOTAL_CONFLICTS -gt 0 ]] && echo -e "  ${YELLOW}Conflitos  : $TOTAL_CONFLICTS${R}"
[[ $TOTAL_SYMLINKS  -gt 0 ]] && echo    "  Symlinks   : $TOTAL_SYMLINKS (ignorados)"
echo -e "${BOLD}  ────────────────────────────────────────────${R}"
echo ""