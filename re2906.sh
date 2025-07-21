#!/bin/bash
set -e
LOG_FILE="./ultimate-repo-manager.log"
trap 'echo "🛑 Stopped"; exit 0' SIGINT
log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# -------------------------------
# 1. Install Node.js (Clean + Latest)
# -------------------------------
install_node() {
  log "🔧 Installing Node.js..."
  apt purge -y nodejs npm || true
  apt autoremove -y || true

  # حذف کامل نسخه قبلی
  rm -rf $HOME/nodejs

  cd /tmp
  NODE_VER="v20.11.1"
  ARCH="linux-x64"
  curl -O https://nodejs.org/dist/$NODE_VER/node-$NODE_VER-$ARCH.tar.xz
  tar -xf node-$NODE_VER-$ARCH.tar.xz
  mkdir -p $HOME/nodejs
  mv node-$NODE_VER-$ARCH/* $HOME/nodejs/
  echo 'export PATH=$HOME/nodejs/bin:$PATH' >> ~/.bashrc
  export PATH=$HOME/nodejs/bin:$PATH
  cd - >/dev/null

  log "✅ Node.js: $(node -v), npm: $(npm -v)"
}

# -------------------------------
# 2. Python venv (PEP668 safe)
# -------------------------------
install_python_env() {
  log "🐍 Setting up Python venv..."
  apt update -y && apt install -y python3 python3-pip python3-venv
  python3 -m venv ~/.venv
  source ~/.venv/bin/activate
  pip install --upgrade pip
  log "✅ Python: $(python --version), pip: $(pip --version)"
}

# -------------------------------
# 3. Install GitHub CLI
# -------------------------------
install_gh_cli() {
  apt install -y gh git curl wget unzip
  log "🔑 GitHub CLI installed"
}

# -------------------------------
# 4. Install func (TON Compiler)
# -------------------------------
install_func() {
  log "💎 Installing TON func..."
  mkdir -p ~/ton-bin && cd ~/ton-bin

  # تلاش برای پیدا کردن آخرین نسخه prebuilt
  FUNC_URL=$(curl -s https://api.github.com/repos/ton-blockchain/ton/releases/latest \
    | grep "browser_download_url" | grep -E 'func$' | cut -d '"' -f 4)

  if [ -n "$FUNC_URL" ]; then
    log "⬇️ Downloading func from: $FUNC_URL"
    wget -q "$FUNC_URL" -O func
    chmod +x func
  else
    log "⚠️ No prebuilt func found. Building from source..."
    apt update -y && apt install -y cmake build-essential git
    git clone --depth=1 https://github.com/ton-blockchain/ton.git ton-src
    cd ton-src
    mkdir -p build && cd build
    cmake ..
    make func
    cp func ~/ton-bin/
    cd ~/ton-bin
  fi

  echo 'export PATH=$HOME/ton-bin:$PATH' >> ~/.bashrc
  export PATH=$HOME/ton-bin:$PATH
  cd - >/dev/null
  log "✅ func ready: $(command -v func)"
}

# -------------------------------
# 5. GitHub Auth (Device Login)
# -------------------------------
github_login() {
  if gh auth status &>/dev/null; then
    log "✅ Already logged in to GitHub"
  else
    log "🔐 Logging into GitHub..."
    gh auth login --device
  fi
}

# -------------------------------
# 6. Process Each Repo
# -------------------------------
process_repo() {
  local dir="$1"
  log "📂 Processing: $dir"
  cd "$dir"

  # بررسی اتصال به ریموت
  if ! git remote -v | grep -q origin; then
    log "⚠️ Skipping (no remote)"
    cd - >/dev/null
    return
  fi

  # ادغام Pull Request ها
  log "🔄 Fetching PRs..."
  gh pr list --state open --limit 10 | while read -r pr; do
    pr_number=$(echo "$pr" | awk '{print $1}')
    if [ -n "$pr_number" ]; then
      gh pr checkout "$pr_number"
      git merge --no-edit
    fi
  done || true

  # نصب وابستگی‌ها
  if [ -f "package.json" ]; then
    log "📦 Node.js: Installing deps..."
    npm install && npm update || true
  fi
  if [ -f "requirements.txt" ]; then
    log "📦 Python: Installing deps..."
    pip install -r requirements.txt || true
  fi

  # ساخت پروژه
  if [ ! -f "build.sh" ] && [ -f "package.json" ]; then
    echo -e "#!/bin/bash\nnpm run build || echo 'No build script'" > build.sh
    chmod +x build.sh
  fi
  [ -f "build.sh" ] && ./build.sh || true

  # کامپایل قراردادهای TON
  if ls *.fc >/dev/null 2>&1; then
    log "💎 Compiling TON contracts..."
    func -o build.fc *.fc || true
  fi

  # Commit, Push, Release
  git add . || true
  git commit -m "Auto-update $(date +%F)" || true
  git push || true
  TAG="v$(date +%Y.%m.%d.%H%M)"
  git tag -a "$TAG" -m "Release $TAG" || true
  git push origin "$TAG" || true
  gh release create "$TAG" --title "Release $TAG" --notes "Automated release" || true

  cd - >/dev/null
}

# -------------------------------
# 7. Scan All Repos
# -------------------------------
scan_all_repos() {
  log "🔍 Scanning all repositories..."
  find . -type d -name ".git" | while read -r g; do
    process_repo "$(dirname "$g")"
  done
}

# -------------------------------
# MAIN EXECUTION
# -------------------------------
install_node
install_python_env
install_gh_cli
install_func
github_login
scan_all_repos
log "🎉 DONE: All repositories updated & deployed!"
