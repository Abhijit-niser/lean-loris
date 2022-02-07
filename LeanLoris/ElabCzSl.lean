import LeanLoris.Evolution
import LeanLoris.FinDist
import LeanLoris.ExprDist
import LeanLoris.Core
import LeanLoris.ProdSeq
import Lean.Meta
import Lean.Elab
import Std
open Lean
open Meta
open Elab
open Lean.Elab.Term
open Std
open Std.HashMap
open Nat
open ProdSeq

namespace CzSl
constant M : Type

instance : Inhabited (M → M → M) := ⟨fun x _ => x⟩

constant mul : M → M → M


noncomputable instance : Mul M := ⟨mul⟩

axiom ax1 : (∀ a b : M, (a * b) * b = a)
axiom ax2 : (∀ a b : M, a * (a * b) = b)
axiom m : M
axiom n : M


theorem CzSlOly : m * n = n * m := by
              have lem1 : (m * n) * n = m := ax1 m n
              have lem2 : (m * n) * ((m * n) * n) = n := ax2 (m * n) n
              have lem3 : ((m * n) * m) * m = m * n  := ax1 (m * n) m
              have lem4 : (m * n) * ((m * n) * n) = (m * n) * m := 
                  congrArg (fun x => (m * n) * x) lem1              
              have lem5 : (m * n) * m = n := by
                    rw [lem4] at lem2
                    assumption
              have lem6 : ((m * n) * m) * m = n * m  := 
                    congrArg (fun x => x * m) lem5 
              rw [lem3] at lem6
              assumption 

set_option maxHeartbeats 10000000
set_option maxRecDepth 1000

def lem1! := (m * n) * n = m 
def lem2! := (m * n) * ((m * n) * n) = n
def lem3! := ((m * n) * m) * m = m * n
def lem4! := (m * n) * ((m * n) * n) = (m * n) * m
def lem5! := (m * n) * m = n
def lem6! := ((m * n) * m) * m = n * m
def thm! := m * n = n * m

def nameDist := #[(``mul, 0), (``ax1, 0), (``ax2, 0)]
def initData : FullData := (FinDist.fromArray nameDist, [], [])

def goals1 : TermElabM (Array Expr) := do
                  parseExprList (← `(expr_list|%[lem1!, lem2!, lem3!]))
-- #eval goals1
def init1 : TermElabM (Array (Expr × Nat)) := do
                  parseExprMap (← `(expr_dist|%{(m, 0), (n, 0), (m *n, 0)}))
def evStep1 : TermElabM (RecEvolverM FullData) := do
                  parseEvolverList (← `(evolver_list|^[name-app, name-binop]))                  
def ev1 : TermElabM (EvolutionM FullData) := do
                  (← evStep1).fixedPoint.evolve.andThenM (logResults <| ←  goals1)
def dist1 : TermElabM ExprDist := do
                  (← ev1) 3 1000 (← ExprDist.fromArray <| ←  init1) initData
def rep1 : TermElabM (Array (Expr × Nat)) := do
                  (← dist1).getGoals (← goals1)

def evStep2 : TermElabM (RecEvolverM FullData) := do
                  parseEvolverList (← `(evolver_list|^[name-app, name-binop, eq-isles]))

def goals2 : TermElabM (Array Expr) := do
                  parseExprList (← `(expr_list|%[lem1!, lem4!]))

def ev2 : TermElabM (EvolutionM FullData) := do
                  (← evStep2).fixedPoint.evolve.andThenM (logResults <| ←  goals2) 

def dist2 : TermElabM ExprDist := do
                  (← ev2) 3 2000 (← ExprDist.fromArray <| ←  init1) initData
def rep2 : TermElabM (Array (Expr × Nat)) := do
                  (← dist2).getGoals (← goals2)

def evStep3 : TermElabM (RecEvolverM FullData) := do
                  parseEvolverList 
                        (← `(evolver_list|^[eq-closure %[n, (m * n) * ((m * n) * n)]]))

def goals3 : TermElabM (Array Expr) := do
                  parseExprList (← `(expr_list|%[lem5!]))

-- #eval goals3

def ev3 : TermElabM (EvolutionM FullData) := do
                  (← evStep3).fixedPoint.evolve.andThenM (logResults <| ←  goals3) 

def dist3 : TermElabM ExprDist := do
                  (← ev3) 1 6000 (← dist2) initData
def rep3 : TermElabM (Array (Expr × Nat)) := do
                  (← dist3).getGoals (← goals3)

def goals4 : TermElabM (Array Expr) := do
                  parseExprList (← `(expr_list|%[lem6!]))
def evStep4 : TermElabM (RecEvolverM FullData) := evStep2

def ev4 : TermElabM (EvolutionM FullData) := do
                  (← evStep4).fixedPoint.evolve.andThenM (logResults <| ←  goals4) 
def dist4 : TermElabM ExprDist := do
                  (← ev4) 3 6000 (← dist3) initData
def rep4 : TermElabM (Array (Expr × Nat)) := do
                  (← dist4).getGoals (← goals4)
def goals5 : TermElabM (Array Expr) := do
                  parseExprList (← `(expr_list|%[thm!]))
def evStep5 : TermElabM (RecEvolverM FullData) := do
                  parseEvolverList 
                        (← `(evolver_list|^[eq-closure]))

def ev5 : TermElabM (EvolutionM FullData) := do
                  (← evStep5).fixedPoint.evolve.andThenM (logResults <| ←  goals5) 
def dist5 : TermElabM ExprDist := do
                  (← ev5) 1 6000 (← dist4) initData
def rep5 : TermElabM (Array (Expr × Nat)) := do
                  (← dist5).getGoals (← goals5)
def view5 : TermElabM String := do
                  (← dist5).viewGoals (← goals5)                
end CzSl
