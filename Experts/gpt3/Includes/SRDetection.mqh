//+------------------------------------------------------------------+
//|                                              SRDetection.mqh      |
//|                    Support/Resistance Detection Module            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| S/R Level Structure                                               |
//+------------------------------------------------------------------+
struct SRLevel
  {
   double            price;
   datetime          last_touch;
   int               touch_count;
   bool              is_support;
   string            source;
   int               strength;
   bool              is_valid;
   
   // Constructor
   SRLevel() : price(0), last_touch(0), touch_count(0), is_support(false), source(""), strength(0), is_valid(false) {}
  };

//+------------------------------------------------------------------+
//| S/R Detection Class                                               |
//+------------------------------------------------------------------+
class CSRDetection
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   bool              m_use_pivots;
   bool              m_use_swings;
   int               m_swing_lookback;
   int               m_swing_strength;
   int               m_min_swing_distance;
   
   SRLevel           m_levels[];
   int               m_levels_count;

public:
                     CSRDetection();
                    ~CSRDetection();
   
   bool              Init(string symbol, ENUM_TIMEFRAMES tf,
                          bool use_pivots, bool use_swings,
                          int swing_lookback, int swing_strength, int min_swing_distance);
   
   void              Update();
   void              DrawLevels();
   
   int               GetLevelsCount() { return m_levels_count; }
   SRLevel           GetLevel(int index);
   SRLevel           GetNearestSupport(double price);
   SRLevel           GetNearestResistance(double price);

private:
   void              DetectPivotLevels();
   void              DetectSwingLevels();
   void              MergeLevels(double tolerance);
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSRDetection::CSRDetection()
  {
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_use_pivots = true;
   m_use_swings = true;
   m_swing_lookback = 100;
   m_swing_strength = 2;
   m_min_swing_distance = 100;
   m_levels_count = 0;
   ArrayResize(m_levels, 0);
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSRDetection::~CSRDetection()
  {
  }

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CSRDetection::Init(string symbol, ENUM_TIMEFRAMES tf,
                        bool use_pivots, bool use_swings,
                        int swing_lookback, int swing_strength, int min_swing_distance)
  {
   m_symbol = symbol;
   m_timeframe = tf;
   m_use_pivots = use_pivots;
   m_use_swings = use_swings;
   m_swing_lookback = swing_lookback;
   m_swing_strength = swing_strength;
   m_min_swing_distance = min_swing_distance;
   
   return true;
  }

//+------------------------------------------------------------------+
//| Update S/R levels                                                 |
//+------------------------------------------------------------------+
void CSRDetection::Update()
  {
   ArrayResize(m_levels, 0);
   m_levels_count = 0;
   
   if(m_use_pivots)
      DetectPivotLevels();
   
   if(m_use_swings)
      DetectSwingLevels();
   
   // Merge close levels
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   MergeLevels(20 * point);
   
   m_levels_count = ArraySize(m_levels);
  }

//+------------------------------------------------------------------+
//| Detect Pivot Levels                                               |
//+------------------------------------------------------------------+
void CSRDetection::DetectPivotLevels()
  {
   // Get yesterday's daily data
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyHigh(m_symbol, PERIOD_D1, 1, 5, high) <= 0) return;
   if(CopyLow(m_symbol, PERIOD_D1, 1, 5, low) <= 0) return;
   if(CopyClose(m_symbol, PERIOD_D1, 1, 5, close) <= 0) return;
   
   // Calculate Pivot Points
   double pivot = (high[0] + low[0] + close[0]) / 3;
   double r1 = 2 * pivot - low[0];
   double r2 = pivot + (high[0] - low[0]);
   double s1 = 2 * pivot - high[0];
   double s2 = pivot - (high[0] - low[0]);
   
   // Add levels
   int size = ArraySize(m_levels);
   ArrayResize(m_levels, size + 5);
   
   m_levels[size].price = s2; m_levels[size].is_support = true; m_levels[size].source = "Pivot"; m_levels[size].is_valid = true; m_levels[size].strength = 7;
   m_levels[size+1].price = s1; m_levels[size+1].is_support = true; m_levels[size+1].source = "Pivot"; m_levels[size+1].is_valid = true; m_levels[size+1].strength = 8;
   m_levels[size+2].price = pivot; m_levels[size+2].is_support = true; m_levels[size+2].source = "Pivot"; m_levels[size+2].is_valid = true; m_levels[size+2].strength = 10;
   m_levels[size+3].price = r1; m_levels[size+3].is_support = false; m_levels[size+3].source = "Pivot"; m_levels[size+3].is_valid = true; m_levels[size+3].strength = 8;
   m_levels[size+4].price = r2; m_levels[size+4].is_support = false; m_levels[size+4].source = "Pivot"; m_levels[size+4].is_valid = true; m_levels[size+4].strength = 7;
  }

//+------------------------------------------------------------------+
//| Detect Swing Levels                                               |
//+------------------------------------------------------------------+
void CSRDetection::DetectSwingLevels()
  {
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(m_symbol, m_timeframe, 0, m_swing_lookback, high) <= 0) return;
   if(CopyLow(m_symbol, m_timeframe, 0, m_swing_lookback, low) <= 0) return;
   
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double min_distance = m_min_swing_distance * point;
   
   // Find swing highs
   for(int i = m_swing_strength; i < m_swing_lookback - m_swing_strength; i++)
     {
      bool is_swing_high = true;
      for(int j = 1; j <= m_swing_strength; j++)
        {
         if(high[i] <= high[i-j] || high[i] <= high[i+j])
           {
            is_swing_high = false;
            break;
           }
        }
      
      if(is_swing_high)
        {
         // Check distance from existing levels
         bool too_close = false;
         for(int k = 0; k < ArraySize(m_levels); k++)
           {
            if(MathAbs(high[i] - m_levels[k].price) < min_distance)
              {
               too_close = true;
               break;
              }
           }
         
         if(!too_close)
           {
            int size = ArraySize(m_levels);
            ArrayResize(m_levels, size + 1);
            m_levels[size].price = high[i];
            m_levels[size].is_support = false;
            m_levels[size].source = "Swing";
            m_levels[size].is_valid = true;
            m_levels[size].strength = 6;
           }
        }
     }
   
   // Find swing lows
   for(int i = m_swing_strength; i < m_swing_lookback - m_swing_strength; i++)
     {
      bool is_swing_low = true;
      for(int j = 1; j <= m_swing_strength; j++)
        {
         if(low[i] >= low[i-j] || low[i] >= low[i+j])
           {
            is_swing_low = false;
            break;
           }
        }
      
      if(is_swing_low)
        {
         bool too_close = false;
         for(int k = 0; k < ArraySize(m_levels); k++)
           {
            if(MathAbs(low[i] - m_levels[k].price) < min_distance)
              {
               too_close = true;
               break;
              }
           }
         
         if(!too_close)
           {
            int size = ArraySize(m_levels);
            ArrayResize(m_levels, size + 1);
            m_levels[size].price = low[i];
            m_levels[size].is_support = true;
            m_levels[size].source = "Swing";
            m_levels[size].is_valid = true;
            m_levels[size].strength = 6;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Merge close levels                                                |
//+------------------------------------------------------------------+
void CSRDetection::MergeLevels(double tolerance)
  {
   for(int i = 0; i < ArraySize(m_levels) - 1; i++)
     {
      for(int j = i + 1; j < ArraySize(m_levels); j++)
        {
         if(m_levels[j].is_valid && MathAbs(m_levels[i].price - m_levels[j].price) < tolerance)
           {
            m_levels[i].price = (m_levels[i].price + m_levels[j].price) / 2;
            m_levels[i].strength = MathMax(m_levels[i].strength, m_levels[j].strength) + 1;
            m_levels[j].is_valid = false;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Get level by index                                                |
//+------------------------------------------------------------------+
SRLevel CSRDetection::GetLevel(int index)
  {
   SRLevel invalid_level;
   if(index < 0 || index >= ArraySize(m_levels))
      return invalid_level;
   return m_levels[index];
  }

//+------------------------------------------------------------------+
//| Get nearest support                                               |
//+------------------------------------------------------------------+
SRLevel CSRDetection::GetNearestSupport(double price)
  {
   SRLevel result;
   double min_distance = 999999;
   
   for(int i = 0; i < ArraySize(m_levels); i++)
     {
      if(m_levels[i].is_valid && m_levels[i].is_support && m_levels[i].price < price)
        {
         double distance = price - m_levels[i].price;
         if(distance < min_distance)
           {
            min_distance = distance;
            result = m_levels[i];
           }
        }
     }
   
   return result;
  }

//+------------------------------------------------------------------+
//| Get nearest resistance                                            |
//+------------------------------------------------------------------+
SRLevel CSRDetection::GetNearestResistance(double price)
  {
   SRLevel result;
   double min_distance = 999999;
   
   for(int i = 0; i < ArraySize(m_levels); i++)
     {
      if(m_levels[i].is_valid && !m_levels[i].is_support && m_levels[i].price > price)
        {
         double distance = m_levels[i].price - price;
         if(distance < min_distance)
           {
            min_distance = distance;
            result = m_levels[i];
           }
        }
     }
   
   return result;
  }

//+------------------------------------------------------------------+
//| Draw S/R levels                                                   |
//+------------------------------------------------------------------+
void CSRDetection::DrawLevels()
  {
   // Delete old lines
   for(int i = ObjectsTotal(0, 0, OBJ_HLINE) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, 0, OBJ_HLINE);
      if(StringFind(name, "SR_") == 0)
         ObjectDelete(0, name);
     }
   
   // Draw new levels
   for(int i = 0; i < ArraySize(m_levels); i++)
     {
      if(!m_levels[i].is_valid) continue;
      
      string name = "SR_" + IntegerToString(i);
      color line_color = m_levels[i].is_support ? clrLimeGreen : clrRed;
      
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, m_levels[i].price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
     }
  }
//+------------------------------------------------------------------+

