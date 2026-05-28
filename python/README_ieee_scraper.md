# ieee_scraper.py

Scrapes IEEE Xplore search results and saves every paper to `docs/research/papers_log.md` with full metadata — title, authors, year, journal/venue, DOI, URL, and abstract.

---

## How It Works

1. Opens a real Chromium browser (via Playwright)
2. Navigates to the IEEE Xplore search page
3. Intercepts the `/rest/search` JSON response that IEEE fires automatically — gets full authors + abstract without needing to click into each paper
4. Strips IEEE highlight markup (`[::keyword::]`) from text
5. Appends all papers to `papers_log.md`, numbered sequentially from where the log left off

---

## Setup (one-time)

```powershell
cd C:\Users\User\workspace\engineering\vsg-project\python
.venv\Scripts\Activate.ps1
pip install playwright
playwright install chromium
```

---

## Usage

### Basic — headless, no login required
Works without SUT proxy. Gets abstracts from the public IEEE search API.

```powershell
.venv\Scripts\python.exe ieee_scraper.py "virtual synchronous generator hardware"
```

### Multiple pages (25 papers per page)

```powershell
.venv\Scripts\python.exe ieee_scraper.py "grid-forming inverter control" --pages 3
```

### With SUT proxy login (full-text access)
Opens a visible browser and pauses so you can log in via SUT library before scraping starts.

```powershell
.venv\Scripts\python.exe ieee_scraper.py "VSG inverter ESP32 control"
# Browser opens -> go to https://library.sut.ac.th/clremsite/?m=eresource
# -> click IEEE/IET Electronic Library (IEL) -> log in with SUT account
# -> browser lands on IEEE Xplore -> come back here and press ENTER
```

### Skip the login pause (already logged in / headless)

```powershell
.venv\Scripts\python.exe ieee_scraper.py "synchronverter prototype" --no-pause
.venv\Scripts\python.exe ieee_scraper.py "virtual inertia embedded" --headless --no-pause
```

---

## Arguments

| Argument | Default | Description |
|---|---|---|
| `query` | required | Search query string, use quotes for phrases |
| `--pages N` | 2 | Number of result pages to fetch (25 papers/page) |
| `--headless` | off | Run browser without a visible window |
| `--no-pause` | off | Skip the manual SUT login wait |

---

## Output

Papers are appended to:
```
C:\Users\User\workspace\engineering\vsg-project\docs\research\papers_log.md
```

Each entry:
```markdown
## [PAPER-001] Paper Title Here

| Field        | Value                              |
|--------------|------------------------------------|
| Authors      | Smith, J.; Lee, K.                 |
| Year         | 2023                               |
| Journal      | IEEE Transactions on ...           |
| DOI          | 10.1109/...                        |
| URL          | https://ieeexplore.ieee.org/...    |

### Abstract
> Full abstract text here...

### Key Takeaways
- [Fill in after reading]
```

Numbering continues from the last PAPER-### already in the log — safe to run multiple times.

---

## Recommended Search Strings for VSG Project

```powershell
# Core VSG hardware
.venv\Scripts\python.exe ieee_scraper.py "virtual synchronous generator hardware prototype" --pages 2

# ESP32 / low-cost MCU
.venv\Scripts\python.exe ieee_scraper.py "virtual synchronous generator embedded microcontroller" --pages 2

# Alternative terminology
.venv\Scripts\python.exe ieee_scraper.py "synchronverter experimental validation inverter" --pages 2

# Grid-forming with BESS
.venv\Scripts\python.exe ieee_scraper.py "grid-forming inverter battery energy storage VSG" --pages 2

# Safety / protection
.venv\Scripts\python.exe ieee_scraper.py "inverter protection gate driver overcurrent hardware" --pages 2
```

---

## Notes

- `--headless` mode cannot use SUT proxy login (no browser UI). Abstracts are still retrieved from the public IEEE API.
- IEEE Xplore abstracts in search results are sometimes truncated. For full abstract, open the paper URL with your SUT account.
- False positives (unrelated papers) appear occasionally — IEEE search is keyword-based. Review `papers_log.md` and delete irrelevant entries manually.
- The log file is UTF-8. Open in VS Code or any modern editor — avoid old Windows Notepad (no UTF-8 BOM support in older versions).
