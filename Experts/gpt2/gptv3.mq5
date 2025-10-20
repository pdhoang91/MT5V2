//+------------------------------------------------------------------+
//|                     Thanh Tan.mq5 |
//|                                                                  |
//+------------------------------------------------------------------+

//---
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh> // Thư viện để tạo đối tượng văn bản

CPositionInfo  m_position;                   // trade position object
CTrade         trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
CMoneyFixedMargin *m_money;

// Trading parameter

input int HL_period=20;                    // Reduced from 156 to 20 for more responsive signals
input int HL_Shift;
//--- input parameters
input double           Lot_size          =0.01  ;
input double           distance          =150;        // Increased to 150 pips for better entry quality
input double           TP=700;                       // Increased to 700 pips for better R:R
input double           SL=400;                       // Increased to 400 pips for better risk management
input ushort           InpTrailingStop   = 200;       // Trailing Stop (in pips) - adjusted for new SL/TP
input ushort           InpTrailingStep   = 50;        // Trailing Step (in pips) - adjusted for new parameters
input int              InpMaxPositions   = 5;        // Maximum positions
input ulong            m_magic=47978073;             // magic number
int input    EXPERT_MAGIC = 1234567;
input        ENUM_TIMEFRAMES              Trading_timframe=PERIOD_H1;

// Dashboard Parameters
input bool             EnableDashboard = true;        // Enable Dashboard

// Input Indicator declaration

input int      period_MA_fast      =50;        // Reduced from 120 to 50 for more responsive MA
input int      Shift_MA_fast       =0;        // Simplified shift to 0

// Simple Breakout Strategy - No Additional Filters

// Global Variable

//SL-TP management
double         m_adjusted_point;             // point value adjusted for 3 or 5 points
ulong          m_slippage=10;                // slippage
double         ExtDistance=0.0;
double         ExtStopLoss=0.0;
double         ExtTakeProfit=0.0;
double         ExtTrailingStop=0.0;
double         ExtTrailingStep=0.0;
double         ExtSpreadLimit=0.0;

// Indicator Declaration
int handel_MA;

// Dashboard Variables
datetime last_dashboard_update = 0;
bool dashboard_created = false;

// Strategy Performance Structure
struct StrategyPerformance
  {
   string            strategy_name;
   int               total_trades;
   int               winning_trades;
   double            total_profit;
   double            max_drawdown;
   double            current_drawdown;
   double            win_rate;
   double            avg_profit;
   double            profit_factor;
   int               open_positions;
   double            current_price;
   double            entry_price;
   double            stop_loss;
   double            take_profit;
   double            unrealized_profit;
   datetime          last_trade_time;
  };

// Strategy Enumeration
enum ENUM_STRATEGY
  {
   STRATEGY_BREAKOUT = 0,
// Thêm chiến lược mới ở đây
   STRATEGY_COUNT
  };

// Strategy Names Array
string strategy_names[] =
  {
   "Breakout"
// Thêm tên chiến lược mới ở đây
  };

// Strategy Performance Array
StrategyPerformance strategy_stats[];

// Magic Number for Orders
#define MAGIC_NUMBER 47978073

// Function to get magic number for a strategy
ulong GetStrategyMagicNumber(ENUM_STRATEGY strategy)
  {
   switch(strategy)
     {
      case STRATEGY_BREAKOUT:
         return MAGIC_NUMBER + 1;
      // Thêm magic number cho chiến lược mới ở đây
      default:
         return MAGIC_NUMBER;
     }
  }

// Function to get strategy name
string GetStrategyName(ENUM_STRATEGY strategy)
  {
   if(strategy >= 0 && strategy < ArraySize(strategy_names))
     {
      return strategy_names[strategy];
     }
   return "Unknown";
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(!m_symbol.Name(Symbol())) // sets symbol name
      return(INIT_FAILED);
   RefreshRates();
//---
   trade.SetExpertMagicNumber((ulong)m_magic);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(m_symbol.Name());
   trade.SetDeviationInPoints(m_slippage);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;

   ExtStopLoss    = SL     * m_adjusted_point;
   ExtTakeProfit  = TP   * m_adjusted_point;
   ExtTrailingStop= InpTrailingStop * m_adjusted_point;
   ExtTrailingStep= InpTrailingStep * m_adjusted_point;
   ExtDistance    = distance*m_adjusted_point;
   double profit=0;
//--- create handle of the indicator MA
   handel_MA=iMA(Symbol(),Trading_timframe,period_MA_fast,Shift_MA_fast,MODE_EMA,PRICE_CLOSE);
//--- if the handle is not created
   if(handel_MA==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the Moving average indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }

// Simple breakout strategy - no additional indicators needed

// Initialize Dashboard and Performance Tracking
   if(EnableDashboard)
     {
      InitializePerformanceTracking();
      CreateDashboard();
     }

//---
   return(INIT_SUCCEEDED);
  }



//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   if(m_money!=NULL)
      delete m_money;

// Clean up Dashboard
   if(EnableDashboard)
     {
      ObjectsDeleteAll(0, OBJ_LABEL, 0, 0);
     }

   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {


// Declaration the Candle
   double high[];
   ArraySetAsSeries(high,true);
   CopyHigh(Symbol(),Trading_timframe,1,1000,high);
   double low[];
   ArraySetAsSeries(low,true);
   CopyLow(Symbol(),Trading_timframe,1,1000,low);
   double open[];
   ArraySetAsSeries(open,true);
   CopyLow(Symbol(),Trading_timframe,1,1000,open);
   double close[];
   ArraySetAsSeries(close,true);
   CopyLow(Symbol(),Trading_timframe,1,1000,close);
// Declaration Array for Moving average
   double MA_Slow[];
   ArraySetAsSeries(MA_Slow,true);
   MA(0,1,MA_Slow);

// Declaration Highest high and lowes low

   double HH= Highest(high,HL_period,HL_Shift);
   MoveLine(HH,"highesthigh",clrRed);// Draw line Resistance
   double LL= Lowest(low,HL_period,HL_Shift);
   MoveLine(LL,"lowestlow",clrRed);// Draw line Support
// declaration count positions
   int count_buy=0;
   int count_sell=0;
   double profit=0;
   CalculatePositions(count_buy,count_sell,profit);
// Execution main Trade

// Only trade at new bar
   if(BarOpen(Symbol(),Trading_timframe))
     {
      CalculatePositions(count_buy,count_sell,profit);
      //Delete pending order
      (OrderManaging(Symbol(),Trading_timframe));
      Trailing();
      
      // Simple Breakout Logic - BUY Signal
      if(count_buy == 0 && CheckVolumeValue(Lot_size) && CheckMoney(Lot_size, ORDER_TYPE_BUY))
        {
         if(HH > MA_Slow[1])  // Simple condition: Highest High > Moving Average
           {
            double entryprice = HH + ExtDistance;
            double sl = entryprice - ExtStopLoss;
            double tp = entryprice + ExtTakeProfit;
            trade.BuyStop(Lot_size, entryprice, Symbol(), sl, tp, ORDER_TIME_GTC, 0, "Breakout_Simple");
            Print("BUY order placed at: ", entryprice, " SL: ", sl, " TP: ", tp);
           }
        }
        
      // Simple Breakout Logic - SELL Signal  
      if(count_sell == 0 && CheckVolumeValue(Lot_size) && CheckMoney(Lot_size, ORDER_TYPE_SELL))
        {
         if(LL < MA_Slow[1])  // Simple condition: Lowest Low < Moving Average
           {
            double entryprice = LL - ExtDistance;
            double sl = entryprice + ExtStopLoss;
            double tp = entryprice - ExtTakeProfit;
            trade.SellStop(Lot_size, entryprice, Symbol(), sl, tp, ORDER_TIME_GTC, 0, "Breakout_Simple");
            Print("SELL order placed at: ", entryprice, " SL: ", sl, " TP: ", tp);
           }
        }
     }

// Check for closed deals and update performance
   CheckForClosedDeals();

// Update Dashboard
   if(EnableDashboard && TimeCurrent() - last_dashboard_update > 5)
     {
      LoadHistoricalPerformance();
      UpdateDashboard();
      last_dashboard_update = TimeCurrent();
     }
  }

//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates(void)
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      Print("RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MoveLine(double price,string name,color clr)
  {
   if(ObjectFind(0,name)<0)
     {
      //--- reset the error value
      ResetLastError();
      //--- create a horizontal line
      if(!ObjectCreate(0,name,OBJ_HLINE,0,0,price))
        {
         Print(__FUNCTION__,
               ": failed to create a horizontal line! Error code = ",GetLastError());
         return;
        }
      //--- set line color
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      //--- set line display style
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASHDOTDOT);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,4);
     }
//--- reset the error value
   ResetLastError();
//--- move a horizontal line
   if(!ObjectMove(0,name,0,0,price))
     {
      Print(__FUNCTION__,
            ": failed to move the horizontal line! Error code = ",GetLastError());
      return;
     }
   ChartRedraw();
  }


//+------------------------------------------------------------------+
//| Calculate positions Buy and Sell                                 |
//+------------------------------------------------------------------+
void CalculatePositions(int &count_buys,int &count_sells,double &profit)
  {
   count_buys=0;
   count_sells=0;
   profit=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() //&& m_position.Magic()==m_magic
           )
           {
            profit+=m_position.Commission()+m_position.Swap()+m_position.Profit();
            if(m_position.PositionType()==POSITION_TYPE_BUY)
               count_buys++;

            if(m_position.PositionType()==POSITION_TYPE_SELL)
               count_sells++;
           }
  }
//+------------------------------------------------------------------+
//| close all positions                                              |
//+------------------------------------------------------------------+
void ClosePositions(const ENUM_POSITION_TYPE pos_type)
  {
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current positions
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
            if(m_position.PositionType()==pos_type) // gets the position type
               trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
  }

//+------------------------------------------------------------------+
//| get highest value for range                                      |
//+------------------------------------------------------------------+
double Highest(const double&array[],int range,int fromIndex)
  {
   double res=0;
//---
   res=array[fromIndex];
   for(int i=fromIndex;i<fromIndex+range;i++)
     {
      if(res<array[i])
         res=array[i];
     }
//---
   return(res);
  }
//+------------------------------------------------------------------+
//| get lowest value for range                                       |
//+------------------------------------------------------------------+
double Lowest(const double&array[],int range,int fromIndex)
  {
   double res=0;
//---
   res=array[fromIndex];
   for(int i=fromIndex;i<fromIndex+range;i++)
     {
      if(res>array[i])
         res=array[i];
     }
//---
   return(res);
  }

//+------------------------------------------------------------------+
// Get value of buffers for the iIchimoku

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MA(int buffer, int index, double &MA_Slow[])
  {
//--- reset error code
   ResetLastError();
//--- fill a part of the iIchimoku array with values from the indicator buffer that has 0 index
   if(CopyBuffer(handel_MA,buffer,index,1000,MA_Slow)<0)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the Moving Arverage indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(0.0);
     }
   return(MA_Slow[0]);
  }
//+------------------------------------------------------------------+
//| Get current server time function                                 |
//+------------------------------------------------------------------+

datetime m_prev_bar;
bool BarOpen(string symbol,ENUM_TIMEFRAMES timeframe)
  {
   datetime bar_time = iTime(symbol, timeframe, 0);
   if(bar_time == m_prev_bar)
     {
      return false;
     }
   m_prev_bar = bar_time;
   return true;
  }

//+------------------------------------------------------------------+
//| Simple order management - delete all pending orders             |
//+------------------------------------------------------------------+
int OrderManaging(string symbol,ENUM_TIMEFRAMES timeframe)
  {
   int orders_deleted = 0;
   
   // Simple order management - delete all pending orders for this symbol
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong orderTicket = OrderGetTicket(i);
      if(OrderSelect(orderTicket))
        {
         if(OrderGetString(ORDER_SYMBOL) == Symbol())
           {
            trade.OrderDelete(orderTicket);
            orders_deleted++;
           }
        }
     }
   return orders_deleted;
  }

//+------------------------------------------------------------------+
//| Trailing                                                         |
//+------------------------------------------------------------------+
void Trailing()
  {
   if(InpTrailingStop==0)
      return;
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of open positions
      if(m_position.SelectByIndex(i))
         if(m_position.Symbol()==m_symbol.Name() //&& m_position.Magic()==m_magic
           )
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               if(m_position.PriceCurrent()-m_position.PriceOpen()>ExtTrailingStop+ExtTrailingStep)
                  if(m_position.StopLoss()<m_position.PriceCurrent()-(ExtTrailingStop+ExtTrailingStep))
                    {
                     if(!trade.PositionModify(m_position.Ticket(),
                                              m_symbol.NormalizePrice(m_position.PriceCurrent()-ExtTrailingStop),
                                              m_position.TakeProfit()))
                        Print("Modify ",m_position.Ticket(),
                              " Position -> false. Result Retcode: ",trade.ResultRetcode(),
                              ", description of result: ",trade.ResultRetcodeDescription());
                     RefreshRates();
                     m_position.SelectByIndex(i);
                     continue;
                    }
              }
            else
              {
               if(m_position.PriceOpen()-m_position.PriceCurrent()>ExtTrailingStop+ExtTrailingStep)
                  if((m_position.StopLoss()>(m_position.PriceCurrent()+(ExtTrailingStop+ExtTrailingStep))) ||
                     (m_position.StopLoss()==0))
                    {
                     if(!trade.PositionModify(m_position.Ticket(),
                                              m_symbol.NormalizePrice(m_position.PriceCurrent()+ExtTrailingStop),
                                              m_position.TakeProfit()))
                        Print("Modify ",m_position.Ticket(),
                              " Position -> false. Result Retcode: ",trade.ResultRetcode(),
                              ", description of result: ",trade.ResultRetcodeDescription());
                     RefreshRates();
                     m_position.SelectByIndex(i);
                    }
              }

           }
  }

//+------------------------------------------------------------------+
//| Dashboard Functions                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Performance Tracking                                  |
//+------------------------------------------------------------------+
void InitializePerformanceTracking()
  {
// Initialize strategy performance array
   ArrayResize(strategy_stats, STRATEGY_COUNT);

   for(int i = 0; i < STRATEGY_COUNT; i++)
     {
      strategy_stats[i].strategy_name = GetStrategyName((ENUM_STRATEGY)i);
      strategy_stats[i].total_trades = 0;
      strategy_stats[i].winning_trades = 0;
      strategy_stats[i].total_profit = 0.0;
      strategy_stats[i].max_drawdown = 0.0;
      strategy_stats[i].current_drawdown = 0.0;
      strategy_stats[i].win_rate = 0.0;
      strategy_stats[i].avg_profit = 0.0;
      strategy_stats[i].profit_factor = 0.0;
      strategy_stats[i].open_positions = 0;
      strategy_stats[i].current_price = 0.0;
      strategy_stats[i].entry_price = 0.0;
      strategy_stats[i].stop_loss = 0.0;
      strategy_stats[i].take_profit = 0.0;
      strategy_stats[i].unrealized_profit = 0.0;
      strategy_stats[i].last_trade_time = 0;
     }

   LoadHistoricalPerformance();
  }

//+------------------------------------------------------------------+
//| Load Historical Performance Data                                |
//+------------------------------------------------------------------+
void LoadHistoricalPerformance()
  {
   datetime start_time = TimeCurrent() - (365 * 24 * 60 * 60); // 1 year

   for(int i = 0; i < STRATEGY_COUNT; i++)
     {
      CalculateStrategyPerformance(strategy_stats[i], start_time);
     }
  }

//+------------------------------------------------------------------+
//| Calculate Strategy Performance                                   |
//+------------------------------------------------------------------+
void CalculateStrategyPerformance(StrategyPerformance &stats, datetime start_time)
  {
   double total_profit = 0.0;
   double total_loss = 0.0;
   int winning_trades = 0;
   int total_trades = 0;
   double max_equity = 0.0;
   double current_equity = 0.0;
   double max_drawdown = 0.0;

   HistorySelect(start_time, TimeCurrent());
   int deals = HistoryDealsTotal();

   for(int i = 0; i < deals; i++)
     {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket > 0)
        {
         string deal_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
         double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
         ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);

         if(deal_entry == DEAL_ENTRY_OUT && deal_profit != 0.0)
           {
            // Check if deal belongs to this strategy by magic number
            ulong strategy_magic = GetStrategyMagicNumber((ENUM_STRATEGY)ArraySearch(strategy_stats, stats.strategy_name));
            if(deal_magic == strategy_magic)
              {
               total_trades++;
               current_equity += deal_profit;

               if(deal_profit > 0)
                 {
                  winning_trades++;
                  total_profit += deal_profit;
                 }
               else
                 {
                  total_loss += MathAbs(deal_profit);
                 }

               // Calculate drawdown
               if(current_equity > max_equity)
                 {
                  max_equity = current_equity;
                 }
               double drawdown = max_equity - current_equity;
               if(drawdown > max_drawdown)
                 {
                  max_drawdown = drawdown;
                 }
              }
           }
        }
     }

// Count open positions for this strategy
   stats.open_positions = 0;
   stats.unrealized_profit = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         ulong strategy_magic = GetStrategyMagicNumber((ENUM_STRATEGY)ArraySearch(strategy_stats, stats.strategy_name));
         if(PositionGetInteger(POSITION_MAGIC) == strategy_magic)
           {
            stats.open_positions++;
            stats.unrealized_profit += PositionGetDouble(POSITION_PROFIT);
            stats.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            stats.stop_loss = PositionGetDouble(POSITION_SL);
            stats.take_profit = PositionGetDouble(POSITION_TP);
            stats.last_trade_time = (datetime)PositionGetInteger(POSITION_TIME);
           }
        }
     }

   stats.current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

// Update statistics
   stats.total_trades = total_trades;
   stats.winning_trades = winning_trades;
   stats.total_profit = total_profit - total_loss;
   stats.win_rate = (total_trades > 0) ? (double)winning_trades / total_trades : 0.0;
   stats.avg_profit = (total_trades > 0) ? stats.total_profit / total_trades : 0.0;
   stats.profit_factor = (total_loss > 0) ? total_profit / total_loss : 0.0;
   stats.max_drawdown = max_drawdown;
   stats.current_drawdown = max_equity - current_equity;
  }

//+------------------------------------------------------------------+
//| Helper function to find strategy index                          |
//+------------------------------------------------------------------+
int ArraySearch(StrategyPerformance &array[], string strategy_name)
  {
   for(int i = 0; i < ArraySize(array); i++)
     {
      if(array[i].strategy_name == strategy_name)
        {
         return i;
        }
     }
   return -1;
  }

//+------------------------------------------------------------------+
//| Create Dashboard                                                 |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   if(!EnableDashboard)
      return;

// Main Dashboard Title
   CreateButton("DashboardTitle", "GPTv3 - Breakout Strategy", 10, 120, 400, 25, clrDarkBlue, clrWhite, 11, false);

// Market Information
   CreateButton("MarketSectionTitle", "Market Info", 10, 95, 400, 18, clrDarkCyan, clrWhite, 10, false);
   CreateButton("SymbolLabel", "Symbol: " + _Symbol, 10, 77, 130, 16, clrDarkGray, clrWhite, 9, false);
   CreateButton("TimeframeLabel", "TF: " + EnumToString(Trading_timframe), 145, 77, 130, 16, clrDarkGray, clrWhite, 9, false);
   CreateButton("SpreadLabel", "Spread: N/A", 280, 77, 130, 16, clrDarkGray, clrWhite, 9, false);

// Breakout Strategy Performance
   CreateButton("StrategySectionTitle", "Breakout Performance", 10, 59, 400, 18, clrDarkCyan, clrWhite, 10, false);
   CreateButton("TradesLabel", "Trades: N/A", 10, 41, 195, 16, clrDarkGray, clrWhite, 9, false);
   CreateButton("WinRateLabel", "Win Rate: N/A", 210, 41, 200, 16, clrDarkGray, clrWhite, 9, false);
   CreateButton("ProfitLabel", "Profit: N/A", 10, 23, 195, 16, clrDarkGray, clrWhite, 9, false);
   CreateButton("PositionsLabel", "Positions: N/A", 210, 23, 200, 16, clrDarkGray, clrWhite, 9, false);

   dashboard_created = true;
  }

//+------------------------------------------------------------------+
//| Update Dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   if(!EnableDashboard || !dashboard_created)
      return;

// Reload performance data
   LoadHistoricalPerformance();

// Update market information
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   UpdateButton("SpreadLabel", StringFormat("Spread: %.4f", spread));

// Update breakout strategy performance
   StrategyPerformance stats = strategy_stats[0]; // Only breakout strategy
   
   UpdateButton("TradesLabel", StringFormat("Trades: %d", stats.total_trades));
   
   color win_rate_bg = clrDarkGray;
   if(stats.win_rate > 0.6) win_rate_bg = clrDarkGreen;
   else if(stats.win_rate < 0.4) win_rate_bg = clrDarkRed;
   UpdateButton("WinRateLabel", StringFormat("Win Rate: %.1f%%", stats.win_rate * 100), clrWhite, win_rate_bg);
   
   color profit_bg = (stats.total_profit >= 0) ? clrDarkGreen : clrDarkRed;
   UpdateButton("ProfitLabel", StringFormat("Profit: %.2f", stats.total_profit), clrWhite, profit_bg);
   
   int open_positions = CountOpenPositionsForStrategy(0);
   color pos_bg = (open_positions > 0) ? clrDarkOrange : clrDarkGray;
   UpdateButton("PositionsLabel", StringFormat("Positions: %d", open_positions), clrWhite, pos_bg);

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Create Button Object                                             |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int width, int height, color bg_color, color text_color, int font_size, bool is_selectable = false)
  {
   if(ObjectFind(0, name) >= 0)
      return;

   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
      return;

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, is_selectable);
  }

//+------------------------------------------------------------------+
//| Update Button Helper Function                                   |
//+------------------------------------------------------------------+
void UpdateButton(string name, string text, color text_color = clrWhite, color bg_color = clrDarkGray)
  {
   if(ObjectFind(0, name) >= 0)
     {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
     }
  }

//+------------------------------------------------------------------+
//| Helper Functions for Dashboard                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Performance Update Functions                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check for Closed Deals and Update Performance                   |
//+------------------------------------------------------------------+
void CheckForClosedDeals()
  {
   static datetime last_deal_check = 0;
   static int last_deals_count = 0;

   if(TimeCurrent() - last_deal_check > 5)
     {
      HistorySelect(0, TimeCurrent());
      int current_deals_count = HistoryDealsTotal();

      if(current_deals_count > last_deals_count)
        {
         bool has_closed_position = false;
         for(int i = last_deals_count; i < current_deals_count; i++)
           {
            ulong deal_ticket = HistoryDealGetTicket(i);
            if(deal_ticket > 0)
              {
               ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
               double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);

               if(deal_entry == DEAL_ENTRY_OUT && deal_profit != 0.0)
                 {
                  long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);

                  // Check if deal belongs to any of our strategies
                  for(int j = 0; j < STRATEGY_COUNT; j++)
                    {
                     if(deal_magic == GetStrategyMagicNumber((ENUM_STRATEGY)j))
                       {
                        has_closed_position = true;
                        break;
                       }
                    }

                  if(has_closed_position)
                     break;
                 }
              }
           }

         if(has_closed_position)
           {
            UpdatePerformanceMetrics();
            UpdateDashboard();
           }

         last_deals_count = current_deals_count;
        }

      last_deal_check = TimeCurrent();
     }
  }

//+------------------------------------------------------------------+
//| Update Performance Metrics                                       |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics()
  {
   datetime start_time = TimeCurrent() - (365 * 24 * 60 * 60); // 1 year

   for(int i = 0; i < STRATEGY_COUNT; i++)
     {
      CalculateStrategyPerformance(strategy_stats[i], start_time);
     }
  }

//+------------------------------------------------------------------+
//| Count Open Positions for Strategy                                |
//+------------------------------------------------------------------+
int CountOpenPositionsForStrategy(int strategy_index)
  {
   int count = 0;
   ulong strategy_magic = GetStrategyMagicNumber((ENUM_STRATEGY)strategy_index);

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) == strategy_magic)
           {
            count++;
           }
        }
     }

   return count;
  }

//+------------------------------------------------------------------+
//| Check the correctness of the order volume                        |
//+------------------------------------------------------------------+
bool CheckVolumeValue(double volume)
  {

//--- minimal allowed volume for trade operations
   double min_volume=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(volume < min_volume)
     {
      //description = StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }

//--- maximal allowed volume of trade operations
   double max_volume=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(volume>max_volume)
     {
      //description = StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }

//--- get minimal step of volume changing
   double volume_step=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   int ratio = (int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      //description = StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f", volume_step,ratio*volume_step);
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Check Money for Trade                                            |
//+------------------------------------------------------------------+
bool CheckMoney(double lots,ENUM_ORDER_TYPE Oder_type)
  {
//--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(_Symbol,mqltick);
   double price=mqltick.ask;
   if(Oder_type==ORDER_TYPE_SELL)
      price=mqltick.bid;
//--- values of the required and free margin
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
//--- call of the checking function
   if(!OrderCalcMargin(Oder_type,_Symbol,lots,price,margin))
     {
      return(false);
     }
//--- if there are insufficient funds to perform the operation
   if(margin>free_margin)
     {
      return(false);
     }
//--- checking successful
   return(true);
  }

//+------------------------------------------------------------------+
//| Check RSI conditions for trading                                 |
//+------------------------------------------------------------------+
// RSI filter removed - using simple breakout logic

//+------------------------------------------------------------------+
//| Check if enough time has passed since last trade                 |
//+------------------------------------------------------------------+
// Cooldown period removed - using simple breakout logic

//+------------------------------------------------------------------+
//| Improved breakout condition check                                |
//+------------------------------------------------------------------+
// Complex breakout condition removed - using simple HH/LL vs MA logic
//+------------------------------------------------------------------+
