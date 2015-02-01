//+------------------------------------------------------------------+
//|                                                   NakedForex.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Martin Bartosch"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <WinUser32.mqh>
#include <ToolBox.mqh>
#include <NakedForexTools.mqh>
#include <ExitStrategies.mqh>

#import "user32.dll"
  int GetForegroundWindow();
#import


input string ZoneFilename = ""; // Zone information filename
input int    ReferenceChartID = 0; // Reference Chart ID for Zones

input int    LowestTimeFrame  = PERIOD_M1; // Lowest Period to monitor
input int    HighestTimeFrame = PERIOD_H4; // Highest Period to monitor

input double MaxRelativeTradeSize = 0.01;  // Max. percentage of Equity at risk per trade
input double MaxAbsoluteRisk = 100.0;      // Max. absolute equity at risk per trade
input int    MaxConcurrentOpenTrades = 1;     // Max. number of concurrent open trades
input int    DebugLevel = 0;


// globals
int MinTimeFrameIndex = 0;
int MaxTimeFrameIndex = 0;

// http://forum.mql4.com/35112
void PauseTest(){
    if ( IsTesting() && IsVisualMode() && IsDllsAllowed() ){
        int main = GetForegroundWindow();
        PostMessageA(main, WM_COMMAND, 0x57a, 0);  }   // 1402. Pause
}

// Global storage for zones on this chart
double Zones[];

datetime LastBarTime[8];


// manage any trades opened by this EA
void ManageTrades() {
  for (int ii = 0; ii < OrdersTotal(); ii++) {
    if (OrderSelect(ii, SELECT_BY_POS) == false)
      continue;

    if (! (OrderMagicNumber() & NFX_TRADE_MAGIC))
      continue;
    // we have found an order that was opened by this EA
    
    if ((OrderType() != OP_BUY) && (OrderType() != OP_SELL))
      continue;
 
    
   }    
}




//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   // we want events for graphical object modification (create, modify, delete), so we must tell MT4 to inform us:
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
   
   NFXSetDebugLevel(DebugLevel);
   
   // NOTE: SymbolPoint is the minimum price indication of the symbol
   // EURUSD: 0.00001
   // DAX: 0.01
   Print("Symbol point value: ", SymbolInfoDouble(Symbol(), SYMBOL_POINT));
   
   if (StringCompare(ZoneFilename, "") == 0) {
     // get all zones drawn in the chart by the user
     GetZonesFromChartObjects(ReferenceChartID, Zones);
   } else {
     if (ReadZonesFromFile(ZoneFilename, Zones) != ERR_NO_ERROR) {
       Alert("ERROR: could not read zone information from file ", ZoneFilename);
       return(INIT_FAILED);
     }
   }

   if(DebugLevel >= 1) Print("Zone summary");
   for (int ii=0; ii < ArraySize(Zones); ii++) {
      if (DebugLevel >= 3) Print("Zone ", ii, " price: ", Zones[ii]);
   }

   MinTimeFrameIndex = PeriodToIndex(LowestTimeFrame);
   MaxTimeFrameIndex = PeriodToIndex(HighestTimeFrame);
   
   if (MinTimeFrameIndex < PeriodToIndex(PERIOD_M1)) {
      Alert("Invalid minimum period specified");
      return(INIT_FAILED);
   }
   if (MinTimeFrameIndex > MaxTimeFrameIndex) {
      Alert("Minimum Period is longer than maximum period");
      return(INIT_FAILED);
   }
   if (MaxTimeFrameIndex > PeriodToIndex(PERIOD_D1)) {
      Alert("Maximum Period is longer than 1 D");
      return(INIT_FAILED);   
   }
   
   for (int ii = 0; ii < 8; ii++)
      LastBarTime[ii] = 0;

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {   
   ManageTrades();
   
   for (int timeframe = MinTimeFrameIndex; timeframe <= MaxTimeFrameIndex; timeframe++) {
      datetime ThisBarTime = iTime(Symbol(), timeframe, 0);
      if (LastBarTime[timeframe] == ThisBarTime)
         continue;
      LastBarTime[timeframe] = ThisBarTime;
      if (DebugLevel >= 3) Print("New candlestick on timeframe ", timeframe);
      
      // New bar on timeframe started
      
      // zone checks
      // NOTE: slack is 0.0 for now, the previous bar must print exactly on the zone line!
      // TODO: determine sensible value for slack that works for DAX (e. g. 2.0) and Forex (0.00002) as well
      int ZoneTouched = PriceActionOnZone(Zones, iHigh(Symbol(), timeframe, 1), iLow(Symbol(), timeframe, 1), 0.0);
#ifdef FIXME
      if (ZoneTouched == -1)
         // price is not on a zone
         continue;
#endif
     
      if (DebugLevel >= 3) Print("Timeframe: ", timeframe, "; price ", iHigh(Symbol(), timeframe, 1), "/", iLow(Symbol(), timeframe, 1), " prints on zone: ", Zones[ZoneTouched]);

      // catalyst checks
      int NFXSignal = 0;
      double QualityNFXCatalyst = NakedForexCatalyst(NFXSignal, timeframe, 1);

      if (NFXSignal == 0)
         continue;

      if (fabs(QualityNFXCatalyst) < 0.01)
         continue;

      // determine trade parameters      
      double TradeTakeProfit = 0.0;
      int    TradeOperation = NFXOrderType();
      double TradeStop      = NFXOrderPrice();
      double TradeStopLoss  = NFXOrderStoploss();
      datetime TradeExpiry    = NFXOrderExpiration();
      double TradeVolume    = 0.1;
      
      
      if (QualityNFXCatalyst > 0) {
         if (DebugLevel >= 1) Print("Timeframe: ", timeframe, "; bullish signal: ", QualityNFXCatalyst, " on zone #", ZoneTouched);

         int NextZone = ZoneTouched + 1;
         if (NextZone < ArraySize(Zones)) {
            TradeTakeProfit = NormRound(Zones[NextZone]);
         } else {
            Alert("No next zone defined, using a default TP of 2 * SL");
            TradeTakeProfit = NormRound(TradeStop + 2 * (TradeStop - TradeStopLoss));
         }

      } else {
         if (DebugLevel >= 1) Print("Timeframe: ", timeframe, "; bearish signal: ", QualityNFXCatalyst, " on zone #", ZoneTouched);

         int NextZone = ZoneTouched - 1;
         if (NextZone >= 0) {
            TradeTakeProfit = NormRound(Zones[NextZone]);
         } else {
            Alert("No next zone defined, using a default TP of 2 * SL");
            TradeTakeProfit = NormRound(TradeStop - 2 * (TradeStopLoss - TradeStop));
         }
      }

      // enable this to pause on each new candlebar. press the "Pause" key to continue.
      //PauseTest();
            
      if (IsTradeAllowed()) {
         OrderSend(Symbol(), TradeOperation, TradeVolume, TradeStop, 0, TradeStopLoss, TradeTakeProfit, "Naked Forex", NFXSignal, TradeExpiry, clrAquamarine);      
      } else {
         Print("Simulated trade: ", TradeOperation, ", @", TradeStop, " SL: ", TradeStopLoss);
      }
   }
}
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   if (DebugLevel >= 1) Print("OnChartEvent id: ", id, " sparam: ", sparam);
   
   switch (id) {
      case CHARTEVENT_KEYDOWN:
        return;
        break;
      case CHARTEVENT_MOUSE_MOVE:
        return;
        break;
      case CHARTEVENT_CLICK:
        return;
        break;
      case CHARTEVENT_OBJECT_CLICK:
        return;
        break;
      case CHARTEVENT_CHART_CHANGE:
        return;
        break;
      default:
        break;
   }

   if (StringCompare(ZoneFilename, "") != 0) {
     // zones specified in file, ignore chart
     return;
   }     

   if (DebugLevel >= 1) Print("Processing chart event, reinitializing zones");
   GetZonesFromChartObjects(ReferenceChartID, Zones);

   if (DebugLevel >= 3) Print("Zone summary");
   for(int ii=0; ii < ArraySize(Zones); ii++) {
      if (DebugLevel >= 3) Print("Zone ", ii, " price: ", Zones[ii]);
   }   
  }
//+------------------------------------------------------------------+
