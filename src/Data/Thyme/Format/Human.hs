{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ViewPatterns #-}

module Data.Thyme.Format.Human
    ( humanTimeDiff
    , humanTimeDiffs
    ) where

import Prelude
import Control.Applicative
import Control.Lens hiding (singular)
import Control.Monad
import Data.AdditiveGroup
import Data.Foldable
import Data.Micro
import Data.Monoid
import Data.Thyme.Clock.Internal
import Data.Thyme.TH
import Data.VectorSpace

data Unit = Unit
    { unit :: Micro
    , singular :: ShowS
    , plural :: ShowS
    }
thymeLenses ''Unit

-- | Display 'DiffTime' or 'NominalDiffTime' in a human-readable form.
{-# INLINE humanTimeDiff #-}
humanTimeDiff :: (TimeDiff d) => d -> String
humanTimeDiff d = humanTimeDiffs d ""

-- | Display 'DiffTime' or 'NominalDiffTime' in a human-readable form.
humanTimeDiffs :: (TimeDiff d) => d -> ShowS
humanTimeDiffs (microTimeDiff -> signed@(Micro (Micro . abs -> us)))
        = (if signed < Micro 0 then (:) '-' else id) . diff where
    diff = maybe id id . getFirst . fold $
        zipWith (approx us . unit) (tail units) units

approx :: Micro -> Micro -> Unit -> First ShowS
approx us next Unit {..} = First $
        shows n . inflection <$ guard (us < next) where
    n = fst $ microQuotRem (us ^+^ half) unit where
        half = Micro . fst $ microQuotRem unit (Micro 2)
    inflection = if n == 1 then singular else plural

times :: String -> Rational -> Unit -> Unit
times ((++) . (:) ' ' -> singular) r Unit {unit}
    = Unit {unit = r *^ unit, plural = singular . (:) 's', ..}

units :: [Unit]
units = scanl (&) usec
    [ times "millisecond" 1000
    , times "second"      1000
    , times "minute"      60
    , times "hour"        60
    , times "day"         24
    , times "week"        7
    , times "month"       (30.4368 / 7)
    , times "year"        12
    , times "decade"      10
    , set _plural (" centuries" ++)
    . times "century"     10
    , set _plural (" millennia" ++)
    . times "millennium"  10
{-     , times "aeon"       1000000 -}
    , const (Unit maxBound id id)
    ] where
    usec = Unit (Micro 1) (" microsecond" ++) (" microseconds" ++)

