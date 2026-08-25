#!/usr/bin/env bash
# Vera-Agent Kaldirici — install.sh'in yerlestirdiklerini geri alir
set -euo pipefail
OC_DIR="$HOME/.config/opencode"
AGENTS_SKILLS="$HOME/.agents/skills"

echo "=== Vera-Agent Kaldirma ==="

rm -f "$OC_DIR/agent/vera-agent.md" && echo "✓ agent silindi"
rm -rf "$AGENTS_SKILLS/ace-playbook" && echo "✓ ace-playbook silindi"

rm -f "$OC_DIR/vera-models.sh" && echo "✓ vera-models.sh silindi"
rm -f "$OC_DIR/command/vera-models.md" && echo "✓ /vera-models komutu silindi"
systemctl --user disable --now vera-night.timer vera-day.timer 2>/dev/null \
  && rm -f "$HOME/.config/systemd/user/vera-"*.service "$HOME/.config/systemd/user/vera-"*.timer \
  && systemctl --user daemon-reload 2>/dev/null; echo "✓ gece vardiyasi temizlendi"
rm -f "$OC_DIR/.vera-models-pending"

if [ -d "$HOME/.local/share/opencode/skills-reserve" ]; then
  read -r -p "Pasif rezervedeki cephanelik de silinsin mi? [e/H]: " a
  [[ "${a,,}" == "e" ]] && { rm -rf "$HOME/.local/share/opencode/skills-reserve"; echo "✓ rezerv silindi"; }
fi

# Config'den vera mcp sunucularini cikar (digerlerine dokunmaz)
command -v node >/dev/null 2>&1 && node - <<'EOF'
const fs = require('fs');
const path = require('path');
const home = require('os').homedir();
for (const name of ['opencode.jsonc', 'opencode.json']) {
  const target = path.join(home, '.config/opencode', name);
  if (!fs.existsSync(target)) continue;
  let raw = fs.readFileSync(target, 'utf8');
  let out='',i=0,inStr=false;
  while(i<raw.length){
    const c=raw[i];
    if(inStr){out+=c; if(c==='"'&&raw[i-1]!=='\\')inStr=false; i++; continue;}
    if(c==='"'){inStr=true;out+=c;i++;continue;}
    if(c==='/'&&raw[i+1]==='/'){while(i<raw.length&&raw[i]!=='\n')i++;continue;}
    if(c==='/'&&raw[i+1]==='*'){i+=2;while(i<raw.length&&!(raw[i]==='*'&&raw[i+1]==='/'))i++;i+=2;continue;}
    out+=c;i++;
  }
  let cfg = JSON.parse(out.replace(/,(\s*[}\]])/g,'$1'));
  for (const srv of ['sequential-thinking','context7','memory','opensandbox','playwright']) {
    delete cfg.mcp?.[srv];
  }
  fs.writeFileSync(target, JSON.stringify(cfg, null, 2) + '\n');
  console.log('✓ config temizlendi:', target);
}
EOF

echo "⚠ memory.json (~/.local/share/opencode/memory.json) ve playbook'lar (.vera/) korunudu — istersen elle sil."
echo "=== TAMAM ==="
