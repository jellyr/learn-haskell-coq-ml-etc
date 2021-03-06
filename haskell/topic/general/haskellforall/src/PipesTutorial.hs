{-
Created       : 2014 May 01 (Thu) 21:59:04 by Harold Carr.
Last Modified : 2016 Apr 09 (Sat) 14:21:06 by Harold Carr.
-}

module PipesTutorial where

import           Control.Exception (throwIO, try)
import           Control.Monad     (forever, replicateM_, unless)
import qualified GHC.IO.Exception  as G (IOErrorType (ResourceVanished),
                                         IOException (IOError), ioe_type)
import           Pipes
import qualified Pipes.Prelude     as P (take)
import           System.IO         (BufferMode (NoBuffering), hPutStrLn,
                                    hSetBuffering, isEOF, stderr, stdout)

{-
-- https://hackage.haskell.org/package/pipes-4.1.8/docs/Pipes-Tutorial.html

note: Some types in comments are simplified from real types.

Pipes give:

Streaming
- pure/lazy list: get (partial) results immediately
  - do not have process/load whole list in memory

Composable
- modular / separable
- do not have to tightly coupled read/transform/write loop in IO
- transform using composable functions in constant space

Effects
- mapM, forM and "ListT done right"

Abstractions:
- Producers (generators)
- Consumers (iteratees)
- Pipes
-}

------------------------------------------------------------------------------
{- INTRO

Connect components that stream data in constant memory.

communicate using:
- yield: send
- await: receive

Components built around yield/await:
- Producers yield/send            : sources
- Consumers await/receive         : sinks
- Pipes     yield  and await      : transformations
- Effects neither yield nor await : model non-streaming components

Connect via:
- 'for' : handles yields
- (>~)  : handles awaits
- (>->) : handles yields and awaits
- (>>=) : handles return values

Done connecting when type is Effect
- meaning all input/output has been handled
- run Effect to begin streaming
-}

------------------------------------------------------------------------------
{- PRODUCERS

Producer
- effectful stream of input
- monad transformer that extends any base monad with a `yield` command
- `yield` sends output downstream to anonymous handler
- decoupling generating values from consuming them
- `yield` emits value, suspends Producer until value consumed
- if value not consumed, `yield` never returns
-}

 --         +--------+-- 'Producer' that yields 'String's
 --         |        |
 --         |        |      +-- monad transformer has a base monad
 --         |        |      |   base monad here is 'IO'
 --         |        |      |
 --         |        |      |  +-- monadic action has return value
 --         |        |      |  |   here returns '()' when finished
 --         v        v      v  v
stdinLn' :: Producer String IO ()
stdinLn' = do
    eof <- lift isEOF        -- 'lift' an 'IO' action from the base monad
    unless eof $ do
        str <- lift getLine
        yield str            -- 'yield' the 'String'
        stdinLn'             -- loop

------------------------------------------------------------------------------
{-
'for' : a way to consume Producer

--                +-- Producer      +-- The body of the   +-- Result
--                |   to loop       |   loop              |
--                v   over          v                     v
--                --------------    ------------------    ----------
for :: Monad m => Producer a m r -> (a -> Effect m ()) -> Effect m r

(for producer body)
- loops over (producer)
- substituting each yield in (producer) with (body)
- body takes one 'a' arg
  - same as output Producer (body gets input from Producer and nowhere else)
- Producer return value matches return value of result
  - (e.g., for must loop over entire Producer not skipping anything)
-}

stdinLoop :: Effect IO ()
-- more concise: stdinLoop = for stdinLn' (lift . putStrLn)
stdinLoop = for stdinLn' $ \str -> -- "for str in stdinLn'"
    lift $ putStrLn str            -- do: body

-- 'for' loops over stdinLn', replaces every 'yield' in stdinLn' with body of loop:
-- equivalent to:
{-
 stdinLoop = do                 |  stdinLn' = do
     eof <- lift isEOF          |      eof <- lift isEOF
     unless eof $ do            |      unless eof $ do
         str <- lift getLine    |          str <- lift getLine
         (lift . putStrLn) str  |          yield str
         stdinLoop              |          stdinLn'

Think of 'yield' as creating a hole, and 'for' loop as one way to fill hole.
-}

runStdinLoop :: IO ()
-- OR:         runEffect $ for stdinLn' (lift . putStrLn)
runStdinLoop = runEffect stdinLoop

-- 'for' works with any Foldable: e.g., convert list to Producer using each:

runListLoop :: IO ()
runListLoop  = runEffect $ for (each [1..4::Int])     (lift . print)

runMaybeLoop :: IO ()
runMaybeLoop = runEffect $ for (each (Just (1::Int))) (lift . print)

------------------------------------------------------------------------------
{-
Composability

Body of 'for' can be Producer.
-}

dup :: Monad m => a -> Producer a m ()
dup x = do yield x; yield x

dupLoop :: Producer String IO ()
dupLoop = for stdinLn' dup

{-
Equivalent to:
          for stdinLn' $ \x -> do yield x; yield x

Since loop is Producer, it cannot be run (has unhandled output)
Use another 'for' to handle dup stream:
-}

runDupLoop :: IO ()
runDupLoop = runEffect $ for dupLoop (lift . putStrLn)

-- written as nested loop:

runDupLoop2 :: IO ()
runDupLoop2 = runEffect $
    for stdinLn' $ \str1 ->
        for (dup str1) $ \str2 ->
            lift $ putStrLn str2

------------------------------------------------------------------------------
{-
Consumers

'for' loop consumes every element of a Producer.

NEXT: General consume solution : externally iterate over Producer using 'next':

next :: Monad m => Producer a m r -> m (Either r (a, Producer a m r))

"pattern matches" Producer head.
- Left : Producer done
- Right : "head" value, and remainder of Producer

or CONSUMER: effectful sink of values.

Consumer : monad transformer that extends base monad with 'await'.
- await : receive input from anonymous upstream source.
-}

--           +--------+-- 'Consumer' that awaits 'String's
--           |        |
--           v        v
stdoutLn' :: Consumer String IO ()
stdoutLn' = do
    str <- await  -- 'await' a 'String'
    x   <- lift $ try $ putStrLn str
    case x of
        -- terminate on broken pipe
        Left e@G.IOError { G.ioe_type = t} -> lift $ unless (t == G.ResourceVanished) $ throwIO e
        Right ()                           -> stdoutLn'

{-
'await' : dual of 'yield'
- suspend Consumer until value received
- if no value provided, await never returns

await :: Monad m => Consumer a m a

Can provide values to a Consumer using (>~) (pronounced "feed"):

 --                 +- Feed       +- Consumer to    +- Returns new
 --                 |  action     |  feed           |  Effect
 --                 v             v                 v
 --                 ----------    --------------    ----------
 (>~) :: Monad m => Effect m b -> Consumer b m c -> Effect m c

(draw >~ consumer) loops over (consumer), substituting each await in (consumer) with (draw).

E.g., replace every await in stdoutLn' with (lift getLine) and then removes all the lifts:
-}

runEcho :: IO ()
runEcho = runEffect $ lift getLine >~ stdoutLn'

-- A Consumer can be fed with another Consumer : await while awaiting.

-- converts stdoutLn/await into two awaits
doubleUp :: Monad m => Consumer String m String
-- more concise: doubleUp = (++) <$> await <*> await
doubleUp = do
    str1 <- await
    str2 <- await
    return (str1 ++ str2)

-- insert between (lift getLine) and stdoutLn:
-- splits every 'await' from stdoutLn' into two 'awaits' and returns concatenated result
runDoubleEcho :: IO ()
runDoubleEcho = runEffect $ lift getLine >~ doubleUp >~ stdoutLn'

------------------------------------------------------------------------------
{-
Pipes

When only using a Producer : detect end of input  (in stdinLn'
When only using a Consumer : detect end of output (in stdoutLn')
Not both at same time.

Producers and Consumers can be connected using (>->) (pronounced "pipe"):

 (>->) :: Monad m => Producer a m r -> Consumer a m r -> Effect m r

-}

-- stream values from stdinLn to stdoutLn

runInPipeOut :: IO ()
runInPipeOut = runEffect $ stdinLn' >-> stdoutLn'

{-

(>->) : "pull-based" : control flow begins at most downstream component (i.e. stdoutLn' above).
When component 'awaits' : blocks and transfers control upstream.
When component 'yields' : blocks and restores control back downstream (satisfying await).

above example, (>->) matches every stdoutLn' await with stdinLn' yield.

Streaming stops when stdinLn' terminates or stdoutLn' terminates (i.e. broken pipe).
Requires both Producer and Consumer share same type of return value
- whichever terminates first provides return value for entire Effect.
-}

runDetectTermination :: IO ()
runDetectTermination = do
    hSetBuffering stdout NoBuffering
    str <- runEffect $ ("End of input!" <$ stdinLn') >-> ("Broken pipe!" <$ stdoutLn')
    hPutStrLn stderr str

-- Pipe : monad transformer that can 'await' and 'yield'.

--               +--------- 'Pipe' that
--               |    +---- 'await's 'a's and
--               |    | +-- 'yield's 'a's
--               |    | |
--               v    v v
take' ::  Int -> Pipe a a IO ()
take' n = do
    replicateM_ n $ do           -- repeat block 'n' times
        x <- await               -- 'await' value of type 'a'
        yield x                  -- 'yield' value of type 'a'
    lift $ putStrLn "take done"  -- replication done

-- take after stdinLn to limit the number of lines from stdin:

maxInput :: Int -> Producer String IO ()
maxInput n = stdinLn' >-> take' n

runMaxInput :: IO ()
runMaxInput = runEffect $ maxInput 3 >-> stdoutLn'

-- before stdout to limit number of lines written to stout:

maxOutput :: Int -> Consumer String IO ()
maxOutput n = take' n >-> stdoutLn'

runMaxOutput :: IO ()
runMaxOutput = runEffect $ stdinLn' >-> maxOutput 3

runMaxMiddle :: IO ()
runMaxMiddle = runEffect $ stdinLn' >-> take' 3 >-> stdoutLn'

-- (>->) : like Unix pipe operator

unixCat :: Monad m => Pipe a a m r
unixCat = forever $ do
    x <- await
    yield x

unixHead :: Monad m => Int -> Pipe a a m ()
unixHead = P.take

unixYes :: Monad m => Producer String m r
unixYes = forever $ yield "y"

runUnix :: IO ()
runUnix = runEffect $ unixYes >-> unixHead 3 >-> stdoutLn'

-- End of file.
