//+------------------------------------------------------------------+
//|                                                 GPTv3 Enhanced.mq5|
//|                        Enhanced Trading Bot with Advanced Features|
//+------------------------------------------------------------------+
//| ENHANCED FEATURES:                                               |
//| - Real Performance Metrics (Win Rate, Drawdown, Profit Factor)  |
//| - Market Condition Analysis (Trend Strength, Volatility)        |
//| - Position Management (Trailing Stop, Partial Close)            |
//| - Correlation Analysis (Position Risk Management)               |
//| - Multi-Timeframe Pivot Points                                  |
//| - News Filter (Time-based)                                      |
//| - Dynamic Lot Sizing (Volatility-based)                         |
//| - Enhanced Dashboard with Real-time Information                 |
//+------------------------------------------------------------------+
#property strict

#include <ChartObjects\ChartObjectsTxtControls.mqh> // Thư viện để tạo đối tượng văn bản

//--- Input Parameters
// General Parameters
input int AnalysisPeriod = 7; // Number of days for historical analysis
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1; // Trading timeframe
// Removed AssetClasses array to avoid input array issues
input string RiskManagementMode = "FixedLot"; // "FixedLot" or "Risk-Based"
input double FixedLotSize = 0.1; // Fixed lot size
input double RiskPercentage = 2.0; // Risk percentage per trade

// Prediction-Based Strategy Selection Parameters
input double TrendPredictionWeight = 0.4; // Weight for trend prediction accuracy
input double SignalStrengthWeight = 0.3; // Weight for signal strength
input double MarketConditionWeight = 0.3; // Weight for market condition alignment

// Enhanced Risk Management
input int MaxPositionsPerStrategy = 1; // Maximum positions per strategy (1 order per strategy)
input double MaxCorrelationThreshold = 0.7; // Maximum correlation between positions
input bool EnableTrailingStop = true; // Enable trailing stop
input double TrailingStopATRMultiplier = 1.5; // Trailing stop ATR multiplier
input bool EnablePartialClose = true; // Enable partial close
input double PartialClosePercentage = 50.0; // Percentage to close at first target
input double PartialCloseTarget = 1.5; // First target as ATR multiplier

// Market Condition Analysis
input bool EnableMarketFilter = true; // Enable market condition filtering
input int TrendStrengthPeriod = 20; // Period for trend strength calculation
input double VolatilityThreshold = 1.5; // Volatility threshold for market condition
input bool EnableNewsFilter = true; // Enable news filter
input int NewsFilterMinutes = 30; // Minutes before/after news to avoid trading

// Dynamic Lot Sizing
input bool EnableDynamicLotSizing = true; // Enable dynamic lot sizing based on volatility
input double BaseLotSize = 0.1; // Base lot size
input double VolatilityMultiplier = 1.0; // Volatility multiplier for lot sizing
input double MinLotSize = 0.01; // Minimum lot size
input double MaxLotSize = 1.0; // Maximum lot size

// Enhanced Pivot Points
input bool EnableMultiTimeframePivots = true; // Enable multi-timeframe pivot analysis
input ENUM_TIMEFRAMES PivotTimeframe1 = PERIOD_H4; // First pivot timeframe
input ENUM_TIMEFRAMES PivotTimeframe2 = PERIOD_D1; // Second pivot timeframe
input double PivotWeightTimeframe1 = 0.6; // Weight for first timeframe
input double PivotWeightTimeframe2 = 0.4; // Weight for second timeframe

// Strategy-Specific Parameters
// Scalping
input int ScalpingBollingerBandsPeriod = 20;
input double ScalpingATRMultiplier = 1.5;
input double ScalpingSL_ATR_Multiplier = 1.0; // SL dựa trên ATR
input double ScalpingTP_ATR_Multiplier = 2.0; // TP dựa trên ATR

// Swing Trading
input int RSIPeriod = 14;
input int FastMAPeriod = 9;
input int SlowMAPeriod = 21;
input double SwingSL_ATR_Multiplier = 1.5; // SL dựa trên ATR
input double SwingTP_ATR_Multiplier = 3.0; // TP dựa trên ATR

// Breakout
input ENUM_TIMEFRAMES PivotPointPeriodTF = PERIOD_D1; // Pivot Points calculated daily
input double VolumeThreshold = 1.5;
input double BreakoutSL_ATR_Multiplier = 1.0; // SL dựa trên ATR
input double BreakoutTP_ATR_Multiplier = 2.0; // TP dựa trên ATR

// Mean Reversion
input double MeanReversionBollingerBandsDeviation = 2.0;
input double MeanReversionSL_ATR_Multiplier = 1.0; // SL dựa trên ATR
input double MeanReversionTP_ATR_Multiplier = 2.0; // TP dựa trên ATR

//--- Global Variables
datetime last_analysis_time = 0;

// Magic Number for Orders
#define MAGIC_NUMBER 123456

//--- Dashboard Variables
double current_atr = 0.0;
double current_sl = 0.0;
double current_tp = 0.0;
double scalping_score = 0.0;
double swing_score = 0.0;
double breakout_score = 0.0;
double mean_reversion_score = 0.0;

// Enhanced Features Variables
struct PositionInfo {
    ulong ticket;
    string strategy;
    double open_price;
    double current_sl;
    double current_tp;
    double partial_close_target;
    bool partial_closed;
    datetime open_time;
};

PositionInfo open_positions[];
int total_positions = 0;

// Market Condition Variables
bool is_trending_market = false;
bool is_volatile_market = false;
double current_volatility = 0.0;
double trend_strength = 0.0;

// News Filter Variables
datetime last_news_check = 0;
bool is_news_time = false;

// Performance Tracking Variables
struct StrategyPerformance {
    string strategy_name;
    int total_trades;
    int winning_trades;
    double total_profit;
    double max_drawdown;
    double current_drawdown;
    double win_rate;
    double avg_profit;
    double profit_factor;
};

StrategyPerformance strategy_stats[4]; // For 4 strategies

//+------------------------------------------------------------------+
//| Initialize Performance Tracking                                  |
//+------------------------------------------------------------------+
void InitializePerformanceTracking()
{
    string strategy_names[] = {"Scalping", "SwingTrading", "Breakout", "MeanReversion"};
    
    for(int i = 0; i < 4; i++) {
        strategy_stats[i].strategy_name = strategy_names[i];
        strategy_stats[i].total_trades = 0;
        strategy_stats[i].winning_trades = 0;
        strategy_stats[i].total_profit = 0.0;
        strategy_stats[i].max_drawdown = 0.0;
        strategy_stats[i].current_drawdown = 0.0;
        strategy_stats[i].win_rate = 0.0;
        strategy_stats[i].avg_profit = 0.0;
        strategy_stats[i].profit_factor = 0.0;
    }
    
    // Load historical performance data
    LoadHistoricalPerformance();
}

//+------------------------------------------------------------------+
//| Load Historical Performance Data                                |
//+------------------------------------------------------------------+
void LoadHistoricalPerformance()
{
    datetime start_time = TimeCurrent() - (AnalysisPeriod * 24 * 3600);
    
    for(int i = 0; i < 4; i++) {
        CalculateStrategyPerformance(strategy_stats[i], start_time);
    }
}

//+------------------------------------------------------------------+
//| Calculate Strategy Performance                                   |
//+------------------------------------------------------------------+
void CalculateStrategyPerformance(StrategyPerformance &stats, datetime start_time)
{
    double balance_peak = AccountInfoDouble(ACCOUNT_BALANCE);
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double total_profit = 0.0;
    double total_loss = 0.0;
    int winning_trades = 0;
    int total_trades = 0;
    
    // Get deal history
    HistorySelect(start_time, TimeCurrent());
    int deals = HistoryDealsTotal();
    
    for(int i = 0; i < deals; i++) {
        ulong deal_ticket = HistoryDealGetTicket(i);
        if(deal_ticket > 0) {
            string deal_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
            double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            
            // Check if deal belongs to this strategy
            if(StringFind(deal_comment, stats.strategy_name) >= 0) {
                total_trades++;
                total_profit += deal_profit;
                
                if(deal_profit > 0) {
                    winning_trades++;
                } else {
                    total_loss += MathAbs(deal_profit);
                }
                
                // Update balance peak and drawdown
                current_balance += deal_profit;
                if(current_balance > balance_peak) {
                    balance_peak = current_balance;
                }
                
                double drawdown = (balance_peak - current_balance) / balance_peak;
                if(drawdown > stats.max_drawdown) {
                    stats.max_drawdown = drawdown;
                }
            }
        }
    }
    
    // Update statistics
    stats.total_trades = total_trades;
    stats.winning_trades = winning_trades;
    stats.total_profit = total_profit;
    stats.win_rate = (total_trades > 0) ? (double)winning_trades / total_trades : 0.0;
    stats.avg_profit = (total_trades > 0) ? total_profit / total_trades : 0.0;
    stats.profit_factor = (total_loss > 0) ? total_profit / total_loss : 0.0;
    stats.current_drawdown = (balance_peak > 0) ? (balance_peak - current_balance) / balance_peak : 0.0;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Khởi tạo dashboard
    CreateDashboard();
    
    // Initialize performance tracking
    InitializePerformanceTracking();
    
    // Initialize position tracking
    InitializePositionTracking();
    
    // Initialize market condition analysis
    AnalyzeMarketConditions();
    
    // Initialize news filter
    if(EnableNewsFilter) {
        CheckNewsEvents();
    }
    
    Print("GPTv3 Enhanced Trading Bot initialized successfully");
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Xóa các đối tượng dashboard khi EA bị gỡ bỏ
    //ObjectsDeleteAll(0, OBJ_LABEL);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Update position tracking
    UpdatePositionTracking();
    
    // Manage open positions (trailing stop, partial close)
    if(EnableTrailingStop || EnablePartialClose) {
        ManageOpenPositions();
    }
    
    // Check news filter
    if(EnableNewsFilter && TimeCurrent() - last_news_check > 300) { // Check every 5 minutes
        CheckNewsEvents();
        last_news_check = TimeCurrent();
    }
    
    // Update market conditions
    if(EnableMarketFilter && TimeCurrent() - last_analysis_time > 300) { // Update every 5 minutes
        AnalyzeMarketConditions();
    }
    
    // Update performance tracking every minute
    static datetime last_performance_update = 0;
    if(TimeCurrent() - last_performance_update > 60) { // Update every minute
        UpdatePerformanceMetrics();
        last_performance_update = TimeCurrent();
    }
    
    // Perform analysis every 15 minutes for testing
    if(TimeCurrent() - last_analysis_time > 15 * 60)
    {
        // Step 1: Analyze All Strategies for Prediction-Based Selection
        scalping_score = AnalyzeScalping();
        swing_score = AnalyzeSwingTrading();
        breakout_score = AnalyzeBreakout();
        mean_reversion_score = AnalyzeMeanReversion();
        
        Print("Strategy Scores - Scalping: ", scalping_score, ", Swing: ", swing_score, ", Breakout: ", breakout_score, ", MeanReversion: ", mean_reversion_score);
        
        // Step 2: Execute All Strategies Independently (1 order per strategy max)
        if(!is_news_time) {
            Print("Executing all strategies independently...");
            
            // Display current strategy position status
            DisplayStrategyPositionStatus();
            
            // Execute Scalping Strategy
            if(scalping_score > 0.5) { // Only execute if prediction score is high enough
                ExecuteScalping();
            }
            
            // Execute Swing Trading Strategy
            if(swing_score > 0.5) {
                ExecuteSwingTrading();
            }
            
            // Execute Breakout Strategy
            if(breakout_score > 0.5) {
                ExecuteBreakout();
            }
            
            // Execute Mean Reversion Strategy
            if(mean_reversion_score > 0.5) {
                ExecuteMeanReversion();
            }
        } else {
            Print("News filter active - skipping trade execution");
        }
        
        // Step 3: Update Dashboard
        UpdateDashboard();
        
        last_analysis_time = TimeCurrent();
    }
    
    // Update dashboard every 30 seconds for real-time monitoring
    static datetime last_dashboard_update = 0;
    if(TimeCurrent() - last_dashboard_update > 30) { // Update every 30 seconds
        UpdateDashboard();
        last_dashboard_update = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Create Dashboard                                                 |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    // Main Dashboard Title
    CreateLabel("DashboardTitle", "GPTv3 Enhanced Dashboard", 10, 10, 20, clrYellow);
    
    // Market Information Section
    CreateLabel("MarketSectionTitle", "=== MARKET CONDITIONS ===", 10, 35, 14, clrCyan);
    CreateLabel("ATRLabel", "ATR: N/A", 10, 55, 12, clrWhite);
    CreateLabel("VolatilityLabel", "Volatility: N/A", 10, 70, 12, clrWhite);
    CreateLabel("TrendStrengthLabel", "Trend Strength: N/A", 10, 85, 12, clrWhite);
    CreateLabel("MarketConditionLabel", "Market Condition: N/A", 10, 100, 12, clrWhite);
    
    // Position Information Section
    CreateLabel("PositionSectionTitle", "=== POSITION MANAGEMENT ===", 10, 120, 14, clrCyan);
    CreateLabel("TotalPositionsLabel", "Total Positions: N/A", 10, 140, 12, clrWhite);
    CreateLabel("NewsFilterLabel", "News Filter: N/A", 10, 155, 12, clrWhite);
    
    // Strategy Performance Section
    CreateLabel("StrategySectionTitle", "=== STRATEGY PERFORMANCE ===", 10, 175, 14, clrCyan);
    
    // Scalping Strategy Details
    CreateLabel("ScalpingTitle", "SCALPING STRATEGY", 10, 195, 13, clrOrange);
    CreateLabel("ScalpingScore", "Prediction Score: N/A", 10, 210, 11, clrWhite);
    CreateLabel("ScalpingStatus", "Status: N/A", 10, 222, 11, clrWhite);
    CreateLabel("ScalpingTrades", "Total Trades: N/A", 10, 234, 11, clrWhite);
    CreateLabel("ScalpingWinRate", "Win Rate: N/A", 10, 246, 11, clrWhite);
    CreateLabel("ScalpingProfit", "Total Profit: N/A", 10, 258, 11, clrWhite);
    CreateLabel("ScalpingDrawdown", "Max Drawdown: N/A", 10, 270, 11, clrWhite);
    CreateLabel("ScalpingPositions", "Open Positions: N/A", 10, 282, 11, clrWhite);
    
    // Swing Trading Strategy Details
    CreateLabel("SwingTitle", "SWING TRADING STRATEGY", 10, 300, 13, clrOrange);
    CreateLabel("SwingScore", "Prediction Score: N/A", 10, 315, 11, clrWhite);
    CreateLabel("SwingStatus", "Status: N/A", 10, 327, 11, clrWhite);
    CreateLabel("SwingTrades", "Total Trades: N/A", 10, 339, 11, clrWhite);
    CreateLabel("SwingWinRate", "Win Rate: N/A", 10, 351, 11, clrWhite);
    CreateLabel("SwingProfit", "Total Profit: N/A", 10, 363, 11, clrWhite);
    CreateLabel("SwingDrawdown", "Max Drawdown: N/A", 10, 375, 11, clrWhite);
    CreateLabel("SwingPositions", "Open Positions: N/A", 10, 387, 11, clrWhite);
    
    // Breakout Strategy Details
    CreateLabel("BreakoutTitle", "BREAKOUT STRATEGY", 10, 405, 13, clrOrange);
    CreateLabel("BreakoutScore", "Prediction Score: N/A", 10, 420, 11, clrWhite);
    CreateLabel("BreakoutStatus", "Status: N/A", 10, 432, 11, clrWhite);
    CreateLabel("BreakoutTrades", "Total Trades: N/A", 10, 444, 11, clrWhite);
    CreateLabel("BreakoutWinRate", "Win Rate: N/A", 10, 456, 11, clrWhite);
    CreateLabel("BreakoutProfit", "Total Profit: N/A", 10, 468, 11, clrWhite);
    CreateLabel("BreakoutDrawdown", "Max Drawdown: N/A", 10, 480, 11, clrWhite);
    CreateLabel("BreakoutPositions", "Open Positions: N/A", 10, 492, 11, clrWhite);
    
    // Mean Reversion Strategy Details
    CreateLabel("MeanRevTitle", "MEAN REVERSION STRATEGY", 10, 510, 13, clrOrange);
    CreateLabel("MeanRevScore", "Prediction Score: N/A", 10, 525, 11, clrWhite);
    CreateLabel("MeanRevStatus", "Status: N/A", 10, 537, 11, clrWhite);
    CreateLabel("MeanRevTrades", "Total Trades: N/A", 10, 549, 11, clrWhite);
    CreateLabel("MeanRevWinRate", "Win Rate: N/A", 10, 561, 11, clrWhite);
    CreateLabel("MeanRevProfit", "Total Profit: N/A", 10, 573, 11, clrWhite);
    CreateLabel("MeanRevDrawdown", "Max Drawdown: N/A", 10, 585, 11, clrWhite);
    CreateLabel("MeanRevPositions", "Open Positions: N/A", 10, 597, 11, clrWhite);
    
    // Overall Performance Summary
    CreateLabel("SummarySectionTitle", "=== OVERALL PERFORMANCE ===", 10, 615, 14, clrCyan);
    CreateLabel("ActiveStrategiesLabel", "Active Strategies: N/A", 10, 635, 12, clrWhite);
    CreateLabel("OverallWinRateLabel", "Overall Win Rate: N/A", 10, 650, 12, clrWhite);
    CreateLabel("OverallProfitFactorLabel", "Overall Profit Factor: N/A", 10, 665, 12, clrWhite);
    CreateLabel("OverallMaxDrawdownLabel", "Overall Max Drawdown: N/A", 10, 680, 12, clrWhite);
    CreateLabel("TotalProfitLabel", "Total Profit: N/A", 10, 695, 12, clrWhite);
}

//+------------------------------------------------------------------+
//| Create Label Helper Function                                    |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int font_size, color text_color)
{
    if(!ObjectFind(0, name))
    {
        CChartObjectLabel label;
        label.Create(0, name, 0, 0, 0);
        //label.Text(text);
        label.FontSize(font_size);
        label.Color(text_color);
        label.X_Distance(x);
        label.Y_Distance(y);
        label.Corner(CORNER_LEFT_UPPER);
    }
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    // Update Market Information
    current_atr = GetCurrentATR();
    current_volatility = CalculateVolatility();
    UpdateLabel("ATRLabel", StringFormat("ATR: %.4f", current_atr));
    UpdateLabel("VolatilityLabel", StringFormat("Volatility: %.4f", current_volatility));
    
    trend_strength = CalculateTrendStrength();
    UpdateLabel("TrendStrengthLabel", StringFormat("Trend Strength: %.2f", trend_strength));
    
    string market_condition = "Unknown";
    if(is_trending_market && is_volatile_market) market_condition = "Trending & Volatile";
    else if(is_trending_market) market_condition = "Trending";
    else if(is_volatile_market) market_condition = "Volatile";
    else market_condition = "Sideways";
    UpdateLabel("MarketConditionLabel", StringFormat("Market Condition: %s", market_condition));
    
    // Update Position Information
    UpdateLabel("TotalPositionsLabel", StringFormat("Total Positions: %d", total_positions));
    
    string news_status = is_news_time ? "ACTIVE - No Trading" : "Inactive";
    color news_color = is_news_time ? clrRed : clrGreen;
    UpdateLabel("NewsFilterLabel", StringFormat("News Filter: %s", news_status), news_color);
    
    // Update Strategy Performance Details
    UpdateStrategyPerformance("Scalping", 0, scalping_score);
    UpdateStrategyPerformance("Swing", 1, swing_score);
    UpdateStrategyPerformance("Breakout", 2, breakout_score);
    UpdateStrategyPerformance("MeanRev", 3, mean_reversion_score);
    
    // Update Overall Performance Summary
    UpdateOverallPerformance();
}

//+------------------------------------------------------------------+
//| Update Individual Strategy Performance                           |
//+------------------------------------------------------------------+
void UpdateStrategyPerformance(string strategy_prefix, int strategy_index, double prediction_score)
{
    // Get strategy statistics
    StrategyPerformance stats = strategy_stats[strategy_index];
    
    // Update prediction score
    UpdateLabel(strategy_prefix + "Score", StringFormat("Prediction Score: %.2f", prediction_score));
    
    // Update status (Active/Inactive based on prediction score)
    string status = (prediction_score > 0.5) ? "ACTIVE" : "Inactive";
    color status_color = (prediction_score > 0.5) ? clrLime : clrGray;
    UpdateLabel(strategy_prefix + "Status", StringFormat("Status: %s", status), status_color);
    
    // Update trade statistics
    UpdateLabel(strategy_prefix + "Trades", StringFormat("Total Trades: %d", stats.total_trades));
    
    // Update win rate with color coding
    color win_rate_color = clrWhite;
    if(stats.win_rate > 0.6) win_rate_color = clrLime;
    else if(stats.win_rate < 0.4) win_rate_color = clrRed;
    UpdateLabel(strategy_prefix + "WinRate", StringFormat("Win Rate: %.1f%%", stats.win_rate * 100), win_rate_color);
    
    // Update total profit with color coding
    color profit_color = (stats.total_profit > 0) ? clrLime : clrRed;
    UpdateLabel(strategy_prefix + "Profit", StringFormat("Total Profit: %.2f", stats.total_profit), profit_color);
    
    // Update max drawdown with color coding
    color drawdown_color = clrWhite;
    if(stats.max_drawdown > 0.1) drawdown_color = clrRed;
    else if(stats.max_drawdown < 0.05) drawdown_color = clrLime;
    UpdateLabel(strategy_prefix + "Drawdown", StringFormat("Max Drawdown: %.1f%%", stats.max_drawdown * 100), drawdown_color);
    
    // Count open positions for this strategy
    int open_positions_count = CountOpenPositionsForStrategy(strategy_index);
    string position_status = (open_positions_count > 0) ? "ACTIVE (" + IntegerToString(open_positions_count) + ")" : "AVAILABLE";
    color position_color = (open_positions_count > 0) ? clrOrange : clrLime;
    UpdateLabel(strategy_prefix + "Positions", StringFormat("Status: %s", position_status), position_color);
}

//+------------------------------------------------------------------+
//| Count Open Positions for Specific Strategy                       |
//+------------------------------------------------------------------+
int CountOpenPositionsForStrategy(int strategy_index)
{
    int count = 0;
    string strategy_names[] = {"Scalping", "SwingTrading", "Breakout", "MeanReversion"};
    string target_strategy = strategy_names[strategy_index];
    
    for(int i = 0; i < total_positions; i++) {
        if(StringFind(open_positions[i].strategy, target_strategy) >= 0) {
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Update Overall Performance Summary                               |
//+------------------------------------------------------------------+
void UpdateOverallPerformance()
{
    // Calculate active strategies
    string active_strategies = "";
    if(scalping_score > 0.5) active_strategies += "Scalping ";
    if(swing_score > 0.5) active_strategies += "Swing ";
    if(breakout_score > 0.5) active_strategies += "Breakout ";
    if(mean_reversion_score > 0.5) active_strategies += "MeanRev ";
    
    if(active_strategies == "") active_strategies = "None";
    UpdateLabel("ActiveStrategiesLabel", StringFormat("Active Strategies: %s", active_strategies));
    
    // Calculate overall metrics
    double overall_win_rate = CalculateOverallWinRate();
    double overall_profit_factor = CalculateOverallProfitFactor();
    double overall_max_drawdown = CalculateOverallMaxDrawdown();
    double total_profit = CalculateTotalProfit();
    
    // Update overall performance with color coding
    color win_rate_color = (overall_win_rate > 0.6) ? clrLime : (overall_win_rate < 0.4) ? clrRed : clrWhite;
    UpdateLabel("OverallWinRateLabel", StringFormat("Overall Win Rate: %.1f%%", overall_win_rate * 100), win_rate_color);
    
    color profit_factor_color = (overall_profit_factor > 1.5) ? clrLime : (overall_profit_factor < 1.0) ? clrRed : clrWhite;
    UpdateLabel("OverallProfitFactorLabel", StringFormat("Overall Profit Factor: %.2f", overall_profit_factor), profit_factor_color);
    
    color drawdown_color = (overall_max_drawdown > 0.1) ? clrRed : (overall_max_drawdown < 0.05) ? clrLime : clrWhite;
    UpdateLabel("OverallMaxDrawdownLabel", StringFormat("Overall Max Drawdown: %.1f%%", overall_max_drawdown * 100), drawdown_color);
    
    color total_profit_color = (total_profit > 0) ? clrLime : clrRed;
    UpdateLabel("TotalProfitLabel", StringFormat("Total Profit: %.2f", total_profit), total_profit_color);
}

//+------------------------------------------------------------------+
//| Calculate Total Profit                                           |
//+------------------------------------------------------------------+
double CalculateTotalProfit()
{
    double total_profit = 0.0;
    
    for(int i = 0; i < 4; i++) {
        total_profit += strategy_stats[i].total_profit;
    }
    
    return total_profit;
}

//+------------------------------------------------------------------+
//| Get Current ATR                                                  |
//+------------------------------------------------------------------+
double GetCurrentATR()
{
    // Tạo handle cho chỉ báo ATR với chu kỳ 14
    int atr_handle = iATR(_Symbol, Timeframe, 14);
    if(atr_handle == INVALID_HANDLE)
    {
        Print("Error creating ATR handle: ", GetLastError());
        return 0.0;
    }

    double atr[];
    // Lấy giá trị ATR gần nhất
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0)
    {
        Print("Error copying ATR data: ", GetLastError());
        IndicatorRelease(atr_handle);
        return 0.0;
    }

    IndicatorRelease(atr_handle);
    return atr[0];
}

//+------------------------------------------------------------------+
//| Update Label Helper Function                                    |
//+------------------------------------------------------------------+
void UpdateLabel(string name, string text, color text_color = clrWhite)
{
    if(ObjectFind(0, name) >= 0)
    {
        CChartObjectLabel label;
        label.Create(0, name, 0, 0, 0);
        //label.Text(text);
        label.Color(text_color);
    }
}

//+------------------------------------------------------------------+
//| Prediction-Based Strategy Analysis Functions                    |
//+------------------------------------------------------------------+
double AnalyzeScalping()
{
    // Calculate trend prediction accuracy
    double trend_prediction = CalculateTrendPrediction("Scalping");
    
    // Calculate signal strength
    double signal_strength = CalculateSignalStrength("Scalping");
    
    // Calculate market condition alignment
    double market_alignment = CalculateMarketAlignment("Scalping");
    
    // Combine scores
    double score = trend_prediction * TrendPredictionWeight + 
                   signal_strength * SignalStrengthWeight + 
                   market_alignment * MarketConditionWeight;
    
    Print("Scalping Analysis - Trend Prediction: ", trend_prediction, ", Signal Strength: ", signal_strength, ", Market Alignment: ", market_alignment, ", Final Score: ", score);
    
    return score;
}

double AnalyzeSwingTrading()
{
    // Calculate trend prediction accuracy
    double trend_prediction = CalculateTrendPrediction("SwingTrading");
    
    // Calculate signal strength
    double signal_strength = CalculateSignalStrength("SwingTrading");
    
    // Calculate market condition alignment
    double market_alignment = CalculateMarketAlignment("SwingTrading");
    
    // Combine scores
    double score = trend_prediction * TrendPredictionWeight + 
                   signal_strength * SignalStrengthWeight + 
                   market_alignment * MarketConditionWeight;
    
    Print("Swing Trading Analysis - Trend Prediction: ", trend_prediction, ", Signal Strength: ", signal_strength, ", Market Alignment: ", market_alignment, ", Final Score: ", score);
    
    return score;
}

double AnalyzeBreakout()
{
    // Calculate trend prediction accuracy
    double trend_prediction = CalculateTrendPrediction("Breakout");
    
    // Calculate signal strength
    double signal_strength = CalculateSignalStrength("Breakout");
    
    // Calculate market condition alignment
    double market_alignment = CalculateMarketAlignment("Breakout");
    
    // Combine scores
    double score = trend_prediction * TrendPredictionWeight + 
                   signal_strength * SignalStrengthWeight + 
                   market_alignment * MarketConditionWeight;
    
    Print("Breakout Analysis - Trend Prediction: ", trend_prediction, ", Signal Strength: ", signal_strength, ", Market Alignment: ", market_alignment, ", Final Score: ", score);
    
    return score;
}

double AnalyzeMeanReversion()
{
    // Calculate trend prediction accuracy
    double trend_prediction = CalculateTrendPrediction("MeanReversion");
    
    // Calculate signal strength
    double signal_strength = CalculateSignalStrength("MeanReversion");
    
    // Calculate market condition alignment
    double market_alignment = CalculateMarketAlignment("MeanReversion");
    
    // Combine scores
    double score = trend_prediction * TrendPredictionWeight + 
                   signal_strength * SignalStrengthWeight + 
                   market_alignment * MarketConditionWeight;
    
    Print("Mean Reversion Analysis - Trend Prediction: ", trend_prediction, ", Signal Strength: ", signal_strength, ", Market Alignment: ", market_alignment, ", Final Score: ", score);
    
    return score;
}

//+------------------------------------------------------------------+
//| Prediction-Based Analysis Functions                              |
//+------------------------------------------------------------------+
double CalculateTrendPrediction(string strategy)
{
    double prediction_score = 0.0;
    
    if(StringCompare(strategy, "Scalping") == 0) {
        // Scalping: Predict short-term price movement based on Bollinger Bands
        prediction_score = CalculateBollingerBandsPrediction();
    }
    else if(StringCompare(strategy, "SwingTrading") == 0) {
        // Swing Trading: Predict medium-term trend based on RSI + MA crossover
        prediction_score = CalculateRSIMAPrediction();
    }
    else if(StringCompare(strategy, "Breakout") == 0) {
        // Breakout: Predict breakout direction based on pivot points and volume
        prediction_score = CalculateBreakoutPrediction();
    }
    else if(StringCompare(strategy, "MeanReversion") == 0) {
        // Mean Reversion: Predict reversal based on extreme Bollinger Bands
        prediction_score = CalculateMeanReversionPrediction();
    }
    
    return MathMax(0.0, MathMin(1.0, prediction_score)); // Normalize to 0-1
}

//+------------------------------------------------------------------+
//| Calculate Bollinger Bands Prediction for Scalping               |
//+------------------------------------------------------------------+
double CalculateBollingerBandsPrediction()
{
    int bb_handle = iBands(_Symbol, Timeframe, ScalpingBollingerBandsPeriod, 2, 0, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) return 0.0;
    
    double upper[], lower[], middle[];
    if(CopyBuffer(bb_handle, 0, 0, 2, upper) <= 0 || 
       CopyBuffer(bb_handle, 1, 0, 2, middle) <= 0 ||
       CopyBuffer(bb_handle, 2, 0, 2, lower) <= 0) {
        IndicatorRelease(bb_handle);
        return 0.0;
    }
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double bb_width = (upper[0] - lower[0]) / middle[0]; // Bollinger Bands width
    double price_position = (current_price - lower[0]) / (upper[0] - lower[0]); // Price position within bands
    
    // Calculate prediction score based on:
    // 1. BB width (narrower = higher prediction confidence)
    // 2. Price position (extreme positions = higher reversal probability)
    double width_score = MathMax(0.0, 1.0 - bb_width * 10); // Narrower bands = higher score
    double position_score = MathAbs(price_position - 0.5) * 2; // Extreme positions = higher score
    
    double prediction_score = (width_score * 0.6) + (position_score * 0.4);
    
    IndicatorRelease(bb_handle);
    return prediction_score;
}

//+------------------------------------------------------------------+
//| Calculate RSI + MA Prediction for Swing Trading                 |
//+------------------------------------------------------------------+
double CalculateRSIMAPrediction()
{
    // RSI
    int rsi_handle = iRSI(_Symbol, Timeframe, RSIPeriod, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return 0.0;
    
    double rsi[];
    if(CopyBuffer(rsi_handle, 0, 0, 2, rsi) <= 0) {
        IndicatorRelease(rsi_handle);
        return 0.0;
    }
    
    // Moving Averages
    int ma_fast_handle = iMA(_Symbol, Timeframe, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    int ma_slow_handle = iMA(_Symbol, Timeframe, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    
    if(ma_fast_handle == INVALID_HANDLE || ma_slow_handle == INVALID_HANDLE) {
        IndicatorRelease(rsi_handle);
        return 0.0;
    }
    
    double ma_fast[], ma_slow[];
    if(CopyBuffer(ma_fast_handle, 0, 0, 2, ma_fast) <= 0 || 
       CopyBuffer(ma_slow_handle, 0, 0, 2, ma_slow) <= 0) {
        IndicatorRelease(rsi_handle);
        IndicatorRelease(ma_fast_handle);
        IndicatorRelease(ma_slow_handle);
        return 0.0;
    }
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate prediction score based on:
    // 1. RSI extreme levels (oversold/overbought)
    // 2. MA crossover signals
    // 3. Price position relative to MAs
    
    double rsi_score = 0.0;
    if(rsi[0] < 30) rsi_score = (30 - rsi[0]) / 30; // Oversold
    else if(rsi[0] > 70) rsi_score = (rsi[0] - 70) / 30; // Overbought
    
    double ma_score = 0.0;
    if(ma_fast[0] > ma_slow[0] && ma_fast[1] <= ma_slow[1]) ma_score = 1.0; // Bullish crossover
    else if(ma_fast[0] < ma_slow[0] && ma_fast[1] >= ma_slow[1]) ma_score = 1.0; // Bearish crossover
    
    double price_score = 0.0;
    if(current_price > ma_fast[0] && current_price > ma_slow[0]) price_score = 0.5; // Above MAs
    else if(current_price < ma_fast[0] && current_price < ma_slow[0]) price_score = 0.5; // Below MAs
    
    double prediction_score = (rsi_score * 0.4) + (ma_score * 0.4) + (price_score * 0.2);
    
    IndicatorRelease(rsi_handle);
    IndicatorRelease(ma_fast_handle);
    IndicatorRelease(ma_slow_handle);
    return prediction_score;
}

//+------------------------------------------------------------------+
//| Calculate Breakout Prediction                                    |
//+------------------------------------------------------------------+
double CalculateBreakoutPrediction()
{
    double pivot = CalculateEnhancedPivotPoint();
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate support and resistance levels
    double resistance = pivot + 0.0010;
    double support = pivot - 0.0010;
    
    // Calculate prediction score based on:
    // 1. Distance to breakout levels
    // 2. Recent price action (consolidation vs trending)
    // 3. Volume confirmation
    
    double distance_to_resistance = MathAbs(current_price - resistance) / current_price;
    double distance_to_support = MathAbs(current_price - support) / current_price;
    
    // Closer to breakout levels = higher prediction score
    double local_breakout_score = MathMax(0.0, 1.0 - MathMin(distance_to_resistance, distance_to_support) * 100);
    
    // Check for consolidation pattern (price near pivot)
    double consolidation_score = 0.0;
    if(MathAbs(current_price - pivot) / current_price < 0.0005) {
        consolidation_score = 1.0; // Price is consolidating near pivot
    }
    
    double prediction_score = (local_breakout_score * 0.7) + (consolidation_score * 0.3);
    return prediction_score;
}

//+------------------------------------------------------------------+
//| Calculate Mean Reversion Prediction                              |
//+------------------------------------------------------------------+
double CalculateMeanReversionPrediction()
{
    int bb_handle = iBands(_Symbol, Timeframe, ScalpingBollingerBandsPeriod, MeanReversionBollingerBandsDeviation, 0, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) return 0.0;
    
    double upper[], lower[], middle[];
    if(CopyBuffer(bb_handle, 0, 0, 2, upper) <= 0 || 
       CopyBuffer(bb_handle, 1, 0, 2, middle) <= 0 ||
       CopyBuffer(bb_handle, 2, 0, 2, lower) <= 0) {
        IndicatorRelease(bb_handle);
        return 0.0;
    }
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate prediction score based on:
    // 1. Distance from mean (middle band)
    // 2. Bollinger Bands width (narrower = higher mean reversion probability)
    // 3. Price momentum towards mean
    
    double distance_from_mean = MathAbs(current_price - middle[0]) / middle[0];
    double bb_width = (upper[0] - lower[0]) / middle[0];
    
    // Higher distance from mean = higher reversal probability
    double distance_score = MathMin(1.0, distance_from_mean * 100);
    
    // Narrower bands = higher mean reversion probability
    double width_score = MathMax(0.0, 1.0 - bb_width * 5);
    
    // Check if price is moving towards mean
    double momentum_score = 0.0;
    if(current_price > middle[0] && current_price < upper[1]) momentum_score = 0.5; // Moving down towards mean
    else if(current_price < middle[0] && current_price > lower[1]) momentum_score = 0.5; // Moving up towards mean
    
    double prediction_score = (distance_score * 0.5) + (width_score * 0.3) + (momentum_score * 0.2);
    
    IndicatorRelease(bb_handle);
    return prediction_score;
}

//+------------------------------------------------------------------+
//| Calculate Signal Strength                                        |
//+------------------------------------------------------------------+
double CalculateSignalStrength(string strategy)
{
    double signal_strength = 0.0;
    
    if(StringCompare(strategy, "Scalping") == 0) {
        // Scalping signal strength based on Bollinger Bands squeeze
        signal_strength = CalculateBollingerBandsSignalStrength();
    }
    else if(StringCompare(strategy, "SwingTrading") == 0) {
        // Swing Trading signal strength based on RSI divergence and MA alignment
        signal_strength = CalculateRSISignalStrength();
    }
    else if(StringCompare(strategy, "Breakout") == 0) {
        // Breakout signal strength based on volume and price action
        signal_strength = CalculateBreakoutSignalStrength();
    }
    else if(StringCompare(strategy, "MeanReversion") == 0) {
        // Mean Reversion signal strength based on extreme RSI and price position
        signal_strength = CalculateMeanReversionSignalStrength();
    }
    
    return MathMax(0.0, MathMin(1.0, signal_strength));
}

//+------------------------------------------------------------------+
//| Calculate Market Alignment                                       |
//+------------------------------------------------------------------+
double CalculateMarketAlignment(string strategy)
{
    double alignment = 0.0;
    
    if(StringCompare(strategy, "Scalping") == 0) {
        // Scalping works best in volatile markets
        alignment = is_volatile_market ? 1.0 : 0.3;
    }
    else if(StringCompare(strategy, "SwingTrading") == 0) {
        // Swing Trading works best in trending markets
        alignment = is_trending_market ? 1.0 : 0.3;
    }
    else if(StringCompare(strategy, "Breakout") == 0) {
        // Breakout works best in trending markets with low volatility
        alignment = (is_trending_market && !is_volatile_market) ? 1.0 : 0.3;
    }
    else if(StringCompare(strategy, "MeanReversion") == 0) {
        // Mean Reversion works best in sideways markets
        alignment = (!is_trending_market) ? 1.0 : 0.3;
    }
    
    return alignment;
}

//+------------------------------------------------------------------+
//| Signal Strength Calculation Functions                            |
//+------------------------------------------------------------------+
double CalculateBollingerBandsSignalStrength()
{
    int bb_handle = iBands(_Symbol, Timeframe, ScalpingBollingerBandsPeriod, 2, 0, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) return 0.0;
    
    double upper[], lower[];
    if(CopyBuffer(bb_handle, 0, 0, 5, upper) <= 0 || CopyBuffer(bb_handle, 2, 0, 5, lower) <= 0) {
        IndicatorRelease(bb_handle);
        return 0.0;
    }
    
    // Calculate BB squeeze (narrowing bands)
    double bb_width_current = upper[0] - lower[0];
    double bb_width_avg = 0.0;
    for(int i = 0; i < 5; i++) {
        bb_width_avg += (upper[i] - lower[i]);
    }
    bb_width_avg /= 5.0;
    
    // Stronger signal if bands are squeezing
    double squeeze_strength = MathMax(0.0, 1.0 - (bb_width_current / bb_width_avg));
    
    IndicatorRelease(bb_handle);
    return squeeze_strength;
}

double CalculateRSISignalStrength()
{
    int rsi_handle = iRSI(_Symbol, Timeframe, RSIPeriod, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return 0.0;
    
    double rsi[];
    if(CopyBuffer(rsi_handle, 0, 0, 3, rsi) <= 0) {
        IndicatorRelease(rsi_handle);
        return 0.0;
    }
    
    // Calculate RSI momentum and divergence
    double rsi_momentum = MathAbs(rsi[0] - rsi[2]);
    double rsi_strength = 0.0;
    
    if(rsi[0] < 30) rsi_strength = (30 - rsi[0]) / 30; // Oversold strength
    else if(rsi[0] > 70) rsi_strength = (rsi[0] - 70) / 30; // Overbought strength
    
    double signal_strength = (rsi_momentum * 0.5) + (rsi_strength * 0.5);
    
    IndicatorRelease(rsi_handle);
    return signal_strength;
}

double CalculateBreakoutSignalStrength()
{
    // Calculate volume-based signal strength
    double volume_strength = 1.0; // Placeholder - would need volume data
    
    // Calculate price action strength
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double high_1 = iHigh(_Symbol, Timeframe, 1);
    double low_1 = iLow(_Symbol, Timeframe, 1);
    
    double price_range = (high_1 - low_1) / current_price;
    double range_strength = MathMin(1.0, price_range * 100); // Higher range = stronger signal
    
    return (volume_strength * 0.6) + (range_strength * 0.4);
}

double CalculateMeanReversionSignalStrength()
{
    int rsi_handle = iRSI(_Symbol, Timeframe, RSIPeriod, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return 0.0;
    
    double rsi[];
    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) <= 0) {
        IndicatorRelease(rsi_handle);
        return 0.0;
    }
    
    // Calculate extreme RSI signal strength
    double rsi_strength = 0.0;
    if(rsi[0] < 20) rsi_strength = (20 - rsi[0]) / 20; // Very oversold
    else if(rsi[0] > 80) rsi_strength = (rsi[0] - 80) / 20; // Very overbought
    
    IndicatorRelease(rsi_handle);
    return rsi_strength;
}

//+------------------------------------------------------------------+
//| Market Condition Analysis Functions                              |
//+------------------------------------------------------------------+
void AnalyzeMarketConditions()
{
    // Calculate trend strength
    trend_strength = CalculateTrendStrength();
    
    // Calculate volatility
    current_volatility = CalculateVolatility();
    
    // Determine market conditions - Lower thresholds for testing
    is_trending_market = (trend_strength > 0.01); // Lowered from 0.6
    is_volatile_market = (current_volatility > 0.001); // Lowered from VolatilityThreshold
    
    Print("Market Analysis - Trend Strength: ", trend_strength, ", Volatility: ", current_volatility);
    Print("Market Conditions - Trending: ", is_trending_market, ", Volatile: ", is_volatile_market);
}

//+------------------------------------------------------------------+
//| Calculate Trend Strength                                         |
//+------------------------------------------------------------------+
double CalculateTrendStrength()
{
    int ma_handle = iMA(_Symbol, Timeframe, TrendStrengthPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if(ma_handle == INVALID_HANDLE) {
        Print("Error creating MA handle for trend strength: ", GetLastError());
        return 0.0;
    }
    
    double ma_values[];
    if(CopyBuffer(ma_handle, 0, 0, TrendStrengthPeriod + 1, ma_values) <= 0) {
        Print("Error copying MA data: ", GetLastError());
        IndicatorRelease(ma_handle);
        return 0.0;
    }
    
    IndicatorRelease(ma_handle);
    
    // Calculate trend strength based on price position relative to MA
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ma_current = ma_values[0];
    double ma_previous = ma_values[TrendStrengthPeriod];
    
    // Calculate how much price has moved relative to MA
    double price_deviation = MathAbs(current_price - ma_current) / ma_current;
    double ma_slope = (ma_current - ma_previous) / ma_previous;
    
    // Combine price deviation and MA slope for trend strength
    double calculated_trend_strength = (price_deviation * 0.7) + (MathAbs(ma_slope) * 0.3);
    
    return MathMin(calculated_trend_strength, 1.0); // Normalize to 0-1
}

//+------------------------------------------------------------------+
//| Calculate Volatility                                             |
//+------------------------------------------------------------------+
double CalculateVolatility()
{
    int atr_handle = iATR(_Symbol, Timeframe, 14);
    if(atr_handle == INVALID_HANDLE) {
        Print("Error creating ATR handle for volatility: ", GetLastError());
        return 0.0;
    }
    
    double atr_values[];
    if(CopyBuffer(atr_handle, 0, 0, 20, atr_values) <= 0) {
        Print("Error copying ATR data: ", GetLastError());
        IndicatorRelease(atr_handle);
        return 0.0;
    }
    
    IndicatorRelease(atr_handle);
    
    // Calculate average ATR over the period
    double avg_atr = 0.0;
    for(int i = 0; i < 20; i++) {
        avg_atr += atr_values[i];
    }
    avg_atr /= 20.0;
    
    // Normalize volatility relative to current price
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double normalized_volatility = avg_atr / current_price;
    
    return normalized_volatility;
}

//+------------------------------------------------------------------+
//| Check if Market Conditions are Favorable                        |
//+------------------------------------------------------------------+
bool IsMarketConditionFavorable(string strategy)
{
    if(!EnableMarketFilter) return true;
    
    if(StringCompare(strategy, "Scalping") == 0) {
        // Scalping works better in volatile markets
        return is_volatile_market;
    }
    else if(StringCompare(strategy, "SwingTrading") == 0) {
        // Swing trading works better in trending markets
        return is_trending_market;
    }
    else if(StringCompare(strategy, "Breakout") == 0) {
        // Breakout works better in trending markets with low volatility
        return is_trending_market && !is_volatile_market;
    }
    else if(StringCompare(strategy, "MeanReversion") == 0) {
        // Mean reversion works better in sideways markets
        return !is_trending_market;
    }
    
    return true; // Default to true if strategy not recognized
}

//+------------------------------------------------------------------+
//| Strategy Execution Functions                                    |
//+------------------------------------------------------------------+
void ExecuteScalping()
{
    // Check market conditions - Temporarily disabled for testing
    // if(!IsMarketConditionFavorable("Scalping")) {
    //     Print("Market conditions not favorable for Scalping strategy");
    //     return;
    // }
    
    // Implement Scalping strategy execution
    Print("Executing Scalping Strategy...");
    // Calculate Bollinger Bands
    int bb_handle = iBands(_Symbol, Timeframe, ScalpingBollingerBandsPeriod, 2, 0, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE)
    {
        Print("Error creating Bollinger Bands handle: ", GetLastError());
        return;
    }
    
    double upper[], lower[];
    // CopyBuffer indices: 0 - Upper Band, 1 - Middle Band, 2 - Lower Band
    if(CopyBuffer(bb_handle, 0, 0, 1, upper) <= 0 || CopyBuffer(bb_handle, 2, 0, 1, lower) <= 0)
    {
        Print("Error copying Bollinger Bands data: ", GetLastError());
        IndicatorRelease(bb_handle);
        return;
    }
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Example Buy Signal
    if(current_price < lower[0])
    {
        Print("Scalping BUY Signal - Price: ", current_price, " < Lower Band: ", lower[0]);
        OpenBuyOrder("Scalping");
    }
    
    // Example Sell Signal
    if(current_price > upper[0])
    {
        Print("Scalping SELL Signal - Price: ", current_price, " > Upper Band: ", upper[0]);
        OpenSellOrder("Scalping");
    }
    
    Print("Scalping Analysis - Current Price: ", current_price, ", Upper: ", upper[0], ", Lower: ", lower[0]);
    
    // Release indicator handle
    IndicatorRelease(bb_handle);
}

void ExecuteSwingTrading()
{
    // Check market conditions - Temporarily disabled for testing
    // if(!IsMarketConditionFavorable("SwingTrading")) {
    //     Print("Market conditions not favorable for Swing Trading strategy");
    //     return;
    // }
    
    // Implement Swing Trading strategy execution
    Print("Executing Swing Trading Strategy...");
    // RSI
    int rsi_handle = iRSI(_Symbol, Timeframe, RSIPeriod, PRICE_CLOSE);
    // handle_iRSI=iRSI(m_symbol.Name(),Period(),rsi_ma_period,PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE)
    {
        Print("Error creating RSI handle: ", GetLastError());
        return;
    }
    
    double rsi[];
    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) <= 0)
    {
        Print("Error copying RSI data: ", GetLastError());
        IndicatorRelease(rsi_handle);
        return;
    }
    
    // Fast MA
    int ma_fast_handle = iMA(_Symbol, Timeframe, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if(ma_fast_handle == INVALID_HANDLE)
    {
        Print("Error creating Fast MA handle: ", GetLastError());
        IndicatorRelease(rsi_handle);
        return;
    }
    
    double ma_fast[];
    if(CopyBuffer(ma_fast_handle, 0, 0, 1, ma_fast) <= 0)
    {
        Print("Error copying Fast MA data: ", GetLastError());
        IndicatorRelease(rsi_handle);
        IndicatorRelease(ma_fast_handle);
        return;
    }
    
    // Slow MA
    int ma_slow_handle = iMA(_Symbol, Timeframe, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if(ma_slow_handle == INVALID_HANDLE)
    {
        Print("Error creating Slow MA handle: ", GetLastError());
        IndicatorRelease(rsi_handle);
        IndicatorRelease(ma_fast_handle);
        return;
    }
    
    double ma_slow[];
    if(CopyBuffer(ma_slow_handle, 0, 0, 1, ma_slow) <= 0)
    {
        Print("Error copying Slow MA data: ", GetLastError());
        IndicatorRelease(rsi_handle);
        IndicatorRelease(ma_fast_handle);
        IndicatorRelease(ma_slow_handle);
        return;
    }
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Buy Condition
    if(rsi[0] < 30 && current_price < ma_fast[0] && current_price > ma_slow[0])
    {
        Print("Swing Trading BUY Signal - RSI: ", rsi[0], ", Price: ", current_price, ", Fast MA: ", ma_fast[0], ", Slow MA: ", ma_slow[0]);
        OpenBuyOrder("SwingTrading");
    }
    
    // Sell Condition
    if(rsi[0] > 70 && current_price > ma_fast[0] && current_price < ma_slow[0])
    {
        Print("Swing Trading SELL Signal - RSI: ", rsi[0], ", Price: ", current_price, ", Fast MA: ", ma_fast[0], ", Slow MA: ", ma_slow[0]);
        OpenSellOrder("SwingTrading");
    }
    
    Print("Swing Trading Analysis - RSI: ", rsi[0], ", Price: ", current_price, ", Fast MA: ", ma_fast[0], ", Slow MA: ", ma_slow[0]);
    
    // Release indicator handles
    IndicatorRelease(rsi_handle);
    IndicatorRelease(ma_fast_handle);
    IndicatorRelease(ma_slow_handle);
}

void ExecuteBreakout()
{
    // Check market conditions - Temporarily disabled for testing
    // if(!IsMarketConditionFavorable("Breakout")) {
    //     Print("Market conditions not favorable for Breakout strategy");
    //     return;
    // }
    
    // Implement Breakout strategy execution
    Print("Executing Breakout Strategy...");
    // Calculate Pivot Point
    double pivot = CalculateEnhancedPivotPoint();
    double resistance = pivot + 0.0010; // Example offset, cần điều chỉnh theo tài sản
    double support = pivot - 0.0010; // Example offset, cần điều chỉnh theo tài sản
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Example Buy Signal
    if(current_price > resistance)
    {
        OpenBuyOrder("Breakout");
    }
    
    // Example Sell Signal
    if(current_price < support)
    {
        OpenSellOrder("Breakout");
    }
}

void ExecuteMeanReversion()
{
    // Check market conditions - Temporarily disabled for testing
    // if(!IsMarketConditionFavorable("MeanReversion")) {
    //     Print("Market conditions not favorable for Mean Reversion strategy");
    //     return;
    // }
    
    // Implement Mean Reversion strategy execution
    Print("Executing Mean Reversion Strategy...");
    // Calculate Bollinger Bands
    int bb_handle = iBands(_Symbol, Timeframe, ScalpingBollingerBandsPeriod, MeanReversionBollingerBandsDeviation, 0, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE)
    {
        Print("Error creating Bollinger Bands handle: ", GetLastError());
        return;
    }
    
    double upper[], lower[], middle[];
    // CopyBuffer indices: 0 - Upper Band, 1 - Middle Band, 2 - Lower Band
    if(CopyBuffer(bb_handle, 0, 0, 1, upper) <= 0 ||
       CopyBuffer(bb_handle, 1, 0, 1, middle) <= 0 ||
       CopyBuffer(bb_handle, 2, 0, 1, lower) <= 0)
    {
        Print("Error copying Bollinger Bands data: ", GetLastError());
        IndicatorRelease(bb_handle);
        return;
    }
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Buy Signal
    if(current_price < lower[0])
    {
        OpenBuyOrder("MeanReversion");
    }
    
    // Sell Signal
    if(current_price > upper[0])
    {
        OpenSellOrder("MeanReversion");
    }
    
    // Release indicator handle
    IndicatorRelease(bb_handle);
}

//+------------------------------------------------------------------+
//| Order Execution Functions                                       |
//+------------------------------------------------------------------+
void OpenBuyOrder(string strategy)
{
    // Check if strategy already has an open position
    if(HasStrategyOpenPosition(strategy)) {
        Print("Strategy ", strategy, " already has an open position. Skipping new order.");
        return;
    }
    
    Print("Attempting to open BUY order for strategy: ", strategy);
    double lot_size = CalculateDynamicLotSize(strategy);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = price - CalculateStopLoss(strategy);
    double tp = price + CalculateTakeProfit(strategy);
    
    Print("Order Details - Lot: ", lot_size, ", Price: ", price, ", SL: ", sl, ", TP: ", tp);
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot_size;
    request.type = ORDER_TYPE_BUY;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = MAGIC_NUMBER;
    request.comment = "Buy Order - " + strategy;
    
    if(!OrderSend(request, result))
    {
        Print("Error opening Buy Order: ", result.comment);
    }
    else
    {
        Print("Buy Order opened successfully. Ticket: ", result.order);
    }
}

void OpenSellOrder(string strategy)
{
    // Check if strategy already has an open position
    if(HasStrategyOpenPosition(strategy)) {
        Print("Strategy ", strategy, " already has an open position. Skipping new order.");
        return;
    }
    
    Print("Attempting to open SELL order for strategy: ", strategy);
    double lot_size = CalculateDynamicLotSize(strategy);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = price + CalculateStopLoss(strategy);
    double tp = price - CalculateTakeProfit(strategy);
    
    Print("Order Details - Lot: ", lot_size, ", Price: ", price, ", SL: ", sl, ", TP: ", tp);
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot_size;
    request.type = ORDER_TYPE_SELL;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = MAGIC_NUMBER;
    request.comment = "Sell Order - " + strategy;
    
    if(!OrderSend(request, result))
    {
        Print("Error opening Sell Order: ", result.comment);
    }
    else
    {
        Print("Sell Order opened successfully. Ticket: ", result.order);
    }
}

//+------------------------------------------------------------------+
//| Risk and Lot Size Calculation Functions                        |
//+------------------------------------------------------------------+
double CalculateLotSize(string strategy)
{
    if(StringCompare(RiskManagementMode, "FixedLot") == 0)
    {
        return FixedLotSize;
    }
    else if(StringCompare(RiskManagementMode, "Risk-Based") == 0)
    {
        // Implement risk-based lot size calculation
        double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double risk_amount = account_balance * (RiskPercentage / 100.0);
        double sl = CalculateStopLoss(strategy);
        double tick_value;
        if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tick_value))
        {
            Print("Error getting tick value: ", GetLastError());
            return FixedLotSize; // Fallback
        }
        double lot_size = risk_amount / (sl / _Point * tick_value);
        lot_size = MathRound(lot_size * 100) / 100; // Adjust decimal places as needed
        return lot_size;
    }
    else
    {
        // Default to fixed lot size
        return FixedLotSize;
    }
}

double CalculateStopLoss(string strategy)
{
    // Tạo handle cho chỉ báo ATR với chu kỳ 14
    int atr_handle = iATR(_Symbol, Timeframe, 14);
    if(atr_handle == INVALID_HANDLE)
    {
        Print("Error creating ATR handle: ", GetLastError());
        return 50 * _Point; // Fallback
    }

    double atr[];
    // Lấy giá trị ATR gần nhất
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0)
    {
        Print("Error copying ATR data: ", GetLastError());
        IndicatorRelease(atr_handle);
        return 50 * _Point; // Fallback
    }

    IndicatorRelease(atr_handle);

    // Xác định hệ số ATR multiplier dựa trên chiến lược
    double sl_atr_multiplier = 1.0; // Default
    if(StringCompare(strategy, "Scalping") == 0)
    {
        sl_atr_multiplier = ScalpingSL_ATR_Multiplier;
    }
    else if(StringCompare(strategy, "SwingTrading") == 0)
    {
        sl_atr_multiplier = SwingSL_ATR_Multiplier;
    }
    else if(StringCompare(strategy, "Breakout") == 0)
    {
        sl_atr_multiplier = BreakoutSL_ATR_Multiplier;
    }
    else if(StringCompare(strategy, "MeanReversion") == 0)
    {
        sl_atr_multiplier = MeanReversionSL_ATR_Multiplier;
    }

    double sl = atr[0] * sl_atr_multiplier;
    return sl;
}

double CalculateTakeProfit(string strategy)
{
    // Tạo handle cho chỉ báo ATR với chu kỳ 14
    int atr_handle = iATR(_Symbol, Timeframe, 14);
    if(atr_handle == INVALID_HANDLE)
    {
        Print("Error creating ATR handle: ", GetLastError());
        return 100 * _Point; // Fallback
    }

    double atr[];
    // Lấy giá trị ATR gần nhất
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0)
    {
        Print("Error copying ATR data: ", GetLastError());
        IndicatorRelease(atr_handle);
        return 100 * _Point; // Fallback
    }

    IndicatorRelease(atr_handle);

    // Xác định hệ số ATR multiplier dựa trên chiến lược
    double tp_atr_multiplier = 2.0; // Default
    if(StringCompare(strategy, "Scalping") == 0)
    {
        tp_atr_multiplier = ScalpingTP_ATR_Multiplier;
    }
    else if(StringCompare(strategy, "SwingTrading") == 0)
    {
        tp_atr_multiplier = SwingTP_ATR_Multiplier;
    }
    else if(StringCompare(strategy, "Breakout") == 0)
    {
        tp_atr_multiplier = BreakoutTP_ATR_Multiplier;
    }
    else if(StringCompare(strategy, "MeanReversion") == 0)
    {
        tp_atr_multiplier = MeanReversionTP_ATR_Multiplier;
    }

    double tp = atr[0] * tp_atr_multiplier;
    return tp;
}

//+------------------------------------------------------------------+
//| Pivot Point Calculation (Simple Example)                        |
//+------------------------------------------------------------------+
double CalculatePivotPoint(string symbol, ENUM_TIMEFRAMES timeframe)
{
    // Tính Pivot Point dựa trên phiên trước
    datetime prev_time = iTime(symbol, timeframe, 1);
    
    double high = iHigh(symbol, timeframe, 1);
    double low = iLow(symbol, timeframe, 1);
    double close = iClose(symbol, timeframe, 1);
    
    double pivot = (high + low + close) / 3.0;
    return pivot;
}

//+------------------------------------------------------------------+
//| Initialize Position Tracking                                     |
//+------------------------------------------------------------------+
void InitializePositionTracking()
{
    ArrayResize(open_positions, 0);
    total_positions = 0;
    UpdatePositionTracking();
}

//+------------------------------------------------------------------+
//| Update Position Tracking                                         |
//+------------------------------------------------------------------+
void UpdatePositionTracking()
{
    ArrayResize(open_positions, 0);
    total_positions = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER) {
                PositionInfo pos;
                pos.ticket = ticket;
                pos.strategy = PositionGetString(POSITION_COMMENT);
                pos.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                pos.current_sl = PositionGetDouble(POSITION_SL);
                pos.current_tp = PositionGetDouble(POSITION_TP);
                pos.partial_close_target = 0.0;
                pos.partial_closed = false;
                pos.open_time = (datetime)PositionGetInteger(POSITION_TIME);
                
                // Calculate partial close target
                if(EnablePartialClose) {
                    double atr = GetCurrentATR();
                    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                        pos.partial_close_target = pos.open_price + (atr * PartialCloseTarget);
                    } else {
                        pos.partial_close_target = pos.open_price - (atr * PartialCloseTarget);
                    }
                }
                
                ArrayResize(open_positions, total_positions + 1);
                open_positions[total_positions] = pos;
                total_positions++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Manage Open Positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    for(int i = 0; i < total_positions; i++) {
        if(PositionSelectByTicket(open_positions[i].ticket)) {
            // Trailing Stop
            if(EnableTrailingStop) {
                ApplyTrailingStop(open_positions[i]);
            }
            
            // Partial Close
            if(EnablePartialClose && !open_positions[i].partial_closed) {
                ApplyPartialClose(open_positions[i]);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(PositionInfo &pos)
{
    double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double atr = GetCurrentATR();
    double trailing_distance = atr * TrailingStopATRMultiplier;
    
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
        double new_sl = current_price - trailing_distance;
        if(new_sl > pos.current_sl && new_sl < current_price) {
            ModifyPositionSL(pos.ticket, new_sl);
            pos.current_sl = new_sl;
        }
    } else {
        double new_sl = current_price + trailing_distance;
        if((pos.current_sl == 0 || new_sl < pos.current_sl) && new_sl > current_price) {
            ModifyPositionSL(pos.ticket, new_sl);
            pos.current_sl = new_sl;
        }
    }
}

//+------------------------------------------------------------------+
//| Apply Partial Close                                              |
//+------------------------------------------------------------------+
void ApplyPartialClose(PositionInfo &pos)
{
    double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    bool should_partial_close = false;
    
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
        should_partial_close = (current_price >= pos.partial_close_target);
    } else {
        should_partial_close = (current_price <= pos.partial_close_target);
    }
    
    if(should_partial_close) {
        double current_volume = PositionGetDouble(POSITION_VOLUME);
        double close_volume = current_volume * (PartialClosePercentage / 100.0);
        
        if(ClosePartialPosition(pos.ticket, close_volume)) {
            pos.partial_closed = true;
            Print("Partial close executed for ticket: ", pos.ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify Position Stop Loss                                        |
//+------------------------------------------------------------------+
bool ModifyPositionSL(ulong ticket, double new_sl)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = new_sl;
    request.tp = PositionGetDouble(POSITION_TP);
    
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Close Partial Position                                           |
//+------------------------------------------------------------------+
bool ClosePartialPosition(ulong ticket, double volume)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = volume;
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.deviation = 10;
    request.comment = "Partial Close";
    
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Correlation Analysis Functions                                   |
//+------------------------------------------------------------------+
bool CanOpenNewPosition()
{
    // Check maximum positions per strategy
    if(!CheckMaxPositionsPerStrategy()) {
        return false;
    }
    
    // Check correlation with existing positions
    if(!CheckPositionCorrelation()) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Maximum Positions Per Strategy                             |
//+------------------------------------------------------------------+
bool CheckMaxPositionsPerStrategy()
{
    int scalping_count = 0;
    int swing_count = 0;
    int breakout_count = 0;
    int mean_reversion_count = 0;
    
    for(int i = 0; i < total_positions; i++) {
        if(StringFind(open_positions[i].strategy, "Scalping") >= 0) scalping_count++;
        else if(StringFind(open_positions[i].strategy, "SwingTrading") >= 0) swing_count++;
        else if(StringFind(open_positions[i].strategy, "Breakout") >= 0) breakout_count++;
        else if(StringFind(open_positions[i].strategy, "MeanReversion") >= 0) mean_reversion_count++;
    }
    
    // Check if any strategy has reached maximum positions
    if(scalping_count >= MaxPositionsPerStrategy || 
       swing_count >= MaxPositionsPerStrategy || 
       breakout_count >= MaxPositionsPerStrategy || 
       mean_reversion_count >= MaxPositionsPerStrategy) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Position Correlation                                       |
//+------------------------------------------------------------------+
bool CheckPositionCorrelation()
{
    if(total_positions == 0) return true;
    
    // Calculate correlation between potential new position and existing positions
    double correlation = CalculatePositionCorrelation();
    
    if(correlation > MaxCorrelationThreshold) {
        Print("Correlation too high: ", correlation, " > ", MaxCorrelationThreshold);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Position Correlation                                   |
//+------------------------------------------------------------------+
double CalculatePositionCorrelation()
{
    // Simple correlation calculation based on position direction
    int buy_positions = 0;
    int sell_positions = 0;
    
    for(int i = 0; i < total_positions; i++) {
        if(PositionSelectByTicket(open_positions[i].ticket)) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                buy_positions++;
            } else {
                sell_positions++;
            }
        }
    }
    
    // Calculate correlation based on position imbalance
    int total_existing = buy_positions + sell_positions;
    if(total_existing == 0) return 0.0;
    
    double imbalance = MathAbs(buy_positions - sell_positions) / (double)total_existing;
    return imbalance; // Higher imbalance = higher correlation
}

//+------------------------------------------------------------------+
//| News Filter Functions                                            |
//+------------------------------------------------------------------+
void CheckNewsEvents()
{
    // This is a simplified news filter
    // In a real implementation, you would connect to a news API
    // For now, we'll use time-based filtering for major news times
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Avoid trading during major news times (simplified)
    // Major news typically occurs at specific times
    bool is_major_news_time = false;
    
    // Check for major news times (example: 8:30 AM, 2:00 PM EST)
    if(dt.hour == 8 && dt.min >= 25 && dt.min <= 35) is_major_news_time = true;
    if(dt.hour == 14 && dt.min >= 55 && dt.min <= 5) is_major_news_time = true;
    
    // Check for Friday afternoon (weekend effect)
    if(dt.day_of_week == 5 && dt.hour >= 20) is_major_news_time = true;
    
    // Check for Monday morning (weekend gap risk)
    if(dt.day_of_week == 1 && dt.hour <= 4) is_major_news_time = true;
    
    is_news_time = is_major_news_time;
    
    if(is_news_time) {
        Print("News filter active - avoiding new trades");
    }
}

//+------------------------------------------------------------------+
//| Enhanced Pivot Point Calculation                                 |
//+------------------------------------------------------------------+
double CalculateEnhancedPivotPoint()
{
    if(!EnableMultiTimeframePivots) {
        return CalculatePivotPoint(_Symbol, PivotPointPeriodTF);
    }
    
    // Calculate pivot points for multiple timeframes
    double pivot1 = CalculatePivotPoint(_Symbol, PivotTimeframe1);
    double pivot2 = CalculatePivotPoint(_Symbol, PivotTimeframe2);
    
    // Weighted average of pivot points
    double weighted_pivot = (pivot1 * PivotWeightTimeframe1) + (pivot2 * PivotWeightTimeframe2);
    
    return weighted_pivot;
}

//+------------------------------------------------------------------+
//| Dynamic Lot Sizing Based on Volatility                          |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(string strategy)
{
    if(!EnableDynamicLotSizing) {
        return CalculateLotSize(strategy);
    }
    
    double base_lot = BaseLotSize;
    double volatility_factor = 1.0;
    
    // Calculate volatility factor
    double atr_value = GetCurrentATR();
    double avg_atr = CalculateAverageATR(20); // 20-period average ATR
    
    if(avg_atr > 0) {
        volatility_factor = atr_value / avg_atr;
        volatility_factor = MathMax(0.5, MathMin(2.0, volatility_factor)); // Limit between 0.5 and 2.0
    }
    
    // Apply volatility multiplier
    double dynamic_lot = base_lot * volatility_factor * VolatilityMultiplier;
    
    // Ensure lot size is within limits
    dynamic_lot = MathMax(MinLotSize, MathMin(MaxLotSize, dynamic_lot));
    
    // Normalize lot size
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    int lot_steps = (int)MathRound(dynamic_lot / lot_step);
    dynamic_lot = lot_steps * lot_step;
    
    return dynamic_lot;
}

//+------------------------------------------------------------------+
//| Calculate Average ATR                                            |
//+------------------------------------------------------------------+
double CalculateAverageATR(int period)
{
    int atr_handle = iATR(_Symbol, Timeframe, 14);
    if(atr_handle == INVALID_HANDLE) {
        return 0.0;
    }
    
    double atr_values[];
    if(CopyBuffer(atr_handle, 0, 0, period, atr_values) <= 0) {
        IndicatorRelease(atr_handle);
        return 0.0;
    }
    
    IndicatorRelease(atr_handle);
    
    double sum = 0.0;
    for(int i = 0; i < period; i++) {
        sum += atr_values[i];
    }
    
    return sum / period;
}

//+------------------------------------------------------------------+
//| Calculate Overall Performance Metrics                            |
//+------------------------------------------------------------------+
double CalculateOverallWinRate()
{
    int total_trades = 0;
    int total_wins = 0;
    
    for(int i = 0; i < 4; i++) {
        total_trades += strategy_stats[i].total_trades;
        total_wins += strategy_stats[i].winning_trades;
    }
    
    return (total_trades > 0) ? (double)total_wins / total_trades : 0.0;
}

double CalculateOverallProfitFactor()
{
    double total_profit = 0.0;
    double total_loss = 0.0;
    
    for(int i = 0; i < 4; i++) {
        total_profit += strategy_stats[i].total_profit;
        // Estimate total loss from profit factor
        if(strategy_stats[i].profit_factor > 0) {
            total_loss += strategy_stats[i].total_profit / strategy_stats[i].profit_factor;
        }
    }
    
    return (total_loss > 0) ? total_profit / total_loss : 0.0;
}

double CalculateOverallMaxDrawdown()
{
    double max_drawdown = 0.0;
    
    for(int i = 0; i < 4; i++) {
        if(strategy_stats[i].max_drawdown > max_drawdown) {
            max_drawdown = strategy_stats[i].max_drawdown;
        }
    }
    
    return max_drawdown;
}

//+------------------------------------------------------------------+
//| Update Performance Metrics                                       |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics()
{
    datetime start_time = TimeCurrent() - (AnalysisPeriod * 24 * 3600);
    
    // Update performance for all strategies
    for(int i = 0; i < 4; i++) {
        CalculateStrategyPerformance(strategy_stats[i], start_time);
    }
    
    Print("Performance metrics updated for all strategies");
}

//+------------------------------------------------------------------+
//| Update Trade Statistics                                          |
//+------------------------------------------------------------------+
void UpdateTradeStats(string strategy_name, double profit)
{
    // Find the strategy index
    int strategy_index = -1;
    string strategy_names[] = {"Scalping", "SwingTrading", "Breakout", "MeanReversion"};
    
    for(int i = 0; i < 4; i++) {
        if(StringCompare(strategy_names[i], strategy_name) == 0) {
            strategy_index = i;
            break;
        }
    }
    
    if(strategy_index >= 0) {
        StrategyPerformance stats = strategy_stats[strategy_index];
        stats.total_trades++;
        stats.total_profit += profit;
        
        if(profit > 0) {
            stats.winning_trades++;
        }
        
        // Update win rate
        stats.win_rate = (double)stats.winning_trades / stats.total_trades;
        
        // Update average profit
        stats.avg_profit = stats.total_profit / stats.total_trades;
        
        Print("Updated trade stats for ", strategy_name, " - Profit: ", profit, ", Total Trades: ", stats.total_trades, ", Win Rate: ", stats.win_rate);
    }
}

//+------------------------------------------------------------------+
//| Display Position Details                                         |
//+------------------------------------------------------------------+
void DisplayPositionDetails()
{
    if(total_positions == 0) {
        Print("No open positions");
        return;
    }
    
    Print("=== OPEN POSITIONS DETAILS ===");
    Print("Total Open Positions: ", total_positions);
    
    for(int i = 0; i < total_positions; i++) {
        if(PositionSelectByTicket(open_positions[i].ticket)) {
            string pos_type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            
            Print("Position ", i+1, ":");
            Print("  Ticket: ", open_positions[i].ticket);
            Print("  Strategy: ", open_positions[i].strategy);
            Print("  Type: ", pos_type);
            Print("  Volume: ", volume);
            Print("  Open Price: ", open_price);
            Print("  Current Price: ", current_price);
            Print("  Stop Loss: ", sl);
            Print("  Take Profit: ", tp);
            Print("  Current Profit: ", profit);
            Print("  Open Time: ", TimeToString(open_positions[i].open_time));
            Print("  ---");
        }
    }
}

//+------------------------------------------------------------------+
//| Get Strategy Performance Summary                                 |
//+------------------------------------------------------------------+
string GetStrategyPerformanceSummary()
{
    string summary = "=== STRATEGY PERFORMANCE SUMMARY ===\n";
    
    string strategy_names[] = {"Scalping", "Swing Trading", "Breakout", "Mean Reversion"};
    
    for(int i = 0; i < 4; i++) {
        StrategyPerformance stats = strategy_stats[i];
        int open_positions_count = CountOpenPositionsForStrategy(i);
        
        summary += StringFormat("%s:\n", strategy_names[i]);
        summary += StringFormat("  Total Trades: %d\n", stats.total_trades);
        summary += StringFormat("  Win Rate: %.1f%%\n", stats.win_rate * 100);
        summary += StringFormat("  Total Profit: %.2f\n", stats.total_profit);
        summary += StringFormat("  Max Drawdown: %.1f%%\n", stats.max_drawdown * 100);
        summary += StringFormat("  Open Positions: %d\n", open_positions_count);
        summary += "  ---\n";
    }
    
    return summary;
}

//+------------------------------------------------------------------+
//| Check if Strategy has Open Position                              |
//+------------------------------------------------------------------+
bool HasStrategyOpenPosition(string strategy)
{
    // Check all open positions for this strategy
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER) {
                string position_comment = PositionGetString(POSITION_COMMENT);
                // Check if position belongs to this strategy
                if(StringFind(position_comment, strategy) >= 0) {
                    Print("Strategy ", strategy, " already has open position: ", ticket);
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get Strategy Open Position Count                                 |
//+------------------------------------------------------------------+
int GetStrategyOpenPositionCount(string strategy)
{
    int count = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER) {
                string position_comment = PositionGetString(POSITION_COMMENT);
                if(StringFind(position_comment, strategy) >= 0) {
                    count++;
                }
            }
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Display Strategy Position Status                                 |
//+------------------------------------------------------------------+
void DisplayStrategyPositionStatus()
{
    string strategies[] = {"Scalping", "SwingTrading", "Breakout", "MeanReversion"};
    
    Print("=== STRATEGY POSITION STATUS ===");
    for(int i = 0; i < ArraySize(strategies); i++) {
        int position_count = GetStrategyOpenPositionCount(strategies[i]);
        string status = (position_count > 0) ? "ACTIVE (" + IntegerToString(position_count) + " positions)" : "AVAILABLE";
        Print(strategies[i], ": ", status);
    }
    Print("================================");
}
