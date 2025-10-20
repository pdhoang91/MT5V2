//+------------------------------------------------------------------+
//|                                      MultiSymbolManager.mqh       |
//|                     Multi-Symbol Position Management              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"

#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Multi Symbol Manager Class                                        |
//+------------------------------------------------------------------+
class CMultiSymbolManager
  {
private:
   string            m_symbols[];          // Array of symbols
   ulong             m_magics[];           // Array of magic numbers (one per symbol)
   int               m_symbol_count;       // Number of symbols
   ulong             m_base_magic;         // Base magic number
   int               m_max_per_symbol;     // Max positions per symbol
   
   CPositionInfo     m_position;

public:
                     CMultiSymbolManager();
                    ~CMultiSymbolManager();
   
   bool              Init(string symbol_list, ulong base_magic, int max_per_symbol);
   
   int               GetSymbolCount() { return m_symbol_count; }
   string            GetSymbol(int index);
   ulong             GetSymbolMagic(string symbol);
   
   int               CountPositions(string symbol, ulong magic);
   int               CountTotalPositions(ulong base_magic);
   
   void              PrintSymbols();
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CMultiSymbolManager::CMultiSymbolManager()
  {
   m_symbol_count = 0;
   m_base_magic = 0;
   m_max_per_symbol = 1;
   ArrayResize(m_symbols, 0);
   ArrayResize(m_magics, 0);
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CMultiSymbolManager::~CMultiSymbolManager()
  {
  }

//+------------------------------------------------------------------+
//| Initialize manager                                                |
//+------------------------------------------------------------------+
bool CMultiSymbolManager::Init(string symbol_list, ulong base_magic, int max_per_symbol)
  {
   m_base_magic = base_magic;
   m_max_per_symbol = max_per_symbol;
   
   // Parse symbol list
   string symbols[];
   int count = StringSplit(symbol_list, ',', symbols);
   
   if(count <= 0)
     {
      Print("ERROR: No symbols provided");
      return false;
     }
   
   ArrayResize(m_symbols, count);
   ArrayResize(m_magics, count);
   m_symbol_count = count;
   
   // Assign unique magic number for each symbol
   for(int i = 0; i < count; i++)
     {
      StringTrimLeft(symbols[i]);
      StringTrimRight(symbols[i]);
      m_symbols[i] = symbols[i];
      
      // Generate unique magic from symbol name
      int hash = 0;
      for(int j = 0; j < StringLen(symbols[i]); j++)
        {
         hash += StringGetCharacter(symbols[i], j) * (j + 1);
        }
      
      m_magics[i] = m_base_magic + (hash % 10000);
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Get symbol by index                                               |
//+------------------------------------------------------------------+
string CMultiSymbolManager::GetSymbol(int index)
  {
   if(index < 0 || index >= m_symbol_count)
      return "";
   return m_symbols[index];
  }

//+------------------------------------------------------------------+
//| Get magic number for symbol                                       |
//+------------------------------------------------------------------+
ulong CMultiSymbolManager::GetSymbolMagic(string symbol)
  {
   for(int i = 0; i < m_symbol_count; i++)
     {
      if(m_symbols[i] == symbol)
         return m_magics[i];
     }
   return m_base_magic;
  }

//+------------------------------------------------------------------+
//| Count positions for specific symbol                               |
//+------------------------------------------------------------------+
int CMultiSymbolManager::CountPositions(string symbol, ulong magic)
  {
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == symbol && m_position.Magic() == magic)
           {
            count++;
           }
        }
     }
   
   return count;
  }

//+------------------------------------------------------------------+
//| Count total positions for all managed symbols                     |
//+------------------------------------------------------------------+
int CMultiSymbolManager::CountTotalPositions(ulong base_magic)
  {
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         ulong pos_magic = m_position.Magic();
         
         // Check if this position belongs to any of our managed symbols
         for(int j = 0; j < m_symbol_count; j++)
           {
            if(pos_magic == m_magics[j])
              {
               count++;
               break;
              }
           }
        }
     }
   
   return count;
  }

//+------------------------------------------------------------------+
//| Print symbols info                                                |
//+------------------------------------------------------------------+
void CMultiSymbolManager::PrintSymbols()
  {
   Print("=== Monitoring ", m_symbol_count, " symbols ===");
   for(int i = 0; i < m_symbol_count; i++)
     {
      Print((i+1), ". ", m_symbols[i], " (Magic: ", m_magics[i], ")");
     }
  }
//+------------------------------------------------------------------+

