//+------------------------------------------------------------------+
//|                                              BreakoutBot.mq5     |
//|                  H1 Breakout Trading Bot - Dynamic SL/TP         |
//|                                 Version 2.0                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

#include "Includes/SRDetection.mqh"
#include "Includes/SignalFilters.mqh"
#include "Includes/TradeLogger.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// === General Settings ===
input group "=== General Settings ==="
input string   InpSymbol = "XAUUSD";                           // Symbol to trade
input double   InpLotSize = 0.1;                              // Lot size
input ulong    InpMagicNumber = 888999;                        // Magic number

// === Risk Management (Dynamic SL/TP) ===
input group "=== Risk Management ==="
input int      InpMinSLPips = 520;                              // Min Stop Loss (pips)
input int      InpMaxSLPips = 780;                              // Max Stop Loss (pips)
input double   InpRiskRewardRatio = 3.5;                       // Risk:Reward Ratio (1:2.5)

// === Breakout Settings ===
input group "=== Breakout Settings ==="
input int      InpHLPeriod = 60;                               // H/L lookback (bars)
input double   InpBreakoutDistance = 80;                       // Entry distance from H/L (pips)

// === S/R Detection ===
input group "=== S/R Detection ==="
input bool     InpUsePivotPoints = true;                       // Use Pivot Points
input bool     InpUseSwingPoints = true;                       // Use Swing High/Low
input int      InpSwingLookback = 50;                          // Swing lookback (bars)
input int      InpSwingStrength = 3;                           // Swing strength
input int      InpMinSwingDistance = 130;                       // Min swing distance (pips)

// === Moving Average Filter ===
input group "=== MA Filter ==="
input bool     InpUseMA = true;                                // Use MA filter
input int      InpMAPeriod = 40;                               // MA Period
input ENUM_MA_METHOD InpMAMethod = MODE_EMA;                   // MA Method

// === Dashboard & Logging ===
input group "=== Dashboard & Logging ==="
input bool     InpEnableDashboard = true;                      // Show dashboard
input bool     InpEnableLogging = true;                        // Enable logging
input string   InpLogFileName = "BreakoutBot_H1.txt";          // Log file name

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade         g_trade;
CPositionInfo  g_position;
CSymbolInfo    g_symbol;
CAccountInfo   g_account;

// Modules
CSRDetection   g_sr;
CTradeLogger   g_logger;

// Timeframe
const ENUM_TIMEFRAMES TIMEFRAME = PERIOD_H1;

// Calculated values
double         g_point;
double         g_min_sl;
double         g_max_sl;
double         g_breakout_distance;

// State
datetime       g_last_bar_time = 0;
datetime       g_last_dashboard_update = 0;
bool           g_dashboard_created = false;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== Breakout Bot H1 v2.0 - Initializing ===");
   
   if(!InitializeSymbol()) return INIT_FAILED;
   if(!InitializeModules()) return INIT_FAILED;
   
   CalculateParameters();
   
   if(InpEnableDashboard) CreateDashboard();
   
   Print("=== Initialization Complete ===");
   Print("  Symbol: ", InpSymbol);
   Print("  Timeframe: H1");
   Print("  SL Range: ", InpMinSLPips, "-", InpMaxSLPips, " pips");
   Print("  R:R Ratio: 1:", DoubleToString(InpRiskRewardRatio, 1));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_logger.LogMessage("Bot stopped. Reason: " + IntegerToString(reason));
   g_logger.Deinit();
   
   DeleteAllPendingOrders();
   
   if(InpEnableDashboard) DeleteDashboard();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime current_bar = iTime(InpSymbol, TIMEFRAME, 0);
   
   if(current_bar != g_last_bar_time)
   {
      g_last_bar_time = current_bar;
      OnNewBar();
   }
   
   if(InpEnableDashboard && TimeCurrent() - g_last_dashboard_update > 10)
   {
      UpdateDashboard();
      g_last_dashboard_update = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| New bar handler                                                   |
//+------------------------------------------------------------------+
void OnNewBar()
{
   // Update S/R levels
   g_sr.Update();
   g_sr.DrawLevels();
   
   // Check if we have position or pending orders
   if(HasPosition()) return;
   
   // Clean old pending orders first
   DeleteAllPendingOrders();
   
   // Place new pending orders (1 Buy + 1 Sell)
   PlacePendingOrders();
}

//+------------------------------------------------------------------+
//| Initialize symbol                                                 |
//+------------------------------------------------------------------+
bool InitializeSymbol()
{
   if(!g_symbol.Name(InpSymbol))
   {
      Print("ERROR: Invalid symbol: ", InpSymbol);
      return false;
   }
   
   g_symbol.RefreshRates();
   return true;
}

//+------------------------------------------------------------------+
//| Initialize modules                                                |
//+------------------------------------------------------------------+
bool InitializeModules()
{
   // S/R Detection
   if(!g_sr.Init(InpSymbol, TIMEFRAME, InpUsePivotPoints, InpUseSwingPoints,
                 InpSwingLookback, InpSwingStrength, InpMinSwingDistance))
   {
      Print("ERROR: Failed to initialize S/R detection");
      return false;
   }
   
   // Logger
   if(!g_logger.Init(InpLogFileName, InpEnableLogging))
   {
      Print("WARNING: Logger initialization failed");
   }
   
   g_logger.LogMessage("Bot initialized - H1 Breakout Strategy");
   g_logger.LogMessage("Dynamic SL/TP: " + IntegerToString(InpMinSLPips) + "-" + 
                       IntegerToString(InpMaxSLPips) + " pips | R:R=1:" + 
                       DoubleToString(InpRiskRewardRatio, 1));
   
   // Trade
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetMarginMode();
   g_trade.SetDeviationInPoints(30);
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate parameters                                              |
//+------------------------------------------------------------------+
void CalculateParameters()
{
   int digits_adjust = (g_symbol.Digits() == 3 || g_symbol.Digits() == 5) ? 10 : 1;
   g_point = g_symbol.Point() * digits_adjust;
   
   g_min_sl = InpMinSLPips * g_point;
   g_max_sl = InpMaxSLPips * g_point;
   g_breakout_distance = InpBreakoutDistance * g_point;
}

//+------------------------------------------------------------------+
//| Check if we have position                                         |
//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_position.SelectByIndex(i))
      {
         if(g_position.Symbol() == InpSymbol && g_position.Magic() == InpMagicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if we have pending orders                                   |
//+------------------------------------------------------------------+
bool HasPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetString(ORDER_SYMBOL) == InpSymbol && 
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                         |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetString(ORDER_SYMBOL) == InpSymbol && 
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            g_trade.OrderDelete(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Place pending orders                                              |
//+------------------------------------------------------------------+
void PlacePendingOrders()
{
   // Get H/L data
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(InpSymbol, TIMEFRAME, 1, InpHLPeriod, high) <= 0) return;
   if(CopyLow(InpSymbol, TIMEFRAME, 1, InpHLPeriod, low) <= 0) return;
   
   double HH = ArrayMaximum(high, 0, WHOLE_ARRAY);
   double LL = ArrayMinimum(low, 0, WHOLE_ARRAY);
   
   if(HH == -1 || LL == -1) return;
   
   HH = high[(int)HH];
   LL = low[(int)LL];
   
   // Get MA filter
   bool ma_buy = true, ma_sell = true;
   if(InpUseMA)
   {
      double ma = GetMAValue();
      if(ma > 0)
      {
         ma_buy = (HH > ma);
         ma_sell = (LL < ma);
      }
   }
   
   // Place BuyStop
   if(ma_buy)
   {
      double entry = HH + g_breakout_distance;
      double sl, tp;
      
      if(CalculateDynamicSLTP(entry, true, sl, tp))
      {
         g_trade.BuyStop(InpLotSize, entry, InpSymbol, sl, tp, 
                        ORDER_TIME_GTC, 0, "H1_Breakout_Buy");
         
         if(g_trade.ResultRetcode() == TRADE_RETCODE_DONE)
         {
            double sl_pips = (entry - sl) / g_point;
            double tp_pips = (tp - entry) / g_point;
            
            Print("BuyStop placed: Entry=", entry, " SL=", sl_pips, "p TP=", tp_pips, "p");
            g_logger.LogEntry(InpSymbol, "BUYSTOP", entry, sl, tp, InpLotSize,
                            "H1 Breakout", 
                            "SL:" + DoubleToString(sl_pips,1) + "p TP:" + 
                            DoubleToString(tp_pips,1) + "p RR:1:" + 
                            DoubleToString(tp_pips/sl_pips,1));
         }
      }
   }
   
   // Place SellStop
   if(ma_sell)
   {
      double entry = LL - g_breakout_distance;
      double sl, tp;
      
      if(CalculateDynamicSLTP(entry, false, sl, tp))
      {
         g_trade.SellStop(InpLotSize, entry, InpSymbol, sl, tp, 
                         ORDER_TIME_GTC, 0, "H1_Breakout_Sell");
         
         if(g_trade.ResultRetcode() == TRADE_RETCODE_DONE)
         {
            double sl_pips = (sl - entry) / g_point;
            double tp_pips = (entry - tp) / g_point;
            
            Print("SellStop placed: Entry=", entry, " SL=", sl_pips, "p TP=", tp_pips, "p");
            g_logger.LogEntry(InpSymbol, "SELLSTOP", entry, sl, tp, InpLotSize,
                            "H1 Breakout",
                            "SL:" + DoubleToString(sl_pips,1) + "p TP:" + 
                            DoubleToString(tp_pips,1) + "p RR:1:" + 
                            DoubleToString(tp_pips/sl_pips,1));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get MA value                                                      |
//+------------------------------------------------------------------+
double GetMAValue()
{
   int ma_handle = iMA(InpSymbol, TIMEFRAME, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);
   if(ma_handle == INVALID_HANDLE) return 0;
   
   double ma[];
   ArraySetAsSeries(ma, true);
   
   if(CopyBuffer(ma_handle, 0, 1, 1, ma) <= 0)
   {
      IndicatorRelease(ma_handle);
      return 0;
   }
   
   double result = ma[0];
   IndicatorRelease(ma_handle);
   
   return result;
}

//+------------------------------------------------------------------+
//| Calculate dynamic SL/TP based on S/R                              |
//+------------------------------------------------------------------+
bool CalculateDynamicSLTP(double entry, bool is_buy, double &sl_out, double &tp_out)
{
   if(is_buy)
   {
      // BUY: SL at support below
      SRLevel support = g_sr.GetNearestSupport(entry);
      
      if(support.is_valid && support.price < entry)
      {
         double distance = entry - support.price;
         
         if(distance < g_min_sl)
            sl_out = entry - g_min_sl;
         else if(distance > g_max_sl)
            sl_out = entry - g_max_sl;
         else
            sl_out = support.price;
      }
      else
      {
         sl_out = entry - g_max_sl;
      }
      
      // TP based on R:R
      double sl_distance = entry - sl_out;
      tp_out = entry + (sl_distance * InpRiskRewardRatio);
      
      // Try to extend TP to next resistance
      SRLevel resistance = g_sr.GetNearestResistance(entry);
      if(resistance.is_valid && resistance.price > tp_out)
      {
         tp_out = resistance.price;
      }
   }
   else  // SELL
   {
      // SELL: SL at resistance above
      SRLevel resistance = g_sr.GetNearestResistance(entry);
      
      if(resistance.is_valid && resistance.price > entry)
      {
         double distance = resistance.price - entry;
         
         if(distance < g_min_sl)
            sl_out = entry + g_min_sl;
         else if(distance > g_max_sl)
            sl_out = entry + g_max_sl;
         else
            sl_out = resistance.price;
      }
      else
      {
         sl_out = entry + g_max_sl;
      }
      
      // TP based on R:R
      double sl_distance = sl_out - entry;
      tp_out = entry - (sl_distance * InpRiskRewardRatio);
      
      // Try to extend TP to next support
      SRLevel support = g_sr.GetNearestSupport(entry);
      if(support.is_valid && support.price < tp_out)
      {
         tp_out = support.price;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Create Dashboard                                                  |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   int x = 15, y = 30, width = 260, row = 25;
   
   CreateLabel("Title", "⚡ BREAKOUT H1", x, y, clrWhite, 12, true);
   y += 40;
   
   // Account
   CreatePanel("PanelAcc", x, y, width, 80, clrDarkSlateGray);
   y += 5;
   CreateLabel("Balance", "Balance: ...", x+10, y, clrLightGray, 9, false);
   y += row;
   CreateLabel("Equity", "Equity: ...", x+10, y, clrLightGray, 9, false);
   y += row;
   CreateLabel("Profit", "Profit: ...", x+10, y, clrLightGreen, 9, true);
   y += 90;
   
   // Status
   CreatePanel("PanelStatus", x, y, width, 80, clrDarkSlateGray);
   y += 5;
   CreateLabel("Position", "Position: 0/1", x+10, y, clrLightGray, 9, false);
   y += row;
   CreateLabel("Symbol", "Symbol: " + InpSymbol, x+10, y, clrLightGray, 9, false);
   y += row;
   CreateLabel("Status", "Status: ● ACTIVE", x+10, y, clrLime, 9, true);
   y += 90;
   
   // Performance
   CreatePanel("PanelPerf", x, y, width, 105, clrDarkSlateGray);
   y += 5;
   CreateLabel("Trades", "Trades: 0", x+10, y, clrLightGray, 9, false);
   y += row;
   CreateLabel("WinLoss", "Wins: 0 | Loss: 0", x+10, y, clrLightGray, 9, false);
   y += row;
   CreateLabel("WinRate", "Win Rate: 0%", x+10, y, clrGold, 9, true);
   y += row;
   CreateLabel("PnL", "P/L: $0.00", x+10, y, clrGold, 9, true);
   
   g_dashboard_created = true;
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!g_dashboard_created) return;
   
   UpdateLabel("Balance", "Balance: $" + DoubleToString(g_account.Balance(), 2));
   UpdateLabel("Equity", "Equity: $" + DoubleToString(g_account.Equity(), 2));
   
   double profit = g_account.Profit();
   color profit_color = (profit >= 0) ? clrLightGreen : clrRed;
   UpdateLabel("Profit", "Profit: $" + DoubleToString(profit, 2), profit_color);
   
   int pos_count = HasPosition() ? 1 : 0;
   UpdateLabel("Position", "Position: " + IntegerToString(pos_count) + "/1");
   
   // Performance
   HistorySelect(0, TimeCurrent());
   int trades = 0, wins = 0;
   double total_pnl = 0;
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         double deal_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(deal_profit != 0)
         {
            trades++;
            total_pnl += deal_profit;
            if(deal_profit > 0) wins++;
         }
      }
   }
   
   double wr = (trades > 0) ? (wins * 100.0 / trades) : 0;
   
   UpdateLabel("Trades", "Trades: " + IntegerToString(trades));
   UpdateLabel("WinLoss", "Wins: " + IntegerToString(wins) + " | Loss: " + IntegerToString(trades - wins));
   UpdateLabel("WinRate", "Win Rate: " + DoubleToString(wr, 1) + "%");
   
   color pnl_color = (total_pnl >= 0) ? clrGold : clrRed;
   UpdateLabel("PnL", "P/L: $" + DoubleToString(total_pnl, 2), pnl_color);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete Dashboard                                                  |
//+------------------------------------------------------------------+
void DeleteDashboard()
{
   ObjectsDeleteAll(0, "Lbl", 0, -1);
   ObjectsDeleteAll(0, "Panel", 0, -1);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create Panel                                                      |
//+------------------------------------------------------------------+
void CreatePanel(string name, int x, int y, int w, int h, color bg)
{
   name = "Panel" + name;
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create Label                                                      |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int size, bool bold)
{
   name = "Lbl" + name;
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Update Label                                                      |
//+------------------------------------------------------------------+
void UpdateLabel(string name, string text, color clr = -1)
{
   name = "Lbl" + name;
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      if(clr != -1) ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
}
//+------------------------------------------------------------------+
