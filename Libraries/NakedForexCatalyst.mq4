//+------------------------------------------------------------------+
//|                                           NakedForexCatalyst.mq4 |
//|                                                  Martin Bartosch |
//|                                          http://fx.bartosch.name |
//+------------------------------------------------------------------+
#property library
#property copyright "Martin Bartosch"
#property link      "http://fx.bartosch.name"
#property version   "1.00"
#property strict

#import "NakedForexTools.ex4"
int LookToTheLeft(string symbol, int timeframe, int offset, double price);
int LookToTheLeft(string symbol, int timeframe, int offset, double price1, double price2);

double CandleStickTotalSize(string symbol, int timeframe, int offset);
double CandleStickBodySize(string symbol, int timeframe, int offset);
double CandleStickTopTailSize(string symbol, int timeframe, int offset);
double CandleStickBottomTailSize(string symbol, int timeframe, int offset);


#import


extern int DebugLevel;



// signal tests

// Last Kiss trade (page 73)
double NakedForexCatalystLastKiss(int timeframe = 0) export {
  return 0.0;
}

// Big Shadow trade (page 95)
double NakedForexCatalystBigShadow(int timeframe = 0) export {
  return 0.0;
}


// Wammies (page 111)
double NakedForexCatalystWammie(int timeframe = 0) export {
  return 0.0;
}

// Moolah (page 111)
double NakedForexCatalystMoolah(int timeframe = 0) export {
  return 0.0;
}


// Kangaroo Tail (page 131)
// arguments
// timeframe: chart timeframe (default: 0/current)
// shift: candlestick to test (default: 1, last)
// PctMaximumBodySize: maximum relative body size
// return
// 0: not a Kangaroo Tail
// > 0 (0.0 .. 1.0): bullish signal
// < 9 (0.0 .. -1.0): bearish signal
double NakedForexCatalystKangarooTail(int timeframe = 0, int shift = 1, double PctMaximumBodySize = 0.2) export {
  // policy settings
  double minTailSize = 0.67;
  double minCandlestickSize = 5;


  double PipSize = (1 / SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE));

  double BarOpen  = iOpen(Symbol(), timeframe, shift);
  double BarClose = iClose(Symbol(), timeframe, shift);
  double BarHigh  = iHigh(Symbol(), timeframe, shift);
  double BarLow   = iLow(Symbol(), timeframe, shift);
  double Indicator = 0; // 1: bullish, -1: bearish

  // a kangaroo has a short body compared to the tail
  double KangarooTotalSize      = CandleStickTotalSize(Symbol(), timeframe, shift);
  double KangarooBodySize       = CandleStickBodySize(Symbol(), timeframe, shift);
  double KangarooTopTailSize    = CandleStickTopTailSize(Symbol(), timeframe, shift);
  double KangarooBottomTailSize = CandleStickBottomTailSize(Symbol(), timeframe, shift);
  
  int ii;

  // Test if this is a bullish or bearish candidate
  if (KangarooTopTailSize > KangarooBottomTailSize)
    Indicator = -1; // bearish
  else
    Indicator = 1; // bullish

  
  // criterium 1: body size compared to tails (page 132)
  if (KangarooTotalSize == 0) {
    if (DebugLevel >= 3) Print("C1: zero size");
    return 0.0;
  }
  double RelativeBodySize = KangarooBodySize / KangarooTotalSize;
  if (RelativeBodySize > PctMaximumBodySize) {
    if (DebugLevel >= 3) Print("C1: relative body size");
    return 0.0;
  }

  // criterium 1a: candlestick absolute minimum pip size
  if (BarHigh - BarLow < minCandlestickSize * PipSize) {
    if (DebugLevel >= 3) Print("C1a: absolute body size");
    return 0.0;
  }

  // criterium 1b: tailsize must be longer than previous candlesticks (page 134, 150)
  for (ii = shift + 1; ii < shift + 10; ii++) {
    double PrevCandleStickSize = iHigh(Symbol(), timeframe, ii) - iLow(Symbol(), timeframe, ii);
    if (fmax(KangarooTopTailSize, KangarooBottomTailSize) < PrevCandleStickSize) {
      if (DebugLevel >= 3) Print("C1b: tailsize relative to previous candlesticks");
      return 0.0;
    }
  }
    
  // weighted criterium, the smaller the body the better. 0 < QualityBodySize <= 1
  double QualityBodySize = (1 / PctMaximumBodySize) * (PctMaximumBodySize - RelativeBodySize);
   
  // criterium 2: body is within 1/3 of the candlestick (page 132)
  double RelativeTailSize = fmax(KangarooTopTailSize, KangarooBottomTailSize) / KangarooTotalSize;
  if (RelativeTailSize < minTailSize) {
    if (DebugLevel >= 3) Print("C2: body within 1/3 of previous candlestick");
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
double NakedForexCatalystBigBelt(int timeframe = 0) export {
  return 0.0;
}

// Trendy Kangaroo (page 163)
double NakedForexCatalystTrendyKangaroo(int timeframe = 0) export {
  return 0.0;
}

