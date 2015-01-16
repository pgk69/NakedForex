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
#include <NakedForexTools.mqh>

#import "user32.dll"
  int GetForegroundWindow();
#import


#import "NakedForexCatalyst.ex4"
  double NakedForexCatalystKangarooTail(int timeframe = 0, int shift = 1, double PctMaximumBodySize = 0.2);

#import

// http://forum.mql4.com/35112
void PauseTest(){
    if ( IsTesting() && IsVisualMode() && IsDllsAllowed() ){
        int main = GetForegroundWindow();
        PostMessageA(main, WM_COMMAND, 0x57a, 0);  }   // 1402. Pause
}


#define NFX_TRADE                    0x00000000

#define NFX_SIGNAL_MASK              0x11100000
#define NFX_SIGNAL_KANGAROOTAIL      0x00100000
#define NFX_SIGNAL_TRENDINGKANGAROO  0x01000000

extern int DebugLevel = 3;

// age of last order placement
int LastSignalAge = 1;

double PipSize;

// Global storage for zones on this chart
double Zones[];



// manage any trades opened by this EA
// TODO: this function is unfinished
void ManageTrades() {
  for (int ii = 0; ii < OrdersTotal(); ii++) {
    if (OrderSelect(ii, SELECT_BY_POS) == false)
      continue;

    if (! (OrderMagicNumber() & NFX_SIGNAL_MASK))
      continue;
    // we have found an order that was opened by this EA
    
    if (OrderMagicNumber() && NFX_SIGNAL_KANGAROOTAIL) {
      if ((OrderType() == OP_BUYSTOP)
          || (OrderType() == OP_SELLSTOP)) {
        if (LastSignalAge > 0) {
           if (DebugLevel >= 1) Print("Delete outdated order ", OrderTicket());

           if (! OrderDelete(OrderTicket())) {
             Alert("Could not delete order ", OrderTicket());
           }
         }
      }
    }
    // for now all NFX orders are managed by the three bar exit
    if (LastSignalAge < 4)
      continue;

    double LastSL = OrderStopLoss();
    
    if (OrderType() == OP_BUY) {
      double SL = RoundNormalizedOnTickValue(iLow(NULL, 0, 0));
      for (int jj = 1; jj <= 3; jj++) {
        SL = fmin(SL, RoundNormalizedOnTickValue(iLow(NULL, 0, jj)));
      }
      if (SL > LastSL) {
        int rc = OrderModify(OrderTicket(), OrderOpenPrice(), SL, OrderTakeProfit(), OrderExpiration(), clrNONE);
        if (DebugLevel >= 1) Print("Modify order ", OrderTicket(), " new SL: ", SL);
        PauseTest();
      }
    }
    if (OrderType() == OP_SELL) {
      double SL = RoundNormalizedOnTickValue(iHigh(NULL, 0, 0));
      for (int jj = 1; jj <= 3; jj++) {
        SL = fmax(SL, RoundNormalizedOnTickValue(iHigh(NULL, 0, jj)));
      }
      if (SL < LastSL) {
        int rc = OrderModify(OrderTicket(), OrderOpenPrice(), SL, OrderTakeProfit(), OrderExpiration(), clrNONE);
        if (DebugLevel >= 1) Print("Modify order ", OrderTicket(), " new SL: ", SL);
        PauseTest();
      }
    }
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

   PipSize = (1 / SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE));
   Print("PipSize: ", PipSize);
   
   // NOTE: SymbolPoint is the minimum price indication of the symbol
   // EURUSD: 0.00001
   // DAX: 0.01
   Print("Symbol point value: ", SymbolInfoDouble(Symbol(), SYMBOL_POINT));

   // get all zones drawn in the chart by the user
   GetZonesFromChartObjects(0, Zones);
   
   //FIXME: strategy tester does not support OnChartEvent, so we need to preallocate the array with some test values
   Alert("NOTE: debugging code in EA, remove following lines!");
   ArrayResize(Zones, 3);
   Zones[0] = 1.25155;
   Zones[1] = 1.25275;
   Zones[2] = 1.25510;
   //END OF FIXME


   if(DebugLevel >= 1) Print("Zone summary");
   for (int ii=0; ii < ArraySize(Zones); ii++) {
      if (DebugLevel >= 3) Print("Zone ", ii, " price: ", Zones[ii]);
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
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   static datetime LastBarTime = 0;

   int timeframe = 0;
   int rc;
   datetime ThisBarTime = iTime(NULL, timeframe, 0);
   
   double TPPips = 1000;
   double SLPips = 4;
   double StopPips = 2;
   double OrderSize = 0.1;
   double Slippage = 0;

   ManageTrades();
   
   // only action on new candle, ignore ticks in between
   if( LastBarTime == ThisBarTime)
      return;
   
   // save start time of this candle   
   LastBarTime = ThisBarTime;
   
   // keep track of last signal age
   LastSignalAge++;

   // enable this to pause on each new candlebar. press the "Pause" key to continue.
   //PauseTest();
   
   // zone checks
   // NOTE: slack is 0.0 for now, the previous bar must print exactly on the zone line!
   // TODO: determine sensible value for slack that works for DAX (e. g. 2.0) and Forex (0.00002) as well
   int ZoneTouched = PriceActionOnZone(Zones, iHigh(Symbol(), timeframe, 1), iLow(Symbol(), timeframe, 1), 0.0);

   if (ZoneTouched == -1)
     // price is not on a zone
     return;
     
   if (DebugLevel >= 3) Print("Z0: price ", iHigh(Symbol(), timeframe, 1), "/", iLow(Symbol(), timeframe, 1), " prints on zone: ", Zones[ZoneTouched]);

   if (true) {
     // show zone action on the chart
     datetime xcoord[2];
     CopyTime(Symbol(), timeframe, 1, 2, xcoord);
     ObjectCreate(ChartID(), "Zone", OBJ_ELLIPSE, 0, xcoord[0], iLow(Symbol(), timeframe, 1), xcoord[1], iHigh(Symbol(), timeframe, 1));
     ChartRedraw();      
   }
   
   // catalyst checks
   double isKangarooTail = NakedForexCatalystKangarooTail(timeframe);

   if (isKangarooTail > 0.01) {
      if (DebugLevel >= 1) Print("Bullish signal: ", isKangarooTail);
      
      double SL   = RoundNormalizedOnTickValue(iLow(Symbol(), timeframe, 1) - SLPips * PipSize);
      double Stop = RoundNormalizedOnTickValue(fmax(Ask, iHigh(Symbol(), timeframe, 1)) + StopPips * PipSize);
      double TP   = RoundNormalizedOnTickValue(Stop + TPPips * PipSize);
      
      // page 146: entering the trade: Stop Buy a few pips above high of tail
      Print("OrderSend StopBuy (Ask/Bid/KangarooMax/KangarooMin - Stop/SL/TP) ", Ask, "/", Bid, "/", iHigh(Symbol(), timeframe, 1), "/", iLow(Symbol(), timeframe, 1), " - ", Stop, "/", SL, "/", TP);
      rc = OrderSend(Symbol(), OP_BUYSTOP, OrderSize, Stop, Slippage, SL, TP, "Kangaroo Tail", NFX_SIGNAL_KANGAROOTAIL, 0, clrNONE);
      if(rc < 0) {
        Print("Failed with error #", GetLastError());
        //BreakPoint();
      }
      // make sure the trade monitor cleans up if trade is not triggered
      LastSignalAge = 0;
      // pause on new trade
      PauseTest();
   }
   if (isKangarooTail < -0.01) {
      if (DebugLevel >= 1) Print("Bearish signal: ", isKangarooTail);

      double SL   = RoundNormalizedOnTickValue(iHigh(Symbol(), timeframe, 1) + SLPips * PipSize);
      double Stop = RoundNormalizedOnTickValue(fmin(Bid, iLow(Symbol(), timeframe, 1)) - StopPips * PipSize);
      double TP   = RoundNormalizedOnTickValue(Stop - TPPips * PipSize);

      rc = OrderSend(Symbol(), OP_SELL, OrderSize, Stop, Slippage, SL, TP, "Kangaroo Tail", NFX_SIGNAL_KANGAROOTAIL, 0, clrNONE);
      Print("OrderSend StopSell (Ask/Bid/KangarooMax/KangarooMin - Stop/SL/TP) ", Ask, "/", Bid, "/", iHigh(Symbol(), timeframe, 1), "/", iLow(Symbol(), timeframe, 1), " - ", Stop, "/", SL, "/", TP);
      if(rc < 0) {
        Print("Failed with error #", GetLastError());
        //BreakPoint();
      }
      // make sure the trade monitor cleans up if trade is not triggered
      LastSignalAge = 0;
      // pause on new trade
      PauseTest();
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

   if (DebugLevel >= 1) Print("Processing chart event, reinitializing zones");
   GetZonesFromChartObjects(0, Zones);

   if (DebugLevel >= 3) Print("Zone summary");
   for(int ii=0; ii < ArraySize(Zones); ii++) {
      if (DebugLevel >= 3) Print("Zone ", ii, " price: ", Zones[ii]);
   }   
  }
//+------------------------------------------------------------------+
