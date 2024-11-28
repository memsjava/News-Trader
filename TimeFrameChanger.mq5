////////////////////////////////////////////////////////////////////////////////
// Mechanical trade system for MetaTrader 5                                   //                                   //
////////////////////////////////////////////////////////////////////////////////
// User script "Synchronizing the timeframes of the charts"                   //
// Unit: TimeFrameChanger                                                          //
////////////////////////////////////////////////////////////////////////////////
// Version:      1.0                                                          //
// Version File: 1.0.0.0                                                      //
// File name: TimeFrameChanger.mq5                                                   //
////////////////////////////////////////////////////////////////////////////////
//                                  Property                                  //
////////////////////////////////////////////////////////////////////////////////
#property description "User script - Synchronizing the timeframes of the charts"
#property description "Version File: 1.0.0.0"
#property copyright "Copyright 2010, Interesting"
#property link "http://www.mql5.com"

#property script_show_inputs
////////////////////////////////////////////////////////////////////////////////
//                      The arrays for keeping main data                      //
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//                              Input parameters                              //
////////////////////////////////////////////////////////////////////////////////
input ENUM_TIMEFRAMES dangerPeriod = PERIOD_H1; // Danger period
input ENUM_TIMEFRAMES WorkPeriod = PERIOD_M5;   // Work period

////////////////////////////////////////////////////////////////////////////////
//                Global variables, used in working the script                //
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//                       Script program start function                        //
////////////////////////////////////////////////////////////////////////////////
void SynchronizeTimeframes(bool isDanger)
{
  //----------------------------------------------------------------------------//
  // Work variables
  ENUM_TIMEFRAMES TimeFrames; // TimeFrames
  if (isDanger)
  {
    TimeFrames = dangerPeriod; // Use dangerPeriod if is_danger is true
  }
  else
  {
    TimeFrames = WorkPeriod; // Use WorkPeriod if is_danger is false
  }

  string ChartSymbolName; // The symbol name for the specified chart

  long ChartFirstID; // The ID of the first chart of the client terminal
  long ChartNextID;  // Identifier for of the new chart

  int Limit = CHARTS_MAX;

  int f;
  //----------------------------------------------------------------------------//

  // Synchronizing the timeframes of the charts
  ChartFirstID = ChartFirst();
  // Processing of the main chart
  if (ChartPeriod(ChartFirstID) != TimeFrames)
  {
    ChartSymbolName = ChartSymbol(ChartFirstID);
    // Change the timeframe of the specified chart
    ChartSetSymbolPeriod(ChartFirstID, ChartSymbolName, TimeFrames);
    // Message for user
    PrintFormat("Change the timeframe of the chart %s. New period %s",
                ChartSymbolName, PeriodToStr(TimeFrames));
  }
  // Processing of additional charts
  f = 0;
  while (f < Limit)
  // We have certainly not more than 100 open charts
  {
    // Get the new chart ID by using the previous chart ID
    ChartNextID = ChartNext(ChartFirstID);

    if (ChartNextID < 0)
      break; // Have reached the end of the chart list

    if (ChartPeriod(ChartNextID) != TimeFrames)
    // Change the timeframe of the specified chart
    {
      ChartSymbolName = ChartSymbol(ChartNextID);
      // Change the timeframe of the specified chart
      ChartSetSymbolPeriod(ChartNextID, ChartSymbolName, TimeFrames);
      // Message for user
      PrintFormat("Change the timeframe of the chart %s. New period %s",
                  ChartSymbolName, PeriodToStr(TimeFrames));
    }

    // Let's save the current chart ID for the ChartNext()
    ChartFirstID = ChartNextID;
    // Do not forget to increase the counter
    f++;
  }

  //----------------------------------------------------------------------------//
}
////////////////////////////////////////////////////////////////////////////////
//                      Specific procedures and functions                     //
////////////////////////////////////////////////////////////////////////////////
// Function PeriodToStr
string PeriodToStr(ENUM_TIMEFRAMES Value)
{
  //----------------------------------------------------------------------------//
  // Work variables
  string Result; // Returned importance
  //----------------------------------------------------------------------------//

  switch (Value)
  {
  case PERIOD_M1:
    Result = "M1";
    break;
  case PERIOD_M2:
    Result = "M2";
    break;
  case PERIOD_M3:
    Result = "M3";
    break;
  case PERIOD_M4:
    Result = "M4";
    break;
  case PERIOD_M5:
    Result = "M5";
    break;
  case PERIOD_M6:
    Result = "M6";
    break;
  case PERIOD_M10:
    Result = "M10";
    break;
  case PERIOD_M12:
    Result = "M12";
    break;
  case PERIOD_M15:
    Result = "M15";
    break;
  case PERIOD_M20:
    Result = "M20";
    break;
  case PERIOD_M30:
    Result = "M30";
    break;
  case PERIOD_H1:
    Result = "H1";
    break;
  case PERIOD_H2:
    Result = "H2";
    break;
  case PERIOD_H3:
    Result = "H3";
    break;
  case PERIOD_H4:
    Result = "H4";
    break;
  case PERIOD_H6:
    Result = "H6";
    break;
  case PERIOD_H8:
    Result = "H8";
    break;
  case PERIOD_H12:
    Result = "H12";
    break;
  case PERIOD_D1:
    Result = "Day";
    break;
  case PERIOD_W1:
    Result = "Week";
    break;
  case PERIOD_MN1:
    Result = "Month";
    break;
  // Unknown
  default:
    Result = "Unknown";
    break;
  }
  //----------------------------------------------------------------------------//
  return (Result);
  //----------------------------------------------------------------------------//
}
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//                         Function to handle on tick events                 //
////////////////////////////////////////////////////////////////////////////////
void OnTick()
{
  // Check if there are any open positions
  if (PositionsTotal() > 1)
  {
    // Synchronize the timeframes to the user's specified timeframe
    SynchronizeTimeframes(true);
  }
  else
  {
    // Synchronize the timeframes to the user's specified timeframe
    SynchronizeTimeframes(false);
  }
}