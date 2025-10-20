# VISUAL GUIDE - BREAKOUT BOT H1

## 📊 PRICE ACTION DIAGRAM

### Scenario 1: Uptrend Breakout (BUY)

```
                                 TP: 2991 ↑ (+2030 pips = $203)
                                      │
                                      │
                                      │
                                      ▲
                       ┌──────────────┼──────────────┐
                       │              │              │
    EMA40: 2750 ─ ─ ─ ┼── ─ ─ ─ ─ ─ ┼ ─ ─ ─ ─ ─ ─ ┼ ─ ─ ─ ─
                       │              │              │
                       │    HH: 2780  ▲              │
                       │              │              │
                       │      ╔═══════╪══════════╗   │
                       │      ║       │          ║   │
         Consolidation │      ║   Entry: 2788   ║   │ Breakout
         (60 bars)     │      ║   (HH + 80)     ║   │ Move
                       │      ║       │          ║   │
                       │      ╚═══════╪══════════╝   │
                       │              │              │
     Pivot S1: 2730 ───┼──────────────●──────────────┼────
                       │              │              │
                       │              ▼              │
                       │         SL: 2730            │
                       │        (-58 pips = -$58)    │
                       └──────────────────────────────┘

Timeline: ───────●────────●────────●────────●────────●───────→
              Day 0    Day 1    Day 2    Day 3    Day 5   Day 7
              Entry  +$20     +$45     +$80     +$140   TP HIT!

Result: +$203 profit, R:R 1:3.5, Hold 7 days
```

---

### Scenario 2: Downtrend Breakout (SELL)

```
                                SL: 2780 ↑ (-78 pips = -$78)
                                      │
                                      ▲
         Pivot R1: 2780 ──────────────●──────────────────────
                                      │
                       ┌──────────────┼──────────────┐
                       │              │              │
    EMA40: 2750 ─ ─ ─ ┼── ─ ─ ─ ─ ─ ┼ ─ ─ ─ ─ ─ ─ ┼ ─ ─ ─ ─
                       │              │              │
                       │              │              │
                       │      ╔═══════╪══════════╗   │
         Consolidation │      ║       │          ║   │
         (60 bars)     │      ║   Entry: 2702   ║   │ Breakout
                       │      ║   (LL - 80)     ║   │ Move
                       │      ║       │          ║   │
                       │      ╚═══════╪══════════╝   │
                       │              ▼              │
                       │      LL: 2710               │
                       └──────────────┼──────────────┘
                                      │
                                      │
                                      │
                                      ▼
                                 TP: 2429 ↓ (+2730 pips = $273)

Timeline: ───────●────────●────────●────────●────────────●──────→
              Day 0    Day 1    Day 2    Day 3       Day 10  TP!
              Entry  +$30     +$60     +$110        TP HIT!

Result: +$273 profit, R:R 1:3.5, Hold 10 days
```

---

## 🔄 ORDER LIFECYCLE

### Hour 0: New H1 Bar Opens
```
┌─────────────────────────────────────────────────────┐
│  BOT WAKES UP                                       │
│  - Calculate S/R levels                             │
│  - Get HH/LL (60 bars)                              │
│  - Check EMA40                                      │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  Has Position?       │
        └──────┬───────────────┘
               │
         ┌─────┴─────┐
         │YES        │NO
         ▼           ▼
    ┌───────┐   ┌──────────────────────┐
    │ SKIP  │   │ Delete Old Orders    │
    └───────┘   │ (BuyStop + SellStop) │
                └──────────┬─────────────┘
                           │
                           ▼
                ┌──────────────────────────┐
                │ Calculate New Orders     │
                │ - BuyStop: HH + 80       │
                │ - SellStop: LL - 80      │
                │ - SL at S/R (520-780)    │
                │ - TP = SL × 3.5          │
                └──────────┬───────────────┘
                           │
                           ▼
                ┌──────────────────────────┐
                │ Place 2 Pending Orders   │
                │ ✓ 1 BuyStop              │
                │ ✓ 1 SellStop             │
                └──────────────────────────┘
```

### Hour 1-59: Waiting for Trigger
```
Price Action: ────●────●────●────────●────●────●──────→
              2700 2710 2720      2730 2740 2750

Pending Orders:
BuyStop @ 2788: 🟡 Waiting... (price below)
SellStop @ 2702: 🟡 Waiting... (price above)

Status: Both orders active, monitoring price
```

### Hour 60: Price Breaks Up
```
Price: 2788 (BuyStop triggered!)

Action:
1. BuyStop → BUY position opened ✓
2. SellStop → AUTO-DELETED
3. Bot manages position until TP/SL

Position:
Entry: 2788.00
SL: 2730.00 (58 pips = $58)
TP: 2991.00 (203 pips = $203)
Status: 🟢 ACTIVE

New H1 Bar:
- No new orders (HasPosition = true)
- Bot waits for TP/SL hit
```

---

## 📈 S/R DETECTION VISUAL

### Pivot Points (Daily Calculation)
```
Yesterday's Data:
High:  2680 ────────────────┐
                            │
Close: 2665 ────────────┐   │
                        │   │
Low:   2640 ────────┐   │   │
                    │   │   │
                    ▼   ▼   ▼
        Pivot = (H + L + C) / 3 = 2661.67

Today's Levels:
R2: 2701.67 ═══════════════════════════
R1: 2683.34 ───────────────────────────
P:  2661.67 ═══════════════════════════ (Main Pivot)
S1: 2643.34 ───────────────────────────
S2: 2621.67 ═══════════════════════════

Usage:
- Price near P → Neutral zone
- Price > P → Bullish bias
- Price < P → Bearish bias
- R1/S1 → First targets
- R2/S2 → Extended targets
```

### Swing High/Low Detection (60 bars H1)
```
Price Chart (60 bars):

2820 ─┐         ┌─── Swing High 1 (bar 15)
      │         │
2790 ─┼──────┐  │  ┌─ Swing High 2 (bar 45)
      │      │  │  │
2760 ─┤      └──┘  │
      │            │
2730 ─┤            └─── Range: 30 pips
      │                 → TOO CLOSE
2700 ─┤                 → Keep only highest (2820)
      │
2670 ─┤  ┌───────────── Swing Low 1 (bar 25)
      │  │
2640 ─┘  │  ┌────────── Swing Low 2 (bar 50)
         │  │
         └──┘  Range: 30 pips
               → TOO CLOSE (< 130 pips)
               → Keep only lowest (2640)

Result:
Valid S/R Levels:
- Swing High: 2820
- Swing Low: 2640
Distance: 180 pips ✓ (> 130 min)
```

---

## 🎯 DYNAMIC SL/TP CALCULATION

### BUY Example: Step by Step

```
Step 1: Entry Calculation
────────────────────────────
HH (60 bars): 2780.00
Breakout Distance: +8.00 (80 pips)
Entry: 2780 + 8 = 2788.00

Step 2: Find Support for SL
────────────────────────────
S/R Levels Below Entry:
│
├─ Pivot S1: 2750.00 (38 pips away) ← Nearest
├─ Swing Low: 2730.00 (58 pips away)
└─ Pivot S2: 2700.00 (88 pips away)

Selected: 2730.00 (58 pips = 580 pips)

Step 3: Validate SL Range
────────────────────────────
SL Distance: 580 pips
Min SL: 520 pips ✓
Max SL: 780 pips ✓
→ WITHIN RANGE, use 2730.00

Step 4: Calculate TP (R:R 1:3.5)
────────────────────────────
SL Distance: 58.00
TP Distance: 58 × 3.5 = 203.00
TP: 2788 + 203 = 2991.00 (2030 pips)

Step 5: Check Next Resistance
────────────────────────────
Resistances Above Entry:
│
├─ Swing High: 2950.00 (162 pips)
├─ Pivot R1: 3000.00 (212 pips)
└─ Pivot R2: 3050.00 (262 pips)

Calculated TP: 2991.00 (203 pips)
→ Between Swing High and R1
→ Good target, keep it

Final Order:
────────────────────────────
BuyStop @ 2788.00
SL: 2730.00 (580 pips = $58 risk)
TP: 2991.00 (2030 pips = $203 profit)
R:R: 1:3.5
```

---

## 🔍 EMA40 FILTER VISUAL

### Uptrend (HH > EMA40)
```
2850 ─┐
      │ ╱
2800 ─┤╱  HH: 2820 ✓
      │   (above EMA)
2750 ─│╱────────── EMA40: 2780
      ╱│
2700─╱ │
    ╱  │
2650   └─ LL: 2690
           (also above EMA)

Decision:
HH (2820) > EMA40 (2780)? YES → Place BuyStop ✓
LL (2690) < EMA40 (2780)? NO  → Skip SellStop ✗

Result: Only BuyStop placed (trend confirmation)
```

### Downtrend (LL < EMA40)
```
2800 ─┐ HH: 2780
      │    (above EMA)
2750 ─│╲────────── EMA40: 2740
      │ ╲
2700 ─┤  ╲ LL: 2680 ✓
      │   ╲(below EMA)
2650 ─┤    ╲
      │     ╲
2600 ─┘

Decision:
HH (2780) > EMA40 (2740)? YES → Place BuyStop ✓
LL (2680) < EMA40 (2740)? YES → Place SellStop ✓

Result: Both orders placed (range-bound)
```

---

## 📊 TRADE PROGRESSION TIMELINE

### Winning Trade Example

```
Day 0 (Entry):
════════════════════════════════════════════════
Price: 2788 → BuyStop triggered
Position: LONG 0.1 lot
Risk: $58 | Target: $203
P/L: $0

Chart:
2990 ─────────────────────────── TP
2850 ─┐
2788 ─● ← Entry
2730 ─────────────────────────── SL
2700 ─┘


Day 1 (+$20):
════════════════════════════════════════════════
Price: 2808 (+20 pips)
P/L: +$20 (10% of TP)

Chart:
2990 ─────────────────────────── TP
2850 ─┐
2808 ─● ← Current
2788 ─○ ← Entry
2730 ─────────────────────────── SL
2700 ─┘


Day 3 (+$80):
════════════════════════════════════════════════
Price: 2868 (+80 pips)
P/L: +$80 (39% of TP)

Chart:
2990 ─────────────────────────── TP
2868 ─● ← Current
2850 ─┤
2788 ─○ ← Entry
2730 ─────────────────────────── SL


Day 7 (TP HIT!):
════════════════════════════════════════════════
Price: 2991 (+203 pips)
Position: CLOSED
Final P/L: +$203 💰

Chart:
2991 ─● ← Exit (TP)
2850 ─┤
2788 ─○ ← Entry
2730 ─────────────────────────── SL

Duration: 7 days
Return: 3.5× risk
Win: +$203
```

### Losing Trade Example

```
Day 0 (Entry):
════════════════════════════════════════════════
Price: 2702 → SellStop triggered
Position: SHORT 0.1 lot
Risk: $78 | Target: $273
P/L: $0

Chart:
2780 ─────────────────────────── SL
2740 ─┐
2702 ─● ← Entry
2650 ─┘
2429 ─────────────────────────── TP


Day 1 (+$30):
════════════════════════════════════════════════
Price: 2672 (-30 pips, moving favorably)
P/L: +$30 (11% of TP)

Chart:
2780 ─────────────────────────── SL
2740 ─┐
2702 ─○ ← Entry
2672 ─● ← Current
2650 ─┘
2429 ─────────────────────────── TP


Day 3 (Reversal):
════════════════════════════════════════════════
Price: 2740 (+38 pips, against us)
P/L: -$38 (49% of risk used)

Chart:
2780 ─────────────────────────── SL
2740 ─● ← Current (danger!)
2702 ─○ ← Entry
2650 ─┘
2429 ─────────────────────────── TP


Day 4 (SL HIT):
════════════════════════════════════════════════
Price: 2780 (+78 pips)
Position: CLOSED (Stop Loss)
Final P/L: -$78 🛑

Chart:
2780 ─● ← Exit (SL)
2740 ─┤
2702 ─○ ← Entry
2429 ─────────────────────────── TP

Duration: 4 days
Result: Loss
Loss: -$78
```

---

## 🎲 PROBABILITY DISTRIBUTION

### Expected Results (100 Trades)

```
Win Rate: 40% (40 wins, 60 losses)

Wins (40 trades):
│
│  ████████████████████ $200 avg
│  ████████████████████
│  ████████████████████
│  ████████████████████
└──────────────────────────────────→
   Total: 40 × $200 = +$8,000

Losses (60 trades):
│
│  ██████ $65 avg
│  ██████
│  ██████
│  ██████
│  ██████
│  ██████
└──────────────────────────────────→
   Total: 60 × -$65 = -$3,900

Net Result:
+$8,000 - $3,900 = +$4,100
Return: 41% (on $10,000 account)

Profit Factor: 8000 / 3900 = 2.05
```

---

## 🔄 ORDER REFRESH MECHANISM

### Every New H1 Bar:

```
Bar 1 (15:00):
═══════════════════════════════════════════════
Create:
- BuyStop @ 2788 (HH + 80)
- SellStop @ 2702 (LL - 80)

Status: 2 orders active


Bar 2 (16:00):
═══════════════════════════════════════════════
Action:
1. Delete old BuyStop @ 2788
2. Delete old SellStop @ 2702
3. Recalculate HH/LL (new 60-bar window)
4. Create NEW orders:
   - BuyStop @ 2790 (new HH + 80)
   - SellStop @ 2705 (new LL - 80)

Status: 2 NEW orders, old ones gone


Bar 3 (17:00):
═══════════════════════════════════════════════
One order triggered! (BuyStop @ 2790)

Action:
1. Position opened: BUY
2. SellStop @ 2705 → AUTO-DELETED
3. No new orders (HasPosition = true)

Status: 1 position, 0 pending orders

Continue until TP/SL hit...
```

---

**VISUAL GUIDE v1.0 - Understanding Breakout Bot Through Diagrams**

*Tham khảo BOT_MECHANISM_EXPLAINED.md để giải thích chi tiết văn bản.*

