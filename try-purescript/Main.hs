{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE JavaScriptFFI            #-}
{-# LANGUAGE QuasiQuotes              #-}
{-# LANGUAGE Rank2Types               #-}
{-# LANGUAGE ScopedTypeVariables      #-}

{-
  A simple example demonstrating ghcjs-ffiqq and working with asynchronous threads
 -}
module Main where

import Control.Applicative
import Control.Concurrent
import Control.Exception
import Control.Monad
import Control.Monad.Reader

import qualified Language.LambdaPiPlus as LPP

import GHCJS.Foreign.QQ

setError :: String -> IO ()
setError xs = [js_| tryps.setError(`xs); |]

compileWorker :: MVar String -> (forall a. IO a -> IO a) -> IO ()
compileWorker mv unmask =
  forever $ unmask doCompile `catch` \(e::AsyncException) -> return ()
    where
      doCompile = do
        src  <- takeMVar mv
        [js_| tryps.setBusy('Compiling...'); |]
        case LPP.parse src of
          Left err -> setError (show err)
          Right parseResult ->
             case LPP.compile parseResult LPP.initialContext of
                  Left err            -> do 
                    let errString = show err
                    setError $ show err
                  Right (_, output) -> [js_| tryps.setResult(`output); |]

abortCompilation :: ThreadId -> IO ()
abortCompilation worker = killThread worker

main :: IO ()
main = do
  [js_| trypsInit();
        tryps.setBusy('Compiling Prelude...');
      |]
  --prelSrc <- [js| tryps.getPrelude() |]
  --let parsePS src = either (error . show) (map snd) $
  --                  P.parseModulesFromFiles (const "<built-in>") [((), src)]
  --    prelMods = parsePS prelSrc
  --    (prelJs, prelExtSrc, _prelEnv) =
  --       either error id $ P.compile prelMods [] `runReaderT` P.defaultCompileOptions
  --    prelExts = parsePS prelExtSrc
  --[js_| tryps.setCompiledPrelude(`prelJs); |]
  mv <- newEmptyMVar
  worker <- mask_ $ forkIOWithUnmask (compileWorker mv)
  forever $ do
    [jsi_| tryps.waitForChange($c); |]
    abortCompilation worker
    threadDelay 500000
    putMVar mv =<< [js| tryps.getEditorContents() |]
