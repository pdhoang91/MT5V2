//+------------------------------------------------------------------+
//|                                        BreakoutDetection.mqh      |
//|                      Breakout and Retest Detection Module         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Breakout Detection Class                                          |
//+------------------------------------------------------------------+
class CBreakoutDetection
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_min_breakout_size;
   bool              m_enable_retest;
   int               m_retest_time_window;
   int               m_retest_tolerance;
   
   // Retest tracking
   bool              m_waiting_retest;
   double            m_breakout_level;
   bool              m_breakout_is_support;  // true = support broken, became resistance
   datetime          m_breakout_time;
   int               m_bars_since_breakout;

public:
                     CBreakoutDetection();
                    ~CBreakoutDetection();
   
   bool              Init(string symbol, ENUM_TIMEFRAMES tf,
                          int min_breakout_size, bool enable_retest,
                          int retest_time_window, int retest_tolerance);
   
   bool              CheckBreakout(double sr_level, bool is_support, double current_price);
   bool              IsWaitingRetest() { return m_waiting_retest; }
   bool              CheckRetest(double current_price);
   void              ResetRetest();
   
   double            GetRetestLevel() { return m_breakout_level; }
   bool              IsRetestSupport() { return !m_breakout_is_support; }  // Flipped
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CBreakoutDetection::CBreakoutDetection()
  {
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_min_breakout_size = 20;
   m_enable_retest = true;
   m_retest_time_window = 10;
   m_retest_tolerance = 10;
   
   m_waiting_retest = false;
   m_breakout_level = 0;
   m_breakout_is_support = false;
   m_breakout_time = 0;
   m_bars_since_breakout = 0;
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CBreakoutDetection::~CBreakoutDetection()
  {
  }

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CBreakoutDetection::Init(string symbol, ENUM_TIMEFRAMES tf,
                               int min_breakout_size, bool enable_retest,
                               int retest_time_window, int retest_tolerance)
  {
   m_symbol = symbol;
   m_timeframe = tf;
   m_min_breakout_size = min_breakout_size;
   m_enable_retest = enable_retest;
   m_retest_time_window = retest_time_window;
   m_retest_tolerance = retest_tolerance;
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check for breakout                                                |
//+------------------------------------------------------------------+
bool CBreakoutDetection::CheckBreakout(double sr_level, bool is_support, double current_price)
  {
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double min_break = m_min_breakout_size * point;
   
   bool breakout_detected = false;
   
   if(is_support && current_price < sr_level - min_break)
     {
      // Support broken (downward breakout)
      breakout_detected = true;
      
      if(m_enable_retest && !m_waiting_retest)
        {
         m_waiting_retest = true;
         m_breakout_level = sr_level;
         m_breakout_is_support = true;  // Was support, now resistance
         m_breakout_time = TimeCurrent();
         m_bars_since_breakout = 0;
        }
     }
   else if(!is_support && current_price > sr_level + min_break)
     {
      // Resistance broken (upward breakout)
      breakout_detected = true;
      
      if(m_enable_retest && !m_waiting_retest)
        {
         m_waiting_retest = true;
         m_breakout_level = sr_level;
         m_breakout_is_support = false;  // Was resistance, now support
         m_breakout_time = TimeCurrent();
         m_bars_since_breakout = 0;
        }
     }
   
   return breakout_detected;
  }

//+------------------------------------------------------------------+
//| Check for retest                                                  |
//+------------------------------------------------------------------+
bool CBreakoutDetection::CheckRetest(double current_price)
  {
   if(!m_waiting_retest)
      return false;
   
   // Update bars since breakout
   m_bars_since_breakout++;
   
   // Check if time window expired
   if(m_bars_since_breakout > m_retest_time_window)
     {
      ResetRetest();
      return false;
     }
   
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double tolerance = m_retest_tolerance * point;
   
   // Check if price is retesting the level
   bool is_retesting = MathAbs(current_price - m_breakout_level) <= tolerance;
   
   return is_retesting;
  }

//+------------------------------------------------------------------+
//| Reset retest state                                                |
//+------------------------------------------------------------------+
void CBreakoutDetection::ResetRetest()
  {
   m_waiting_retest = false;
   m_breakout_level = 0;
   m_breakout_is_support = false;
   m_breakout_time = 0;
   m_bars_since_breakout = 0;
  }
//+------------------------------------------------------------------+

