# Vera-Agent Kurulum Rehberi (Detaylı)

Bu rehber; hızlı kurulum, manuel kurulum, doğrulama ve sorun giderme adımlarını içerir.
Kısa bakış için README.md'ye, kurucunun kendisi için `bash install.sh --help` komutuna bakın.

---

## 1. Gereksinimler

| Bileşen | Zorunlu mu? | Not |
|---|---|---|
| **opencode** | ✅ Evet | `curl -fsSL https://opencode.ai/install \| bash` veya `npm i -g opencode-ai` |
| **Node.js 18+** | ✅ Evet | 5 MCP sunucusu npx ile çalışır |
| **git** | Önerilen | Ekstra plugin'lerin klonlanması için |
| **uv / uvx** | Koşullu | opensandbox MCP kullanılacaksa (kurucu otomatik kurabilir) |
| **Docker** | Opsiyonel | Sadece OpenSandbox backend için |
| **systemd (user)** | Opsiyonel | Linux'ta backend otomatik servisi; macOS'ta manuel başlatılır |
| **Windows** | — | Doğrudan değil; **WSL2 içinde** kurun |

Model tarafı: LM Studio (`http://127.0.0.1:1234`), herhangi bir OpenAI-uyumlu API ya da
opencode'un desteklediği tüm sağlayıcılar çalışır. Vera model-bağımsızdır.

---

## 2. Hızlı Kurulum (önerilen)

```bash
tar xzf verapack.tar.gz && cd verapack
bash getvera.sh          # eksikleri sorar, kurulumu yapar
```

Her şeyi sorulamadan kurmak:

```bash
bash install.sh --all --with-opensandbox
```

Sonrasında: **terminali kapatıp açın** (PATH tazelensin) → `opencode` başlatın.

---

## 3. Manuel Kurulum (script'siz)

### 3.1 Dosyaları yerleştir

```bash
mkdir -p ~/.config/opencode/agent ~/.agents/skills/ace-playbook

cp agent/vera-agent.md            ~/.config/opencode/agent/
cp skills/ace-playbook/SKILL.md   ~/.agents/skills/ace-playbook/
```

### 3.2 Config birleştirme

Mevcut config'iniz YOKSA:

```bash
cp config-snippet.jsonc ~/.config/opencode/opencode.jsonc
```

VARSA: `config-snippet.jsonc` içeriğindeki `"mcp"` bloğunu ve `"permission"`
bloğunu kendi `~/.config/opencode/opencode.json(c)` dosyanıza ekleyin.
Var olan anahtarlarınızı ezmeden yalnızca eksikleri taşıyın.

### 3.3 Ekstralar (isteğe bağlı)

```bash
# Alt-ajan orkestrasyonu
npm install --prefix ~/.config/opencode oh-my-openagent@latest
# config'deki "plugin" dizisine: "oh-my-openagent@latest"

# Öz-evrim döngüsü (Hermes tarzı)
git clone --depth 1 https://github.com/okdk7788/opencode-self-improving-skills.git \
  ~/.config/opencode/plugins/self-improving-skills
mkdir -p ~/.config/opencode/skills
cp -r ~/.config/opencode/plugins/self-improving-skills/skills/* ~/.config/opencode/skills/
# config'deki "plugin" dizisine: "./plugins/self-improving-skills/index.ts"

# Evrim becerileri
npx skills add https://github.com/FishSerrie/skill-evolver.git --skill '*' --global --agent opencode --yes
npx skills add https://github.com/wshobson/agents --skill llm-evaluation --global --agent opencode --yes
```

---

## 4. Kurulum Sonrası Doğrulama

```bash
# 1) Dosyalar yerinde mi?
ls ~/.config/opencode/agent/vera-agent.md
ls ~/.agents/skills/ace-playbook/SKILL.md

# 2) Config gecerli mi? (hata vermemeli)
cat ~/.config/opencode/opencode.jsonc   # gozle gezin; JSON hatasi varsa .bak-vera ile karsilastirin
```

opencode'u başlattıktan sonra:

1. **Tab** tuşuyla agent listesinde **vera-agent**'ı görün ve seçin
2. Ajan'a sorun: *"Hangi MCP araçların ve yeteneklerin var?"*
   - Beklenen: playwright, opensandbox, memory, sequential-thinking, context7 araçlarını sayar;
     ace-playbook + karpathy-guidelines gibi skill'lerden bahseder
3. İlk gerçek görevde `<proje>/.vera/playbook.md` oluşmaya başlar (öğrenme sistemi çalışıyor demektir)

> ⏱️ İlk açılışta MCP'ler npx/uvx üzerinden iner → 30-90 sn gecikme normaldir.

---

## 5. Sorun Giderme

| Belirti | Neden | Çözüm |
|---|---|---|
| `opencode: command not found` | PATH eski | Terminali yeniden açın; `~/.local/bin` ve `~/.opencode/bin` PATH'te mi kontrol edin |
| İlk açılış çok uzun sürüyor | MCP ilk indirmesi | Normal; ikinci açılışta cache'den hızlı gelir |
| `memory` araçları boş döner | İlk kullanım | Normal — graph boş başlar; Vera görevlerle doldurur |
| Sandbox oluşturma hatası "Network connectivity" | Docker imajları lokalde yok | `docker pull python:3.12 && docker pull opensandbox/execd:v1.0.21` |
| `localhost:8080/health` yanıt yok | Backend kapalı | `systemctl --user start opensandbox-server` (Linux) veya `uvx opensandbox-server` (macOS/manuel) |
| systemd user servisi kurulmuyor | macOS / WSL sınırı | Servis adımını atlayın; backend'i ayrı terminalde `uvx opensandbox-server` ile tutun |
| LM Studio modelleri görünmüyor | Studio kapalı/port | LM Studio'da server'ı başlatın (varsayılan port 1234); config'de `baseURL` ile eşleşsin |
| Config hatasıyla opencode açılmıyor | Bozuk merge | `cp ~/.config/opencode/opencode.jsonc.bak-vera ~/.config/opencode/opencode.jsonc` |
| Skill'ler tetiklenmiyor | Kurulumdan sonra restart edilmemiş | opencode kapat-aç; skill'ler açılışta taranır |

## 5a-bis. TAM CEPHANELİK

`install.sh` sırasında sorulur. Aktive edilmezse skill'ler
`~/.local/share/opencode/skills-reserve/` altında pasif bekler; opencode onları görmez.
Açmak: `bash <paket>/enable-arsenal.sh`

## 5b. Model Yöneticisi (vera-models)

Kurulumun **zorunlu son adımıdır**. Üç kapı sunar: Otomatik (sağlayıcı taraması +
akıllı ön-doldurma), Manuel (tüm rolleri tek tek seç) veya Atla (`.vera-models-pending`
işareti konur; Vera ilk açılışta hatırlatır).

İçerik: sağlayıcı taraması (LM Studio `:1234`, Ollama `:11434`, config'deki
OpenAI-uyumlu sağlayıcılar, auth.json'daki resmî sağlayıcılar) → tüm ajan-rol
matrisi → smoke-test doğrulama döngüsü (hata olursa o rol için yeniden seçim) →
atomik yazım (`.bak-vera-models` yedekli).

Yardımcı komutlar: `--status`, `--doctor`, `--rollback`, `--list-models`,
`--apply-profile AD --dry-run`, `--night-on/--night-off`.
Soğuk model yüklemeleri uzun sürebilir (35B lokal ≈ 2 dk) — smoke timeout 240 sn'dir.

---

## 6. Kaldırma & Taşıma

```bash
bash uninstall.sh        # vera-agent + ace-playbook + config'deki vera MCP'leri silinir
```

Korunanlar (elle silinebilir): `~/.local/share/opencode/memory.json` (ajan hafızası),
projelerdeki `.vera/playbook.md` dosyaları.

Deneyimi başka makineye taşımak: `~/.local/share/opencode/memory.json` dosyasını da kopyalayın.

---

## 7. SSS

**S: Vera hangi modellerle çalışır?**
C: Hepsinde aynı disiplinle çalışır — LM Studio lokal modeller, OpenAI-uyumlu API'ler,
resmî sağlayıcılar. Model Adaptivity bölümü gereği zayıf modelde checklist'e daha sıkı yaslanır.

**S: 143 skill'i de kurmam gerekir mi?**
C: Hayır. Paket yalnızca ace-playbook ile gelir ve Vera bu haliyle tam iş görür.
Diğer skill'ler opsiyonel güç artışıdır; Vera Self-Check ile neyin kurulu olduğunu kendisi anlar.

**S: İnternet olmadan çalışır mı?**
C: İlk MCP indirmelerinden sonra büyük ölçüde evet (lokal modellerle). context7/web araştırma
gibi çevrimiçi özellikler elbette internet ister.

**S: Güvenliği nasıl garantiliyorsunuz?**
C: İzin kuralları yıkıcı komutları deny/ask ile keser; bilinmeyen kod sandbox'ta koşar;
pentest skill'leri yalnızca yetkili hedefler için aktive olur (prompt'ta yazılı).
