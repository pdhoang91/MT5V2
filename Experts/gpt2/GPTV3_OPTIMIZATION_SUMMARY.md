# GPTv3 Simple Breakout Strategy

## 🎯 **CHIẾN LƯỢC BREAKOUT ĐƠN GIẢN**

### **1. Tham Số Chiến Lược**
- **HL_period**: 20 (tìm HH/LL trong 20 nến)
- **distance**: 150 pips (khoảng cách từ HH/LL)
- **TP**: 700 pips (take profit)
- **SL**: 400 pips (stop loss)
- **MA_period**: 50 (Moving Average 50)
- **TrailingStop**: 200 pips
- **TrailingStep**: 50 pips

### **2. Logic Giao Dịch Đơn Giản**
**BUY Signal:**
```mql5
if(HH > MA_Slow[1]) {
    double entryprice = HH + ExtDistance;
    trade.BuyStop(Lot_size, entryprice, Symbol(), sl, tp, ORDER_TIME_GTC);
}
```

**SELL Signal:**
```mql5
if(LL < MA_Slow[1]) {
    double entryprice = LL - ExtDistance;
    trade.SellStop(Lot_size, entryprice, Symbol(), sl, tp, ORDER_TIME_GTC);
}
```

### **3. Giao Dịch 24/7**
- **No Time Filter**: EA giao dịch liên tục 24/7
- **No Cooldown**: Không có khoảng cách thời gian giữa các lệnh
- **Simple Logic**: Chỉ dựa vào HH/LL vs MA

### **4. Không Có Filter Phức Tạp**
- **No RSI Filter**: Không sử dụng RSI
- **No Volume Filter**: Không kiểm tra volume
- **No News Filter**: Không tránh tin tức
- **Pure Breakout**: Chỉ dựa vào breakout thuần túy

### **5. Quản Lý Lệnh Chờ Đơn Giản**
```mql5
// Xóa tất cả lệnh chờ cho symbol này
for(int i = OrdersTotal() - 1; i >= 0; i--) {
    if(OrderGetString(ORDER_SYMBOL) == Symbol()) {
        trade.OrderDelete(orderTicket);
    }
}
```

### **6. Risk Management**
- **Risk/Reward Ratio**: 1:1.75 (SL 400, TP 700)
- **Trailing Stop**: Tự động bảo vệ lợi nhuận
- **Simple Logic**: Không có filter phức tạp

## 📊 **KẾT QUẢ DỰ KIẾN**

### **Simple Breakout Strategy:**
- ✅ Logic đơn giản, dễ hiểu
- ✅ Tỷ lệ thực hiện lệnh: 20-30%
- ✅ Risk/Reward: 1:1.75 (SL 400, TP 700)
- ✅ Giao dịch 24/7 không giới hạn
- ✅ Win rate dự kiến: 40-50%
- ✅ Drawdown tối đa: < 15%

## 🚀 **TÍNH NĂNG MỚI**

### **1. Logic Giao Dịch Thuần Túy**
```mql5
// BUY: HH > MA
if(HH > MA_Slow[1]) {
    double entryprice = HH + ExtDistance;
    trade.BuyStop(Lot_size, entryprice, Symbol(), sl, tp, ORDER_TIME_GTC);
}

// SELL: LL < MA  
if(LL < MA_Slow[1]) {
    double entryprice = LL - ExtDistance;
    trade.SellStop(Lot_size, entryprice, Symbol(), sl, tp, ORDER_TIME_GTC);
}
```

### **2. Quản Lý Lệnh Đơn Giản**
```mql5
// Xóa tất cả lệnh chờ
for(int i = OrdersTotal() - 1; i >= 0; i--) {
    if(OrderGetString(ORDER_SYMBOL) == Symbol()) {
        trade.OrderDelete(orderTicket);
    }
}
```

## 📈 **HƯỚNG DẪN SỬ DỤNG**

### **1. Backtest**
- Chạy backtest với dữ liệu ít nhất 3 tháng
- Kiểm tra win rate, profit factor, max drawdown
- So sánh với chiến lược cũ

### **2. Demo Trading**
- Chạy demo ít nhất 1 tháng
- Theo dõi hiệu suất real-time
- Điều chỉnh tham số nếu cần

### **3. Live Trading**
- Bắt đầu với lot size nhỏ
- Tăng dần khi hiệu suất ổn định
- Luôn theo dõi và quản lý rủi ro

## ⚠️ **LƯU Ý QUAN TRỌNG**

1. **Luôn backtest trước khi live**
2. **Bắt đầu với lot size nhỏ**
3. **Theo dõi hiệu suất thường xuyên**
4. **Điều chỉnh tham số theo thị trường**
5. **Không bao giờ risk quá 2% account mỗi lệnh**

## 🎯 **MỤC TIÊU HIỆU SUẤT**

- **Win Rate**: 40-50%
- **Profit Factor**: > 1.2
- **Max Drawdown**: < 15%
- **Monthly Return**: 5-12%
- **Risk/Reward**: 1:1.75
- **Simple Logic**: Dễ hiểu và maintain

---
*Đơn giản hóa hoàn thành vào: $(date)*
*Phiên bản: GPTv3 Simple Breakout*
