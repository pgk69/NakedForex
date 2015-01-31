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

#import "NakedForexTools.ex4"
  // Chart analysis
  int    LookToTheLeft(string symbol, int timeframe, int offset, double price);
  int    LookToTheLeft(string symbol, int timeframe, int offset, double price1, double price2);
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
  double NakedForexCatalystLastKiss(int timeframe = 0, int shift = 1);
  double NakedForexCatalystBigShadow(int timeframe = 0, int shift = 1);
  double NakedForexCatalystWammie(int timeframe = 0, int shift = 1);
  double NakedForexCatalystMoolah(int timeframe = 0, int shift = 1);
  double NakedForexCatalystKangarooTail(int timeframe = 0, int shift = 1);
  double NakedForexCatalystBigBelt(int timeframe = 0, int shift = 1);
  double NakedForexCatalystTrendyKangaroo(int timeframe = 0, int shift = 1);
  
#import


#endif
