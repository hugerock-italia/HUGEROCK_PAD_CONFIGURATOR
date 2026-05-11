# KAT-ADV Companion App — Project Context

Questo file viene caricato automaticamente da Claude Code in ogni sessione. Contiene il contesto persistente del progetto: cos'è, com'è organizzato, e le convenzioni di lavoro.

## Cos'è il progetto

App Flutter companion per la pulsantiera **KAT-ADV** (KAT1), un dispositivo per navigazione in motorally basato su microcontrollore ESP32-S3.

Funzioni principali dell'app:
- Configurazione della pulsantiera via BLE (Bluetooth Low Energy)
- Aggiornamento firmware via OTA (BLE)
- Visualizzazione stato di connessione
- Gestione mappe di tasti per app diverse (DMD2, Whip Live, ecc.)

Repository GitHub: `hugerock-italia/HUGEROCK_PAD_CONFIGURATOR`
Path locale: `C:\HUGEROCK\APP\HUGEROCK_PAD_CONFIGURATOR\`

## Stack tecnico

- **Flutter** 3.x con null-safety (versione esatta in `pubspec.yaml`)
- **BLE**: `flutter_blue_plus`
- **Permessi runtime**: `permission_handler`
- **Versione app**: `package_info_plus`
- **State management**: usa il pattern già adottato nei file esistenti, non introdurre librerie nuove senza richiesta esplicita

## Struttura cartelle (progetto)

```
HUGEROCK_PAD_CONFIGURATOR/
├── lib/
│   ├── main.dart                # entry point, definisce AppColors, AppTheme
│   ├── screens/                 # schermate principali dell'app
│   │   ├── home_screen.dart
│   │   ├── config_screen.dart
│   │   ├── ota_screen.dart
│   │   └── auto_config_screen.dart
│   └── services/                # logica di business
│       └── ble_manager.dart
├── android/                     # configurazione Android nativa
├── assets/                      # immagini, font, icone
├── test/                        # test unitari e widget
├── pubspec.yaml                 # dipendenze e metadata
├── .claude/
│   ├── agents/                  # sub-agenti Claude Code
│   └── settings.local.json      # configurazione locale (gitignored, contiene segreti)
└── CLAUDE.md                    # questo file
```

## Convenzioni di codice

- Codice in **inglese**: identificatori, stringhe utente, dartdoc. Commenti in italiano accettabili dove aiutano chiarezza
- Naming Dart standard: `lowerCamelCase` per variabili e metodi, `UpperCamelCase` per classi, `snake_case.dart` per file
- Doc inline: dartdoc per ogni API pubblica nuova (`///` sopra la dichiarazione)
- Niente `print()` in produzione: usare `debugPrint`

## Convenzioni Git e GitHub

- **Commit messages**: Conventional Commits in inglese. Esempi:
  - `feat(app): add update check on startup`
  - `fix(app): handle BLE disconnect gracefully`
  - `docs(app): update README with build instructions`
  - `chore: bump flutter_blue_plus to 1.32.0`
- **Branch naming**: `feat/<slug>`, `fix/<slug>`, `chore/<slug>`, `docs/<slug>`
- **Pull request**: sempre da feature branch verso `main`. **MAI** push diretto su `main`
- **PR body**: motivazione + change list + screenshot per modifiche UI

## Rete di agenti Claude Code

Il progetto usa una rete di sub-agenti in `.claude/agents/`. Fase attuale del piano: **A** (3 agenti operativi).

Agenti attivi:
- **orchestrator** — decompone i task, smista, valida UX gate
- **app-engineer-flutter** — modifica codice Dart e configurazioni
- **github-operator** — operazioni Git e GitHub (branch, commit, push, PR)

Documento di architettura completo della rete: `KAT-ADV-Agent-Network.md` nel root del repo (se presente).

## REGOLA D'ORO per usare gli agenti

**Una sola richiesta all'orchestrator per task.** Includi tutto il task (modifica + commit + push + PR) in una singola frase iniziale. **Non spezzettare turno per turno** — se inizi a dire "ok adesso committa", "ok adesso pusha", Claude Code principale prende il controllo e bypassa gli agenti specializzati.

Esempio CORRETTO:
> `@orchestrator aggiungi la sezione X al README, committa "docs: ..." su feature branch e apri la PR`

Esempio SBAGLIATO:
> Turno 1: `@orchestrator aggiungi sezione X`
> Turno 2: `commit this`
> Turno 3: `push it`

## Regole di base per gli agenti

- **Read before write**: prima di modificare un file, leggerlo sempre
- **Edit, non Write**: per modificare file esistenti usare il tool `Edit` con modifiche puntuali. `Write` è solo per file nuovi
- **No workaround creativi**: niente Python/Bash/heredoc per scrivere file Dart. Se `Edit` fallisce, segnalare l'errore, non improvvisare
- **UX changes richiedono conferma utente**: nuovi dialog, modifiche visibili → l'agente deve chiedere PRIMA di procedere
- **Validazione locale prima del commit**: `dart format` e `flutter analyze` devono uscire puliti

## Note ambientali

- Sistema: **Windows**
- Auth GitHub: gestita da GitHub Desktop (Git Credential Manager). gh CLI installato ma autenticazione separata in `.claude/settings.local.json` (file gitignored)
- Path semplice (`C:\HUGEROCK\APP\HUGEROCK_PAD_CONFIGURATOR\`) per evitare problemi bash con caratteri speciali
