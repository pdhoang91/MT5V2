# QUICK REFERENCE - BREAKOUT BOT H1

## ⚡ TÓM TẮT NHANH

```
CHIẾN LƯỢC: H/L Breakout + Dynamic S/R SL/TP
TIMEFRAME: H1
STYLE: Swing Trading (3-10 ngày)
TARGET: Major trend moves (1000+ pips)
```

---

## 📊 CONFIG HIỆN TẠI

| Parameter | Value | Ý Nghĩa |
|-----------|-------|---------|
| **Lot Size** | 0.1 | $1/pip XAUUSD |
| **Min SL** | 520 pips | $52 risk minimum |
| **Max SL** | 780 pips | $78 risk maximum |
| **R:R Ratio** | 1:3.5 | $52 risk → $182 profit |
| **H/L Period** | 60 bars | 60 giờ = 2.5 ngày |
| **Breakout Distance** | 80 pips | Confirmation threshold |
| **Min Swing Dist** | 130 pips | Major S/R spacing |
| **MA Period** | EMA 40 | Trend filter |

---

## 🔄 FLOW 1 CÂY NẾN H1

```
1. New H1 Bar Opens
   ↓
2. Update S/R Levels (Pivots + Swings)
   ↓
3. Check: Có position? → YES → Skip | NO → Continue
   ↓
4. Delete ALL old pending orders
   ↓
5. Calculate HH (60 bars), LL (60 bars)
   ↓
6. Get EMA 40 value
   ↓
7. Place NEW orders:
   - BuyStop: HH + 80 pips (if HH > EMA40)
   - SellStop: LL - 80 pips (if LL < EMA40)
   ↓
8. Wait for next bar
```

---

## 💰 VÍ DỤ GIAO DỊCH

### BUY Example
```
HH: 2780.00 (60 bars)
EMA40: 2750.00
✓ 2780 > 2750 → Place BuyStop

Entry: 2780 + 8 = 2788.00
Nearest Support: 2730.00 (Pivot S1)
SL Distance: 58.00 = 580 pips

SL: 2730.00 (580 pips = $58 risk)
TP: 2788 + (58 × 3.5) = 2991.00 (2030 pips = $203 profit)

Order: BuyStop @ 2788, SL: 2730, TP: 2991
```

### SELL Example
```
LL: 2710.00 (60 bars)
EMA40: 2750.00
✓ 2710 < 2750 → Place SellStop

Entry: 2710 - 8 = 2702.00
Nearest Resistance: 2780.00 (Pivot R1)
SL Distance: 78.00 = 780 pips

SL: 2780.00 (780 pips = $78 risk)
TP: 2702 - (78 × 3.5) = 2429.00 (2730 pips = $273 profit)

Order: SellStop @ 2702, SL: 2780, TP: 2429
```

---

## 📈 EXPECTED PERFORMANCE

```
Trades/Month: 6-12
Win Rate: 35-45%
Profit Factor: 2.0-3.0

Example (10 trades):
4 wins × $200 = +$800
6 losses × -$65 = -$390
Net: +$410 profit (41% monthly return)
```

---

## ⚠️ RISK PER TRADE

| Account Size | Risk % | Safe? |
|--------------|--------|-------|
| $10,000 | 0.52-0.78% | ✅ Conservative |
| $5,000 | 1.04-1.56% | ⚠️ Moderate |
| $1,000 | 5.2-7.8% | ❌ Aggressive |

**Recommended:** $10,000+ account

---

## 🎯 KHI NÀO ORDER TRIGGER?

### BuyStop Triggers When:
```
Price reaches: HH + 80 pips
→ Buy automatically at that price
→ SellStop auto-deleted
→ Position held until TP/SL
```

### SellStop Triggers When:
```
Price reaches: LL - 80 pips
→ Sell automatically at that price
→ BuyStop auto-deleted
→ Position held until TP/SL
```

### Both Orders Pending:
```
Price between: (LL - 80) and (HH + 80)
→ Consolidation zone
→ Waiting for breakout
→ Orders refreshed every H1 bar
```

---

## 📊 S/R DETECTION

### Pivot Points (Daily)
```
Yesterday:
High: 2680
Low: 2640
Close: 2665

Today:
Pivot: 2661.67
R1: 2683.34
R2: 2701.67
S1: 2643.34
S2: 2621.67
```

### Swing High/Low
```
Scan 60 bars:
- Find peaks/troughs with 3 bars confirmation
- Must be >130 pips apart
- Mark as major S/R levels

Example:
Swing High 1: 2820.00
Swing High 2: 2950.00 (130+ pips away ✓)
Swing Low 1: 2680.00
Swing Low 2: 2550.00 (130+ pips away ✓)
```

---

## 🔍 DASHBOARD METRICS

```
⚡ BREAKOUT H1
├── Balance: $10,000
├── Equity: $10,150
├── Profit: +$150
├── Position: 1/1 (BUY active)
├── Symbol: XAUUSD
├── Status: ● ACTIVE
├── Trades: 8
├── Wins: 3 | Loss: 5
├── Win Rate: 37.5%
└── P/L: +$340
```

**Giải thích:**
- Win rate 37.5% vẫn profitable (R:R 1:3.5)
- 3 wins × $200 = $600
- 5 losses × $65 = -$325
- Net: +$275 (thực tế +$340 do TP lớn hơn dự kiến)

---

## ⚙️ CONFIG TIPS

### More Conservative (Giảm risk):
```
Min SL: 600 → 650 pips
Max SL: 800 → 900 pips
Lot: 0.1 → 0.05
Breakout Distance: 80 → 100 pips
```

### More Aggressive (Tăng frequency):
```
H/L Period: 60 → 40 bars
Min SL: 520 → 400 pips
MA Period: 40 → 30
R:R: 3.5 → 3.0
```

### Longer-Term (Hold weeks):
```
H/L Period: 60 → 100 bars
Min SL: 520 → 800 pips
Max SL: 780 → 1200 pips
R:R: 3.5 → 4.0
```

---

## 📝 DAILY CHECKLIST

### Morning (Before Market):
- [ ] Check dashboard status
- [ ] Review pending orders (should be 2 max)
- [ ] Verify SL/TP levels
- [ ] Check account balance

### During Day:
- [ ] Monitor position (if any)
- [ ] Don't touch orders manually
- [ ] Let bot manage everything

### Evening (After Close):
- [ ] Review log file
- [ ] Check trades executed
- [ ] Update performance spreadsheet

---

## 🆘 TROUBLESHOOTING

### No Orders Placed:
```
1. Check: Có position không? (Max 1)
2. Check: HH > EMA40? (for Buy)
3. Check: LL < EMA40? (for Sell)
4. Check: S/R detected? (min 3 levels)
```

### Order Triggered but Hit SL:
```
Normal! Expected 55-65% loss rate
Key: Losses small ($52-78), Wins big ($182-273)
Long-term: Win rate 35-45% = profitable
```

### Too Many Losses Consecutively:
```
If 8+ losses in a row:
1. Check market regime (ranging vs trending)
2. Consider pause trading
3. Review H/L period (increase to 80-100)
4. Tighten MA filter
```

---

## 🎓 KEY CONCEPTS

### Tại sao 60 bars?
```
60 giờ = 2.5 ngày
→ Capture consolidation before major move
→ Not too short (noise)
→ Not too long (miss moves)
```

### Tại sao 80 pips breakout?
```
Confirmation threshold
→ Avoid false breakouts
→ Still good entry price
→ Balance between safety and entry quality
```

### Tại sao SL 520-780 pips?
```
XAUUSD major S/R spacing: 400-800 pips
→ SL at S/R = logical exit
→ Not random SL
→ Market structure-based
```

### Tại sao R:R 1:3.5?
```
With wide SL (520-780), need big TP
→ Win 35% × 3.5 = 1.225
→ Loss 65% × 1 = 0.65
→ Net: +0.575 (57.5% return)
```

---

## 📞 SUPPORT FILES

1. **BOT_MECHANISM_EXPLAINED.md** - Chi tiết đầy đủ
2. **BreakoutBot.mq5** - Source code
3. **Breakout_Bot_H1.txt** - Log file (in MQL5/Files/)

---

**Quick Ref v1.0 - Breakout Bot H1 Swing Trading Strategy**

