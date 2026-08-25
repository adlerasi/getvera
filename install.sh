#!/usr/bin/env bash
# Vera-Agent Kurucu — OpenCode CLI icin tasinabilir kurulum
# Kullanim:
#   bash install.sh                    -> interaktif (eksikleri sorar)
#   bash install.sh --with-opensandbox -> sandbox backend'i de kur
#   bash install.sh --all              -> hic sormadan tum ekstraları kur
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OC_DIR="$HOME/.config/opencode"
AGENTS_SKILLS="$HOME/.agents/skills"
WITH_SANDBOX=0
show_help() {
  cat <<'HELP'
Vera-Agent Kurucu — OpenCode CLI icin otonom ajan paketi

KULLANIM
  bash install.sh [secenekler]

SEÇENEKLER
  (yok)                Eksik bilesenleri sorar, temel kurulumu yapar
  --all                Hic sormadan tum ekstraları kurar
  --with-opensandbox   OpenSandbox backend servisini de ekler (Docker gerekir)
  -h, --help           Bu yardimi gosterir

NE KURAR (temel, her zaman)
  ~/.config/opencode/agent/vera-agent.md      Agent tanimi
  ~/.agents/skills/ace-playbook/SKILL.md      ACE ogrenme skill'i
  opencode config'ine merge:                  5 MCP sunucusu + akilli izin kurallari
    playwright | opensandbox | memory | sequential-thinking | context7
  Mevcut config'iniz EZILMEZ — once .bak-vera yedegi alinir, sadece
  eksik anahtarlar eklenir.

SORABILECEGI EKSTRALAR
  opencode CLI          Yoksa resmi installer'i onerir
  uv                    opensandbox MCP icin
  oh-my-openagent       Alt-ajan orkestrasyonu (explore/librarian/oracle)
  self-improving-skills Hermes tarzi arka plan oz-evrim dongusu
  skill-evolver         Skill olcme ve gelistirme becerileri
  OpenSandbox backend   Docker uzerinde sandbox sunucusu (systemd user)

GEREKSINIMLER
  Linux veya macOS (Windows icin WSL2) · Node.js 18+ · opencode
  Opsiyonel: Docker (sandbox backend), git (plugin klonlama)

ILK ACILIS NOTU
  MCP sunuculari ilk opencode acilisinda npx/uvx ile otomatik iner;
  ilk baslatma 30-90 sn surebilir — bu donma degil, indirmedir.

AYRINTILI REHBER
  Sorun giderme, manuel kurulum ve dogrulama adimlari icin: KURULUM.md
HELP
}

ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --with-opensandbox) WITH_SANDBOX=1 ;;
    --all) ASSUME_YES=1 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Bilinmeyen secenek: $arg (--help bak)"; exit 1 ;;
  esac
done

ask() { # ask "soru" -> 0 ise evet
  local q="$1"
  if [ "$ASSUME_YES" = "1" ]; then echo "→ $q [--all: EVET]"; return 0; fi
  local a=""; read -r -p "$q [e/H]: " a || a=""
  [[ "${a,,}" == "e" || "${a,,}" == "y" ]]
}

echo "=== Vera-Agent Kurulumu ==="

# 0) opencode'un kendisi
if ! command -v opencode >/dev/null 2>&1; then
  echo "⚠ opencode CLI bulunamadi."
  if ask "opencode simdi kurulsun mu? (resmi installer)"; then
    curl -fsSL https://opencode.ai/install | bash
    export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
    command -v opencode >/dev/null 2>&1 && echo "✓ opencode kuruldu" || echo "⚠ terminali yeniden acip 'opencode -v' ile dogrula"
  else
    echo "ℹ opencode olmadan dosyalar yerlesir ama calismaz. Sonra: https://opencode.ai"
  fi
fi

# 1) Node.js (MCP'ler icin sart)
command -v node >/dev/null 2>&1 || echo "⚠ node yok — MCP sunuculari calismaz. https://nodejs.org (18+)"

# 2) uv (opensandbox MCP icin)
if ! command -v uvx >/dev/null 2>&1; then
  if ask "uv kurulsun mu? (opensandbox MCP icin gerekli)"; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo "ℹ opensandbox MCP config'de duracak ama calismayacak; digerleri etkilenmez."
  fi
fi

# 3) Dizinler + temel dosyalar (her zaman, sormadan)
mkdir -p "$OC_DIR/agent" "$AGENTS_SKILLS/ace-playbook"
cp "$DIR/agent/vera-agent.md" "$OC_DIR/agent/vera-agent.md"
echo "✓ agent → $OC_DIR/agent/vera-agent.md"
cp "$DIR/skills/ace-playbook/SKILL.md" "$AGENTS_SKILLS/ace-playbook/SKILL.md"
echo "✓ skill → $AGENTS_SKILLS/ace-playbook/"

# 4) Config birlestirme
merge_config() {
  node - "$1" "$2" <<'EOF'
const fs = require('fs');
const [target, snippetPath] = process.argv.slice(2);
function stripJsonc(raw){
  let out='',i=0,inStr=false;
  while(i<raw.length){
    const c=raw[i];
    if(inStr){out+=c; if(c==='"'&&raw[i-1]!=='\\')inStr=false; i++; continue;}
    if(c==='"'){inStr=true;out+=c;i++;continue;}
    if(c==='/'&&raw[i+1]==='/'){while(i<raw.length&&raw[i]!=='\n')i++;continue;}
    if(c==='/'&&raw[i+1]==='*'){i+=2;while(i<raw.length&&!(raw[i]==='*'&&raw[i+1]==='/'))i++;i+=2;continue;}
    out+=c;i++;
  }
  return JSON.parse(out.replace(/,(\s*[}\]])/g,'$1'));
}
const snippet = stripJsonc(fs.readFileSync(snippetPath,'utf8'));
let cfg = {};
if (fs.existsSync(target)) {
  cfg = stripJsonc(fs.readFileSync(target,'utf8'));
  fs.copyFileSync(target, target + '.bak-vera');
}
cfg.mcp = Object.assign({}, snippet.mcp || {}, cfg.mcp || {});
cfg.permission = cfg.permission || {};
for (const k of ['read','edit','glob','grep','list','webfetch','websearch']) {
  if (!(k in cfg.permission)) cfg.permission[k] = snippet.permission[k];
}
cfg.permission.bash = Object.assign({}, snippet.permission?.bash || {}, cfg.permission.bash || {});
fs.writeFileSync(target, JSON.stringify(cfg, null, 2) + '\n');
EOF
  echo "✓ config → $1 (yedek: .bak-vera)"
}

add_plugin_entry() {
  node - "$1" "$2" <<'EOF'
const fs=require('fs');
const [p,entry]=process.argv.slice(2);
const raw=fs.readFileSync(p,'utf8');let out='',i=0,inStr=false;
while(i<raw.length){const c=raw[i];if(inStr){out+=c;if(c==='"'&&raw[i-1]!=='\\\\')inStr=false;i++;continue;}
if(c==='"'){inStr=true;out+=c;i++;continue;}
if(c==='/'&&raw[i+1]==='/'){while(i<raw.length&&raw[i]!=='\n')i++;continue;}
out+=c;i++;}
const cfg=JSON.parse(out.replace(/,(\s*[}\]])/g,'$1'));
if(!Array.isArray(cfg.plugin))cfg.plugin=[];
if(!cfg.plugin.includes(entry))cfg.plugin.push(entry);
fs.writeFileSync(p,JSON.stringify(cfg,null,2)+'\n');
console.log('✓ plugin config\'e eklendi: '+entry);
EOF
}

CONFIG_TARGET=""
for f in "$OC_DIR/opencode.jsonc" "$OC_DIR/opencode.json"; do
  [ -f "$f" ] && CONFIG_TARGET="$f" && break
done
if [ -z "$CONFIG_TARGET" ]; then
  CONFIG_TARGET="$OC_DIR/opencode.jsonc"
  cp "$DIR/config-snippet.jsonc" "$CONFIG_TARGET"
  echo "✓ config → $CONFIG_TARGET (yeni olusturuldu)"
else
  command -v node >/dev/null 2>&1 && merge_config "$CONFIG_TARGET" "$DIR/config-snippet.jsonc" \
    || echo "⚠ node yok — '$DIR/config-snippet.jsonc' icerigini $CONFIG_TARGET icine ELLE birlestir."
fi

# 5) EKSTRALAR — interaktif sorulur
echo ""
echo "--- Ekstralar (hepsi opsiyonel; Vera eksiklerini Self-Check ile tolere eder) ---"

# 5a) oh-my-openagent: subagent orkestrasyonu
if ! grep -qi "openagent\|oh-my-opencode" "$CONFIG_TARGET" 2>/dev/null; then
  if ask "oh-my-openagent plugin'i kurulsun mu? (Vera'ya alt-ajan orkestrasyonu katar)"; then
    npm install --prefix "$OC_DIR" oh-my-openagent@latest >/dev/null 2>&1 \
      && add_plugin_entry "$CONFIG_TARGET" "oh-my-openagent@latest" \
      || echo "⚠ npm kurulumu basarisiz — manuel: npm install --prefix $OC_DIR oh-my-openagent@latest"
  fi
else
  echo "ℹ oh-my-openagent zaten config'de"
fi

# 5b) Self-improving loop (Hermes tarzi arka plan evrimi)
SIS_DIR="$OC_DIR/plugins/self-improving-skills"
if [ ! -d "$SIS_DIR" ]; then
  if ask "Öz-evrim döngüsü plugin'i kurulsun mu? (skill-distiller/optimize-skill + arka plan öğrenmesi)"; then
    mkdir -p "$OC_DIR/plugins"
    git clone --depth 1 https://github.com/okdk7788/opencode-self-improving-skills.git "$SIS_DIR" \
      && mkdir -p "$OC_DIR/skills" \
      && cp -r "$SIS_DIR/skills/"* "$OC_DIR/skills/" \
      && add_plugin_entry "$CONFIG_TARGET" "./plugins/self-improving-skills/index.ts" \
      || echo "⚠ kurulum yarim kaldı — README'deki manuel adimlari izle"
  fi
else
  echo "ℹ self-improving plugin zaten kurulu"
fi

# 5c) Evrim becerileri
if [ ! -d "$AGENTS_SKILLS/skill-evolver" ]; then
  if ask "Evrim becerileri kurulsun mu? (skill-evolver + llm-evaluation)"; then
    npx -y skills@latest add https://github.com/FishSerrie/skill-evolver.git --skill '*' --global --agent opencode --yes >/dev/null 2>&1 \
      && echo "✓ skill-evolver kuruldu" || echo "⚠ skill-evolver kurulamadi"
    npx -y skills@latest add https://github.com/wshobson/agents --skill llm-evaluation --global --agent opencode --yes >/dev/null 2>&1 \
      && echo "✓ llm-evaluation kuruldu" || true
  fi
else
  echo "ℹ skill-evolver zaten kurulu"
fi

# 5d) TAM CEPHANELİK — 141 skill (sorulur; reddedilirse pasif rezerve gider)
RESERVE="$HOME/.local/share/opencode/skills-reserve"
if [ -d "$DIR/arsenal" ] && [ -n "$(ls -A "$DIR/arsenal" 2>/dev/null)" ]; then
  ARSENAL_COUNT=$(ls "$DIR/arsenal" | wc -l)
  echo ""
  echo "--- TAM CEPHANELİK ($ARSENAL_COUNT skill) ---"
  cat <<'ARSENALINFO'
  İçindekiler:
   • Güvenlik zinciri (~48): pentest suite, SAST/DAST/SCA, audit→rapor
   • Dil & framework uzmanları (~25): TypeScript, Python, Go, Rust, Vue, React...
   • AI/NLP: transformers/spaCy rehberi, sentiment + intent analizi, RAG mimarisi
   • Üretim: Figma→kod, frontend tasarım disiplini, Playwright test
   • Araştırma: OSINT keşif, paper-summarizer, spec-miner, davranış analizi
   • Meta: karpathy-guidelines, agents-md bakımı, mcp-builder
ARSENALINFO
  if ask "TAM cephaneliği şimdi aktive et? (H dersen pasif rezerve bekler — istediğin an açarsın)"; then
    cp -r "$DIR/arsenal/"* "$AGENTS_SKILLS/"
    echo "✓ $ARSENAL_COUNT skill → $AGENTS_SKILLS"
  else
    mkdir -p "$RESERVE"
    cp -r "$DIR/arsenal/"* "$RESERVE/" 2>/dev/null
    echo "ℹ Pasif rezerve alındı: $RESERVE"
    echo "  Sonra açmak için: bash $DIR/enable-arsenal.sh"
  fi
fi

# 6) MODEL AYARI — zorunlu adım
cp "$DIR/vera-models.sh" "$OC_DIR/vera-models.sh"
chmod +x "$OC_DIR/vera-models.sh"
mkdir -p "$OC_DIR/command"
cat > "$OC_DIR/command/vera-models.md" <<'CMDEOF'
---
description: Vera-Agent model yoneticisi (durum, doctor, profil)
---
Kullanıcı model yönetimi istiyor. Uygun alt komudu bash aracıyla çalıştır ve çıktıyı yorumla:

- Durum: `bash ~/.config/opencode/vera-models.sh --status`
- Sağlık muayenesi: `bash ~/.config/opencode/vera-models.sh --doctor`
- Profil uygulama: `bash ~/.config/opencode/vera-models.sh --apply-profile <ad>`
- Bozuksa geri dönüş: `bash ~/.config/opencode/vera-models.sh --rollback`

Not: İnteraktif sihirbaz yalnızca gerçek terminalde çalışır — kullanıcıya şunu söyle:
"Tam sihirbaz için ayrı bir terminalde: bash ~/.config/opencode/vera-models.sh"
CMDEOF
echo "✓ vera-models.sh + /vera-models komutu yerleşti"
echo ""
echo "--- MODEL AYARI (zorunlu adım) ---"
MODEL_WIZ_RAN=0
if [ "$ASSUME_YES" = "1" ] || ask "Model atamalarını şimdi yapılandıralım mı? (atlanırsa ilk açılışta Vera hatırlatır)"; then
  bash "$OC_DIR/vera-models.sh" && MODEL_WIZ_RAN=1 || true
else
  mkdir -p "$OC_DIR"; touch "$OC_DIR/.vera-models-pending"
  warn "beklemeye alındı — işaret dosyası oluşturuldu"
fi

# 7) Gece vardiyası
if [ "$MODEL_WIZ_RAN" = "1" ]; then
  if [ "$ASSUME_YES" = "1" ]; then
    NIGHT=0
  elif ask "Hafif profil ile gece vardiyası kurulsun mu? (02:00 hafif profil ↔ 08:00 gündüz; kota koruma)"; then
    NIGHT=1
  else
    NIGHT=0
  fi
  [ "$NIGHT" = 1 ] && { read -r -p "gece profili adı [free-local]: " NP; NP="${NP:-free-local}"; "$OC_DIR/vera-models.sh" --night-on "$NP"; }
elif [ ! -f "$PENDING_FLAG" ] && [ ! -f "$OC_DIR/.vera-models-pending" ]; then
  :
fi

# 8) OpenSandbox backend
if [ "$WITH_SANDBOX" = "1" ] || { command -v docker >/dev/null 2>&1 && ask "OpenSandbox backend servisi kurulsun mu? (Docker gerektirir)"; }; then
  export PATH="$HOME/.local/bin:$PATH"
  mkdir -p "$HOME/.config/systemd/user"
  cp "$DIR/optional/opensandbox/opensandbox-server.service" "$HOME/.config/systemd/user/" 2>/dev/null || true
  systemctl --user daemon-reload 2>/dev/null && systemctl --user enable --now opensandbox-server.service 2>/dev/null \
    && echo "✓ opensandbox-server servisi aktif" \
    || echo "⚠ servis kurulamadi — manuel: uvx opensandbox-server"
  [ -f "$HOME/.sandbox.toml" ] || uvx opensandbox-server init-config ~/.sandbox.toml --example docker
else
  echo "ℹ OpenSandbox backend atlandi (Vera sandbox'siz de calisir, sadece izole-kod ozelligi olmaz)"
fi

echo ""
echo "=== TAMAM ==="
echo "Son adim: opencode'u yeniden baslat → Tab ile Vera-Agent'a gec."
