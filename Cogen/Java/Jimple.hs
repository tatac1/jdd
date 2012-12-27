{-# LANGUAGE FlexibleInstances #-}

module Cogen.Java.Jimple where

import Prelude hiding (const)
import Data.List

import qualified Data.ByteString.Char8 as B

import Parser (Desc(..), Class(..))
import Cogen.Java (Java(..), Javable(..), JavaStmt(..))
import Jimple.Types



-- s1 <- staticField
-- invoke I_special this MethodSig
-- return ()

--
instance Javable (Stmt Value) where
  toJava = stmtToJava


line st = Java $ [JavaStmt 0 $ st ++ ";"]


-- class path
path = str . B.map fix
  where
    fix '/' = '.'
    fix c   = c


-- string (TODO: UTF8?)
str = B.unpack


-- constant
const (C_string s) = show s


-- expression
expr e = case e of
  E_invoke it (MethodSig _cl nm pars res) args ->
    concat [invoke it, ".", str nm, "(", intercalate "," (map value args), ")"]


-- invoke
invoke (I_virtual v) = value v


-- variable
var (VarRef r)   = ref r
var (VarLocal l) = show l


-- reference
ref r = case r of
  R_staticField (Class cp) (Desc nm tp) -> concat [path cp, ".", str nm]


-- value
value (VConst c) = const c
value (VLocal v) = var v
value (VExpr  e) = expr e


stmtToJava s = case s of
  S_assign v val | var v == "_" -> line $ value val
  S_assign v val -> line $ var v ++ " = " ++ value val
  S_returnVoid -> line "return"