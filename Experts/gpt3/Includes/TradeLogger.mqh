//+------------------------------------------------------------------+
//|                                              TradeLogger.mqh      |
//|                          Trade Logging Module                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Trade Logger Class                                                |
//+------------------------------------------------------------------+
class CTradeLogger
  {
private:
   string            m_filename;
   bool              m_enabled;
   int               m_file_handle;

public:
                     CTradeLogger();
                    ~CTradeLogger();
   
   bool              Init(string filename, bool enabled);
   void              Deinit();
   
   void              LogMessage(string message);
   void              LogEntry(string symbol, string type, double price, 
                              double sl, double tp, double lot, 
                              string reason, string details);
   void              LogExit(string symbol, ulong ticket, double close_price, 
                             double profit, string reason);
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTradeLogger::CTradeLogger()
  {
   m_filename = "EA_Log.txt";
   m_enabled = false;
   m_file_handle = INVALID_HANDLE;
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTradeLogger::~CTradeLogger()
  {
   Deinit();
  }

//+------------------------------------------------------------------+
//| Initialize logger                                                 |
//+------------------------------------------------------------------+
bool CTradeLogger::Init(string filename, bool enabled)
  {
   m_filename = filename;
   m_enabled = enabled;
   
   if(!m_enabled) return true;
   
   // Create/Open log file
   m_file_handle = FileOpen(m_filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
   if(m_file_handle == INVALID_HANDLE)
     {
      Print("ERROR: Cannot open log file: ", m_filename);
      return false;
     }
   
   FileSeek(m_file_handle, 0, SEEK_END);
   
   string separator = "=================================================";
   FileWrite(m_file_handle, separator);
   FileWrite(m_file_handle, "Bot Log - Started: " + TimeToString(TimeCurrent()));
   FileWrite(m_file_handle, separator);
   
   FileClose(m_file_handle);
   
   return true;
  }

//+------------------------------------------------------------------+
//| Deinitialize logger                                               |
//+------------------------------------------------------------------+
void CTradeLogger::Deinit()
  {
   if(m_file_handle != INVALID_HANDLE)
     {
      FileClose(m_file_handle);
      m_file_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Log message                                                       |
//+------------------------------------------------------------------+
void CTradeLogger::LogMessage(string message)
  {
   if(!m_enabled) return;
   
   int handle = FileOpen(m_filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) return;
   
   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle, TimeToString(TimeCurrent()) + " | INFO | " + message);
   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| Log entry                                                         |
//+------------------------------------------------------------------+
void CTradeLogger::LogEntry(string symbol, string type, double price,
                            double sl, double tp, double lot,
                            string reason, string details)
  {
   if(!m_enabled) return;
   
   int handle = FileOpen(m_filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) return;
   
   FileSeek(handle, 0, SEEK_END);
   
   string log = StringFormat("%s | ENTRY | %s | %s | Price:%.5f | SL:%.5f | TP:%.5f | Lot:%.2f",
                             TimeToString(TimeCurrent()),
                             symbol,
                             type,
                             price,
                             sl,
                             tp,
                             lot);
   
   FileWrite(handle, log);
   FileWrite(handle, "  Reason: " + reason);
   if(details != "") FileWrite(handle, "  Details: " + details);
   
   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| Log exit                                                          |
//+------------------------------------------------------------------+
void CTradeLogger::LogExit(string symbol, ulong ticket, double close_price,
                           double profit, string reason)
  {
   if(!m_enabled) return;
   
   int handle = FileOpen(m_filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) return;
   
   FileSeek(handle, 0, SEEK_END);
   
   string log = StringFormat("%s | EXIT | %s | Ticket:%I64u | Close:%.5f | Profit:%.2f | %s",
                             TimeToString(TimeCurrent()),
                             symbol,
                             ticket,
                             close_price,
                             profit,
                             reason);
   
   FileWrite(handle, log);
   FileClose(handle);
  }
//+------------------------------------------------------------------+

