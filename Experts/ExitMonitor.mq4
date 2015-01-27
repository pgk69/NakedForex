//+------------------------------------------------------------------+
//|                                                  ExitMonitor.mq4 |
//|                                                      Peter Kempf |
//|                                                      Version 1.0 |
//+------------------------------------------------------------------+
#property copyright "Peter Kempf"
#property link      ""

//--- input parameters
//- MagicNumber:    0: Every trade will be monitored
//               <> 0: Only trades with MagicNumber will be monitored
extern int MagicNumber = 0;

//- onlyCurrentSymbol: true:  Only the current Symbol will be monitored
//                     false: every Symbol will be monitored
extern bool onlyCurrentSymbol   = true;


//--- Global variables
extern

//--- Includes
#include <ToolBox.mqh>
#include <ExitStrategies.mqh>

//--- Imports


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  ExitStrategies_Init();
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
}

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
void OnTick() {
  int rc, Retry, Ticket;
  double Correction, TPPips, SLPips, TPTrailPips, TP, SL, SLTrailPips;

  // Bearbeitung aller offenen Trades
  if (DebugLevel > 3) Print(OrderSymbol()," Read Orderbook (Total of all Symbols: ",OrdersTotal(),")");
  for (int i=0; i<OrdersTotal(); i++) {
    // Only valid Tickets are processed
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)    continue;
    // Only OP_BUY or OP_SELL Tickets are processed
    if ((OrderType() != OP_BUY) && (OrderType() != OP_SELL))    continue;
    // according to onlyCurrentSymbol only tickets trading the current symbol are processed
    if (onlyCurrentSymbol && (OrderSymbol() != Symbol()))       continue;
    // according to MagicNumber only tickets with fitting magicnumber are processed
    if (myMagicNumber && (OrderMagicNumber() != myMagicNumber)) continue;
 
    // Possibly determine an correctionfactor
    Correction = indFaktor();
    // Falls TPPercent angegeben ist, wird TPPips errechnet
    TPPips = calcPips(TP_Grenze, TP_Percent, TP_Pips);
    // Falls SLPercent angegeben ist, wird SLPips errechnet
    SLPips = calcPips(SL_Grenze, SL_Percent, SL_Pips);
    // Falls TPTrailPercent angegeben ist, wird TPTrailPips errechnet
    TPTrailPips = calcPips(TP_Trail_Grenze, TP_Trail_Percent, TP_Trail_Pips);
    // Falls TPTrailPercent angegeben ist, wird TPTrailPips errechnet
    SLTrailPips = calcPips(SL_Trail_Grenze, SL_Trail_Percent, SL_Trail_Pips);
  
    TP = bestimmeTP(Correction, OrderTakeProfit(), TPPips, TPTrailPips, OrderStopLoss(), SLPips, SLTrailPips);
    SL = bestimmeSL(Correction, OrderTakeProfit(), TPPips, TPTrailPips, OrderStopLoss(), SLPips, SLTrailPips);
  
    if (SL != OrderStopLoss() || TP != OrderTakeProfit()) {
      if (DebugLevel > 1) {
        Print(OrderSymbol(), " OrderModify(SL:", SL, ", TP:", TP, ")");
        Print(OrderSymbol()," Corrections determined as: ", Anpassung);
        if (TP_Pips != TPPips)            Print(OrderSymbol(), " TP_Pips changed from ", TP_Pips, " to ", TPPips);
        if (TP_Trail_Pips != TPTrailPips) Print(OrderSymbol(), " TP_Trail_Pips changed from ", TP_Trail_Pips, " to ", TPTrailPips);
        if (SL_Pips != SLPips)            Print(OrderSymbol(), " SL_Pips changed from ", SL_Pips, " to ", SLPips);
      }
      Retry  = 0;
      rc     = 0;
      Ticket = OrderTicket();
      while ((rc == 0) && (Retry < MaxRetry)) {
        RefreshRates();
        rc = OrderModify(Ticket, 0, SL, TP, 0, CLR_NONE);
        if (!rc) {
          rc = GetLastError();
          if (DebugLevel > 0) Print(OrderSymbol(), " OrderModify(", Ticket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
          Print(IntegerToString(rc) + ": " + ErrorDescription(rc));
        } else {
          if (DebugLevel > 1) Print(OrderSymbol(), " OrderModify(", Ticket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
        }
        Retry++;
      }
    }
  }

  return(0);
}