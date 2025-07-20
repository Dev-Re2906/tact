#!/bin/bash

# ================================================================
# 🔧 Ultimate Multi-Stack Dev Assistant - Build, Watch & Deploy
# Supports: Node.js, Python, Docker, Git, TON Smart Contracts
# Modes: One-Time, Continuous Watch, CI/CD
# ================================================================

LOG_FILE="./dev-assistant.log"
RUN_ALL=true
WATCH_INTERVAL=30
MODE="one-time"  # default: one-time, options: watch, cicd

trap 'echo "🛑 Stopping assistant..."; exit 0' SIGINT

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# -------------------------------
# Detect Project Type
# -------------------------------
detect_type() {
  local dir="$1"
  if [ -f "$dir/package.json" ]; then echo "node"
  elif [ -f "$dir/requirements.txt" ] || [ -f "$dir/pyproject.toml" ]; then echo "python"
  elif [ -f "$dir/Dockerfile" ]; then echo "docker"
  elif [ -f "$dir/jetton-minter.fc" ] || [ -f "$dir/jetton-wallet.fc" ]; then echo "ton"
  elif [ -d "$dir/.git" ]; then echo "git"
  else echo "unknown"; fi
}

# -------------------------------
# Deploy Functions
# -------------------------------
deploy_node() {
  local dir="$1"
  log "🚀 Deploying Node.js app from $dir to production..."
  (cd "$dir" && npx vercel --prod || npx netlify deploy --prod) || log "⚠️ Node.js deploy failed"
}

deploy_docker() {
  local dir="$1"
  log "🐳 Deploying Docker image from $dir..."
  (cd "$dir" && docker build -t "$(basename "$dir")" . && docker push "$(basename "$dir")") || log "⚠️ Docker deploy failed"
}

deploy_ton() {
  local dir="$1"
  log "💎 Deploying TON smart contract from $dir to Mainnet..."
  (cd "$dir" && toncli contract deploy --net mainnet --ton-os-se --wc 0 || tondev deploy) || log "⚠️ TON deploy failed"
}

deploy_git() {
  local dir="$1"
  log "📤 Pushing latest changes from $dir..."
  (cd "$dir" && git add . && git commit -m "Auto-deploy" && git push && git tag -a "v$(date +%Y.%m.%d.%H%M)" -m "Release" && git push --tags) || log "⚠️ Git push failed"
}

# -------------------------------
# Build & Run Project by Type
# -------------------------------
process_project() {
  local dir="$1"
  local type; type=$(detect_type "$dir")
  log "📂 Processing: $dir (type: $type)"

  case $type in
    node)
      (cd "$dir" && npm install --silent)
      (cd "$dir" && npm run build || true)
      if $RUN_ALL; then (cd "$dir" && npm start &) fi
      deploy_node "$dir"
      ;;
    python)
      (cd "$dir" && pip install -r requirements.txt >/dev/null 2>&1 || true)
      if $RUN_ALL && [ -f "$dir/main.py" ]; then (cd "$dir" && python3 main.py &) fi
      ;;
    docker)
      (cd "$dir" && docker build -t "$(basename "$dir")" .)
      if $RUN_ALL; then (cd "$dir" && docker run -d --rm "$(basename "$dir")") fi
      deploy_docker "$dir"
      ;;
    ton)
      log "🔨 Building TON contract..."
      (cd "$dir" && func -o build.fc *.fc || true)
      deploy_ton "$dir"
      ;;
    git)
      (cd "$dir" && git pull --quiet)
      deploy_git "$dir"
      ;;
    *)
      log "ℹ️ Skipping unknown project type at $dir"
      ;;
  esac
}

# -------------------------------
# Scan All Projects Recursively
# -------------------------------
scan_projects() {
  log "🔍 Scanning for all projects..."
  find . -type d \( -name "node_modules" -o -name ".venv" \) -prune -o \
    -type f \( -name "package.json" -o -name "requirements.txt" -o -name "Dockerfile" -o -name "jetton-minter.fc" \) -print |
  while read -r file; do
    process_project "$(dirname "$file")"
  done
}

# -------------------------------
# Mode Selection
# -------------------------------
show_help() {
  echo "Usage: $0 [mode]"
  echo "Modes:"
  echo "  one-time    Build, run, deploy all projects once (default)"
  echo "  watch       Continuously monitor and deploy on changes"
  echo "  cicd        CI/CD mode (optimized for GitHub Actions)"
  exit 0
}

if [ "$1" = "watch" ]; then
  MODE="watch"
elif [ "$1" = "cicd" ]; then
  MODE="cicd"
elif [ "$1" = "help" ] || [ "$1" = "--help" ]; then
  show_help
fi

# -------------------------------
# Main Loop
# -------------------------------
case $MODE in
  one-time)
    log "▶️ Running one-time build & deploy for all projects"
    scan_projects
    ;;
  watch)
    log "👀 Starting watch mode (polling every $WATCH_INTERVAL seconds)"
    while true; do
      scan_projects
      sleep "$WATCH_INTERVAL"
    done
    ;;
  cicd)
    log "⚙️ Running in CI/CD mode (non-interactive, optimized for pipelines)"
    RUN_ALL=false
    scan_projects
    ;;
esac
