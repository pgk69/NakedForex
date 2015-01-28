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
  double RoundNormalizedOnTickValue(double Value);

  void   GetZonesFromChartObjects(long ChartID, double &arg[]);

  int    WriteZonesToFile(string Filename, double &arg[]);
  int    ReadZonesFromFile(string Filename, double &arg[], bool MergeArray = false);

  int    PriceActionOnZone(double &arg[], double price1, double price2, double slack = 0);
#import


#endif
