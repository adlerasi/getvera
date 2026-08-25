# Vera-Agent

> **[OpenCode](https://opencode.ai) için otonom mühendis ajanı — model-bağımsız, kendi kendine öğrenen, güvenlik bilinçli.**
>
> 🇬🇧 English: [README.md](README.md) · 🇩🇪 Deutsch: [README.de.md](README.de.md)
> ⚖️ Lisans: [LICENSE](LICENSE) · [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)

**Vera**, OpenCode için yazılmış özel bir birincil ajandır; LM Studio veya Ollama'daki
9B lokal modellerden frontier API'lere kadar **hangi modelle çalışsa aynı davranır**.
Disiplin; mekanik karar ağaçlarından ve zorunlu kontrol listelerinden gelir — model
zekâsına değil. Üç katmanlı öğrenme sistemi, tam kapsamlı model yöneticisi ve opsiyonel
141 skill'lik cephanelik ile birlikte gelir.

---

## ✨ Özellikler

### 🧠 Ajan Beyni (`agent/vera-agent.md`)
- **STEP 0 oryantasyonu** — her görev: hafıza sorgusu → playbook okuma → skill taraması → bağımlılık nabzı
- **Mekanik karar ağaçları** — skill ve araç seçimi IF/THEN kuralı olarak; sezgi yok
- **Zorunlu doğrulama checklist'i** — build, lint, test, görsel kontrol; kanıtsız "bitti" = başarısızlık
- **Model adaptivitesi** — zayıf model checklist'e sıkı yaslanır, güçlü model serbest çalışır; disiplin değişmez
- **Güvenlik refleksleri** — sırlar radyoaktiftir; açık istenmeden raporlanır; pentest yalnızca yetkili hedefte
- **Kendi kendini geliştirme** — kullanıcı düzeltmesi kalıcı kayda dönüşür, başarısızlıkta post-mortem zorunlu, teslim öncesi öz-eleştiri kapısı

### 📚 Üç Katmanlı Öğrenme Sistemi
| Katman | Neyi öğrenir | Nerede |
|---|---|---|
| **ACE Playbook** (`.vera/playbook.md`) | `helpful/harmful` sayaçlı proje stratejileri, sadece delta güncelleme (ICLR 2026 yöntemi) | proje başına |
| **Memory MCP** (knowledge graph) | Seninle ve ortamınla ilgili kalıcı gerçekler | global |
| **Skill evrimi** (`skill-evolver` + GEPA döngüsü plugin'i*) | Başarısızlık izlerinden rafine edilen prosedürler | global |

*\* kurulumda opsiyonel ekstra*

### 🎛️ Model Yöneticisi (`vera-models.sh` + `/vera-models` komutu)
- **Zorunlu kurulum adımı** — üç kapı: otomatik / manuel sihirbaz / hatırlatmalı atlama
- Sağlayıcı keşfi: **LM Studio**, **Ollama**, config'deki her sağlayıcı, opencode'a auth'lu tüm resmî sağlayıcılar (doğrulama `opencode run` üzerinden — API lehçesi fark etmez)
- **Tam rol matrisi**: Vera, small_model, explore, librarian, oracle, frontend-engineer… hepsine ayrı model
- Smoke-test doğrulama döngüsü — düşen rol geçene kadar yeniden seçilir (240 sn soğuk-yükleme payı)
- Rol gereksinimi ↔ context kapasitesi karşılaştırması (lokal model kullanıcısının cankurtaranı)
- Tek-uç nokta koruması: her şey tek lokal sunucudaysa arka plan eşzamanlılığı otomatik düşer
- Profiller: `free-local`, `hybrid`, `premium`, özel — API anahtarları profillere ASLA yazılmaz
- `--doctor` (tam muayene + rollback önerisi), `--status`, `--rollback`, `--dry-run`
- Opsiyonel **gece vardiyası**: 02:00 hafif profil ↔ 08:00 gündüz profili (systemd timer, kota koruma)

### 🛡️ Güvenlik
- İzin kalkanı: yıkıcı komutlar engelli, sudo/force-push sorar, gerisi akıcı
- Güvenilmeyen kod OpenSandbox konteynerinde koşar — host'a hiç dokunmaz
- Pentest/redteam skill'leri yalnızca yetkili hedeflerde aktive olur

### ⚔️ Tam Cephanelik (opsiyonel, pakette gömülü — 141 skill)
Güvenlik zinciri (~48), dil/framework uzmanları (~25), AI/NLP + RAG, Figma→UI,
Playwright test, OSINT araştırma seti, `karpathy-guidelines` disiplini ve dahası.
Kurulumda sorulur: **e** → tamamı aktif; **H** → pasif rezerve bekler,
sonradan `enable-arsenal.sh` ile tek komut açılır.

---

## 🚀 Kurulum

### 🖥️ Yöntem A — Manuel (terminal)

```bash
git clone https://github.com/adlerasi/getvera.git
cd getvera
bash getvera.sh                            # interaktif sihirbaz: ekstralar + cephanelik + model atamaları
bash getvera.sh --all --with-opensandbox   # ya da tam otomatik: sorusuz her şey
```

opencode'u yeniden başlat → **Tab** → **vera-agent**'ı seç → hedef ver.
Gereksinimler: Linux/macOS (Windows → WSL2), Node.js 18+.
Tam rehber: [KURULUM.md](KURULUM.md) · bayraklar: `bash getvera.sh --help`

### 🤖 Yöntem B — opencode içinden (ajan yardımıyla)

Terminal işlerine girmeden: opencode'u aç, şu istemi yapıştır:

> Bana https://github.com/adlerasi/getvera deposunu kur: ~/getvera içine klonla,
> `bash getvera.sh` çalıştırıp sorularını benimle birlikte yanıtla,
> sonra `vera-models.sh --doctor` ile sağlık kontrolü yap ve rollere model atmama yardım et.

Çalışan ajan klonlamayı ve kurulumu seninle birlikte yürütür; Vera'nın model yöneticisi
kurulumu tamamlar. Herhangi bir ortamda çalışır (opencode, Claude Code, Cursor…).

### 📦 Alternatif: sürüm arşivi

[Releases](https://github.com/adlerasi/getvera/releases) sayfasından `verapack.tar.gz`
indirip Yöntem A'daki `tar xzf` adımından devam edin.


## ✅ Doğrulama

```bash
ls ~/.config/opencode/agent/vera-agent.md ~/.agents/skills/ace-playbook/SKILL.md
bash ~/.config/opencode/vera-models.sh --status
```

opencode'u başlat → **Tab** ile **vera-agent**'ı seç → hedef ver.

## 🗑️ Kaldırma

```bash
bash uninstall.sh   # Vera bileşenlerini söker; kendi provider/plugin'lerin yerinde kalır
```

## ⚖️ Lisans & Bildirimler

Bu **bireysel, ticari olmayan bir projedir**. Kendi kod/dokümanlar: MIT ([LICENSE](LICENSE)).
`arsenal/` içindeki skill'ler orijinal yazarlarına aittir — tam kaynak/lisans eşlemesi
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) dosyasındadır; kişisel kullanım için
korunan lisanssız birkaç madde de orada listelenir (istediğin an çıkarılabilir).
