;; ════════════════════════════════════════════════════════════════════
;; LOOP DRAWING AUTOMATION — loop_draw.lsp  v5.1
;; One command — DRAWLOOPS
;; Opens AutoCAD, reads CSV, creates all drawings automatically
;; No template file needed
;; ════════════════════════════════════════════════════════════════════

;; ── USER CONFIG ─────────────────────────────────────────────────────
(setq BASE     (strcat (getenv "USERPROFILE") "\\OneDrive\\Desktop\\LOOP_DRAWINGS\\"))
(setq CSV-FILE (strcat BASE "loop_data.csv"))
(setq OUT-DIR  (strcat BASE "OUTPUT\\"))
;; ────────────────────────────────────────────────────────────────────

;; ── A3 SHEET CONSTANTS (all mm) ─────────────────────────────────────
;;
;;  y=292 ┌──────────────────────────────────────────────┐
;;        │                                              │
;;        │                                              │
;;  y=158 │  [PT]─[■]════════════[○]════════════[■■]    │
;;        │                                              │
;;        │                                              │
;;   y=25 ├──────────────────────────────────────────────┤
;;    y=5 │ LOOP NO │ TITLE/SERVICE │ DRG NO │ REV │ SHT │
;;        └──────────────────────────────────────────────┘
;;        x=5                                       x=415

;; Instrument bubble
(setq BX  50.0)   ; centre X
(setq BY 158.0)   ; centre Y
(setq BR   8.0)   ; radius

;; Instrument terminal box (right of bubble)
(setq TX1 59.0)   ; left X
(setq TX2 73.0)   ; right X
(setq TCH  8.0)   ; cell height

;; Signal wires
(setq WX1  73.0)  ; start X (terminal box right edge)
(setq WX2 350.0)  ; end X   (JB left edge)

;; Cable oval
(setq OX  211.0)  ; centre X
(setq ORX   5.0)  ; X radius
(setq ORY2 10.0)  ; Y radius for 2-wire (4-20mA)
(setq ORY3 14.0)  ; Y radius for 3-wire (3W-RTD)

;; JB terminal strip
(setq JX1 350.0)  ; left X
(setq JX2 382.0)  ; right X
(setq JW   32.0)  ; width

;; Text heights
(setq TH-V  5.0)  ; title block values
(setq TH-L  3.5)  ; labels (bubble, JB name etc.)
(setq TH-F  2.5)  ; ferrule text
(setq TH-S  2.5)  ; title block small labels

;; Title block Y positions
(setq TB-VAL  14.0)   ; value text Y (middle of 5-25 strip)
(setq TB-LBL  22.0)   ; label text Y

;; CSV column indices (0-based)
(setq CI-TAG  0)(setq CI-SIG  1)(setq CI-SVC  2)
(setq CI-JB   3)(setq CI-TB   4)(setq CI-CBL  5)
(setq CI-SPC  6)(setq CI-DRG  7)(setq CI-REV  8)
(setq CI-FW1 10)(setq CI-FW2 11)(setq CI-FW3 12)

;; ════════════════════════════════════════════════════════════════════
;; UTILITIES
;; ════════════════════════════════════════════════════════════════════

(defun G (x y) (list x y 0.0))

;; Strip trailing CR LF space
(defun STRIPCR (s / n)
  (setq n (strlen s))
  (while (and (> n 0)
              (member (ascii (substr s n 1)) (list 13 10 32)))
    (setq n (1- n)))
  (substr s 1 n))

;; Split CSV line on commas
(defun SPLITCSV (raw / s r tok i ch)
  (setq s (STRIPCR raw) r '() tok "" i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (if (= ch ",")
      (progn (setq r (append r (list tok))) (setq tok ""))
      (setq tok (strcat tok ch)))
    (setq i (1+ i)))
  (append r (list tok)))

;; Get field n (0-based) trimmed
(defun FLD (n lst / i v)
  (setq i 0)
  (while (and lst (< i n))
    (setq lst (cdr lst)) (setq i (1+ i)))
  (setq v (if lst (car lst) ""))
  (vl-string-trim " " v))

;; Count real data rows (skip header + hint)
;; Extract terminal number from ferrule label
;; e.g. "PT-101(+) / JB-1-TB1-06" -> "06"
;; Returns "" if ferrule is empty (e.g. fw3 for 4-20mA)
(defun TERMNO (fw / idx last)
  (if (or (null fw) (= (vl-string-trim " " fw) ""))
    ""
    (progn
      (setq idx 0 last 0)
      (while (vl-string-search "-" fw (1+ idx))
        (setq last idx)
        (setq idx (vl-string-search "-" fw (1+ idx))))
      (setq last idx)
      (if (> last 0)
        (vl-string-trim " " (substr fw (+ last 2)))
        fw))))

(defun COUNTROWS (fp / f ln cnt tag comma)
  (setq cnt 0 f (open fp "r"))
  (if f (progn
    (read-line f) (read-line f)
    (while (setq ln (read-line f))
      (setq ln (STRIPCR ln))
      ;; Get first field (LOOP_TAG) = text before first comma
      (setq comma (vl-string-search "," ln 0))
      (setq tag   (if comma
                    (vl-string-trim " " (substr ln 1 comma))
                    ""))
      ;; Count only if tag is non-empty and not hint text
      (if (and (> (strlen tag) 0)
               (not (= (substr tag 1 3) "e.g")))
        (setq cnt (1+ cnt))))
    (close f)))
  cnt)

;; ════════════════════════════════════════════════════════════════════
;; LAYER + DRAWING SETUP
;; ════════════════════════════════════════════════════════════════════

(defun SETUP-DOC ()
  ;; Force metric measurement system
  (setvar "MEASUREMENT" 1)
  ;; Units: decimal mm
  (setvar "INSUNITS" 4)
  (setvar "LUNITS"   2)
  (setvar "LUPREC"   4)
  ;; Limits: A3
  (setvar "LIMMIN" '(0.0 0.0))
  (setvar "LIMMAX" '(420.0 297.0))
  ;; Create layers colour 7
  (foreach n (list "BORDER" "INSTRUMENT" "WIRING"
                   "FERRULE" "CABLE" "JB" "TITLEBLOCK")
    (command "_.LAYER" "_M" n "_C" "7" n ""))
  ;; Zoom to A3
  (command "_.ZOOM" "_W" "0,0" "420,297"))

(defun SL (n) (command "_.LAYER" "_S" n ""))

;; ════════════════════════════════════════════════════════════════════
;; DRAWING PRIMITIVES
;; ════════════════════════════════════════════════════════════════════

(defun DTXT (layer str pos h)
  (SL layer)
  (command "_.TEXT" "_J" "_MC" pos h 0 str))

(defun DLINE (layer p1 p2)
  (SL layer)
  (command "_.LINE" p1 p2 ""))

(defun DRECT (layer p1 p2)
  (SL layer)
  (command "_.RECTANG" p1 p2))

;; ════════════════════════════════════════════════════════════════════
;; SHEET BORDER + TITLE BLOCK
;; ════════════════════════════════════════════════════════════════════

(defun DRAW-SHEET ()
  ;; Outer border
  (DRECT "BORDER" (G 5.0 5.0) (G 415.0 292.0))
  ;; Title block outer box
  (DRECT "TITLEBLOCK" (G 5.0 5.0) (G 415.0 25.0))
  ;; Vertical dividers
  (DLINE "TITLEBLOCK" (G  80.0 5.0) (G  80.0 25.0))
  (DLINE "TITLEBLOCK" (G 230.0 5.0) (G 230.0 25.0))
  (DLINE "TITLEBLOCK" (G 320.0 5.0) (G 320.0 25.0))
  (DLINE "TITLEBLOCK" (G 360.0 5.0) (G 360.0 25.0))
  ;; Static labels
  (DTXT "TITLEBLOCK" "LOOP NO."        (G  42.0 TB-LBL) TH-S)
  (DTXT "TITLEBLOCK" "TITLE / SERVICE" (G 155.0 TB-LBL) TH-S)
  (DTXT "TITLEBLOCK" "DRG NO."         (G 275.0 TB-LBL) TH-S)
  (DTXT "TITLEBLOCK" "REV"             (G 340.0 TB-LBL) TH-S)
  (DTXT "TITLEBLOCK" "SHEET"           (G 387.0 TB-LBL) TH-S))

;; ════════════════════════════════════════════════════════════════════
;; LOOP DRAWING ELEMENTS
;; ════════════════════════════════════════════════════════════════════

(defun DRAW-BUBBLE (tag sig / dp fs ns)
  (SL "INSTRUMENT")
  (command "_.CIRCLE" (G BX BY) BR)
  (if (= sig "4-20mA")
    (DLINE "INSTRUMENT" (G (- BX BR) BY) (G (+ BX BR) BY)))
  (setq dp (vl-string-search "-" tag))
  (if dp
    (progn (setq fs (substr tag 1 dp))
           (setq ns (substr tag (+ dp 2))))
    (progn (setq fs tag) (setq ns "")))
  (if (= sig "4-20mA")
    (progn (DTXT "INSTRUMENT" fs (G BX (+ BY 3.0)) TH-L)
           (DTXT "INSTRUMENT" ns (G BX (- BY 3.0)) TH-L))
    (progn (DTXT "INSTRUMENT" fs (G BX (+ BY 2.5)) TH-L)
           (DTXT "INSTRUMENT" ns (G BX (- BY 2.5)) TH-L))))

(defun DRAW-TERM (sig / n labs ytop ybot i lbl yc xm)
  (setq n    (if (= sig "4-20mA") 2 3)
        labs (if (= sig "4-20mA") (list "+" "-") (list "1" "2" "3"))
        ytop (if (= sig "4-20mA") (+ BY TCH) (+ BY (* 1.5 TCH)))
        ybot (if (= sig "4-20mA") (- BY TCH) (- BY (* 1.5 TCH)))
        xm   (/ (+ TX1 TX2) 2.0))
  (DRECT "INSTRUMENT" (G TX1 ybot) (G TX2 ytop))
  (setq i 0)
  (foreach lbl labs
    (setq yc (- ytop (* TCH (+ i 0.5))))
    (if (< i (1- n))
      (DLINE "INSTRUMENT"
        (G TX1 (- ytop (* TCH (1+ i))))
        (G TX2 (- ytop (* TCH (1+ i))))))
    (DTXT "INSTRUMENT" lbl (G xm yc) TH-L)
    (setq i (1+ i))))

(defun DRAW-WIRES (sig fw1 fw2 fw3 / fl lx rx ys i y ft)
  (setq fl  (list fw1 fw2 fw3)
        lx  (+ WX1 (/ (- OX WX1) 2.0))
        rx  (+ OX  (/ (- WX2 OX) 2.0))
        ys  (if (= sig "4-20mA")
              (list (+ BY (/ TCH 2.0)) (- BY (/ TCH 2.0)))
              (list (+ BY TCH) BY (- BY TCH))))
  (setq i 0)
  (foreach y ys
    (DLINE "WIRING" (G WX1 y) (G WX2 y))
    (setq ft (FLD i fl))
    (if (> (strlen ft) 0)
      (progn (DTXT "FERRULE" ft (G lx (+ y 3.0)) TH-F)
             (DTXT "FERRULE" ft (G rx (+ y 3.0)) TH-F)))
    (setq i (1+ i))))

(defun DRAW-CABLE (sig cn cs / ry ytop ybot)
  (setq ry   (if (= sig "4-20mA") ORY2 ORY3)
        ytop (+ BY ry)
        ybot (- BY ry))
  (SL "CABLE")
  ;; Draw ellipse using explicit coordinate strings — avoids numeric parsing issues
  ;; ELLIPSE _C: centre, axis endpoint (right), other half-distance as number string
  (command "_.ELLIPSE"
           "_C"
           (strcat (rtos OX 2 4) "," (rtos BY 2 4))
           (strcat (rtos (+ OX ORX) 2 4) "," (rtos BY 2 4))
           (rtos ry 2 4))
  (DTXT "CABLE" cn (G OX (+ ytop 5.0)) TH-L)
  (DTXT "CABLE" cs (G OX (+ ytop 9.5)) TH-L))

(defun DRAW-JB (sig jb tb fw1 fw2 fw3 / n ytop ybot cx i yc tnums)
  (setq n     (if (= sig "4-20mA") 2 3)
        cx    (+ JX1 (/ JW 2.0))
        ytop  (if (= sig "4-20mA") (+ BY TCH) (+ BY (* 1.5 TCH)))
        ybot  (if (= sig "4-20mA") (- BY TCH) (- BY (* 1.5 TCH)))
        ;; Extract actual terminal numbers from ferrule labels
        tnums (list (TERMNO fw1) (TERMNO fw2) (TERMNO fw3)))
  (DTXT "JB" jb (G cx (+ ytop 10.0)) TH-L)
  (DTXT "JB" tb (G cx (+ ytop  5.0)) TH-L)
  (DRECT "JB" (G JX1 ybot) (G JX2 ytop))
  (setq i 0)
  (while (< i n)
    (setq yc  (- ytop (* TCH (+ i 0.5)))
          tno (nth i tnums))
    (if (< i (1- n))
      (DLINE "JB"
        (G JX1 (- ytop (* TCH (1+ i))))
        (G JX2 (- ytop (* TCH (1+ i))))))
    ;; Only draw if terminal number is valid
    (if (and tno (> (strlen tno) 0))
      (DTXT "JB" tno (G cx yc) TH-V))
    (setq i (1+ i))))

(defun DRAW-TB (tag svc drg rev sht)
  (DTXT "TITLEBLOCK" tag (G  42.0 TB-VAL) TH-V)
  (DTXT "TITLEBLOCK" svc (G 155.0 TB-VAL) TH-V)
  (DTXT "TITLEBLOCK" drg (G 275.0 TB-VAL) TH-V)
  (DTXT "TITLEBLOCK" rev (G 340.0 TB-VAL) TH-V)
  (DTXT "TITLEBLOCK" sht (G 387.0 TB-VAL) TH-V))

;; ════════════════════════════════════════════════════════════════════
;; DRAW ONE LOOP — new doc, draw, save, close
;; ════════════════════════════════════════════════════════════════════

(defun DRAW-ONE (tag sig svc jb tb cbl spc drg rev
                 fw1 fw2 fw3 sht out fmt)
  ;; New blank drawing — no template
  ;; acadiso.dwt = built-in metric template, every AutoCAD has it
  (command "_.NEW" "acadiso.dwt")
  (SETUP-DOC)
  ;; Set UNDO mark — reset point after each loop saved
  (command "_.UNDO" "_M")
  ;; Template already has border + title block labels
  (DRAW-BUBBLE tag sig)
  (DRAW-TERM   sig)
  (DRAW-WIRES  sig fw1 fw2 fw3)
  (DRAW-CABLE  sig cbl spc)
  (DRAW-JB     sig jb tb fw1 fw2 fw3)
  (DRAW-TB     tag svc drg rev sht)
  ;; Zoom to exact A3 window
  (command "_.ZOOM" "_W" "0,0" "420,297")
  ;; Save
  (command "_.SAVEAS" fmt out)
  ;; Reset drawing to template state for next loop
  ;; UNDO all entities drawn in this session (template entities are preserved)
  (command "_.UNDO" "_B"))

;; ════════════════════════════════════════════════════════════════════
;; MAIN COMMAND — DRAWLOOPS
;; ════════════════════════════════════════════════════════════════════

(defun c:DRAWLOOPS (/ f ln parts total sno fmt av
                     tag sig svc jb tb cbl spc drg rev
                     fw1 fw2 fw3 sht out)

  (if (not (findfile CSV-FILE))
    (progn (alert (strcat "CSV not found:\n" CSV-FILE)) (exit)))

  (vl-mkdir OUT-DIR)

  (setq total (COUNTROWS CSV-FILE))
  (if (= total 0) (progn (alert "No data rows in CSV.") (exit)))

  ;; Detect DWG format from AutoCAD version
  (setq av  (atof (getvar "ACADVER")))
  (setq fmt (if (>= av 21.0) "2018" "2010"))

  (princ (strcat "\n" (itoa total) " loops found.\n"))
  (princ (strcat "AutoCAD " (getvar "ACADVER") " | Format: " fmt "\n"))
  (princ (strcat "Output: " OUT-DIR "\n\n"))

  (setq f (open CSV-FILE "r") sno 0)
  (read-line f)  ; skip header
  (read-line f)  ; skip hint row

  (while (setq ln (read-line f))
    (setq ln (STRIPCR ln))
    (if (and (> (strlen ln) 2)
             (not (= (substr ln 1 3) "e.g")))
      (progn
        (setq parts (SPLITCSV ln)
              tag   (FLD CI-TAG  parts)
              sig   (FLD CI-SIG  parts)
              svc   (FLD CI-SVC  parts)
              jb    (FLD CI-JB   parts)
              tb    (FLD CI-TB   parts)
              cbl   (FLD CI-CBL  parts)
              spc   (FLD CI-SPC  parts)
              drg   (FLD CI-DRG  parts)
              rev   (FLD CI-REV  parts)
              fw1   (FLD CI-FW1  parts)
              fw2   (FLD CI-FW2  parts)
              fw3   (FLD CI-FW3  parts))

        (if (> (strlen tag) 0)
          (progn
            (setq sno (1+ sno)
                  sht (strcat (itoa sno) " of " (itoa total))
                  out (strcat OUT-DIR tag ".dwg"))
            (princ (strcat "[" (itoa sno) "/" (itoa total) "] " tag "\n"))
            (DRAW-ONE tag sig svc jb tb cbl spc drg rev
                      fw1 fw2 fw3 sht out fmt)
            (princ (strcat "  saved: " tag ".dwg\n")))))))

  (close f)
  (princ (strcat "\nDone! " (itoa sno) " drawings saved to:\n" OUT-DIR "\n"))
  (alert (strcat "Done! " (itoa sno) " loop drawings created.\n\n"
                 "To print all as PDF:\n"
                 "Type PUBLISH -> Add Sheets -> select all DWGs in OUTPUT folder"))
  (princ))

;; ── LOAD BANNER ──────────────────────────────────────────────────────
(princ "\n╔══════════════════════════════════════╗")
(princ "\n║  Loop Drawing Automation  v5.1       ║")
(princ (strcat "\n║  AutoCAD: " (getvar "ACADVER") "                 ║"))
(princ "\n║  Type DRAWLOOPS to start             ║")
(princ "\n╚══════════════════════════════════════╝\n")
(princ)
