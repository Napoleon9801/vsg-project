# VSG Project — Python Scripts

## ieee_scraper.py

ดึงข้อมูล paper จาก IEEE Xplore แล้วบันทึกลง `docs/research/papers_log.md`
ได้ครบ: ชื่อ, ผู้แต่ง, ปี, journal, DOI, URL, abstract

---

## วิธีรัน

เปิด PowerShell แล้ว:

```powershell
cd C:\Users\User\workspace\engineering\vsg-project\python
.venv\Scripts\python.exe ieee_scraper.py "คำค้นหา" --pages 2
```

Browser จะเปิดขึ้น → **login SUT** ผ่าน IEEE/IET Electronic Library → กด **Enter** ใน PowerShell

---

## ตัวอย่าง Query

```powershell
# VSG hardware
.venv\Scripts\python.exe ieee_scraper.py "virtual synchronous generator hardware prototype" --pages 2

# ESP32 + inverter
.venv\Scripts\python.exe ieee_scraper.py "ESP32 inverter control embedded" --pages 2

# Grid-forming
.venv\Scripts\python.exe ieee_scraper.py "grid-forming inverter laboratory implementation" --pages 3
```

---

## ไม่ต้อง login (headless)

```powershell
.venv\Scripts\python.exe ieee_scraper.py "synchronverter prototype" --pages 2 --headless --no-pause
```

---

## ผลลัพธ์

บันทึกที่ `docs\research\papers_log.md` ต่อท้ายจาก PAPER-### เดิมอัตโนมัติ

---

## Setup (ครั้งแรกครั้งเดียว)

```powershell
.venv\Scripts\pip.exe install playwright
.venv\Scripts\python.exe -m playwright install chromium
```
