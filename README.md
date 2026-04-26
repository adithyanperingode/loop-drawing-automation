# 🔄 Loop Drawing Automation

<div align="center">

![AutoCAD](https://img.shields.io/badge/AutoCAD-2025%2B-red?style=for-the-badge&logo=autodesk&logoColor=white)
![AutoLISP](https://img.shields.io/badge/AutoLISP-Built--in-blue?style=for-the-badge)
![Excel](https://img.shields.io/badge/Microsoft_Excel-Input-green?style=for-the-badge&logo=microsoft-excel&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![ISA](https://img.shields.io/badge/Standard-ISA%205.1-orange?style=for-the-badge)

**Automatically generate ISA 5.1 instrument loop drawings in AutoCAD from Excel data.**  
One command. No manual drawing. All loops done in minutes.

[Download](#-download) • [Quick Start](#-quick-start) • [How It Works](#-how-it-works) • [Troubleshooting](#-troubleshooting)

</div>

---

## ✨ What It Does

Instead of manually drawing each loop diagram in AutoCAD, you:

1. Fill in an Excel sheet with your instrument data
2. Save as CSV
3. Open the AutoCAD template
4. Type `DRAWLOOPS` in AutoCAD

The script automatically generates one complete DWG file per loop with all wiring, labels, ferrule numbers and title block filled in correctly.

---

## 📋 Supported Instruments

| Tag | Instrument | Signal Type | Wires | Terminal Labels |
|-----|-----------|-------------|-------|-----------------|
| PT | Pressure Transmitter | 4-20mA | 2 | + / - |
| TT | Temperature Transmitter | 4-20mA | 2 | + / - |
| TE | Temperature Element (RTD) | 3-Wire RTD | 3 | 1 / 2 / 3 |

---

## 🖼️ Sample Output

See `sample_output.pdf` for rendered examples of all three instrument types.

Each generated drawing contains:
- **Instrument bubble** — circle with tag. PT/TT have horizontal midline, TE is plain circle
- **Terminal box** — polarity labels inside cells (+/- or 1/2/3)
- **Signal wires** — 2 or 3 wires with ferrule labels on both sides
- **Cable marker** — cable name and specification
- **JB terminal strip** — correct terminal numbers auto-extracted from ferrule data
- **Title block** — loop tag, service, drawing number, revision, sheet number

---

## 📥 Download

### If you know GitHub — clone the repo:
```bash
git clone https://github.com/adithyanperingode/loop-drawing-automation.git
```

### If you are new to GitHub — download as ZIP:

```
Step 1: Click the green "Code" button at the top of this page
        ┌──────────────────────────────────────┐
        │  <>  Code  ▼                         │  ← Click here
        └──────────────────────────────────────┘

Step 2: Click "Download ZIP" from the dropdown
        ┌──────────────────────────────────────┐
        │  Clone                               │
        │  ─────────────────────────────────   │
        │  HTTPS  SSH  GitHub CLI              │
        │  https://github.com/adithyanperin... │
        │                                      │
        │  [⬇] Download ZIP                   │  ← Click here
        └──────────────────────────────────────┘

Step 3: Extract the ZIP file
        Right-click the downloaded file → Extract All

Step 4: Rename the extracted folder to:
        LOOP_DRAWINGS

Step 5: Move the LOOP_DRAWINGS folder to your Desktop
```

---

## ⚡ Quick Start

### Prerequisites
- AutoCAD 2025 or later
- Microsoft Excel

### 1. Set up folder on Desktop

After downloading, your folder should look like this:

```
Desktop\LOOP_DRAWINGS\
    ├── loop_draw.lsp          ← AutoLISP script
    ├── loop_template.dwt      ← AutoCAD template (border + title block)
    ├── loop_data.xlsx         ← Excel input file
    ├── sample_output.pdf      ← sample drawings for reference
    └── OUTPUT\                ← create this empty subfolder manually
```

> ⚠️ **Create the OUTPUT folder manually:**  
> Right-click inside LOOP_DRAWINGS → New → Folder → name it `OUTPUT`

> ⚠️ **OneDrive users:** If your Desktop is inside OneDrive, update line 8 of `loop_draw.lsp`:
> ```lisp
> (setq BASE (strcat (getenv "USERPROFILE") "\\OneDrive\\Desktop\\LOOP_DRAWINGS\\"))
> ```

### 2. Prepare your data

Open `loop_data.xlsx` and fill the **yellow columns** only:

| Column | Field | Example |
|--------|-------|---------|
| A | LOOP_TAG | PT-101 |
| B | SIGNAL_TYPE | `4-20mA` or `3W-RTD` |
| C | SERVICE | CW Supply Pressure |
| D | JB_NAME | JB-1 |
| E | TB_NAME | TB1 |
| F | CABLE_NAME | C-PT-101 |
| G | CABLE_SPEC | 1P x 1.5 Sq.mm |
| H | DRG_NO | LD-PT-101 |
| I | REV | A0 |

> Columns J–M (ferrule labels, terminal sequence) are **auto-calculated** — do not edit.

**Save as CSV:**
```
1. Make sure you are on the LOOP_DATA sheet tab
2. File → Save As
3. File type: CSV (Comma delimited) (*.csv)
4. File name: loop_data
5. Save to: Desktop\LOOP_DRAWINGS\
6. Excel warning appears:
   ┌─────────────────────────────────────────────────────┐
   │ ⚠ The selected file type does not support           │
   │   workbooks that contain multiple sheets.           │
   │   To save only the active sheet, click OK.          │
   │                                                     │
   │              [ OK ]      [ Cancel ]                 │
   └─────────────────────────────────────────────────────┘
   → Click OK — this is expected, only saves the data sheet
```

### 3. Open the AutoCAD template

> ⚠️ **Important:** Open `loop_template.dwt` before running the script.

```
1. Open AutoCAD
2. File → Open → browse to LOOP_DRAWINGS\loop_template.dwt
3. The template opens showing A3 sheet border and title block
```

### 4. Run in AutoCAD

```
1. Type APPLOAD → press Enter
2. Browse to LOOP_DRAWINGS\loop_draw.lsp → click Load
```

> ⚠️ **Security warning may appear:**
> ```
> ┌────────────────────────────────────────────────────────────────┐
> │ Security - Unsigned Executable File                            │
> │                                                                │
> │ The publisher of this file could not be verified...           │
> │                                                                │
> │  [ Always Load ]   [ Load Once ]   [ Do Not Load ]            │
> └────────────────────────────────────────────────────────────────┘
> ```
> → Click **Load Once** to proceed safely

```
3. Click Close in APPLOAD dialog
4. Type DRAWLOOPS → press Enter
5. Script runs automatically — progress shown in command line
6. Check OUTPUT\ folder for your DWG files
```

---

## 🏗️ How It Works

```
Excel (loop_data.xlsx)
        │
        │  Fill yellow columns (A to I)
        │  File → Save As → CSV (Comma delimited)
        │  Click OK on the multiple sheets warning
        ▼
loop_data.csv  saved to LOOP_DRAWINGS folder
        │
        │  Open loop_template.dwt in AutoCAD
        │  APPLOAD → load loop_draw.lsp → click Load Once on warning
        │  Type DRAWLOOPS
        ▼
AutoLISP Script (loop_draw.lsp)
        │
        ├── Reads CSV row by row
        ├── Opens loop_template.dwt as base for each loop
        ├── Draws: bubble → terminal box → wires →
        │         ferrule labels → cable marker →
        │         JB terminal strip → title block values
        ├── Saves as OUTPUT\PT-101.dwg
        └── Repeats for every loop in CSV
```

### Ferrule Label Format

```
PT-101(+) / JB-1-TB1-01
│       │    │   │   │
│       │    │   │   └── Terminal number (sequential per JB+TB)
│       │    │   └─────── Terminal block name
│       │    └─────────── Junction box name
│       └──────────────── Polarity (+/- for 4-20mA, 1/2/3 for RTD)
└──────────────────────── Instrument tag
```

Terminal numbers auto-increment per JB+TB — mixed signal types (4-20mA and 3W-RTD) in the same terminal block are handled correctly.

---

## 📁 Repository Structure

```
loop-drawing-automation/
├── README.md                 ← You are here
├── .gitignore
├── loop_draw.lsp             ← AutoLISP script (main file)
├── loop_data.xlsx            ← Excel input file with auto ferrule formulas
├── loop_template.dwt         ← AutoCAD template (A3 border + title block)
└── sample_output.pdf         ← Sample drawings — PT, TT and TE examples
```

---

## 🚧 Known Limitations (MVP v1.0)

- Field side and JB side only — control room side not yet implemented
- Instruments: PT, TT, TE only
- Manual PDF export via AutoCAD PUBLISH command

---

## 🗺️ Roadmap

- [ ] Control room / DCS side
- [ ] Additional instruments (FT, LT, AT)
- [ ] Automatic PDF generation
- [ ] Revision management
- [ ] ISA symbol block library

---

## 🔧 Troubleshooting

| Issue | Fix |
|-------|-----|
| CSV not found | Check loop_data.csv is in LOOP_DRAWINGS\ |
| Template not found | Check loop_template.dwt is in LOOP_DRAWINGS\ |
| Security warning on APPLOAD | Normal — click **Load Once** to proceed |
| Excel warning when saving CSV | Normal — click **OK** to save active sheet only |
| Sheet shows wrong total | Delete blank rows in Excel before saving as CSV |
| Drawing looks stretched | UNITS → Insertion scale must be Millimeters |
| Stops after first file | Reload script via APPLOAD and run DRAWLOOPS again |
| Double labels on drawing | Do not manually add labels — template already has them |

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 👤 Author

**Adithyan Peringode**  
*Making Engineering Smarter using AI and Automation*

Built to automate ISA 5.1 instrument loop drawing generation reducing manual drawing time from hours to minutes.

📧 [adithyanperingode95@gmail.com](mailto:adithyanperingode95@gmail.com)  
💼 [linkedin.com/in/adithyanperingode](https://in.linkedin.com/in/adithyanperingode)

> Feel free to reach out if you need help setting this up or want to contribute!
> Please don’t forget to give a ⭐ if you liked my work.
