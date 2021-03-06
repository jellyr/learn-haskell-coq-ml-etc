module Logging where

import           Control.Monad     (forM_)
import qualified System.Log.Logger as Log

lBASE, lDIRECT, lLEDGER, lMINER, lPOOLED, lTAMPEREVIDENT :: String
lBASE   = "BASE"
lDIRECT = "DIRECT"
lLEDGER = "LEDGER"
lMINER  = "MINER"
lPOOLED  = "POOLED"
lTAMPEREVIDENT = "TAMPEREVIDENT"

setLogLevels :: IO ()
setLogLevels =
  forM_ [lBASE, lDIRECT, lLEDGER, lMINER, lPOOLED, lTAMPEREVIDENT] $ \x ->
    Log.updateGlobalLogger x (Log.setLevel Log.DEBUG)

