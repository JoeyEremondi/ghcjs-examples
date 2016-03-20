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

import Text.Parsec.Pos (SourcePos, sourceColumn, sourceLine)

import qualified Language.LambdaPiPlus as LPP

import GHCJS.Foreign.QQ

addError :: (Maybe SourcePos, String) -> IO ()
addError (Nothing, xs) = [js_| tryps.addError(`xs); |]
addError (Just pos, xs) =
  let
    ln = sourceLine pos
    col = sourceColumn pos
  in
    [js_| tryps.addErrorAt(`ln, `col, `xs); |]

reportSource :: String -> IO ()
reportSource src = [js_| tryps.reportTypeError(`src); |]

compileWorker :: MVar String -> (forall a. IO a -> IO a) -> IO ()
compileWorker mv unmask =
  forever $ unmask doCompile `catch` \(e::AsyncException) -> return ()
    where
      doCompile = do
        src  <- takeMVar mv
        [js_| tryps.setBusy('Compiling...'); |]
        case LPP.parse src of
          Left errList -> do
            [js_| tryps.clearError(); |]
            forM_ errList addError
          Right parseResult ->
             case LPP.compile parseResult LPP.initialContext of
                  Left errList            -> do
                    [js_| tryps.clearError(); |]
                    forM_ errList $ \(loc, err) -> do
                      addError (loc, err)
                      reportSource src
                  Right (_, output) -> [js_| tryps.setResult(`output); |]

abortCompilation :: ThreadId -> IO ()
abortCompilation worker = killThread worker

main :: IO ()
main = do
  [js_| trypsInit();
        tryps.setResult('Enter your code on the left, then click the button on the right to typecheck.');
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
