{-# LANGUAGE DeriveFunctor
           , DeriveFoldable
           , OverloadedStrings
  #-}

module Jimple.Types where

import qualified Data.ByteString as B
import qualified Data.Foldable as F
import qualified Parser as CF


type LabelStmt v = (Maybe Label, Stmt v)


data JimpleMethod v = Method
                      { methodSig        :: MethodSignature
                      , methodLocalDecls :: [LocalDecl]
                      , methodIdentStmts :: [IdentStmt v]
                      , methodStmts      :: [LabelStmt v]
                      , methodExcepts    :: [Except v] }
                  deriving (Eq, Show)

data IdentStmt v = IStmt Local (Ref v)
               deriving (Eq, Ord, Show, Functor, F.Foldable)

data LocalDecl = LocalDecl Type Local
               deriving (Eq, Ord, Show)

data Except v = Except (Ref v) Label Label Label
            deriving (Eq, Ord, Show, Functor, F.Foldable)

data Stmt v = S_breakpoint
            | S_assign (Variable v) v
            | S_enterMonitor v
            | S_exitMonitor  v
            | S_goto Label
            | S_if (Expression v) Label   -- Only condition expressions are allowed
            | S_lookupSwitch v Label [(Integer, Label)]
            | S_nop
            | S_ret Local
            | S_return v
            | S_returnVoid
            | S_tableSwitch v Label [(Integer, Label)]
            | S_throw v
            -- Below are statements for transitioning from Jimple to Java
            | S_ifElse (Expression v) [LabelStmt v] [LabelStmt v]
            -- We used labeled continue/break to tie the action to the loop
            | S_doWhile  String [LabelStmt v] Value
            | S_break    String
            | S_continue String
            | S_switch   String v [(Maybe Integer, [LabelStmt v])]
            deriving (Eq, Ord, Functor, F.Foldable)


data Value = VConst Constant
           | VLocal (Variable Value)
           | VExpr  (Expression Value)
           deriving (Eq, Ord)

data Label = Label Integer
           deriving (Eq, Ord)

instance Show     Label where show (Label l) = show l
instance Num      Label where
  fromInteger = Label
  (+)         = labelOp (+)
  (*)         = labelOp (*)
  signum (Label n) = Label $ signum n
  abs    (Label n) = Label $ abs n

labelOp f (Label a) (Label b) = Label $ a `f` b


data Local = Local String
           deriving (Eq, Ord)
instance Show Local where show (Local s) = s


data AccessFlags = F_public
                 | F_private
                 | F_protected
                 | F_static
                 | F_final
                 | F_synchronized
                 | F_bridge
                 | F_varargs
                 | F_native
                 | F_abstract
                 | F_strict
                 | F_synthetic
                 deriving (Eq, Ord, Show)

data Constant = C_double Double
              | C_float  Double
              | C_int    Integer
              | C_long   Integer
              | C_string B.ByteString
              | C_null
              | C_boolean Bool
              deriving (Eq, Ord, Show)

data Variable v = VarRef (Ref v)
                | VarLocal Local
                deriving (Eq, Ord, Functor, F.Foldable)

data Ref v = R_caughtException
           | R_parameter     Integer
           | R_this
           | R_array         v v
           | R_instanceField v CF.Desc
           | R_staticField     CF.Class CF.Desc
           | R_object          CF.Class
           deriving (Eq, Ord, Show, Functor, F.Foldable)


data Expression v = E_eq v v -- Conditions
                  | E_ge v v
                  | E_le v v
                  | E_lt v v
                  | E_ne v v
                  | E_gt v v

                  | E_add  v v -- Binary ops
                  | E_sub  v v
                  | E_and  v v
                  | E_or   v v
                  | E_xor  v v
                  | E_shl  v v
                  | E_shr  v v
                  | E_ushl v v
                  | E_ushr v v
                  | E_cmp  v v
                  | E_cmpg v v
                  | E_cmpl v v
                  | E_mul  v v
                  | E_div  v v
                  | E_rem  v v

                  | E_length        v
                  | E_instanceOf    v    (Ref v)
                  | E_cast          Type v
                  | E_newArray      Type v
                  | E_newMultiArray Type v [v] -- TODO: empty dims?
                  | E_new           (Ref v)
                  | E_invoke (InvokeType v) MethodSignature [v]
                  deriving (Eq, Ord, Functor, F.Foldable)

data InvokeType v = I_interface v
                  | I_special   v
                  | I_virtual   v
                  | I_static
                deriving (Eq, Ord, Show, Functor, F.Foldable)

data MethodSignature = MethodSig
                       { methodClass  :: CF.Class
                       , methodName   :: B.ByteString
                       , methodAccess :: [ AccessFlags ]
                       , methodParams :: [Type]
                       , methodResult :: Type
                       }
                     deriving (Eq, Ord, Show)

data Type = T_byte | T_char  | T_int | T_boolean | T_short
          | T_long | T_float | T_double
          | T_object B.ByteString | T_addr | T_void
          | T_array Int Type
          | T_unknown
          deriving (Eq, Ord, Show)




instance Show v => Show (Stmt v) where
  show (S_breakpoint)    = "breakpoint"

  show (S_assign x a)    = show x ++ " <- " ++ show a

  show (S_enterMonitor i) = "enterMonitor " ++ show i
  show (S_exitMonitor  i) = "exitMonitor " ++ show i

  show (S_goto lbl)      = "goto " ++ show lbl
  show (S_if con lbl)    = "if (" ++ show con ++ ") " ++ show lbl
  show (S_ifElse c a b)  = concat ["if (", show c, ") "
                                  , show a, " else "
                                  , show b]

  show (S_continue name) = "continue " ++ name
  show (S_break    name) = "break "    ++ name

  show (S_doWhile name body cond) = concat [name, ": do ", show body
                                           , " while (", show cond, ")"]

  show (S_lookupSwitch v lbl ls) = "lswitch " ++ show v ++ " " ++ show lbl ++ " " ++ show ls

  show (S_nop)           = "nop"

  show (S_ret v)         = "return (" ++ show v ++ ")"
  show (S_return i)      = "return (" ++ show i ++ ")"
  show (S_returnVoid)    = "return"

  show (S_tableSwitch i lbl ls) = "tswitch" ++ show i ++ " " ++ show lbl ++ " "
                                  ++ show ls

  show (S_switch name v cs) = concat [name, ": switch (", show v, ") ", show cs]

  show (S_throw i) = "throw " ++ show i


instance Show v => Show (Variable v) where
  show (VarRef   ref) = '@' : show ref
  show (VarLocal var) = show var

instance Show Value where
  show (VConst c) = show c
  show (VLocal l) = show l
  show (VExpr  e) = show e


instance Show v => Show (Expression v) where
  show (E_eq a b) = show a ++ " == " ++ show b
  show (E_ge a b) = show a ++ " >= " ++ show b
  show (E_le a b) = show a ++ " <= " ++ show b
  show (E_ne a b) = show a ++ " /= " ++ show b
  show (E_lt a b) = show a ++ " < " ++ show b
  show (E_gt a b) = show a ++ " > " ++ show b

  show (E_add a b) = show a ++ " + " ++ show b
  show (E_sub a b) = show a ++ " - " ++ show b
  show (E_and a b) = show a ++ " & " ++ show b
  show (E_or  a b) = show a ++ " | " ++ show b
  show (E_xor a b) = show a ++ " ^ " ++ show b
  show (E_shl a b) = show a ++ " shl " ++ show b
  show (E_shr a b) = show a ++ " shr " ++ show b
  show (E_ushl a b) = show a ++ " ushl " ++ show b
  show (E_ushr a b) = show a ++ " ushr " ++ show b
  show (E_cmp a b) = show a ++ " cmp " ++ show b
  show (E_cmpg a b) = show a ++ " cmpg " ++ show b
  show (E_cmpl a b) = show a ++ " cmpl " ++ show b

  show (E_mul a b) = show a ++ " * " ++ show b
  show (E_div a b) = show a ++ " / " ++ show b
  show (E_rem a b) = show a ++ " rem " ++ show b

  show (E_length a) = "length " ++ show a
  show (E_cast t a) = "(" ++ show t ++ ") " ++ show a
  show (E_instanceOf i r) = show i ++ " instanceOf " ++ show r
  show (E_newArray t i) = "newArray " ++ show t ++ "[" ++ show i ++ "]"
  show (E_new r) = "new " ++ show r
  show (E_newMultiArray t i is) = "newMArray " ++ show t ++ "(" ++ show (i, is) ++ ")"
  show (E_invoke t m ims) = concat ["invoke ", show t, " "
                                   , show m, " ", show ims]





