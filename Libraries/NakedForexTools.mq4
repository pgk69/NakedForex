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

extern int DebugLevel;

const string Magic = "NFZT 1.0";

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
double CandleStickTotalSize(string symbol, int timeframe, int offset) export {
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


// rounds the argument to the nearest tick value
double RoundNormalizedOnTickValue(double Value) export {
  int    OrderDigits        = SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);
  double OrderTradeTickSize = SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_TICK_SIZE);

  Value = OrderTradeTickSize * round(Value / OrderTradeTickSize);
  Value = NormalizeDouble(Value, OrderDigits);

  return(Value);
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

  // Alert("PriceActionOnZone for price range ", PriceMin, " - ", PriceMax);
  
  if (indexhigh <= 0)
    return -1; // array is empty

//  Alert("Arraysize: ", indexhigh);

  while (indexlow <= indexhigh) {
//    Alert("LowIndex: ", indexlow, " HighIndex: ", indexhigh);
    int mid = (indexhigh + indexlow) / 2;
    
    if (arg[mid] >= PriceMax) {
      indexhigh = mid - 1;
//      Alert("Index mid value ", arg[mid], " is too high, next high index: ", indexhigh);
      continue;
    }
    if (arg[mid] <= PriceMin) {
      indexlow = mid + 1;
//      Alert("Index mid value ", arg[mid], " is too low, next low index: ", indexhigh);
      continue;
    }
    
//    Alert("Match found: ", arg[mid]);
    return mid;
  }
    
  return -1;
}
