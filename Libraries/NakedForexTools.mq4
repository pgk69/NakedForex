//+------------------------------------------------------------------+
//|                                              NakedForexTools.mq4 |
//|                                                  Martin Bartosch |
//|                                          http://fx.bartosch.name |
//+------------------------------------------------------------------+
#property library
#property copyright "Martin Bartosch"
#property link      "http://fx.bartosch.name"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| My function                                                      |
//+------------------------------------------------------------------+
// int MyCalculator(int value,int value2) export
//   {
//    return(value+value2);
//   }
//+------------------------------------------------------------------+

#include <NakedForexTools.mqh>
#include <ToolBox.mqh>

int DebugLevel = 0;
const string Magic = "NFZT 1.0";

// global variables for trade initiation
int      SignalOrderType = 0;
double   SignalOrderPrice = 0.0;
double   SignalOrderStoploss = 0.0;
datetime SignalOrderExpiration = 0;
datetime SignalOrderTimestamp = 0;

// accessor functions
int NFXOrderType(int arg = -1) export {
   if (arg > 0)
      SignalOrderType = arg;
   return SignalOrderType;
}

double NFXOrderPrice(double arg = -1.0) export {
   if (arg > 0.0)
      SignalOrderPrice = arg;
   return SignalOrderPrice;
}

double NFXOrderStoploss(double arg = -1.0) export {
   if (arg > 0.0)
      SignalOrderStoploss = arg;
   return SignalOrderStoploss;
}

datetime NFXOrderExpiration(datetime arg = -1) export {
   if (arg > 0)
      SignalOrderExpiration = arg;
   return SignalOrderExpiration;
}

datetime NFXOrderTimestamp(datetime arg = -1) export {
   if (arg > 0)
      SignalOrderTimestamp = arg;
   return SignalOrderTimestamp;
}

void NFXSetDebugLevel(int arg) export {
   DebugLevel = arg;
}


// returns the bitmask for the specified timeframe
int PeriodToNFXTimeFrame(int timeframe) export {
   switch (timeframe) {
      case PERIOD_M1:
         return NFX_TIMEFRAME_M1;
         break;
      case PERIOD_M5:
         return NFX_TIMEFRAME_M5;
         break;
      case PERIOD_M15:
         return NFX_TIMEFRAME_M15;
         break;
      case PERIOD_M30:
         return NFX_TIMEFRAME_M30;
         break;
      case PERIOD_H1:
         return NFX_TIMEFRAME_H1;
         break;
      case PERIOD_H4:
         return NFX_TIMEFRAME_H4;
         break;
      case PERIOD_D1:
         return NFX_TIMEFRAME_D1;
         break;
      default:
         return NFX_TIMEFRAME_UNDEF;
         break;
   }
}

// Inspect objects on chart. Determine price levels for all horizontal lines 
// and all fibonacci retracements in the chart. Store all levels in the dynamic
// array passed as second argument.
//
// arguments:
// ChartID: ID of the chart to inspect. 0 means current chart.
// arg: dynamic array which will be filled with the zone levels identified. will be modified.
// return: void
void GetZonesFromChartObjects(long ChartID, double &arg[]) export {
// preallocate some space for found objects
   int ZoneCount = 0;
   ArrayResize(arg, ZoneCount, 40);

   for(int ii = 0; ii < ObjectsTotal(ChartID, -1, -1); ii++) {
      string ObjName;
      int ObjType;
      ObjName = ObjectName(ii);
      ObjType = ObjectType(ObjName);

      if (ObjType == OBJ_HLINE) {
         double price;
         price = ObjectGetDouble(ChartID, ObjName, OBJPROP_PRICE, 0);
         ArrayResize(arg, ZoneCount + 1);
         arg[ZoneCount++] = price;
         if(DebugLevel>=3) Print("Found a line, price: ", price);
      }

      if(ObjType == OBJ_FIBO) {
         // preallocate room for up to 32 fibo levels
         ArrayResize(arg, ZoneCount, ZoneCount+32);

         double price100 = ObjectGetDouble(ChartID, ObjName, OBJPROP_PRICE1, 0);
         double price0   = ObjectGetDouble(ChartID, ObjName, OBJPROP_PRICE2, 0);
         if(DebugLevel>= 3) Print("Found a fibo, price 0%: ", price0, ", price 100%: ", price100);

         for (int jj = 0; jj < 32; jj++) {
            double level_pct;
            level_pct = ObjectGetDouble(ChartID, ObjName, OBJPROP_LEVELVALUE, jj);
            if (GetLastError() != 0)
               break;
            // calculate price of level
            double price_of_level = price0 + ((price100 - price0) * level_pct);
            if (DebugLevel >= 3) Print("Found fibonacci level ", jj, ", percentage: ", level_pct, ", price: ", price_of_level);
            ArrayResize(arg, ZoneCount + 1);
            arg[ZoneCount++] = price_of_level;
         }
      }
   }
   ArrayResize(arg, ZoneCount);
   if (ZoneCount > 0)
     ArraySort(arg, WHOLE_ARRAY, 0, MODE_ASCEND);
     
   if(DebugLevel >= 3) Print("Number of zones found: ", ZoneCount);
}


// write zone array contents to CSV file
int WriteZonesToFile(string Filename, double &arg[]) export {
   int fh = FileOpen(Filename, FILE_WRITE | FILE_CSV);
   if (fh == INVALID_HANDLE) {
      return GetLastError();
   }
   FileWrite(fh, Magic, "Zones", Symbol(), EnumToString(ENUM_TIMEFRAMES(_Period)), TimeCurrent());
   for (int ii = 0; ii < ArraySize(arg); ii++) {
      FileWrite(fh, arg[ii]);
   }
   FileClose(fh);
   return ERR_NO_ERROR;
}

int ReadZonesFromFile(string Filename, double &arg[], bool MergeArray = false) export {
   int fh = FileOpen(Filename, FILE_READ | FILE_CSV);
   if (fh == INVALID_HANDLE) {
      return GetLastError();
   }

   string fmagic = FileReadString(fh);
   if (StringCompare(fmagic, Magic) != 0) {
      if (DebugLevel >= 0) Print("File magic mismatch: ", fmagic, " (expected: ", Magic, ")");
         return ERR_USER_ERROR_FIRST;
   }
   string ftype = FileReadString(fh);
   if (StringCompare(ftype, "Zones") != 0) {
      if (DebugLevel >= 0) Print("File type mismatch: ", ftype, " (expected: Zones)");
         return ERR_USER_ERROR_FIRST;
   }
    
   string fsymbol = FileReadString(fh);
   if (DebugLevel >= 0) Print("Symbol: ", fsymbol);

   string ftimeframe = FileReadString(fh);
   if (DebugLevel >= 0) Print("Timeframe: ", ftimeframe);

   string ftime = FileReadString(fh);
   if (DebugLevel >= 0) Print("Created: ", ftime);
    
   int ii = 0;
   if (MergeArray)
      ii = ArraySize(arg);

   while(!FileIsEnding(fh)) {
      string tmp = FileReadString(fh);
      double price = StringToDouble(tmp);
      ArrayResize(arg, ii + 1, 100);
      arg[ii++] = price;
   }
    
   if (ArraySize(arg) > 0)
      ArraySort(arg, WHOLE_ARRAY, 0, MODE_ASCEND);

   return ERR_NO_ERROR;
}

// "look to the left"
// starting at time series index shift search for the first bar that contains the specified price point
// if AboveOrBelow is 0 then it does not matter if the previous price action is above or below the reference price
// if AboveOrBelow > 0 then previous price action must print ABOVE price (bullish indicator)
// if AboveOrBelow < 0 then previous price action must print BELOW price
// returns the index of the first bar whose (low, high) includes price
// 0: the bar at offset matches
int LookToTheLeft(string symbol, int timeframe, int offset, int AboveOrBelow, double price) export {
   int ii;
   for (ii = offset; ii < iBars(symbol, timeframe); ii++) {
      if (AboveOrBelow > 0) {
         if (iLow(symbol, timeframe, ii) < price)
            break;
      }
      if (AboveOrBelow < 0) {
         if (iHigh(symbol, timeframe, ii) > price)
            break;
      }
      if ((price <= iHigh(symbol, timeframe, ii))
          && (price >= iLow(symbol, timeframe, ii)))
         break;
   }
   return ii - offset;
}

// just like the previous function, but checks if either of price1, price2 is within previous bar
int LookToTheLeft(string symbol, int timeframe, int offset, int AboveOrBelow, double price1, double price2) export {
   int ii;
   for (ii = offset; ii < iBars(symbol, timeframe); ii++) {
      if (AboveOrBelow > 0) {
         if (iLow(symbol, timeframe, ii) < fmax(price1, price2))
            break;
      }
      if (AboveOrBelow < 0) {
         if (iHigh(symbol, timeframe, ii) > fmin(price1, price2))
            break;
      }
      if (((price1 <= iHigh(symbol, timeframe, ii))
          && (price1 >= iLow(symbol, timeframe, ii)))
         || ((price2 <= iHigh(symbol, timeframe, ii))
          && (price2 >= iLow(symbol, timeframe, ii))))
         break;
   }
   return ii - offset;
}


// return total bar price range
double CandleStickRange(string symbol, int timeframe, int offset) export {
   return(iHigh(symbol, timeframe, offset) - iLow(symbol, timeframe, offset));
}

// return body price range
double CandleStickBodySize(string symbol, int timeframe, int offset) export {
   return(fabs(iOpen(symbol, timeframe, offset) - iClose(symbol, timeframe, offset)));
}

// return top tail size
double CandleStickTopTailSize(string symbol, int timeframe, int offset) export {
   return(iHigh(symbol, timeframe, offset) - fmax(iOpen(symbol, timeframe, offset), iClose(symbol, timeframe, offset)));
}

// return bottom tail size
double CandleStickBottomTailSize(string symbol, int timeframe, int offset) export {
   return(fmin(iOpen(symbol, timeframe, offset), iClose(symbol, timeframe, offset)) - iLow(symbol, timeframe, offset));
}


// check if price action is on a zone
// return -1 if no match is found
// returns the index in arg[] that denotes the zone that is touched
// checks if the interval price1, price2 prints on a zone of the prices within arg[], allowing tolerance +/- slack
// NOTE: array arg[] must be sorted ascending!
int PriceActionOnZone(double &arg[], double price1, double price2, double slack = 0) export {
   double PriceMax  = fmax(price1, price2) + slack;
   double PriceMin  = fmin(price1, price2) - slack;

   int indexhigh = ArraySize(arg);
   int indexlow  = 0;
  
   if (indexhigh <= 0)
      return -1; // array is empty

   while (indexlow <= indexhigh) {
      int mid = (indexhigh + indexlow) / 2;
    
      if (arg[mid] >= PriceMax) {
         indexhigh = mid - 1;
         continue;
      }
      if (arg[mid] <= PriceMin) {
         indexlow = mid + 1;
         continue;
      }
    
      return mid;
   }
    
   return -1;
}



///////////////////////////////////////////////////////////
// Catalysts

// Catch-All function that wraps all individual Catalysts
double NakedForexCatalyst(int &NFXTradeInfo, int timeframe = 0, int shift = 1, int NFXMask = NFX_SIGNAL_MASK) export {
   double threshold = 0.1;
   double rc = 0.0;

   // force current timeframe
   if (timeframe == 0)
      timeframe = Period();
      
   // preallocate output (will be reset on error later)
   NFXTradeInfo = NFX_TRADE_MAGIC | PeriodToNFXTimeFrame(timeframe);
   
   if ((NFXMask & NFX_SIGNAL_LASTKISS) != 0) {
      rc = NakedForexCatalystLastKiss(timeframe, shift);
      if (fabs(rc) > threshold) {
         NFXTradeInfo |= NFX_SIGNAL_LASTKISS;
         return rc;
      }
   }         
   if ((NFXMask & NFX_SIGNAL_BIGSHADOW) != 0) {
      rc = NakedForexCatalystBigShadow(timeframe, shift);
      if (fabs(rc) > threshold) {
         NFXTradeInfo |= NFX_SIGNAL_BIGSHADOW;
         return rc;
      }
   }         
   if ((NFXMask & NFX_SIGNAL_WAMMIE) != 0) {
      rc = NakedForexCatalystWammie(timeframe, shift);
      if (fabs(rc) > threshold) {
         NFXTradeInfo |= NFX_SIGNAL_WAMMIE;
         return rc;
      }
   }         
   if ((NFXMask & NFX_SIGNAL_MOOLAH) != 0) {
      rc = NakedForexCatalystMoolah(timeframe, shift);
      if (fabs(rc) > threshold) {
         NFXTradeInfo |= NFX_SIGNAL_MOOLAH;
         return rc;
      }
   }
   if ((NFXMask & NFX_SIGNAL_KANGAROOTAIL) != 0) {
      rc = NakedForexCatalystKangarooTail(timeframe, shift);
      if (fabs(rc) > threshold) {
         NFXTradeInfo |= NFX_SIGNAL_KANGAROOTAIL;
         return rc;
      }
   }
   if ((NFXMask & NFX_SIGNAL_BIGBELT) != 0) {
      rc = NakedForexCatalystBigBelt(timeframe, shift);
      if (fabs(rc) > threshold) {
         NFXTradeInfo |= NFX_SIGNAL_BIGBELT;
         return rc;
      }
   }
   if ((NFXMask & NFX_SIGNAL_TRENDINGKANGAROO) != 0) {
      rc = NakedForexCatalystTrendyKangaroo(timeframe, shift);
      if (fabs(rc) > threshold) {
         NFXTradeInfo |= NFX_SIGNAL_TRENDINGKANGAROO;
         return rc;
      }
   }
   if ((NFXMask & NFX_SIGNAL_BEND) != 0) {
      rc = NakedForexCatalystBend(timeframe, shift);
      if (fabs(rc) > threshold) {
         NFXTradeInfo |= NFX_SIGNAL_BEND;
         return rc;
      }
   }
   
   // not matched, reset flag
   NFXTradeInfo = 0;

   return 0;
}


// Last Kiss trade (page 73)
double NakedForexCatalystLastKiss(int timeframe = 0, int shift = 1) export {
   return 0.0;
   if (DebugLevel >= 2) Print("NFX Catalyst Test: Last Kiss");
}

// Big Shadow trade (page 95)
double NakedForexCatalystBigShadow(int timeframe = 0, int shift = 1) export {
   int numberOfPreviousCandlesticks = 10;   // number of candlesticks to consider. Minimum: 3, recommended: 5, optimum: 10
   double maxPredecessorRatio     = 0.6;   // maximum relative size of previous candlestick in percent of the Big Shadow
   double maxOtherPredessorsRatio = 0.7;   // maximum relative size of candlesticks before the predecessor in percent of the Big Shadow
   double PctMinimumBodySize      = 0.5;   // in percent relative to total range
   double PctMinimumCloseDistance = 0.85;  // in percent relative to total range
   double minQualityRoomToTheLeft = 0.7;
   double PctStopBeyondSignal     = 0.02;  // percentage below/above Big Shadow for stop price calculation (based on AveragPreviousRange)


   double AveragePreviousRange         = 0.0;   // will hold the average range of the previous n candlesticks (for stop buy/sell and stop loss computation)
   double BarOpen  = iOpen(Symbol(),  timeframe, shift);
   double BarClose = iClose(Symbol(), timeframe, shift);
   double BarHigh  = iHigh(Symbol(),  timeframe, shift);
   double BarLow   = iLow(Symbol(),   timeframe, shift);
   int    Indicator = 0; // 1: bullish, -1: bearish

   // Big Shadow has the largest range of the n previous candlesticks (page 95 f)
   // The defining characteristics of the big-shadow candlestick are as follows: 
   // The big- shadow candlestick is much larger than the previous candlestick, 
   // the big-shadow candlestick has a wide range, and the big-shadow candlestick 
   // is the largest candlestick the market has seen for some time.
   double BigShadowRange            = CandleStickRange(Symbol(), timeframe, shift);
   double BigShadowBodySize         = CandleStickBodySize(Symbol(), timeframe, shift);
   double BigShadowPredecessorRange = CandleStickRange(Symbol(), timeframe, shift + 1);
   double BigShadowPredecessorBodySize = CandleStickBodySize(Symbol(), timeframe, shift + 1);

   if (DebugLevel >= 2) Print("NFX Catalyst Test: Big Shadow");
   if (DebugLevel >= 3) Print("BarOpen/BarClose/BarHigh/BarLow: ", BarOpen, "/", BarClose, "/", BarHigh, "/", BarLow);  

   // MB: body size should be not too small (not explained, but obvious from charts)
   if (BigShadowRange == 0.0) {
       if (DebugLevel >= 3) Print("C0a: Big Shadow range is zero");
         return 0.0;   
   }
   if (BigShadowPredecessorRange == 0.0) {
       if (DebugLevel >= 3) Print("C0b: Big Shadow predecessor body range is zero");
         return 0.0;   
   }
   if (BigShadowBodySize / BigShadowRange < PctMinimumBodySize) {
       if (DebugLevel >= 3) Print("C0c: Big Shadow body size should be considerable");
         return 0.0;   
   }
   if (BigShadowPredecessorBodySize / BigShadowPredecessorRange < PctMinimumBodySize) {
       if (DebugLevel >= 3) Print("C0d: Big Shadow predecessor body size should be considerable");
         return 0.0;   
   }

   // page 109: The big-shadow candlestick has a higher high and a lower low than the previous candlestick.
   if (! (iHigh(Symbol(), timeframe, shift) > iHigh(Symbol(), timeframe, shift + 1))) {
       if (DebugLevel >= 3) Print("C1: Big Shadow has higher high than the previous candlestick");
         return 0.0;
   }

   if (! (iLow(Symbol(), timeframe, shift) < iLow(Symbol(), timeframe, shift + 1))) {
       if (DebugLevel >= 3) Print("C1: Big Shadow has lower low than the previous candlestick");
         return 0.0;
   }

   if (BigShadowPredecessorRange / BigShadowRange > maxPredecessorRatio) {
      if (DebugLevel >= 3) Print("C2: Big Shadow is much larger than previous candlestick");
      return 0.0;   
   }

   AveragePreviousRange = BigShadowRange + BigShadowPredecessorRange;

   int ii;
   for (ii = shift + 2; ii < shift + numberOfPreviousCandlesticks + 1; ii++) {
      AveragePreviousRange += CandleStickRange(Symbol(), timeframe, ii);
      if (CandleStickRange(Symbol(), timeframe, ii) / BigShadowRange > maxOtherPredessorsRatio) {
         if (DebugLevel >= 3) Print("C3: range larger than previous candlesticks");
         return 0.0;

      }
   }
   AveragePreviousRange /= numberOfPreviousCandlesticks;
   
   if (iOpen(Symbol(), timeframe, shift) == iClose(Symbol(), timeframe, shift)) {
       if (DebugLevel >= 3) Print("C4: zero body size");
         return 0.0;
   }

   double QualityCloseDistance = 0.0;

   // Test if this is a bullish or bearish candidate
   if (iOpen(Symbol(), timeframe, shift) > iClose(Symbol(), timeframe, shift)) {
      Indicator = -1; // bearish
      QualityCloseDistance = 1 - ((BarClose - iLow(Symbol(), timeframe, shift) - BarClose) / BigShadowRange);
   } else {
      Indicator = 1; // bullish
      QualityCloseDistance = 1 - ((iHigh(Symbol(), timeframe, shift) - BarClose) / BigShadowRange);
   }
   
   // Closing price close to high/low
   // The ideal closing price for a bullish big shadow candlestick is the high. 
   // The big-shadow candlestick has a very good chance of success if the candlestick 
   // closes on the high. Obviously, it is rare for the closing price of a bullish 
   // big-shadow candlestick to be equal to the high. The closer the closing price is 
   // to the high for the bullish big-shadow candlestick, the better the trade signal.
   if (QualityCloseDistance < PctMinimumCloseDistance) {
      if (DebugLevel >= 3) Print("C5: Close distance to High/Low too low");
         return 0.0;
   }

   // room to the left (page 103)
   double BigShadowMiddle = BigShadowRange / 2 + iLow(Symbol(), timeframe, shift);
   
   int RoomToLeft = LookToTheLeft(Symbol(), timeframe, shift + 3, Indicator, BigShadowMiddle, BarClose);
   double QualityRoomToLeft = 1.0 - (1 / (RoomToLeft + 1));

   if (QualityRoomToLeft < minQualityRoomToTheLeft) {
      if (DebugLevel >= 3) Print("C6: room to left (", RoomToLeft, " bars)");
      return 0.0;
   }
  
   // advise the trade to caller
   if (Indicator > 0) {
      NFXOrderType(OP_BUYSTOP);
      NFXOrderPrice(NormRound(iHigh(Symbol(), timeframe, shift) + AveragePreviousRange * PctStopBeyondSignal)); // buy just above high
      NFXOrderStoploss(NormRound(iLow(Symbol(), timeframe, shift) - AveragePreviousRange * PctStopBeyondSignal));
   }
   if (Indicator < 0) {
      NFXOrderType(OP_SELLSTOP);
      NFXOrderPrice(NormRound(iLow(Symbol(), timeframe, shift) - AveragePreviousRange * PctStopBeyondSignal)); // sell just below low
      NFXOrderStoploss(NormRound(iHigh(Symbol(), timeframe, shift) + AveragePreviousRange * PctStopBeyondSignal));
   }
   NFXOrderTimestamp(TimeCurrent());
   NFXOrderExpiration(TimeCurrent() + timeframe * 60);

   return Indicator * fabs(QualityCloseDistance * QualityRoomToLeft);;
}

// Wammies (page 111)
double NakedForexCatalystWammie(int timeframe = 0, int shift = 1) export {
   return 0.0;
   if (DebugLevel >= 2) Print("NFX Catalyst Test: Wammie");
}

// Moolah (page 111)
double NakedForexCatalystMoolah(int timeframe = 0, int shift = 1) export {
   return 0.0;
   if (DebugLevel >= 2) Print("NFX Catalyst Test: Moolah");
}


// Kangaroo Tail (page 131)
// arguments
// timeframe: chart timeframe (default: 0/current)
// shift: candlestick to test (default: 1, last)
// return
// 0: not a Kangaroo Tail
// > 0 (0.0 .. 1.0): bullish signal
// < 9 (0.0 .. -1.0): bearish signal
double NakedForexCatalystKangarooTail(int timeframe = 0, int shift = 1) export {
   // policy settings
   double minTailSize                  = 2.0/3.0;  // in percent
   int    numberOfPreviousCandlesticks = 10;
   double PctMaximumBodySize           = 0.2; // in percent relative to total range
   double minQualityRoomToTheLeft      = 0.7;
   double PctStopBeyondSignal          = 0.02;  // percentage below/above signal for stop price calculation (based on AveragPreviousRange)


   double AveragePreviousRange         = 0.0;   // will hold the average range of the previous n candlesticks (for stop buy/sell and stop loss computation)
   double BarOpen  = iOpen(Symbol(),  timeframe, shift);
   double BarClose = iClose(Symbol(), timeframe, shift);
   double BarHigh  = iHigh(Symbol(),  timeframe, shift);
   double BarLow   = iLow(Symbol(),   timeframe, shift);
   int    Indicator = 0; // 1: bullish, -1: bearish

   if (DebugLevel >= 2) Print("NFX Catalyst Test: Kangaroo Tail");
   if (DebugLevel >= 3) Print("BarOpen/BarClose/BarHigh/BarLow: ", BarOpen, "/", BarClose, "/", BarHigh, "/", BarLow);  

   // a kangaroo has a short body compared to the tail
   double KangarooRange          = CandleStickRange(Symbol(),          timeframe, shift);
   double KangarooBodySize       = CandleStickBodySize(Symbol(),       timeframe, shift);
   double KangarooTopTailSize    = CandleStickTopTailSize(Symbol(),    timeframe, shift);
   double KangarooBottomTailSize = CandleStickBottomTailSize(Symbol(), timeframe, shift);

   if (DebugLevel >= 3) Print("Kangaroo Range/Body/Top/Bottom sizes: ", KangarooRange, "/", KangarooBodySize, "/", KangarooTopTailSize, "/", KangarooBottomTailSize);  

   // Test if this is a bullish or bearish candidate
   if (KangarooTopTailSize > KangarooBottomTailSize)
      Indicator = -1; // bearish
   else
      Indicator = 1; // bullish
  
   // criterium 1: body size compared to tails (page 132)
   if (KangarooRange == 0) {
      if (DebugLevel >= 3) Print("C1: zero size");
      return 0.0;
   }

   double RelativeBodySize = KangarooBodySize / KangarooRange;
   if (RelativeBodySize > PctMaximumBodySize) {
      if (DebugLevel >= 3) Print("C1: relative body size");
      return 0.0;
   }

   // criterium 1b: range must be longer than previous candlesticks (page 134, 150)
   int ii;
   AveragePreviousRange = KangarooRange;
   for (ii = shift + 1; ii < shift + numberOfPreviousCandlesticks; ii++) {
      double PrevCandleStickRange = CandleStickRange(Symbol(), timeframe, ii);
      AveragePreviousRange += PrevCandleStickRange;
      if (KangarooRange < PrevCandleStickRange) {
         if (DebugLevel >= 3) Print("C1: tailsize relative to previous candlesticks (", PrevCandleStickRange, ")");
         return 0.0;
      }
   }
   
   AveragePreviousRange /= numberOfPreviousCandlesticks;
    
   // weighted criterium, the smaller the body the better. 0 < QualityBodySize <= 1
   double QualityBodySize = (1 / PctMaximumBodySize) * (PctMaximumBodySize - RelativeBodySize);
   
   // criterium 2: body is within 1/3 of the candlestick (page 132)
   double RelativeTailSize = fmax(KangarooTopTailSize, KangarooBottomTailSize) / KangarooRange;
   if (RelativeTailSize < minTailSize) {
      if (DebugLevel >= 3) Print("C2: body within a third of the current candlestick");
      return 0.0;
   }
    
   // criterium 3: open and close of Kangaroo Tail should be within previous candle (page 139 ff)
   if (! (iLow(Symbol(), timeframe, shift + 1) < fmin(BarOpen, BarClose))
          && (fmax(BarOpen, BarClose) < iHigh(Symbol(), timeframe, shift + 1))) {
      if (DebugLevel >= 3) Print("C3: open/close within previous candle");
      return 0.0;
   }
    
   // TODO quality measure: depth of enclosure (distance of the body to the high/low of the previous candle stick)
   double QualityEnclosure = 1.0;

   // criterium 4: room to the left (page 141)
   // previous candle range engulfs Kangaroo body, hence start at the one before the previous candle
   int RoomToLeft = LookToTheLeft(Symbol(), timeframe, shift + 2, Indicator, fmin(BarOpen, BarClose), fmax(BarOpen, BarClose));
   double QualityRoomToLeft = 1.0 - (1 / (RoomToLeft + 1));

   if (QualityRoomToLeft < minQualityRoomToTheLeft) {
      if (DebugLevel >= 3) Print("C4: room to left (", RoomToLeft, " bars)");
      return 0.0;
   }
  
   double QualityTailSize = RelativeTailSize;  // note: do not rescale this value, it is already in the range of 0.67 .. 1.0
  
   if (DebugLevel >= 1) Print("Kangaroo ", Indicator, " High/Low: ", BarHigh, "/", BarLow, " Open/Close: ", BarOpen, "/", BarClose, 
    " Body/TailTop/TailBottom: ", KangarooBodySize, "/", KangarooTopTailSize, "/", KangarooBottomTailSize, " QualityBody/QualityTail: ", QualityBodySize, "/", QualityTailSize);


   // advise the trade to caller
   if (Indicator > 0) {
      NFXOrderType(OP_BUYSTOP);
      NFXOrderPrice(NormRound(iHigh(Symbol(), timeframe, shift) + AveragePreviousRange * PctStopBeyondSignal)); // buy just above high
      NFXOrderStoploss(NormRound(iLow(Symbol(), timeframe, shift) - AveragePreviousRange * PctStopBeyondSignal));
   }
   if (Indicator < 0) {
      NFXOrderType(OP_SELLSTOP);
      NFXOrderPrice(NormRound(iLow(Symbol(), timeframe, shift) - AveragePreviousRange * PctStopBeyondSignal)); // sell just below low
      NFXOrderStoploss(NormRound(iHigh(Symbol(), timeframe, shift) + AveragePreviousRange * PctStopBeyondSignal));
   }
   NFXOrderTimestamp(TimeCurrent());
   NFXOrderExpiration(TimeCurrent() + timeframe * 60);



   return Indicator * fabs(QualityBodySize * QualityEnclosure * QualityRoomToLeft * QualityTailSize);
}

// Big Belt (page 151)
double NakedForexCatalystBigBelt(int timeframe = 0, int shift = 1) export {
   return 0.0;
   if (DebugLevel >= 2) Print("NFX Catalyst Test: Big Belt");
}

// Trendy Kangaroo (page 163)
double NakedForexCatalystTrendyKangaroo(int timeframe = 0, int shift = 1) export {
   return 0.0;
   if (DebugLevel >= 2) Print("NFX Catalyst Test: Trendy Kangaroo");
}

// Bend (extra chapter)
double NakedForexCatalystBend(int timeframe = 0, int shift = 1) export {
   return 0.0;
   if (DebugLevel >= 2) Print("NFX Catalyst Test: Bend");
}
