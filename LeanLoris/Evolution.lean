import LeanLoris.FinDist
import LeanLoris.ExprDist
import LeanLoris.Core
import LeanLoris.ProdSeq
import Lean
import Lean.Meta
import Lean.Elab
import Std
open Lean
open Meta
open Elab
open Lean.PrettyPrinter
open Lean.Elab.Term
open Std
open Std.HashMap
open Nat
open ProdSeq

structure GenDist where
  weight: Nat
  card : Nat
  exprDist : HashExprDist

class DataUpdate (D: Type) where
  update: ExprDist → Nat → Nat → D → D

def dataUpdate{D: Type}[du : DataUpdate D](d: ExprDist)(wb card: Nat) : D → D :=
  du.update d wb card

def idUpate{D: Type} : DataUpdate D :=
  ⟨fun _ _ _ d => d⟩

instance : DataUpdate Unit := idUpate 

instance : DataUpdate NameDist := idUpate

class IsNew (D: Type) where
  isNew: D → Nat → Nat →  Expr → Nat →  TermElabM Bool
  isNewPair : D → Nat → Nat →  Expr → Nat →  Expr → Nat → TermElabM Bool
  isNewTriple : D → Nat → Nat →  Expr → Nat →  Expr → Nat → Expr → Nat →   TermElabM Bool

def isNew{D: Type}[c: IsNew D] : D → Nat → Nat →   Expr  → Nat  → TermElabM Bool :=
  c.isNew

def allNew{D: Type} : IsNew D :=
  ⟨fun d _ _ e _ => pure true, fun d _ _ _ _ _ _  => pure true,
  fun _ _ _ _ _ _ _ _ _ => pure true⟩

instance : IsNew Unit := allNew

instance : NewElem Expr Unit := constNewElem (true, true)

instance {D: Type} : NewElem Name D := constNewElem (false, true)

def isNewPair{D: Type}[c: IsNew D] : D → Nat → Nat →  
        (Expr ×   Expr) → (Nat × Nat)  → TermElabM Bool :=
  fun d wb cb (e1, e2) (w1, w2) => c.isNewPair d wb cb e1 w1 e2 w2

class GetNameDist (D: Type) where
  nameDist: D → NameDist

def nameDist{D: Type}[c: GetNameDist D] : D  → NameDist :=
  c.nameDist

instance : GetNameDist NameDist := ⟨fun nd => nd⟩

instance : GetNameDist Unit := ⟨fun _ => FinDist.empty⟩

instance : IsNew NameDist := allNew

instance : NewElem Expr NameDist := constNewElem (true, true)

class DistHist (D: Type) where
  distHist: D → List GenDist
  extHist : D → List HashExprDist

def newFromHistory {D: Type}[cl: DistHist D] : IsNew D :=
  ⟨fun d wb c e w => do
    let exs ← ((cl.distHist d).anyM <| fun dist =>  dist.exprDist.existsM e w)
    return !exs,
  fun d wb c e1 w1 e2 w2 => do
    let exs ← ((cl.distHist d).anyM <| fun ⟨wt, _,dist⟩ => 
      dist.existsM e1 w1 <&&>  (dist.existsM e2 w2) <&&> return (w1 + w2 + 1 ≤ wt))
    return !exs,
    fun d wb c e1 w1 e2 w2 e3 w3 => do
    let exst ← ((cl.distHist d).anyM <| fun ⟨wt, _,dist⟩ => do
      dist.existsM e1 w1 <&&> (dist.existsM e2 w2) <&&> (dist.existsM e3 w3) <&&>
        return (w1 + w2 + w3 + 1 ≤ wt))
     return !exst⟩

def newElemFromHistory {D: Type}[cl: DistHist D] : NewElem Expr D :=
  ⟨fun d  e w => do
    let exst ← ((cl.distHist d).anyM <| fun dist =>  dist.exprDist.existsM e w)
    let extrn ← ((cl.extHist d).anyM <| fun dist =>  dist.existsM e w)
    return (!exst, !extrn)⟩

instance {D: Type}[cl: DistHist D] : IsNew D := newFromHistory 

instance {D: Type}[cl: DistHist D] : NewElem Expr D := newElemFromHistory 

class IsleData(D: Type) where
  isleData : D → ExprDist → Nat → Nat → D

def isleData{D: Type}[c: IsleData D] : D → ExprDist → Nat → Nat → D := c.isleData

def idIsleData{D:Type} : IsleData D := ⟨fun d _ _ _=> d⟩

instance : IsleData Unit := idIsleData

instance : IsleData NameDist := idIsleData

abbrev FullData := NameDist × (List GenDist) × (List HashExprDist)

instance : DistHist FullData := ⟨fun (nd, hist, ehist) => hist,
                                fun (nd, hist, ehist) => ehist⟩

instance : GetNameDist FullData := ⟨fun (nd, _) => nd⟩

instance : DataUpdate FullData := ⟨fun d w c (nd, hist, ehist) => 
                                                        (nd, [⟨w, c, d.hashDist⟩], ehist)⟩

instance : IsleData FullData :=
  ⟨fun ⟨nd, hist, ehist⟩ d w c => (nd, [⟨w, c, d.hashDist⟩], [d.hashDist])⟩ 

-- same signature for full evolution and single step, with ExprDist being initial state or accumulated state and the weight bound that for the result or the accumulated state
def Evolution(D: Type) : Type := (weightBound: Nat) → (cardBound: Nat) →  ExprDist  → (initData: D) → ExprDist

def initEvolution(D: Type) : Evolution D := fun _ _ init _ => init

-- can again play two roles; and is allowed to depend on a generator; fixed-point should only be used for full generation, not for single step.
def RecEvolver(D: Type) : Type := (weightBound: Nat) → (cardBound: Nat) →  ExprDist → (initData: D) → (evo: Evolution D) → ExprDist

instance{D: Type} : Inhabited <| Evolution D := ⟨initEvolution D⟩

partial def RecEvolver.fixedPoint{D: Type}(recEv: RecEvolver D) : Evolution D :=
        fun d c init memo => recEv d c init  memo (fixedPoint recEv)

-- same signature for full evolution and single step, with ExprDist being initial state or accumulated state and the weight bound that for the result or the accumulated state
def EvolverM(D: Type) : Type := (weightBound: Nat) → (cardBound: Nat) →  (initData: D) → ExprDist  → TermElabM ExprDist


-- like EvolverM, can  play two roles; and is allowed to depend on a generator; fixed-point should only be used for full generation, not for single step.
def RecEvolverM(D: Type) : Type := (weightBound: Nat) → (cardBound: Nat) →  ExprDist → (initData: D) → (evo: EvolverM D) → TermElabM ExprDist

namespace EvolverM

def init(D: Type) : EvolverM D := fun _ _ _ init  => pure init

def tautRec{D: Type}(ev: EvolverM D) : RecEvolverM D := 
        fun wb cb init d _ => ev wb cb d init 

def andThenM{D: Type}(ev : EvolverM D) 
              (effect: ExprDist → TermElabM Unit) : EvolverM D := 
      fun wb cb initDist data  => 
        do
          let newDist ← ev wb cb initDist data 
          effect newDist
          pure newDist

end EvolverM


instance{D: Type} : Inhabited <| EvolverM D := ⟨EvolverM.init D⟩

namespace RecEvolverM

def init(D: Type) := (EvolverM.init D).tautRec

partial def fixedPoint{D: Type}(recEv: RecEvolverM D) : EvolverM D :=
        fun wb c data init => recEv wb c init data (fixedPoint recEv)

def iterateAux{D: Type}[DataUpdate D](stepEv : RecEvolverM D)(incWt accumWt cardBound: Nat) : 
                     ExprDist → (initData: D) → (evo: EvolverM D) → TermElabM ExprDist := 
                     match incWt with
                     | 0 => fun initDist _ _ => return initDist
                     | m + 1 => fun initDist d evo => 
                      do
                        IO.println s!"Evolver step: weight-bound = {accumWt+ 1}; cardinality-bound = {cardBound}; mono-time = {← IO.monoMsNow}"
                        let newDist ←  stepEv (accumWt + 1) cardBound initDist d evo
                        IO.println s!"step completed: weight-bound = {accumWt+ 1}; cardinality-bound = {cardBound}; mono-time = {← IO.monoMsNow}"
                        let newData := dataUpdate initDist accumWt cardBound d
                        -- IO.println s!"data updated: wb = {accumWt+ 1} cardBound = {cardBound} time = {← IO.monoMsNow} "
                        iterateAux stepEv m (accumWt + 1) cardBound newDist newData evo

def iterate{D: Type}[DataUpdate D](stepEv : RecEvolverM D): RecEvolverM D := 
      fun wb cb initDist data evo => 
        iterateAux stepEv wb 0 cb initDist data evo

def levelIterate{D: Type}[DataUpdate D](stepEv : RecEvolverM D)
                    (steps maxWeight cardBound: Nat) : 
                     ExprDist → (initData: D) → (evo: EvolverM D) → TermElabM ExprDist := 
                     match steps with
                     | 0 => fun initDist _ _ => return initDist
                     | m + 1 => fun initDist d evo => 
                      do
                        let newDist ←  stepEv maxWeight cardBound initDist d evo
                        let newData := dataUpdate newDist  maxWeight cardBound d
                        levelIterate stepEv m maxWeight cardBound newDist newData evo

def merge{D: Type}(fst: RecEvolverM D)(snd: RecEvolverM D) : RecEvolverM D := 
      fun wb cb initDist data evo => 
        do
          let fstDist ← fst wb cb initDist data evo
          let sndDist ← snd wb cb initDist data evo
          fstDist ++ sndDist

def transformM{D: Type} (recEv : RecEvolverM D) 
            (f: ExprDist → TermElabM ExprDist) : RecEvolverM D := 
      fun wb cb initDist data evo => 
        do
          let newDist ← recEv wb cb initDist data evo
          f newDist

def andThenM{D: Type}(recEv : RecEvolverM D) 
              (effect: ExprDist → TermElabM Unit) : RecEvolverM D := 
      fun wb cb initDist data evo => 
        do
          let newDist ← recEv wb cb initDist data evo
          effect newDist
          pure newDist

end RecEvolverM

instance {D: Type}: Append <| RecEvolverM D := ⟨fun fst snd => fst.merge snd⟩

def EvolverM.evolve{D: Type}[DataUpdate D](ev: EvolverM D) : EvolverM D :=
        ev.tautRec.iterate.fixedPoint

def isleM {D: Type}[IsleData D](type: Expr)(evolve : EvolverM D)(weightBound: Nat)(cardBound: Nat)
      (init : ExprDist)(initData: D)(includePi : Bool := true)(excludeProofs: Bool := false)(excludeLambda : Bool := false)(excludeInit : Bool := false): TermElabM (ExprDist) := 
    withLocalDecl Name.anonymous BinderInfo.default (type)  $ fun x => 
        do
          -- IO.println s!"Isle variable type: {← view <| ← whnf <| ← inferType x}; is-proof? : {← isProof x}"
          let dist ←  init.updateExprM x 0
          let pts ← dist.termsArr.mapM (fun (term, w) => do 
            return (← inferType term, w))
          -- IO.println s!"initial terms in isle: {pts}"
          let foldedFuncs : Array (Expr × Nat) ← 
            (← init.funcs).filterMapM (
              fun (f, w) => do
                if !(f.isLambda) then pure none else
                  let y ← (mkAppOpt f x)
                  return y.map (fun y => (y, w))
              )
          let dist ← dist.mergeArray foldedFuncs
          -- logInfo "started purging terms"
          let purgedTerms ← dist.termsArr.filterM (fun (term, w) => do
              -- logInfo m!"considering term: {term}"
              match term with
              | Expr.lam _ t y _ => 
                -- logInfo m!"term is lambda t: {t}, y: {y}"
                let res ←  
                  try 
                    return !(← isType y <&&> isDefEq (← inferType x) t)
                  catch _ => pure true
                -- if !res then logInfo m!"purged term: {term}"
                return res
              | _ => pure true
          )
          -- logInfo "finished purging terms"
          -- let pts ← purgedTerms.mapM (fun (term, w) => do (← inferType term, w))
          -- IO.println s!"terms in isle: {pts.size}"
          let dist := ⟨purgedTerms, dist.proofsArr⟩
          -- IO.println s!"entered isle: {← IO.monoMsNow} "
          let eva ← evolve weightBound cardBound  
                  (isleData initData dist weightBound cardBound) dist
          -- IO.println s!"inner isle distribution obtained: {← IO.monoMsNow} "
          -- IO.println s!"initial size: {eva.termsArr.size}, {eva.proofsArr.size}"
          let evb ← if excludeInit then eva.diffM dist else pure eva
          -- IO.println s!"diff size ({excludeInit}): {evb.termsArr.size}, {evb.proofsArr.size}"
          -- IO.println s!"dist: {← dist.existsM x 0}, eva: {← eva.existsM x 0}, evb: {← evb.existsM x 0}"
          let innerTerms : Array (Expr × Nat) :=  if excludeProofs 
          then ← evb.termsArr.filterM ( fun (t, _) => do
              let b ← isDefEq t x
              return !b)
          else evb.termsArr
          let innerTypes ← innerTerms.filterM (fun (t, _) => liftMetaM (isType t))
          let lambdaTerms ← innerTerms.mapM (fun (t, w) =>
              return (← mkLambdaFVars #[x] t, w))  
          let piTypes ←  innerTypes.mapM (fun (t, w) =>
              return (← mkForallFVars #[x] t, w))
          let proofs ← evb.proofsArr.mapM (fun (prop, pf, w) => do
            let expPf ← mkLambdaFVars #[x] pf
            let expPf ← whnf expPf
            Term.synthesizeSyntheticMVarsNoPostponing
            return (← inferType expPf , expPf , w))
          let mut evl : ExprDist := ExprDist.empty
          -- IO.println s!"inner isle distribution exported: {← IO.monoMsNow} "
          let res := 
            ⟨if includePi then 
                if excludeLambda then piTypes else lambdaTerms ++ piTypes  
              else  lambdaTerms, if excludeProofs then #[] else proofs⟩
          -- IO.println s!"outer isle distribution obtained: {← IO.monoMsNow} "
          return res

-- Some evolution cases; just one step (so update not needed)

def applyEvolver(D: Type)[NewElem Expr D] : EvolverM D := fun wb c d init => 
  do
    -- logInfo m!"apply evolver started, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    let res ← prodGenArrM applyOpt wb c (← init.funcs) init.allTermsArr d 
    -- logInfo m!"apply evolver finished, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    return res

def applyPairEvolver(D: Type)[cs : IsNew D][NewElem Expr D]: EvolverM D := 
  fun wb c d init =>
  do
    -- logInfo m!"apply pair evolver started, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    let funcs ← init.termsArr.filterM $ fun (e, _) => 
       do return Expr.isForall <| ← inferType e
    let pfFuncs ← init.proofsArr.filterMapM <| fun (l, f, w) =>
      do if (l.isForall) then return some (f, w) else return none
    let res ← tripleProdGenArrM applyPairOpt wb c 
          (← init.funcs) init.allTermsArr init.allTermsArr d
    -- logInfo m!"apply pair evolver finished, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    return res

def simpleApplyEvolver(D: Type)[NewElem Expr D] : EvolverM D := fun wb c d init => 
  do
    -- logInfo m!"apply evolver started, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    /- for a given type α; functions with domain α and terms with type α  
    -/ 
    let mut grouped : HashMap UInt64 (Array (Expr × (Array (Expr  × Nat)) × (Array (Expr × Nat)))) := HashMap.empty
    for (x, w) in init.allTermsArr do
      let type ← whnf <| ← inferType x
      match type with
      | Expr.forallE _ dom b _ =>
          let key ← exprHash dom
          let arr := grouped.findD key #[] 
          match ← arr.findIdxM? <| fun (y, _, _) => isDefEq y dom with
          | some j =>
              let (y, fns, ts) := arr.get! j
              grouped := grouped.insert key (arr.set! j (y, fns.push (x, w), ts))
          | none => 
              grouped := grouped.insert key (arr.push (dom, #[(x, w)], #[]))
      |  _ => pure ()
      let key ← exprHash type
      let arr := grouped.findD key #[] 
      match ← arr.findIdxM? <| fun (y, _, _) => isDefEq y type with
      | some j =>
              let (y, fns, ts) := arr.get! j
              grouped := grouped.insert key (arr.set! j (y, fns, ts.push (x, w)))
      | none => 
              grouped := grouped.insert key (arr.push (type, #[], #[(x, w)]))
    let mut cumPairCount : HashMap Nat Nat := HashMap.empty
    for (_, arr) in grouped.toArray do
      for (dom, fns, ts) in arr do
        for (f, wf) in fns do
          for (x, wx) in ts do
            let w := wf + wx + 1
            for j in [w: wb+ 1] do
            cumPairCount := cumPairCount.insert j (cumPairCount.findD j 0 + 1)
    let mut resTerms: Array (Expr × Nat) := #[]
    for (_, arr) in grouped.toArray do
      for (dom, fns, ts) in arr do
        for (f, wf) in fns do
          for (x, wx) in ts do
            let w := wf + wx + 1
            if w ≤ wb && cumPairCount.findD w 0 ≤  c then
              let y := mkApp f x
              let y ← whnf y
              Term.synthesizeSyntheticMVarsNoPostponing
              resTerms := resTerms.push (y, w)
    ExprDist.fromArray resTerms
    -- let res ← prodGenArrM mkAppOpt wb c (← init.funcs) init.allTermsArr d 
    -- logInfo m!"apply evolver finished, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    -- return res

def simpleApplyPairEvolver(D: Type)[cs : IsNew D][NewElem Expr D]: EvolverM D := 
  fun wb c d init =>
  do
    -- logInfo m!"apply pair evolver started, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    let res ← tripleProdGenArrM mkAppPairOpt wb c 
          (← init.funcs) init.allTermsArr init.allTermsArr d
    -- logInfo m!"apply pair evolver finished, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    return res

def nameApplyEvolver(D: Type)[IsNew D][GetNameDist D][NewElem Expr D]: EvolverM D := 
  fun wb c d init =>
  do
    -- logInfo m!"name apply evolver started, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    let names := (nameDist d).toArray
    let res ← prodGenArrM nameApplyOpt wb c names init.allTermsArr d
    -- logInfo m!"name apply evolver finished, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    return res

def nameApplyPairEvolver(D: Type)[cs: IsNew D][GetNameDist D][NewElem Expr D]: 
        EvolverM D := fun wb c d init  =>
  do
    -- logInfo m!"name apply pair evolver started, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    let names := (nameDist d).toArray
    let res ← tripleProdGenArrM nameApplyPairOpt wb c names init.allTermsArr init.allTermsArr d
    -- logInfo m!"name apply pair evolver finished, wb: {wb}, c: {c}, time: {← IO.monoMsNow}"
    return res

def rewriteEvolver(flip: Bool)(D: Type)[IsNew D][NewElem Expr D] : EvolverM D := 
  fun wb c d init => 
  do
    prodGenArrM (rwPushOpt flip) wb c init.allTermsArr (← init.eventuallyEqls) d

def congrEvolver(D: Type)[IsNew D][NewElem Expr D] : EvolverM D := 
  fun wb c d init  => 
  do
    prodGenArrM congrArgOpt wb c (← init.funcs) (← init.eqls) d

def eqIsleEvolver(D: Type)[IsNew D][NewElem Expr D][IsleData D] : RecEvolverM D := 
  fun wb c init d evolve => 
  do
    -- logInfo m!"isle called: weight-bound {wb}, cardinality: {c}"
    -- logInfo m!"initial time: {← IO.monoMsNow}"
    let mut eqTypes: FinDist Expr := FinDist.empty -- lhs types, (minimum) weights
    let mut eqs: FinDist Expr := FinDist.empty -- equalities, weights
    let mut eqTriples : Array (Expr × Expr × Nat) := #[] -- equality, lhs type, weight
    for (l, exp, w) in init.proofsArr do
      match l.eq? with
      | none => pure ()
      | some (α, lhs, rhs) =>
          eqTypes :=  eqTypes.update α w
          eqs :=  eqs.update exp w
          eqTriples := eqTriples.push (exp, α, w)
    let eqsCum := eqs.cumulWeightCount wb
    let mut isleDistMap : HashMap Expr ExprDist := HashMap.empty
    -- logInfo m!"equality types: {eqTypes.size}"
    for (type, w) in eqTypes.toArray do
      if wb - w > 0 then
        let ic := c / (eqsCum.find! w) -- should not be missing
        let isleDist ←   isleM type evolve (wb -w -1) ic init d false true false true
        isleDistMap := isleDistMap.insert type isleDist
    -- logInfo m!"tasks to be defined :{← IO.monoMsNow}"
    let finDistsAux : Array (Task (TermElabM ExprDist)) :=  
        (eqTriples.filter (fun (_, _, weq) => wb - weq > 0)).map <|
          fun (eq, type, weq) => 
          Task.spawn ( fun _ =>
            let isleDistBase := isleDistMap.findD type ExprDist.empty
            let xc := c / (eqsCum.find! weq) -- should not be missing
            let isleDist := (isleDistBase.bound (wb -weq -1) xc).termsArr
            isleDist.foldlM (
                fun d (f, wf) => do 
                  match ← congrArgOpt f eq with 
                  | none => pure d
                  | some y => 
                      d.updateExprM y (wf + weq + 1)
                ) ExprDist.empty) 
    -- logInfo m!"tasks defined :{← IO.monoMsNow}"
    let finDists ← finDistsAux.mapM <| fun t => t.get
    let finDists := finDists.filter (fun d => d.termsArr.size > 0 || d.proofsArr.size > 0)
    -- logInfo m!"tasks executed :{← IO.monoMsNow}"
    let res := finDists.foldlM (fun x y => x ++ y) ExprDist.empty
    -- logInfo m!"isles done time: {← IO.monoMsNow}, isles: {finDists.size}"
    res

def allIsleEvolver(D: Type)[IsNew D][IsleData D] : RecEvolverM D := fun wb c init d evolve => 
  do
    let typeDist ← init.allSorts
    let typesCum := typeDist.cumulWeightCount wb
    let mut finalDist: ExprDist := ExprDist.empty
    for (type, w) in typeDist.toArray do
      if wb - w > 0 then
        let ic := c / (typesCum.find! w)
        let isleDist ←   isleM type evolve (wb -w -1) ic init d   
        finalDist ←  finalDist ++ isleDist
    return finalDist

def eqSymmTransEvolver (D: Type)[IsNew D](goalterms: Array Expr := #[]) : EvolverM D 
  := fun wb card d init => 
  do
    -- IO.println s!"eqSymmTrans called: weight-bound {wb}, cardinality: {card}"
    -- IO.println s!"initial terms: {init.termsArr.size}"
    -- IO.println s!"initial proofs: {init.proofsArr.size}"        
    let mut eqs := ExprDist.empty -- new equations only
    let mut allEquationGroups : HashMap (UInt64) ExprDist := HashMap.empty
    -- let mut allEquations := ExprDist.empty
    -- initial equations
    for (l, pf, w) in init.proofsArr do
      match l.eq? with
        | some (_, lhs, rhs) => if !(← isDefEq lhs rhs) then
          let key ← exprHash l
          allEquationGroups := allEquationGroups.insert key <|
              (allEquationGroups.findD key ExprDist.empty).pushProof l pf w
        | none => pure ()
    -- symmetrize
    let eqnArray := allEquationGroups.toArray
    for (key, allEquations) in eqnArray do
      for (l, pf, w) in allEquations.proofsArr do
        match l.eq? with
        | none => pure ()
        | some (_, lhs, rhs) =>
          let flipProp ← mkEq rhs lhs
          let flip ← whnf (← mkAppM ``Eq.symm #[pf])
          let flipkey ← exprHash flipProp
          match ← (allEquationGroups.findD flipkey ExprDist.empty).updatedProofM? 
                  flipProp flip (w + 1) with
          | none => pure ()
          | some dist => 
            allEquationGroups := allEquationGroups.insert flipkey dist
            eqs := eqs.pushProof flipProp flip (w + 1)
    /- group equations, for y we have proofs of x = y and then y = z,
        record array of (x, pf, w) and array of (z, pf, z)
    -/
    let mut grouped : HashMap (UInt64)
          (Array (Expr × (Array (Expr × Expr × Nat)) × (Array (Expr × Expr × Nat)))) := 
      HashMap.empty
    for (key, allEquations) in allEquationGroups.toArray do
      for (l, pf, w) in allEquations.proofsArr do
        match l.eq? with
        | none => pure ()
        | some (_, lhs, rhs) =>
          let lhs ← whnf lhs
          let rhs ← whnf rhs
          Term.synthesizeSyntheticMVarsNoPostponing
          -- update first component, i.e. y = rhs
          let key ← exprHash rhs
          match ← (grouped.findD key  #[]).findIdxM? <| fun (y, _, _) => isDefEq y rhs with
          | none => -- no equation involving rhs
            let weight := Nat.min w (← init.findD lhs w)
            grouped := grouped.insert key <|
              (grouped.findD key  #[]).push (rhs, #[(lhs, pf, weight)] , #[])
          | some j => 
            let (y, withRhs, withLhs) := (grouped.findD key  #[]).get! j
            -- if !((← exprHash rhs) = (← exprHash y)) then
            --   IO.println s!"Hash mismatch for \nrhs: {rhs}, \ny: {y};\nkey: {key}"
            let weight := Nat.min w (← init.findD lhs w)
            grouped := grouped.insert key <|
              (grouped.findD key  #[]).set! j (rhs, withRhs.push (lhs, pf, weight) , withLhs)
          -- update second component
          let key ← exprHash lhs
          match ← (grouped.findD key  #[]).findIdxM? <| fun (y, _, _) => isDefEq y lhs with
          | none => -- no equation involving lhs
            let weight := Nat.min w (← init.findD rhs w)
            grouped := grouped.insert key <|
              (grouped.findD key  #[]).push (lhs, #[], #[(rhs, pf, weight)])
          | some j => 
            let (y, withRhs, withLhs) := (grouped.findD key  #[]).get! j
            let weight := Nat.min w (← init.findD rhs w)
            grouped := grouped.insert key <|
              (grouped.findD key  #[]).set! j (lhs, withRhs, withLhs.push (rhs, pf, weight))
    -- count cumulative weights of pairs, deleting reflexive pairs (assuming symmetry)
    -- IO.println s!"grouped; mono-time {←  IO.monoMsNow}"
    let mut cumPairCount : HashMap Nat Nat := HashMap.empty
    for (key, group) in grouped.toArray do
      for (_, m ,_) in group do
        let weights := m.map <| fun (_, _, w) => w
        for w1 in weights do
          for w2 in weights do 
            for j in [w1 + w2:wb + 1] do
              cumPairCount := cumPairCount.insert j (cumPairCount.findD j 0 + 1)
        for w1 in weights do 
          for j in [w1 + w1:wb + 1] do
            cumPairCount := cumPairCount.insert j (cumPairCount.findD j 0 - 1)
    -- IO.println s!"cumulative pair count: {cumPairCount.toArray}"
    -- for g in goalterms do
    --   IO.println s!"goalterm: {g},  {← init.getTerm? g}" 
    for (key, group) in grouped.toArray do
      -- IO.println s!"group: {key}, size : {group.size}"
      for (y, withRhs, withLhs) in group do
        -- let focus ← goalterms.anyM <| fun t => isDefEq t y
        -- if focus then 
        -- IO.println s!"y: {y}, withRhs: {withRhs.size}, withLhs: {withLhs.size}"
        for (x, eq1, w1) in withRhs do
          -- IO.println s!"x: {x}, w1: {w1}"
          for (z, eq2, w2) in withLhs do
          -- IO.println s!"z: {z}, w2: {w2}"
          let w := w1 + w2
              -- if focus then IO.println s!"x: {x}, z: {z}, w: {w}" 
              if w ≤ wb && (cumPairCount.findD w 0) ≤ card * 2 then 
              unless ← isDefEq x  z do
                let eq3 ← whnf (←   mkAppM ``Eq.trans #[eq1, eq2]) 
                let prop ← mkEq x z
                Term.synthesizeSyntheticMVarsNoPostponing
                let key ← exprHash prop
                unless ← (allEquationGroups.findD key ExprDist.empty).existsPropM prop w do
                  eqs := eqs.pushProof prop eq3 w   
    -- IO.println s!"eqs: {eqs.proofsArr.size}"
    return eqs


def funcDomIsleEvolver(D: Type)[IsNew D][IsleData D] : RecEvolverM D := fun wb c init d evolve => 
  do
    let mut typeDist := FinDist.empty
    for (x, w) in init.allTermsArr do
      let type ← whnf (← inferType x)
      match type with
      | Expr.forallE _ t .. =>
          typeDist := typeDist.update type w
      | _ => pure ()
    let typesCum := typeDist.cumulWeightCount wb
    let mut finalDist: ExprDist := ExprDist.empty
    for (type, w) in typeDist.toArray do
      if wb - w > 0 then
        let ic := c / (typesCum.findD w 0)
        let isleDist ←   isleM type evolve (wb -w -1) ic init d true false true  
        finalDist ←  finalDist ++ isleDist
    return finalDist

-- domains of terms (goals) that are pi-types, with minimum weight
def piDomains(terms: Array (Expr × Nat)) : TermElabM (Array (Expr × Nat)) := do
  let mut domains := Array.empty
  for (t, w) in terms do
    match t with
    | Expr.forallE _ t .. =>
      match ← domains.findIdxM? <| fun (type, w) => isDefEq type t with
      | some j =>
        let (type, weight) := domains.get! j
        if w < weight then 
          domains := domains.set! j (t, w) 
      | _ =>
        domains := domains.push (t, w)
    | _ => pure ()
  return domains

-- generating from domains of pi-types
def piGoalsEvolverM(D: Type)[IsNew D][NewElem Expr D][IsleData D](goalsOnly: Bool) : RecEvolverM D := 
  fun wb c init d evolve => 
  -- if wb = 0 then init else
  do
    let targets ← if goalsOnly then init.goalsArr else pure init.allTermsArr
    let piDoms ← piDomains (init.termsArr)
    -- IO.println s!"pi-domains: {← piDoms.mapM <| fun (t , w) => do return (← view <| ← whnf t, w)}"
    let cumWeights := FinDist.cumulWeightCount  (FinDist.fromArray piDoms) wb
    let mut finalDist: ExprDist := ExprDist.empty
    for (type, w) in piDoms do
      if w ≤ wb && (cumWeights.find! w ≤ c) then
      -- convert pi-types with given domain to lambdas
      let isleTerms ←  init.termsArr.mapM (fun (t, w) => do 
          match t with
          | Expr.forallE _ l b _ =>
            if ← isDefEq l type then
              -- logInfo m!"made pi to lambda"
              withLocalDecl Name.anonymous BinderInfo.default t  $ fun f =>
              withLocalDecl Name.anonymous BinderInfo.default l  $ fun x => do
                let y :=  mkApp f x
                let bt ← inferType y
                -- logInfo m!"x: {x}; y: {y}, bt: {bt}"
                let t ← mkLambdaFVars #[x] bt
                let t ← whnf t
                Term.synthesizeSyntheticMVarsNoPostponing
                pure (t, w)
            else
              -- logInfo m!"not made pi to lambda as {l} is not {type}" 
              pure (t, w)
          | _ => pure (t, w))
      -- logInfo "obtained isle-terms"
      let isleInit :=
          -- ←  ExprDist.fromArray isleTerms  
          ⟨isleTerms, init.proofsArr⟩
      let ic := c / (cumWeights.find! w)
      let isleDist ←   isleM type evolve (wb ) ic isleInit 
                (isleData d init wb c) true false false true
      finalDist ←  finalDist ++ isleDist
    -- logInfo "finished for loop for pi-domains"
    return finalDist

def weightByType(cost: Nat): ExprDist → TermElabM ExprDist := fun init => do
  let mut finalDist := init
  for (x, w) in init.termsArr do
    let α := ← whnf (← inferType x)
    match ← init.getTerm? α   with
    | some (_, w)  => finalDist ←  ExprDist.updateTermM finalDist x (w + cost)
    | _ => pure ()
  for (α , x, w) in init.proofsArr do
    match ← init.getTerm? α  with
    | some (_, w)  => finalDist ←  ExprDist.updateProofM finalDist α x (w + cost)
    | _ => pure ()
  return finalDist

def refineWeight(weight? : Expr → TermElabM (Option Nat)):
      ExprDist → TermElabM ExprDist := fun init => do
  let mut finalDist := init
  for (x, w) in init.termsArr do
    match ← weight? x   with
    | some w  => finalDist ←  finalDist.updateTermM x (w)
    | _ => pure ()
  for (prop, x, w) in init.proofsArr do
    match ← weight? x   with
    | some w  => finalDist ←  finalDist.updateProofM prop x (w)
    | _ => pure ()
  return finalDist


def logResults(goals : Array Expr) : ExprDist →  TermElabM Unit := fun dist => do
    IO.println s!"number of terms : {dist.termsArr.size}"
    IO.println s!"number of proofs: {dist.proofsArr.size}"
    IO.println s!"term distribution : {(arrWeightCount dist.termsArr).toArray}"
    IO.println s!"proof distribution: {(arrWeightCount <| dist.proofsArr.map (fun (l, _, w) => (l, w))).toArray}"
    IO.println s!"function distribution : {(arrWeightCount <| ←  dist.funcs).toArray}"
    -- for (l, pf, w) in dist.proofsArr do
      -- logInfo m!"{l} : {pf} : {w}" 
    let mut count := 0
    for g in goals do
      count := count + 1
      IO.println s!"goal {count}: {← view g}"
      let statement ←  (dist.allTermsArr.findM? $ fun (s, _) => isDefEq s g)
      let statement ←  statement.mapM $ fun (e, w) => do
        let e ← whnf e
        pure (← view e, w) 
      if ← isProp g then
        IO.println s!"proposition generated: {statement}"
        let proof ←  dist.proofsArr.findM? $ fun (l, t, w) => 
                do isDefEq l g
        match proof with
        | some (_, pf, w) =>
          -- logInfo m!"found proof {pf} for proposition goal {count} : {g}"
          IO.println s!"proof generated: {← view pf}, weight : {w}"
        | none => pure () -- IO.println s!"no proof generated"
      else
        IO.println s!"term generated: {statement}"
    
-- examples

def egEvolver : EvolverM Unit := 
  ((applyEvolver Unit).tautRec ++ (RecEvolverM.init Unit)).fixedPoint

def egEvolverFull : EvolverM FullData := 
  ((applyEvolver FullData).tautRec ++ (RecEvolverM.init FullData)).fixedPoint

