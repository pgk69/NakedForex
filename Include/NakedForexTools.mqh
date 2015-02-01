//+------------------------------------------------------------------+
//|                                              NakedForexTools.mqh |
//|                                                  Martin Bartosch |
//|                                          http://fx.bartosch.name |
//+------------------------------------------------------------------+
#property copyright "Martin Bartosch"
#property link      "http://fx.bartosch.name"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
#ifndef __NakedForexTools_H__
#define __NakedForexTools_H__

#define NFX_TRADE_MAGIC              0x10000000

#define NFX_SIGNAL_MASK              0x00111000

#define NFX_SIGNAL_LASTKISS          0x00000000
#define NFX_SIGNAL_BIGSHADOW         0x00001000
#define NFX_SIGNAL_WAMMIE            0x00010000
#define NFX_SIGNAL_MOOLAH            0x00011000
#define NFX_SIGNAL_KANGAROOTAIL      0x00100000
#define NFX_SIGNAL_BIGBELT           0x00101000
#define NFX_SIGNAL_TRENDINGKANGAROO  0x00110000
#define NFX_SIGNAL_BEND              0x00111000

// Our EA will handle timeframes between 1 min and 1 day
#define NFX_TIMEFRAME_MASK           0x00000111

#define NFX_TIMEFRAME_UNDEF          0x00000000
#define NFX_TIMEFRAME_M1             0x00000001
#define NFX_TIMEFRAME_M5             0x00000010
#define NFX_TIMEFRAME_M15            0x00000011
#define NFX_TIMEFRAME_M30            0x00000100
#define NFX_TIMEFRAME_H1             0x00000101
#define NFX_TIMEFRAME_H4             0x00000110
#define NFX_TIMEFRAME_D1             0x00000111



#import "NakedForexTools.ex4"
  void NFXSetDebugLevel(int arg);
  
  // Accessors
  int      NFXOrderType(int arg = -1);
  double   NFXOrderPrice(double arg = -1.0);
  double   NFXOrderStoploss(double arg = -1.0);
  datetime NFXOrderExpiration(datetime arg = -1);
  datetime NFXOrderTimestamp(datetime arg = -1);

  // Chart analysis
  int    LookToTheLeft(string symbol, int timeframe, int offset, int AboveOrBelow, double price);
  int    LookToTheLeft(string symbol, int timeframe, int offset, int AboveOrBelow, double price1, double price2);
  double CandleStickRange(string symbol, int timeframe, int offset);
  double CandleStickBodySize(string symbol, int timeframe, int offset);
  double CandleStickTopTailSize(string symbol, int timeframe, int offset);
  double CandleStickBottomTailSize(string symbol, int timeframe, int offset);

  // Zone functions
  void   GetZonesFromChartObjects(long ChartID, double &arg[]);
  int    WriteZonesToFile(string Filename, double &arg[]);
  int    ReadZonesFromFile(string Filename, double &arg[], bool MergeArray = false);
  int    PriceActionOnZone(double &arg[], double price1, double price2, double slack = 0);
    
  // Catalysts
  // wrapper catch-all function
  // NFXTradeInfo should be initialized with 0 before calling. 
  // Function returns NFXTradeInfo mask with the signal type that triggered (if applicable).
  // If NFXTradeInfo is 0 then no signal triggered.
  // Function will only consider NFX Trade Signals explicitly enabled via NFXMask (default: all)
  // Return value: quality of the signal
  // 0.1 .. 1.0: Buy signal
  // -0.1 .. -1.0: Sell signal
  // the closer the absolute value is to 1.0 the better the signal
  // different NFX Catalysts return different quality levels!
  double NakedForexCatalyst(int &NFXTradeInfo, int timeframe = 0, int shift = 1, int NFXMask = NFX_SIGNAL_MASK);

  double NakedForexCatalystLastKiss(int timeframe = 0, int shift = 1);
  double NakedForexCatalystBigShadow(int timeframe = 0, int shift = 1);
  double NakedForexCatalystWammie(int timeframe = 0, int shift = 1);
  double NakedForexCatalystMoolah(int timeframe = 0, int shift = 1);
  double NakedForexCatalystKangarooTail(int timeframe = 0, int shift = 1);
  double NakedForexCatalystBigBelt(int timeframe = 0, int shift = 1);
  double NakedForexCatalystTrendyKangaroo(int timeframe = 0, int shift = 1);
  double NakedForexCatalystBend(int timeframe = 0, int shift = 1);
  
#import


#endif
