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

int DebugLevel = 0;

const string Magic = "NFZT 1.0";

void NakedForexSetDebugLevel(int arg) export {
   DebugLevel = arg;
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
// returns the index of the first bar whose (low, high) includes price
// 0: the bar at offset matches
int LookToTheLeft(string symbol, int timeframe, int offset, double price) export {
   int ii;
   for (ii = offset; ii < iBars(symbol, timeframe); ii++) {
      if ((price <= iHigh(Symbol(), timeframe, ii))
          && (price >= iLow(Symbol(), timeframe, ii)))
         break;
   }
   return ii - offset;
}

// just like the previous function, but checks if either of price1, price2 is within previous bar
int LookToTheLeft(string symbol, int timeframe, int offset, double price1, double price2) export {
   int ii;
   for (ii = offset; ii < iBars(symbol, timeframe); ii++) {
      if (((price1 <= iHigh(Symbol(), timeframe, ii))
          && (price1 >= iLow(Symbol(), timeframe, ii)))
         || ((price2 <= iHigh(Symbol(), timeframe, ii))
          && (price2 >= iLow(Symbol(), timeframe, ii))))
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

// Last Kiss trade (page 73)
double NakedForexCatalystLastKiss(int timeframe = 0, int shift = 1) export {
   return 0.0;
}

// Big Shadow trade (page 95)
double NakedForexCatalystBigShadow(int timeframe = 0, int shift = 1) export {
   return 0.0;
}


// Wammies (page 111)
double NakedForexCatalystWammie(int timeframe = 0, int shift = 1) export {
   return 0.0;
}

// Moolah (page 111)
double NakedForexCatalystMoolah(int timeframe = 0, int shift = 1) export {
   return 0.0;
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
   double minTailSize = 2.0/3.0;  // in percent
   int    numberOfPreviousCandlesticks = 10;
   double PctMaximumBodySize = 0.2; // in percent relative to total range

   double BarOpen  = iOpen(Symbol(), timeframe, shift);
   double BarClose = iClose(Symbol(), timeframe, shift);
   double BarHigh  = iHigh(Symbol(), timeframe, shift);
   double BarLow   = iLow(Symbol(), timeframe, shift);
   double Indicator = 0; // 1: bullish, -1: bearish

   if (DebugLevel >= 3) Print("BarOpen/BarClose/BarHigh/BarLow: ", BarOpen, "/", BarClose, "/", BarHigh, "/", BarLow);  

   // a kangaroo has a short body compared to the tail
   double KangarooRange          = CandleStickRange(Symbol(), timeframe, shift);
   double KangarooBodySize       = CandleStickBodySize(Symbol(), timeframe, shift);
   double KangarooTopTailSize    = CandleStickTopTailSize(Symbol(), timeframe, shift);
   double KangarooBottomTailSize = CandleStickBottomTailSize(Symbol(), timeframe, shift);

   if (DebugLevel >= 3) Print("Kangaroo Range/Body/Top/Bottom sizes: ", KangarooRange, "/", KangarooBodySize, "/", KangarooTopTailSize, "/", KangarooBottomTailSize);  
   int ii;

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
   for (ii = shift + 1; ii < shift + numberOfPreviousCandlesticks; ii++) {
      double PrevCandleStickRange = CandleStickRange(Symbol(), timeframe, ii);
      if (KangarooRange < PrevCandleStickRange) {
         if (DebugLevel >= 3) Print("C1: tailsize relative to previous candlesticks (", PrevCandleStickRange, ")");
            return 0.0;
      }
   }
    
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
   int RoomToLeft = LookToTheLeft(Symbol(), timeframe, shift + 2, fmin(BarOpen, BarClose), fmax(BarOpen, BarClose));
   double QualityRoomToLeft = 1.0 - (1 / (RoomToLeft + 1));

   if (QualityRoomToLeft < 0.7) {
      if (DebugLevel >= 3) Print("C4: room to left (", RoomToLeft, " bars)");
         return 0.0;
   }
  
   double QualityTailSize = RelativeTailSize;  // note: do not rescale this value, it is already in the range of 0.67 .. 1.0
  
   if (DebugLevel >= 1) Print("Kangaroo ", Indicator, " High/Low: ", BarHigh, "/", BarLow, " Open/Close: ", BarOpen, "/", BarClose, 
    " Body/TailTop/TailBottom: ", KangarooBodySize, "/", KangarooTopTailSize, "/", KangarooBottomTailSize, " QualityBody/QualityTail: ", QualityBodySize, "/", QualityTailSize);

   return Indicator * fabs(QualityBodySize * QualityEnclosure * QualityRoomToLeft * QualityTailSize);
}



// Big Belt (page 151)
double NakedForexCatalystBigBelt(int timeframe = 0, int shift = 1) export {
   return 0.0;
}

// Trendy Kangaroo (page 163)
double NakedForexCatalystTrendyKangaroo(int timeframe = 0, int shift = 1) export {
   return 0.0;
}

