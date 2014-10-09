{-# LANGUAGE LambdaCase, GADTs #-}
module Main where

import Control.Object
import Control.Monad.Objective
import Control.Applicative
import Buttons

import Graphics.Gloss.Interface.IO.Game

data Async a b r where
  Push :: a -> Async a b ()
  Pull :: Async a b b

foldO :: Monad m => (a -> r -> r) -> r -> Object (Async a r) m
foldO c r = Object $ \case
  Pull -> return (r, foldO c r)
  Push a -> return ((), foldO c (c a r))

bool :: a -> a -> Bool -> a
bool a _ False = a
bool _ b True = b

toggler :: Monad m => Object (Async ButtonClick Bool) m
toggler = \case { Click -> id; Toggle -> not } `foldO` True

count0 :: IO (Address (Async ButtonClick Int) IO)
count0 = do
  counter <- new $ \case { Click -> (+1); Toggle -> const 0 } `foldO` (0 :: Int)
  mode <- new toggler
  new $ liftO $ \case
    Push b -> do
      counter .- Push b
      mode .- Push b
    Pull -> (mode .- Pull) >>= bool (return (-1)) (counter .- Pull)

count5 :: IO (Address (Async ButtonClick Int) IO)
count5 = do
  counter <- new $ \case { Click -> (+1); Toggle -> id } `foldO` (0 :: Int)
  mode <- new toggler
  new $ liftO $ \case
    Push b -> do
      mode .- Push b
      (mode .- Pull) >>= bool (return ()) (counter .- Push b)
    Pull -> (mode .- Pull) >>= bool (return (-1)) (counter .- Pull)

count10 :: IO (Address (Async ButtonClick Int) IO)
count10 = do
  counter <- new $ \case { Click -> (+1); Toggle -> id } `foldO` (0 :: Int)
  mode <- new toggler
  new $ liftO $ \case
    Push b -> do
      counter .- Push b
      mode .- Push b
    Pull -> (mode .- Pull) >>= bool (return (-1)) (counter .- Pull)

main = do
  c0 <- count0
  c5 <- count5
  c10 <- count10
  playIO (InWindow "Objective Example" (320, 240) (800, 200))
                 white
                 300
                 ()
                 (const $ renderButtons <$> (c0 .- Pull) <*> pure Nothing
                  <*> (c5 .- Pull) <*> pure Nothing
                  <*> (c10 .- Pull) <*> pure Nothing)
                 (\e () -> do
                    maybe (return ()) ((c0 .-) . Push) $ filter0 e
                    maybe (return ()) ((c5 .-) . Push) $ filter5 e
                    maybe (return ()) ((c10 .-) . Push) $ filter10 e)
                 (\_ _ -> return ())