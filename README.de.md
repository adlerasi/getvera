# Vera-Agent

> **Autonomes Engineering-Agenten-Paket für [OpenCode](https://opencode.ai) — modellagnostisch, selbstlernend, sicherheitsbewusst.**
>
> 🇬🇧 English: [README.md](README.md) · 🇹🇷 Türkçe: [README.tr.md](README.tr.md)
> ⚖️ Lizenz: [LICENSE](LICENSE) · [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)

**Vera** ist ein benutzerdefinierter Primär-Agent für OpenCode, der sich auf jedem Modell
gleich verhält — von 9B-Modellen in LM Studio oder Ollama bis zu Frontier-APIs. Die
Disziplin kommt aus mechanischen Entscheidungsbäumen und Pflicht-Checklisten, nicht aus
der Modellintelligenz. Enthalten: ein dreischichtiges Lernsystem, ein vollständiger
Modell-Manager und ein optionales Arsenal von 141 Skills.

---

## ✨ Funktionen

### 🧠 Agentengehirn (`agent/vera-agent.md`)
- **STEP 0-Orientierung** — bei jeder Aufgabe: Gedächtnisabfrage → Playbook lesen → Skill-Scan → Abhängigkeitscheck
- **Mechanische Entscheidungsbäume** — Skill- und Tool-Auswahl als IF/THEN-Regeln
- **Pflicht-Checkliste** — Build, Lint, Tests, visuelle Prüfung; „fertig" ohne Beleg = Fehlschlag
- **Modelladaptivität** — schwache Modelle halten sich strikt an Checklisten, starke erhalten Freiheit; die Disziplin bleibt gleich
- **Sicherheitsinstinkte** — Geheimnisse sind radioaktiv; Schwachstellen werden unaufgefordert gemeldet; Pentesting nur für autorisierte Ziele
- **Selbstentwicklung** — Nutzerkorrekturen werden dauerhaft gespeichert; Post-Mortems nach Fehlern; Selbstkritik-Gate vor jeder Übergabe

### 📚 Dreischichtiges Lernsystem
| Schicht | Was gelernt wird | Wo |
|---|---|---|
| **ACE Playbook** (`.vera/playbook.md`) | Projektstrategien mit `helpful/harmful`-Zählern, nur Delta-Updates (ICLR-2026-Methode) | pro Projekt |
| **Memory MCP** (Wissensgraph) | Dauerhafte Fakten über Nutzer und Umgebungen | global |
| **Skill-Evolution** (`skill-evolver` + GEPA-Schleifen-Plugin*) | Verfahren, verfeinert aus Fehlerprotokollen | global |

*\* optionales Extra bei der Installation*

### 🎛️ Modell-Manager (`vera-models.sh` + Befehl `/vera-models`)
- **Pflichtschritt bei der Installation** mit drei Wegen: automatisch / manueller Assistent / überspringen (mit Erinnerung)
- Anbietererkennung: **LM Studio**, **Ollama**, alle Konfigurationsanbieter, alle opencode-authentifizierten Anbieter (Validierung über `opencode run` — jede API-Sprache funktioniert)
- **Vollständige Rollenmatrix**: Modelle für Vera, small_model, explore, librarian, oracle, frontend-engineer … einzeln zuweisbar
- Smoke-Test-Schleife — eine fehlschlagende Rolle wird neu gewählt, bis sie besteht (240 s Kaltlade-Timeout)
- Kontextlängen-Vergleich gegen Rollenanforderungen (Rettungsanker für lokale Modelle)
| Einzelpunkt-Schutz: alles auf einem lokalen Server → Hintergrund-Konkurrenz wird automatisch gesenkt |
- Profile: `free-local`, `hybrid`, `premium`, benutzerdefiniert — API-Schlüssel landen NIE in Profilen
- `--doctor` (volle Gesundheitsprüfung + Rollback-Vorschlag), `--status`, `--rollback`, `--dry-run`
- Optionaler **Nachtdienst**: 02:00 leichtes Profil ↔ 08:00 Tagesprofil (systemd-Timer, Kontoschoner)

### 🛡️ Sicherheit
- Berechtigungsschild: destruktive Befehle verboten, sudo/force-push fragt nach, Rest fließt
- Nicht vertrauenswürdiger Code läuft in OpenSandbox-Containern — nie auf dem Host
- Pentest-/Redteam-Skills aktivieren sich nur für autorisierte Ziele

### ⚔️ Volles Arsenal (optional, gebündelt — 141 Skills)
Sicherheitskette (~48), Sprach-/Framework-Experten (~25), AI/NLP + RAG, Figma→UI,
Playwright-Tests, OSINT-Recherche-Set, `karpathy-guidelines`-Disziplin und mehr.
Der Installer fragt: **e** → sofort aktiv; **H** → liegt passiv in Reserve,
später per Einzeiler (`enable-arsenal.sh`) aktivierbar.

---

## 🚀 Installation

### 🖥️ Methode A — Manuel (Terminal)

```bash
git clone https://github.com/adlerasi/getvera.git
cd getvera
bash getvera.sh                            # interaktiver Assistent: Extras + Arsenal + Modell-Zuteilung
bash getvera.sh --all --with-opensandbox   # oder vollautomatisch: alles ohne Fragen
```

opencode neu starten → **Tab** → **vera-agent** wählen → Ziel geben.
Voraussetzungen: Linux/macOS (Windows → WSL2), Node.js 18+.
Vollständige Anleitung: [KURULUM.md](KURULUM.md) · Flags: `bash getvera.sh --help`

### 🤖 Methode B — Aus opencode heraus (agentenunterstützt)

Terminal-Akrobatik nicht nötig. opencode überall öffnen und diesen Prompt einfügen:

> Installiere mir https://github.com/adlerasi/getvera: klone es nach ~/getvera,
> führe `bash getvera.sh` aus und beantworte die Fragen gemeinsam mit mir,
> danach `vera-models.sh --doctor` und hilf mir, die Modelle pro Rolle zuzuweisen.

Dein laufender Agent klont und installiert *mit* dir; Veras Modell-Manager schließt
das Setup ab. Funktioniert aus jedem Harness (opencode, Claude Code, Cursor…).

### 📦 Alternative: Release-Archiv

`verapack.tar.gz` von den [Releases](https://github.com/adlerasi/getvera/releases)
laden und bei Methode A ab dem `tar xzf`-Schritt weitermachen.


## ✅ Verifizieren

```bash
ls ~/.config/opencode/agent/vera-agent.md ~/.agents/skills/ace-playbook/SKILL.md
bash ~/.config/opencode/vera-models.sh --status
```

opencode starten → **Tab** drücken → **vera-agent** wählen → Ziel geben.

## 🗑️ Deinstallation

```bash
bash uninstall.sh   # entfernt Vera-Komponenten; eigene Provider/Plugins bleiben unberührt
```

## ⚖️ Lizenz & Hinweise

Dies ist ein **individuelles, nicht-kommerzielles Projekt**. Eigener Code/Doku: MIT
([LICENSE](LICENSE)). Die gebündelten `arsenal/`-Skills gehören ihren ursprünglichen
Autoren — vollständige Quellen-/Lizenzzuordnung in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md); die wenigen unlizenzierten Einträge
(nur persönliche Nutzung) sind dort gelistet und jederzeit entfernbar.
