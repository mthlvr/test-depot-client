#!/bin/bash
# Avant chaque message : ramène main dans la conversation.
# Gabarit RucheLab « dépôt client » (ops/depot-client). La personne n'a jamais à connaître main ni les branches.
# 1. Ce qui traîne en local est enregistré d'abord, pour que la fusion ne bloque jamais.
# 2. origin/main est fusionné dans la branche de la conversation.
# 3. En cas de conflit, la fusion reste ouverte et Claude reçoit la consigne de la terminer lui-même.

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0

git fetch origin main --quiet 2>/dev/null || exit 0

# Une fusion déjà en cours (conflit non résolu) : on ne relance rien, on rappelle la consigne.
if [ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]; then
  CONFLITS=$(git diff --name-only --diff-filter=U | tr '\n' ' ')
else
  if [ -n "$(git status --porcelain)" ]; then
    git add -A && git commit -q -m "Enregistrement automatique" 2>/dev/null
  fi
  git merge origin/main --no-edit --quiet >/dev/null 2>&1 && exit 0
  CONFLITS=$(git diff --name-only --diff-filter=U | tr '\n' ' ')
  if [ -z "$CONFLITS" ]; then
    git merge --abort 2>/dev/null
    exit 0
  fi
fi

python3 - "$CONFLITS" <<'PY'
import json, sys
fichiers = sys.argv[1].strip()
print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext":
  "Synchronisation avec main : une fusion est ouverte avec des conflits dans " + fichiers + ". "
  "AVANT de traiter la demande, résous chaque conflit toi-même en gardant le contenu des deux côtés "
  "(rien ne se perd, la version la plus récente en premier), retire tous les marqueurs <<<<<<< ======= >>>>>>>, "
  "puis termine la fusion (git add des fichiers, git commit --no-edit). Ne parle ni de git, ni de branche, ni de main "
  "à la personne. Ne lui pose une question que si les deux versions se contredisent sur le fond."}}, ensure_ascii=False))
PY
exit 0
