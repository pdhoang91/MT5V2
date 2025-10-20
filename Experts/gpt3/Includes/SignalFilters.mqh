//+------------------------------------------------------------------+
//|                                              SignalFilters.mqh   |
//|                          RSI Filter for Signal Confirmation      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Signal Filters Class                                              |
//+------------------------------------------------------------------+
class CSignalFilters
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   
   // RSI
   bool              m_use_rsi;
   int               m_rsi_handle;
   int               m_rsi_period;
   double            m_rsi_level_buy;
   double            m_rsi_level_sell;
   double            m_rsi_current;

public:
                     CSignalFilters();
                    ~CSignalFilters();
   
   bool              Init(string symbol, ENUM_TIMEFRAMES tf,
                          bool use_rsi, int rsi_period, 
                          double rsi_buy, double rsi_sell,
                          bool use_candle, bool pin_bar, bool engulfing,
                          double pin_body, double pin_wick);
   void              Deinit();
   
   bool              RSIConfirmBuy();
   bool              RSIConfirmSell();
   bool              ConfirmBuySignal();
   bool              ConfirmSellSignal();
   double            GetRSIValue() { return m_rsi_current; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSignalFilters::CSignalFilters()
  {
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_use_rsi = false;
   m_rsi_handle = INVALID_HANDLE;
   m_rsi_period = 14;
   m_rsi_level_buy = 40;
   m_rsi_level_sell = 60;
   m_rsi_current = 50;
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSignalFilters::~CSignalFilters()
  {
   Deinit();
  }

//+------------------------------------------------------------------+
//| Initialize filters                                                |
//+------------------------------------------------------------------+
bool CSignalFilters::Init(string symbol, ENUM_TIMEFRAMES tf,
                          bool use_rsi, int rsi_period,
                          double rsi_buy, double rsi_sell,
                          bool use_candle, bool pin_bar, bool engulfing,
                          double pin_body, double pin_wick)
  {
   m_symbol = symbol;
   m_timeframe = tf;
   
   // RSI
   m_use_rsi = use_rsi;
   m_rsi_period = rsi_period;
   m_rsi_level_buy = rsi_buy;
   m_rsi_level_sell = rsi_sell;
   
   if(m_use_rsi)
     {
      m_rsi_handle = iRSI(m_symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
      if(m_rsi_handle == INVALID_HANDLE)
        {
         Print("ERROR: Failed to create RSI indicator for ", m_symbol);
         return false;
        }
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Deinitialize                                                      |
//+------------------------------------------------------------------+
void CSignalFilters::Deinit()
  {
   if(m_rsi_handle != INVALID_HANDLE)
     {
      IndicatorRelease(m_rsi_handle);
      m_rsi_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Check RSI for BUY signal                                          |
//+------------------------------------------------------------------+
bool CSignalFilters::RSIConfirmBuy()
  {
   if(!m_use_rsi) return true;
   
   double rsi[];
   ArraySetAsSeries(rsi, true);
   
   if(CopyBuffer(m_rsi_handle, 0, 0, 2, rsi) <= 0)
     {
      return false;
     }
   
   m_rsi_current = rsi[0];
   return (m_rsi_current < m_rsi_level_buy);
  }

//+------------------------------------------------------------------+
//| Check RSI for SELL signal                                         |
//+------------------------------------------------------------------+
bool CSignalFilters::RSIConfirmSell()
  {
   if(!m_use_rsi) return true;
   
   double rsi[];
   ArraySetAsSeries(rsi, true);
   
   if(CopyBuffer(m_rsi_handle, 0, 0, 2, rsi) <= 0)
     {
      return false;
     }
   
   m_rsi_current = rsi[0];
   return (m_rsi_current > m_rsi_level_sell);
  }

//+------------------------------------------------------------------+
//| Confirm BUY signal (all filters)                                  |
//+------------------------------------------------------------------+
bool CSignalFilters::ConfirmBuySignal()
  {
   return RSIConfirmBuy();
  }

//+------------------------------------------------------------------+
//| Confirm SELL signal (all filters)                                 |
//+------------------------------------------------------------------+
bool CSignalFilters::ConfirmSellSignal()
  {
   return RSIConfirmSell();
  }
//+------------------------------------------------------------------+

