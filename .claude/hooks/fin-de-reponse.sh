#!/bin/bash
# Après chaque réponse : relit, enregistre, envoie.
# Gabarit RucheLab « dépôt client » (ops/depot-client).
# 1. Tirets cadratins ou demi-cadratins dans les lignes AJOUTÉES aux .md : Claude corrige avant de rendre la main
#    (une seule relance par réponse, jamais de boucle).
# 2. Tout est enregistré et envoyé sur GitHub. L'Action fusion-auto le verse dans main.
# Ne bloque jamais la session sur une erreur git.

ENTREE=$(cat)
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0
DEJA_RELANCE=$(printf '%s' "$ENTREE" | grep -c '"stop_hook_active"[[:space:]]*:[[:space:]]*true')
EXCLURE='^(00-Inbox|04-Archives)/'

# Une fusion avec conflit en cours : on n'enregistre surtout pas des marqueurs de conflit.
if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
  if [ "$DEJA_RELANCE" = "0" ]; then
    echo "Une fusion avec conflits est encore ouverte ($(git diff --name-only --diff-filter=U | tr '\n' ' ')). Termine-la : garde le contenu des deux côtés, retire les marqueurs, git add, git commit --no-edit." >&2
    exit 2
  fi
  exit 0
fi

# 1. Les tirets
if [ "$DEJA_RELANCE" = "0" ]; then
  git fetch origin main --quiet 2>/dev/null
  BASE=$(git merge-base HEAD origin/main 2>/dev/null || git rev-parse HEAD)
  TROUVES=$(
    {
      git diff -U0 "$BASE" -- '*.md' | awk '/^\+\+\+ b\//{f=substr($0,7)} /^\+[^+]/{print f": "substr($0,2)}'
      git ls-files --others --exclude-standard -- '*.md' | while read -r f; do sed "s|^|$f: |" "$f"; done
    } | grep -E '—|–' | grep -Ev "$EXCLURE" | cut -c1-160 | head -20
  )
  if [ -n "$TROUVES" ]; then
    {
      echo "Ta réponse a laissé des tirets cadratins (—) ou demi-cadratins (–), interdits par CLAUDE.md."
      echo "Remplace-les dans les fichiers ci-dessous : virgule, deux-points, point ou parenthèses ; « 7h30 à 8h » pour une plage horaire. Puis termine, sans en parler."
      echo "$TROUVES"
    } >&2
    exit 2
  fi
fi

# 2. Enregistrer et envoyer
if [ -n "$(git status --porcelain)" ]; then
  git add -A && git commit -q -m "Enregistrement automatique" 2>/dev/null
fi
BRANCHE=$(git branch --show-current)
[ -z "$BRANCHE" ] && exit 0
if ! git push -q -u origin HEAD 2>/dev/null; then
  echo '{"systemMessage": "Enregistrement en ligne impossible pour l instant, je réessaie à la prochaine réponse."}'
fi
exit 0
