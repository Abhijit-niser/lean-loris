import Lean.Meta
import Lean.Elab
import Std
open Lean
open Meta
open Lean.Elab.Term
open Std
open Std.HashMap
open Nat

abbrev ExprDist := HashMap Expr Nat

def mergeDist{α : Type}[Hashable α][BEq α] 
    (fst: HashMap α Nat)(snd: HashMap α Nat)  := Id.run do
  let mut min := fst
  for (key, val) in snd.toArray do
    match min.find? key with
    | some v =>
      if val < v then
        min := min.insert key val
    | none => 
        min := min.insert key val
  return min

def mapDist{α β : Type}[Hashable α][BEq α][Hashable β][BEq β]
    (dist: HashMap α Nat)(f: α → β )  := Id.run do
  let mut map := HashMap.empty
  for (key, val) in dist.toArray do
    let y := f key
    match map.find? <| y with
    | some v =>
      map := map.insert y (min v val)
    | none => 
        map := map.insert y val
  return map

def mapDistM{α β : Type}[Hashable α][BEq α][Hashable β][BEq β]
    (dist: HashMap α Nat)(f: α → TermElabM β ) : TermElabM <| HashMap β Nat  := do
  let mut map := HashMap.empty
  for (key, val) in dist.toArray do
    let y : β  ←  f key
    match map.find? <| y with
    | some v =>
      map := map.insert y (min v val)
    | none => 
        map := map.insert y val
  return map

def weightCount{α : Type}[Hashable α][BEq α] 
    (m: HashMap α Nat) : HashMap Nat Nat := Id.run do
      let mut w := HashMap.empty
      for (key, val) in m.toArray do
        match w.find? val with
        | some v =>
          w := w.insert val (v + 1)
        | none => 
          w := w.insert val 1
      return w

def cumulWeightCount{α : Type}[Hashable α][BEq α] 
    (m: HashMap α  Nat) : HashMap Nat Nat := Id.run do
      let base := weightCount m
      let mut w := base
      for (key, val) in base.toArray do
        for j in [0:key] do
          match w.find? j with
          | some v =>
            w := w.insert j (v + val)
          | none => 
            w := w.insert j val
      return w

def filterDist{α : Type}[Hashable α][BEq α] 
    (m: HashMap α Nat) (p: α → Bool) : HashMap α Nat := Id.run do
  let mut w := HashMap.empty
  for (key, val) in m.toArray do
    if p key then
      w := w.insert key val
  return w

def filterDistM{α : Type}[Hashable α][BEq α]
    (m: HashMap α Nat) (p: α  → TermElabM Bool) : TermElabM <| HashMap α Nat := do
  let mut w := HashMap.empty
  for (key, val) in m.toArray do
    if ← p key then
      w := w.insert key val
  return w

def boundDist{α : Type}[Hashable α][BEq α] 
    (m: HashMap α Nat) (maxWeight card: Nat)  : HashMap α Nat := Id.run do
  let mut w := HashMap.empty
  let cumul := cumulWeightCount m
  let top := (cumul.toList.map (fun (k, v) => v)).maximum?.getD 0 
  for (key, val) in m.toArray do
    if val ≤ maxWeight && ((cumul.getOp val).getD top ≤ card) then
      w := w.insert key val
  return w

def zeroLevelDist{α : Type}[Hashable α][BEq α] 
    (arr: Array α) : HashMap α Nat := Id.run do
  let mut w := HashMap.empty
  for x in arr  do
    w := w.insert x 0
  return w

def distUpdate{α : Type}[Hashable α][BEq α] 
    (m: HashMap α Nat) (x: α) (d: Nat) : HashMap α Nat := 
  match m.find? x with
  | some v => if d < v then m.insert x d else m
  | none => m.insert x d

def prodGen{α β γ : Type}[Hashable α][BEq α][Hashable β][BEq β]
    [Hashable γ][BEq γ](fst: HashMap α Nat)(snd: HashMap β Nat)
    (maxWeight card: Nat)(compose: α → β → Option γ)
    (newPair: α × β → Bool) : HashMap γ  Nat := Id.run do 
    let mut w := HashMap.empty
    if maxWeight > 0 then
      let fstBdd := boundDist fst (maxWeight - 1) card
      let fstCount := cumulWeightCount fstBdd
      let fstTop := (fstCount.toList.map (fun (k, v) => v)).maximum?.getD 0 
      for (key, val) in fstBdd.toArray do
        let fstNum := (fstCount.getOp val).getD fstTop
        let sndCard := card / fstNum
        let sndBdd := boundDist snd (maxWeight - val - 1) sndCard
        for (key2, val2) in sndBdd.toArray do
          if newPair (key, key2) then
            match compose key key2 with
            | some key3 =>
                w := distUpdate w key3 (val + val2 + 1)
            | none => ()
    return w

def prodGenTermElab{α β γ : Type}[Hashable α][BEq α][Hashable β][BEq β]
    [Hashable γ][BEq γ](fst: HashMap α Nat)(snd: HashMap β Nat)
    (maxWeight card: Nat)(compose: α → β → TermElabM (Option γ))
    (newPair: α × β → Bool) : TermElabM (HashMap γ  Nat) := do 
    let mut w := HashMap.empty
    if maxWeight > 0 then
      let fstBdd := boundDist fst (maxWeight - 1) card
      let fstCount := cumulWeightCount fstBdd
      let fstTop := (fstCount.toList.map (fun (k, v) => v)).maximum?.getD 0 
      for (key, val) in fstBdd.toArray do
        let fstNum := (fstCount.getOp val).getD fstTop
        let sndCard := card / fstNum
        let sndBdd := boundDist snd (maxWeight - val - 1) sndCard
        for (key2, val2) in sndBdd.toArray do
          if newPair (key, key2) then
            match ← compose key key2 with
            | some key3 =>
                w := distUpdate w key3 (val + val2 + 1)
            | none => ()
    return w

def tripleProdGen{α β γ δ : Type}[Hashable α][BEq α][Hashable β][BEq β]
    [Hashable γ][BEq γ][Hashable δ][BEq δ]
    (fst: HashMap α Nat)(snd: HashMap β Nat)(third : HashMap γ Nat)
    (maxWeight card: Nat)(compose: α → β → γ  → Option δ)
    (newPair: α × β × γ  → Bool) : HashMap δ Nat := Id.run do 
    let mut w := HashMap.empty
    if maxWeight > 0 then
      let fstBdd := boundDist fst (maxWeight - 1) card
      let fstCount := cumulWeightCount fstBdd
      let fstTop := (fstCount.toList.map (fun (k, v) => v)).maximum?.getD 0 
      for (key, val) in fstBdd.toArray do
        let fstNum := (fstCount.getOp val).getD fstTop
        let sndCard := card / fstNum
        let sndBdd := boundDist snd (maxWeight - val - 1) sndCard
        let sndCount := cumulWeightCount sndBdd
        let sndTop := (sndCount.toList.map (fun (k, v) => v)).maximum?.getD 0 
        for (key2, val2) in sndBdd.toArray do
          let sndNum := (sndCount.getOp val2).getD sndTop
          let thirdCard := sndCard / sndNum
          let thirdBdd := boundDist third (maxWeight - val - val2 - 1) thirdCard
          for (key3, val3) in thirdBdd.toArray do
            if newPair (key, key2, key3) then
              match compose key key2 key3 with
              | some key3 =>
                  w := distUpdate w key3 (val + val2 + val3 + 1)
              | none => ()
    return w

def tripleProdGenTermElab{α β γ δ : Type}[Hashable α][BEq α][Hashable β][BEq β]
    [Hashable γ][BEq γ][Hashable δ][BEq δ]
    (fst: HashMap α Nat)(snd: HashMap β Nat)(third : HashMap γ Nat)
    (maxWeight card: Nat)(compose: α → β → γ  → TermElabM (Option δ))
    (newPair: α × β × γ  → Bool) : TermElabM <| HashMap δ Nat := do 
    let mut w := HashMap.empty
    if maxWeight > 0 then
      let fstBdd := boundDist fst (maxWeight - 1) card
      let fstCount := cumulWeightCount fstBdd
      let fstTop := (fstCount.toList.map (fun (k, v) => v)).maximum?.getD 0 
      for (key, val) in fstBdd.toArray do
        let fstNum := (fstCount.getOp val).getD fstTop
        let sndCard := card / fstNum
        let sndBdd := boundDist snd (maxWeight - val - 1) sndCard
        let sndCount := cumulWeightCount sndBdd
        let sndTop := (sndCount.toList.map (fun (k, v) => v)).maximum?.getD 0 
        for (key2, val2) in sndBdd.toArray do
          let sndNum := (sndCount.getOp val2).getD sndTop
          let thirdCard := sndCard / sndNum
          let thirdBdd := boundDist third (maxWeight - val - val2 - 1) thirdCard
          for (key3, val3) in thirdBdd.toArray do
            if newPair (key, key2, key3) then
              match ← compose key key2 key3 with
              | some key3 =>
                  w := distUpdate w key3 (val + val2 + val3 + 1)
              | none => ()
    return w

structure GenDist where
  weight: Nat
  card : Nat
  exprDist : ExprDist

-- same signature for full evolution and single step, with ExprDist being initial state or accumulated state and the wieght bound that for the result or the accumulated state
def Evolution(D: Type) : Type := (weightBound: Nat) → (cardBound: Nat) →  ExprDist  → (initData: D) → ExprDist

def initEvolution(D: Type) : Evolution D := fun _ _ init _ => init

-- can again play two roles; and is allowed to depend on a generator; diagonal should only be used for full generation, not for single step.
def RecEvolver(D: Type) : Type := (weightBound: Nat) → (cardBound: Nat) →  ExprDist → (initData: D) → (evo: Evolution D) → ExprDist

instance{D: Type} : Inhabited <| Evolution D := ⟨initEvolution D⟩

partial def RecEvolver.diag{D: Type}(recEv: RecEvolver D) : Evolution D :=
        fun d c init memo => recEv d c init  memo (diag recEv)

-- same signature for full evolution and single step, with ExprDist being initial state or accumulated state and the wieght bound that for the result or the accumulated state
def EvolutionM(D: Type) : Type := (weightBound: Nat) → (cardBound: Nat) →  ExprDist  → (initData: D) → TermElabM ExprDist

def initEvolutionM(D: Type) : EvolutionM D := fun _ _ init _ => pure init

-- can again play two roles; and is allowed to depend on a generator; diagonal should only be used for full generation, not for single step.
def RecEvolverM(D: Type) : Type := (weightBound: Nat) → (cardBound: Nat) →  ExprDist → (initData: D) → (evo: EvolutionM D) → TermElabM ExprDist

instance{D: Type} : Inhabited <| EvolutionM D := ⟨initEvolutionM D⟩

partial def RecEvolverM.diag{D: Type}(recEv: RecEvolverM D) : EvolutionM D :=
        fun d c init memo => recEv d c init memo (diag recEv)

def isleM {D: Type}(type: Expr)(recEv : RecEvolverM D)(weightBound: Nat)(cardBound: Nat)
      (init : ExprDist)(initData: D)(evolve : EvolutionM D)(includePi : Bool := true)(excludeProofs: Bool := false): TermElabM (ExprDist) := 
    withLocalDecl Name.anonymous BinderInfo.default (type)  $ fun x => 
        do
          let dist := init.insert x 0
          -- logInfo m!"initial in isle: {l}"
          let evb ← recEv weightBound cardBound dist initData evolve
          let evc ← recEv weightBound cardBound init initData evolve
          let mut evl : ExprDist := HashMap.empty
          for (y, w) in evb.toArray do
            unless excludeProofs && ((← inferType y).isProp) do
            let inEvc : Bool := 
              match evc.getOp y with
              | some w2 => w2 < w
              | none => false
            unless inEvc do 
              evl := distUpdate evl y w
          let evt ← filterDistM evl (fun x => liftMetaM (isType x))
          let exported ← mapDistM evl (fun e => mkLambdaFVars #[x] e)
          let exportedPi ← mapDistM evt (fun e => mkForallFVars #[x] e)
          let res := if includePi then mergeDist exported  exportedPi else exported
          return res

-- Auxiliary functions mainly from lean source for subexpressions

def isBlackListed (env: Environment) (declName : Name) : IO  Bool := do
  declName.isInternal
  <||> isAuxRecursor env declName
  <||> isNoConfusion env declName
  <||> isRecCore env declName
  <||> isMatcherCore env declName

def isAux (env: Environment) (declName : Name) : IO  Bool := do
  isAuxRecursor env declName
  <||> isNoConfusion env declName
  
def isNotAux (env: Environment) (declName : Name) : IO  Bool := do
  let nAux ← isAux env declName
  return (not nAux)

def isWhiteListed (env: Environment)(declName : Name) : IO Bool := do
  let bl ← isBlackListed env declName
  return !bl

-- Basic functions for generation

-- (optional) function application with unification
def applyOpt (f x : Expr) : TermElabM (Option Expr) :=
  do
    try
      let expr ← elabAppArgs f #[] #[Arg.expr x] none (explicit := false) (ellipsis := false)
      let exprType ← inferType expr
      if (← isTypeCorrect expr) &&  (← isTypeCorrect exprType)  then return some expr
      else return none
    catch e =>
      return none

-- (optional) function application with unification given name of function
def nameApplyOpt (f: Name) (x : Expr) : TermElabM (Option Expr) :=
  do
    try
      let expr ← mkAppM f #[x]
      let exprType ← inferType expr
      if (← isTypeCorrect expr) &&  (← isTypeCorrect exprType)  then 
        -- Elab.logInfo m!"from name, arg : {expr}"
        return some expr
      else
      Elab.logWarning m!"not type correct : {expr} = {f} ({x})" 
      return none
    catch e =>
        -- Elab.logInfo m!"failed from name, arg : 
        --     {f} at {x} with type {← inferType x}"
      return none

-- (optional) function application with unification given name of function and a pair of arguments
def nameApplyPairOpt (f: Name) (x y: Expr) : TermElabM (Option Expr) :=
  do
    try
      let expr ← mkAppM f #[x, y]
      let exprType ← inferType expr
      if (← isTypeCorrect expr) &&  (← isTypeCorrect exprType)  then 
        -- Elab.logInfo m!"from name, arg : {expr}"
        return some expr
      else
      Elab.logWarning m!"not type correct : {expr} = {f}({x}, {y})" 
      return none
    catch e =>
        -- Elab.logInfo m!"failed from name, arg : 
        --     {f} at {x}, {y} with type {← inferType x}"
      return none


-- copied from lean4 source code and modified; optionally returns proof that
-- a rewritten expression is equal to the original one.
def rewriteProof (e: Expr) (heq : Expr) (symm : Bool := false) : MetaM (Option Expr) :=
  do
    let heqType ← instantiateMVars (← inferType heq)
    let (newMVars, binderInfos, heqType) ← forallMetaTelescopeReducing heqType
    let heq := mkAppN heq newMVars
    match heqType.eq? with
    | none => none
    | some (α , lhs, rhs) =>
    let heqType := if symm then ← mkEq rhs lhs else heqType
    let hep := if symm then mkEqSymm heq else heq
    if lhs.getAppFn.isMVar then none
    else
    let e ← instantiateMVars e
    let eAbst ←  kabstract e lhs
    if !eAbst.hasLooseBVars then none
    else
    let eNew := eAbst.instantiate1 rhs
    let eNew ← instantiateMVars eNew
    let eEqE ← mkEq e e
    let eEqEAbst := mkApp eEqE.appFn! eAbst
    let motive := Lean.mkLambda `_a BinderInfo.default α eEqEAbst
    if !(← isTypeCorrect motive) then none
    else            
    let eqRefl ← mkEqRefl e
    let eqPrf ← mkEqNDRec motive eqRefl heq
    return some eqPrf

-- transports a term using equlity if its type can be rewritten
def rwPushOpt(e : Expr) (heq : Expr) 
      (symm : Bool := false): MetaM (Option Expr) :=
  do
    let t ← inferType e
    let pfOpt ← rewriteProof t heq symm
    match pfOpt with
    | none => return none
    | some pf =>
      try
        let expr ← mkAppM ``Eq.mp #[pf, e]
        let exprType ← inferType expr
        if (← isTypeCorrect expr) &&  (← isTypeCorrect exprType)  
        then return some expr
        else return none
      catch _ => 
        return none

-- (optional) congrArg for an equality
def eqCongrOpt (f: Expr)(eq : Expr) : MetaM (Option Expr) :=
  do
    try
      let expr ← mkAppM ``congrArg #[f, eq]
      let exprType ← inferType expr
      if (← isTypeCorrect expr) &&  (← isTypeCorrect exprType)  then return some expr
      else 
        return none
    catch e => 
      return none 
