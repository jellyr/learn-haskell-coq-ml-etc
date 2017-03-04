module ValidResponses where

useIt :: (Eq a, Show a) => [a] -> [a] -> IO ()
useIt xs ys =
  case invalidResponses xs ys of
    []  -> putStrLn "success: pretend you are doing real blockchain work"
    xys -> complain xys

invalidResponses :: Eq a => [a] -> [a] -> [(a,a)]
invalidResponses xs ys =
  filter (\(x,y) -> x /= y) (zip xs ys)

complain :: (Eq a, Show a) => [(a,a)] -> IO ()
complain = do
  mapM_ debugFn .
    map (\(x,y) ->
            "CONFLICTING RESPONSES: " ++
            "leader: '" ++ show x ++ "' " ++
            "follower: '" ++ show y)

------

-- example usage:

debugFn :: Show a => a -> IO ()
debugFn = putStrLn . show

cmds1 = [1,2,3]
cmds2 = [1,3,2]

tryIt1 = useIt cmds1 cmds1
tryIt2 = useIt cmds1 cmds2
