#!/usr/bin/env bash
# vera-models — Vera-Agent model yonetim sihurbazi (v1)
# Modlar:
#   (yok)                 Etkilesimli sihirbaz: saglayici tarama -> rol matrisi -> dogrulama -> uygula
#   --status              Mevcut atamalar + son test durumu panosu
#   --doctor              Tam muayene: config, saglayicilar, rol smoke-testleri; bozuksa rollback onerir
#   --rollback            En son .bak yedeklerinden geri don
#   --apply-profile AD    Kayitli profili uygula (--dry-run ile onizleme)
#   --save-profile AD     Mevcut atamalari profil olarak kaydet
#   --dry-run             Yazmadan once degisiklikleri goster
#   --list-models         Kesfedilen tum saglayici+modelleri listele
#   --night-on [profil]   Gece vardiyasi timer kurar (varsayilan gece profili: free-local)
#   --night-off           Gece vardiyasi timer kaldirir
set -uo pipefail

VERSION="1.0.0"
OC_DIR="$HOME/.config/opencode"
OMO_CONFIG="$OC_DIR/oh-my-opencode.json"
PROFILES_DIR="$OC_DIR/vera-profiles"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
PENDING_FLAG="$OC_DIR/.vera-models-pending"
SMOKE_CACHE="$PROFILES_DIR/.last-smoke.json"
LMSTUDIO_URL="http://127.0.0.1:1234"
OLLAMA_URL="http://127.0.0.1:11434"
DRY_RUN=0

c_red=$'\033[31m'; c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_blu=$'\033[34m'; c_off=$'\033[0m'
ok()   { echo "${c_grn}✓${c_off} $*"; }
warn() { echo "${c_ylw}⚠ ${c_off} $*"; }
err()  { echo "${c_red}✗${c_off} $*"; }

command -v node >/dev/null 2>&1 || { err "node gerekli (JSON islemleri) — https://nodejs.org"; exit 2; }
command -v curl >/dev/null 2>&1 || { err "curl gerekli"; exit 2; }
mkdir -p "$PROFILES_DIR"

# ---------- JSONC okuma/yazma yardimcilari (node) ----------
jsonc_read() { # jsonc_read <dosya>  -> stdout: temiz JSON
  node -e '
const fs=require("fs");
const raw=fs.readFileSync(process.argv[1],"utf8");
let out="",i=0,inStr=false;
while(i<raw.length){const c=raw[i];
if(inStr){out+=c;if(c==="\x22"&&raw[i-1]!=="\\\\")inStr=false;i++;continue;}
if(c==="\x22"){inStr=true;out+=c;i++;continue;}
if(c==="/"&&raw[i+1]==="/"){while(i<raw.length&&raw[i]!=="\n")i++;continue;}
out+=c;i++;}
process.stdout.write(out.replace(/,(\s*[}\]])/g,"$1"));
' "$1" 2>/dev/null
}

json_write_atomic() { # json_write_atomic <dosya> <json-string>
  local f="$1" data="$2"
  [ -f "$f" ] && cp "$f" "$f.bak-vera-models"
  printf '%s\n' "$data" > "$f.tmp" && mv "$f.tmp" "$f"
}

oc_config_file() {
  for f in "$OC_DIR/opencode.jsonc" "$OC_DIR/opencode.json"; do
    [ -f "$f" ] && { echo "$f"; return; }
  done
  echo ""
}

# ---------- Saglayici kesfi ----------
declare -A PROVIDER_URL   # name -> baseURL (openai-uyumlu probe icin)
declare -A PROVIDER_KIND  # name -> local|http|official
declare -A PROVIDER_MODELS # name -> newline ayrik model listesi

probe_openai_models() { # url -> model id listesi (basarisizsa bos)
  local url="$1"
  curl -s --max-time 5 "$url/models" 2>/dev/null | node -e '
let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
try{const j=JSON.parse(d);console.log((j.data||j.models||[]).map(m=>m.id||m.name).filter(Boolean).join("\n"));}catch(e){}})'
}

ollama_context() { # model -> context uzunlugu ya da ?
  curl -s --max-time 5 "$OLLAMA_URL/api/show" -d "{\"name\":\"$1\"}" 2>/dev/null | node -e '
let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
try{const j=JSON.parse(d);const mi=j.model_info||{};
const key=Object.keys(mi).find(k=>k.endsWith(".context_length"));
console.log(key?String(mi[key]):"?");}catch(e){console.log("?")}})'
}

discover_providers() {
  PROVIDER_URL=(); PROVIDER_KIND=(); PROVIDER_MODELS=()
  echo ""
  echo "── Sağlayıcı taraması ──"

  if curl -s --max-time 3 "$LMSTUDIO_URL/v1/models" | grep -q '"id"'; then
    PROVIDER_KIND[lmstudio]="local"; PROVIDER_URL[lmstudio]="$LMSTUDIO_URL/v1"
    PROVIDER_MODELS[lmstudio]="$(probe_openai_models "$LMSTUDIO_URL/v1")"
    ok "LM Studio :1234 — $(echo "${PROVIDER_MODELS[lmstudio]}" | grep -c .) model"
  else
    warn "LM Studio :1234 erişilemiyor"
  fi

  if curl -s --max-time 3 "$OLLAMA_URL/api/tags" | grep -q '"name"\|"model"'; then
    PROVIDER_KIND[ollama]="local"; PROVIDER_URL[ollama]="$OLLAMA_URL/v1"
    PROVIDER_MODELS[ollama]="$(curl -s --max-time 5 "$OLLAMA_URL/api/tags" | node -e '
let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);
console.log((j.models||[]).map(m=>m.name).filter(Boolean).join("\n"));}catch(e){}})')"
    ok "Ollama :11434 — $(echo "${PROVIDER_MODELS[ollama]}" | grep -c .) model"
  else
    warn "Ollama :11434 erişilemiyor"
  fi

  local cfg; cfg=$(oc_config_file)
  if [ -n "$cfg" ]; then
    while IFS=$'\t' read -r name base; do
      [ -z "$name" ] && continue
      case "$name" in lmstudio|ollama) continue;; esac
      PROVIDER_KIND["$name"]="http"; PROVIDER_URL["$name"]="$base"
      PROVIDER_MODELS["$name"]="$(probe_openai_models "$base")"
      local n; n=$(echo "${PROVIDER_MODELS[$name]}" | grep -c .)
      [ "$n" -gt 0 ] && ok "$name — $n model (config)" || warn "$name — liste alınamadı ($base)"
    done < <(jsonc_read "$cfg" | node -e '
let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
try{const j=JSON.parse(d);
for(const [k,v] of Object.entries(j.provider||{})){
const b=v.options&&v.options.baseURL;if(b&&/^https?:/.test(b))console.log(k+"\t"+b.replace(/\/$/,"").replace(/\/v1$/,"")+"/v1");}
}catch(e){}})')
  fi

  local AUTH="$HOME/.local/share/opencode/auth.json"
  if [ -f "$AUTH" ]; then
    while IFS= read -r p; do
      case "$p" in lmstudio|ollama) continue;; esac
      PROVIDER_KIND["$p"]="${PROVIDER_KIND[$p]:-official}"
      [ -z "${PROVIDER_MODELS[$p]:-}" ] && PROVIDER_MODELS["$p"]="(opencode üzerinden)"
    done < <(jsonc_read "$AUTH" | node -e '
let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
try{const j=JSON.parse(d);console.log(Object.keys(j).join("\n"));}catch(e){}})')
    ok "opencode kimlikli sağlayıcılar: $(jsonc_read "$AUTH" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{console.log(Object.keys(JSON.parse(d)).join(", "))}catch(e){}})')"
  fi
}

# ---------- Rol matrisi ----------
KNOWN_ROLES=(VERA small_model explore librarian oracle frontend-engineer metis momus prometheus multimodal-looker)

role_list() { # dinamik: OMO config + bilinen liste birlesimi
  local list=""
  if [ -f "$OMO_CONFIG" ]; then
    list+="$(jsonc_read "$OMO_CONFIG" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);console.log(Object.keys(j.agent||{}).join("\n"));}catch(e){}})')
"
  fi
  for r in "${KNOWN_ROLES[@]}"; do list+="$r"$'\n'; done
  echo "$list" | awk '!seen[$0]++ && NF' | sort
}

current_model_of() { # rol -> su anki model (varsa)
  local role="$1" cfg; cfg=$(oc_config_file)
  case "$role" in
    VERA)       [ -n "$cfg" ] && jsonc_read "$cfg" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);console.log(j.model||"")}catch(e){}})' ;;
    small_model)[ -n "$cfg" ] && jsonc_read "$cfg" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);console.log(j.small_model||"")}catch(e){}})' ;;
    *)          [ -f "$OMO_CONFIG" ] && jsonc_read "$OMO_CONFIG" | node -e '
let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
try{const j=JSON.parse(d);const a=(j.agent||{})[process.argv[1]];console.log(a&&(a.model||""))||"";}catch(e){}})' "$role" ;;
  esac
}

choose_provider() { # secim -> provider adini echo eder
  local i=1 names=()
  for p in "${!PROVIDER_KIND[@]}"; do names+=("$p"); printf '  %d) %-12s (%s)\n' "$i" "$p" "${PROVIDER_KIND[$p]}"; i=$((i+1)); done
  [ ${#names[@]} -eq 0 ] && { err "Hiç sağlayıcı bulunamadı"; return 1; }
  local a; read -r -p "  sağlayıcı no: " a
  local idx=$((a)); [ "$idx" -ge 1 ] && [ "$idx" -le ${#names[@]} ] && echo "${names[$((idx-1))]}"
}

choose_model() { # provider -> model id echo
  local p="$1" models="${PROVIDER_MODELS[$p]:-}"
  if [ -z "$(echo "$models" | grep -c .)" ]; then
    local m; read -r -p "  model ID (elle gir — $p listelenemiyor): " m; echo "$m"; return
  fi
  local i=1
  while IFS= read -r m; do printf '  %d) %s\n' "$i" "$m"; i=$((i+1)); done <<< "$models"
  local a; read -r -p "  model no / elle ID: " a
  [[ "$a" =~ ^[0-9]+$ ]] && sed -n "${a}p" <<< "$models" || echo "$a"
}

# ---------- Dogrulama ----------
smoke_test() { # role provider model -> 0 basari
  local role="$1" p="$2" m="$3"
  if command -v opencode >/dev/null 2>&1; then
    timeout 240 opencode run --model "$p/$m" "Reply with exactly: OK" >/dev/null 2>&1
  elif [ "${PROVIDER_KIND[$p]:-}" = "local" ] || [ "${PROVIDER_KIND[$p]:-}" = "http" ]; then
    local r; r=$(curl -s --max-time 240 "${PROVIDER_URL[$p]}/chat/completions" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"Say OK\"}],\"max_tokens\":5}" 2>/dev/null)
    echo "$r" | grep -q '"choices"'
  else
    return 3  # test edilemedi (resmi saglayici, opencode yok)
  fi
}

validate_matrix() { # MATRIX dosyasi (satirlar: role<TAB>provider<TAB>model) -> hepsi gecene kadar duzelttirir
  local file="$1" fails=0 round=1
  while : ; do
    fails=0
    echo ""; echo "── Doğrulama turu $round ──"
    local total; total=$(grep -c . "$file")
    local n=0
    while IFS=$'\t' read -r role p m; do
      [ -z "$role" ] && continue; n=$((n+1))
      printf '  [%d/%d] %-18s %-12s %-28s ' "$n" "$total" "$role" "$p" "$m"
      if smoke_test "$role" "$p" "$m"; then ok "geçti"
      else err "BAŞARISIZ (sağlayıcı çevrimdışı olabilir)"; echo "$role"$'\t'"$p"$'\t'"$m" >> "$file.fails"; fails=$((fails+1)); fi
    done < "$file"
    [ "$fails" -eq 0 ] && { ok "Tüm roller doğrulandı"; return 0; }
    echo ""
    warn "$fails rol başarısız. Her biri için yeniden seçim yapılacak."
    local fixed="$file.fixed"; : > "$fixed"
    while IFS=$'\t' read -r role p m; do
      [ -z "$role" ] && continue
      echo -n "  $role — yeniden seçim: "; choose_provider || { printf '%s\t%s\t%s\n' "$role" "$p" "$m" >> "$fixed"; continue; }
      local np; np=$(choose_provider) || { printf '%s\t%s\t%s\n' "$role" "$p" "$m" >> "$fixed"; continue; }
      local nm; nm=$(choose_model "$np")
      printf '%s\t%s\t%s\n' "$role" "$np" "$nm" >> "$fixed"
    done < "$file.fails"
    rm -f "$file.fails"
    local keep="$file.keep"; : > "$keep"
    grep -Fvf <(cut -f1 "$file.fails" 2>/dev/null) "$file" >> /dev/null 2>&1
    awk -F'\t' 'NR==FNR{bad[$1]=1;next} !($1 in bad)' "$file.fails" "$file" >> "$keep" 2>/dev/null
    cat "$fixed" >> "$keep"; mv "$keep" "$file"; rm -f "$fixed"
    round=$((round+1))
  done
}

# ---------- Uygulama ----------
apply_matrix() { # apply_matrix <matrix-dosyasi>
  local file="$1"
  [ -f "$file" ] || { err "matris dosyası yok"; return 1; }
  if command -v opencode >/dev/null 2>&1; then :; fi
  node - "$file" "$OC_DIR" "$DRY_RUN" <<'EOF'
const fs=require('fs'),path=require('path');
const [matrixFile,ocDir,dryRaw]=process.argv.slice(2);
const dry=dryRaw==='1';
function strip(raw){let out='',i=0,inStr=false;
while(i<raw.length){const c=raw[i];if(inStr){out+=c;if(c==='"'&&raw[i-1]!=='\\')inStr=false;i++;continue;}
if(c==='"'){inStr=true;out+=c;i++;continue;}
if(c==='/'&&raw[i+1]==='/'){while(i<raw.length&&raw[i]!=='\n')i++;continue;}
if(c==='/'&&raw[i+1]==='*'){i+=2;while(i<raw.length&&!(raw[i]==='*'&&raw[i+1]==='/'))i++;i+=2;continue;}
out+=c;i++;}
return out.replace(/,(\s*[}\]])/g,'$1');}
function load(f){return fs.existsSync(f)?JSON.parse(strip(fs.readFileSync(f,'utf8'))):null;}
function atomicWrite(f,data){if(fs.existsSync(f))fs.copyFileSync(f,f+'.bak-vera-models');
fs.writeFileSync(f+'.tmp',data);fs.renameSync(f+'.tmp',f);}
const rows=fs.readFileSync(matrixFile,'utf8').split('\n').filter(Boolean)
.map(l=>l.split('\t')).filter(r=>r.length>=3);
const ocPath=['opencode.jsonc','opencode.json'].map(n=>path.join(ocDir,n)).find(p=>fs.existsSync(p));
let oc=ocPath?load(ocPath):{};
const omoPath=path.join(ocDir,'oh-my-opencode.json');
let omo=load(omoPath)||{};
const changes=[];
for(const [role,prov,model] of rows){
  const ref=`${prov}/${model}`;
  if(role==='VERA'){ if((oc.model||'')!==ref){changes.push(`opencode.model = ${ref}`);oc.model=ref;} }
  else if(role==='small_model'){ if((oc.small_model||'')!==ref){changes.push(`opencode.small_model = ${ref}`);oc.small_model=ref;} }
  else { omo.agent=omo.agent||{}; omo.agent[role]=omo.agent[role]||{};
    if((omo.agent[role].model||'')!==ref){changes.push(`agent.${role}.model = ${ref}`);omo.agent[role].model=ref;} }
}
console.log(changes.length?('Planlanan değişiklikler:\n  '+changes.join('\n  ')):'Değişiklik yok — zaten güncel.');
if(dry){console.log('[dry-run] yazma yapılmadı.');process.exit(0);}
if(ocPath)atomicWrite(ocPath,JSON.stringify(oc,null,2)+'\n');else atomicWrite(path.join(ocDir,'opencode.jsonc'),JSON.stringify({$schema:'https://opencode.ai/config.json',...oc},null,2)+'\n');
atomicWrite(omoPath,JSON.stringify(omo,null,2)+'\n');
console.log('✓ uygulandı (yedekler: *.bak-vera-models)');
EOF
}

concurrency_check() { # tum roller ayni lokal ucta mi?
  local file="$1" uniq
  uniq=$(cut -f2 "$file" | sort -u | grep -c .)
  [ "$uniq" = "1" ] || return 0
  local p; p=$(head -1 "$file" | cut -f2)
  [ "${PROVIDER_KIND[$p]:-}" = "local" ] || return 0
  warn "TÜM roller tek lokal uç noktada ($p) — background eşzamanlılık 1'e çekiliyor"
  node - "$OMO_CONFIG" <<'EOF'
const fs=require('fs'),path=require('path');
const f=process.argv[2];
let cfg={};try{cfg=JSON.parse(stripJsoncLite(fs.readFileSync(f,'utf8')))}catch(e){}
function strip(raw){let out='',i=0,inStr=false;
while(i<raw.length){const c=raw[i];if(inStr){out+=c;if(c==='"'&&raw[i-1]!=='\\')inStr=false;i++;continue;}
if(c==='"'){inStr=true;out+=c;i++;continue;}
out+=c;i++;}
return out.replace(/,(\s*[}\]])/g,'$1');}
cfg.background=Object.assign({},cfg.background,{max_concurrency:1});
if(fs.existsSync(f))fs.copyFileSync(f,f+'.bak-vera-models');
fs.writeFileSync(f+'.tmp',JSON.stringify(cfg,null,2)+'\n');fs.renameSync(f+'.tmp',f);
EOF
  ok "eşzamanlılık = 1 kaydedildi"
}

# ---------- Profiller ----------
save_profile() {
  local name="$1" cfg; cfg=$(oc_config_file)
  local main small; main=$(current_model_of VERA); small=$(current_model_of small_model)
  { printf '{"name":"%s","model":"%s","small_model":"%s","agents":{' "$name" "$main" "$small"
    local first=1 r
    while IFS= read -r r; do
      r=$(echo "$r"); [ -z "$r" ] && continue; [ "$r" = "VERA" ] && continue; [ "$r" = "small_model" ] && continue
      [ $first = 0 ] && printf ','
      printf '"%s":{"model":"%s"}' "$r" "$(current_model_of "$r")"; first=0
    done < <(role_list)
    printf '}}\n'
  } > "$PROFILES_DIR/$name.json.tmp" && mv "$PROFILES_DIR/$name.json.tmp" "$PROFILES_DIR/$name.json"
  ok "profil kaydedildi: $PROFILES_DIR/$name.json (API anahtarı içermez)"
}

apply_profile() {
  local name="$1"; local pf="$PROFILES_DIR/$name.json"
  [ -f "$pf" ] || { err "profil yok: $pf"; ls "$PROFILES_DIR"/*.json 2>/dev/null | sed 's/^/  mevcut: /'; return 1; }
  [ "$QUIET" = 0 ] && discover_providers
  local m="$PROFILES_DIR/.apply.matrix"; : > "$m"
  node - "$pf" >> "$m" <<'EOF'
const fs=require('fs');
const j=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
if(j.model)console.log(`VERA\t${j.model.replace(/^([^/]+)\//,'$1\t')}`);
if(j.small_model)console.log(`small_model\t${j.small_model.replace(/^([^/]+)\//,'$1\t')}`);
for(const [a,v] of Object.entries(j.agents||{})){const parts=(v.model||'').split('/');
if(parts.length>1)console.log(`${a}\t${parts[0]}\t${parts.slice(1).join('/')}`);}
EOF
  grep -v '^$' "$m" > "$m.c" && mv "$m.c" "$m"
  [ "$DRY_RUN" = 1 ] && { echo "[dry-run] profil: $name"; }
  validate_matrix_quiet "$m" || return 1
  apply_matrix "$m"
}

validate_matrix_quiet() { # gece/otomatik kullanım: sadece VERA rolunu test eder
  local file="$1" line; line=$(grep '^VERA' "$file" | head -1)
  [ -z "$line" ] && return 0
  IFS=$'\t' read -r _ p _ <<< "$line"
  smoke_test VERA "$p" "$(cut -f3 <<<"$line")" && return 0
  err "ana model smoke-test başarısız (sağlayıcı çevrimdışı olabilir) — profil uygulanmadı"; return 1
}

# ---------- Status / Doctor / Rollback ----------
status_dashboard() {
  echo ""; echo "── Vera Model Panosu ──"
  local cfg; cfg=$(oc_config_file)
  while IFS= read -r r; do
    r=$(echo "$r"); [ -z "$r" ] && continue
    printf '  %-20s %s\n' "$r" "$(current_model_of "$r")"
  done < <(role_list)
  [ -f "$SMOKE_CACHE" ] && { echo ""; echo "Son smoke-test sonucu:"; cat "$SMOKE_CACHE"; }
  [ -f "$PENDING_FLAG" ] && warn "Model ayarı beklemede! Bu sihirbazı çalıştırın."
}

doctor() {
  echo ""; echo "── Doctor Muayenesi ──"
  local bad=0 cfg; cfg=$(oc_config_file)
  if [ -z "$cfg" ]; then err "opencode config dosyası bulunamadı"; bad=1
  else
    jsonc_read "$cfg" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{JSON.parse(d);process.exit(0)}catch(e){process.exit(1)}})' \
      && ok "config parse geçerli ($cfg)" || { err "config BOZUK: $cfg"; bad=1; }
  fi
  discover_providers >/dev/null 2>&1
  local np=${#PROVIDER_KIND[@]}
  [ "$np" -gt 0 ] && ok "erişilebilir sağlayıcı: $np" || { err "hiç sağlayıcı erişilemiyor"; bad=1; }
  if [ -f "$OMO_CONFIG" ]; then
    jsonc_read "$OMO_CONFIG" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{JSON.parse(d);process.exit(0)}catch(e){process.exit(1)}})' \
      && ok "OMO config geçerli" || { err "OMO config BOZUK"; bad=1; }
  fi
  local probe="$PROFILES_DIR/.doctor.matrix"; : > "$probe"
  while IFS= read -r r; do
    r=$(echo "$r"); [ -z "$r" ] && continue
    local m; m=$(current_model_of "$r")
    [[ "$m" == */* ]] && printf '%s\n' "$r"$'\t'"$(dirname "$m" | sed 's|/$||')"$'\t'"${m#*/}" >> "$probe"
  done < <(role_list)
  if [ -s "$probe" ] && command -v opencode >/dev/null 2>&1; then
    while IFS=$'\t' read -r role p m; do
      printf '  %-18s %-30s ' "$role" "$p/$m"
      if smoke_test "$role" "$p" "$m"; then ok "yanıt veriyor"; else err "YANIT VERMİYOR"; bad=1; fi
    done < "$probe"
  else
    warn "opencode bulunamadı — salt-restore modu (smoke test atlandı)"
  fi
  if [ "$bad" = 1 ]; then
    echo ""
    if ls "$OC_DIR"/*.bak-vera* >/dev/null 2>&1 || ls "$OC_DIR"/*.bak-vera-models >/dev/null 2>&1; then
      warn "Bozulmadan önceki yedekler mevcut. Geri dönmek istiyor musunuz?"
      read -r -p "--rollback çağrılsın mı? [e/H]: " a
      [[ "${a,,}" == "e" ]] && do_rollback
    fi
  fi
}

do_rollback() {
  local restored=0
  for bak in "$OC_DIR"/*.bak-vera-models "$OC_DIR"/*.bak-vera "$OC_DIR"/oh-my-opencode.json.bak-vera-models; do
    [ -f "$bak" ] || continue
    local orig="${bak%.bak-vera-models}"; orig="${orig%.bak-vera}"
    cp "$bak" "$orig" && ok "geri yüklendi: $orig" && restored=$((restored+1))
  done
  [ "$restored" = 0 ] && warn "geri alınacak yedek bulunamadı" || ok "$restored dosya geri yüklendi — opencode'u yeniden başlatın"
}

# ---------- Gece vardiyasi ----------
night_setup() {
  local night="${1:-free-local}"
  systemctl --user daemon-reload 2>/dev/null || true
  local svc_dir="$HOME/.config/systemd/user"
  mkdir -p "$svc_dir"
  cat > "$svc_dir/vera-night.service" <<UNIT
[Unit]
Description=Vera-Agent gece profili
[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH --apply-profile "$night" --quiet
UNIT
  cat > "$svc_dir/vera-night.timer" <<UNIT
[Unit]
Description=Vera gece profili tetikleyici
[Timer]
OnCalendar=*-*-* 02:00
Persistent=true
[Install]
WantedBy=timers.target
UNIT
  cat > "$svc_dir/vera-day.service" <<UNIT
[Unit]
Description=Vera-Agent gunduz profili
[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH --apply-profile gunduz --quiet
UNIT
  cat > "$svc_dir/vera-day.timer" <<UNIT
[Unit]
Description=Vera gunduz profili tetikleyici
[Timer]
OnCalendar=*-*-* 08:00
Persistent=true
[Install]
WantedBy=timers.target
UNIT
  systemctl --user daemon-reload && systemctl --user enable --now vera-night.timer vera-day.timer \
    && ok "gece vardiyası aktif: 02:00 '$night' ↔ 08:00 'gunduz' (profiller kayıtlı olmalı)" \
    || err "timer kurulamadı (systemd user yok?)"
}

night_off() {
  systemctl --user disable --now vera-night.timer vera-day.timer 2>/dev/null && ok "gece vardiyası kapatıldı" || warn "timer bulunamadı"
}

# ---------- Sihirbaz ----------
wizard() {
  echo ""; echo "═══ Vera Model Yöneticisi v$VERSION ═══"
  discover_providers
  echo ""
  local matrix="$PROFILES_DIR/.wizard.matrix"; : > "$matrix"
  echo "── Rol matrisi (ENTER = mevcut değeri koru) ──"
  while IFS= read -r role; do
    role=$(echo "$role"); [ -z "$role" ] && continue
    local cur; cur=$(current_model_of "$role")
    printf '\n  %s%s\n' "$role" "${cur:+  [şu an: $cur]}"
    read -r -p "  sağlayıcı/model seçilsin mi? [e/H]: " a
    if [[ "${a,,}" != "e" ]]; then
      [ -n "$cur" ] && printf '%s\t%s\n' "$role" "$cur" | awk -F/ '{print $1"\t"substr($0,index($0,$2))}' | { IFS=$'\t' read -r rp rm; printf '%s\t%s\t%s\n' "$role" "${rp:-?}" "${rm:-$cur}"; } >> "$matrix"
      continue
    fi
    local p m; p=$(choose_provider) || continue
    m=$(choose_model "$p")
    printf '%s\t%s\t%s\n' "$role" "$p" "$m" >> "$matrix"
  done < <(role_list)
  echo ""
  validate_matrix "$matrix" || return 1
  concurrency_check "$matrix"
  [ "$DRY_RUN" = 1 ] && DRY_RUN=1 || DRY_RUN=0
  apply_matrix "$matrix"
  rm -f "$PENDING_FLAG"
  echo ""
  local a; read -r -p "Bu ayarlar profil olarak kaydedilsin mi? [e/H]: " a
  [[ "${a,,}" == "e" ]] && { read -r -p "profil adı: " pn; save_profile "${pn:-ozel}"; }
}

usage() { sed -n '2,18p' "$SCRIPT_PATH"; }

# ---------- Arguman isleme ----------
QUIET=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run|--quiet) [ "$a" = "--dry-run" ] && DRY_RUN=1; QUIET=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
CMD="${ARGS[0]:-}"

case "$CMD" in
  "")            wizard ;;
  --help|-h)     usage ;;
  --status)      status_dashboard ;;
  --doctor)      doctor ;;
  --rollback)    do_rollback ;;
  --list-models) discover_providers; echo ""; for p in "${!PROVIDER_MODELS[@]}"; do echo "[$p]"; echo "${PROVIDER_MODELS[$p]}" | sed 's/^/  /'; done ;;
  --save-profile)[ -n "${ARGS[1]:-}" ] && save_profile "${ARGS[1]}" || { err "kullanım: --save-profile AD"; exit 1; } ;;
  --apply-profile)
    [ -n "${ARGS[1]:-}" ] || { err "kullanım: --apply-profile AD [--dry-run] [--quiet]"; exit 1; }
    apply_profile "${ARGS[1]}" ;;
  --night-on)    night_setup "${ARGS[1]:-free-local}" ;;
  --night-off)   night_off ;;
  *)             err "bilinmeyen komut: $CMD (--help bak)"; exit 1 ;;
esac
