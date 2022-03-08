import LeanLoris.Syntax 

/-
Examples of simple proofs, which can readily run in the intepreter.
-/

/-
Our first example is one of the first abstract results one sees in algebra: given a multiplication on a set `α` with a left-identity `eₗ` and a right identity `eᵣ`, we have `eₗ = eᵣ`.

Our first proof is by forward reasoning using funtion application and equality closure under symmetry and transitivty.
-/
def left_right_identities1(α : Type)[Mul α](eₗ eᵣ: α)
      (idₗ : ∀ x : α, eₗ * x = x)(idᵣ : ∀ x: α, x * eᵣ = x) :=
        let thm! := eₗ = eᵣ 
        let directProof := evolve! ev![app, eq-closure] exp![thm!] 
                exp!{(idₗ, 0), (idᵣ, 0), (eₗ, 0), (eᵣ, 0)} 2 5000
        let ⟨⟨thm, _⟩, _⟩ := directProof
        thm 

#check left_right_identities1

/-
We give a second proof of the result: given a multiplication on a set `α` with a left-identity `eₗ` and a right identity `eᵣ`, we have `eₗ = eᵣ` to illustrate implicit "lemma choosing". Notice that the cutoff is just `1` for both steps. However the proof is obtained as during equality generation, we look-ahead and generate proofs of statements that are simple.

This example also illustrates saving the result of a step and loading in the next step.
-/
def left_right_identities2(α : Type)[Mul α](eₗ eᵣ: α)
      (idₗ : ∀ x : α, eₗ * x = x)(idᵣ : ∀ x: α, x * eᵣ = x) :=
        let thm! := eₗ = eᵣ 
        let lem1! := eₗ * eᵣ = eᵣ
        let lem2! := eₗ * eᵣ = eₗ
        let step1 := evolve! ev![app] exp![lem1!, lem2!] 
              exp!{(idₗ, 0), (idᵣ, 0), (eₗ, 0), (eᵣ, 0)} 1 1000 =: dist1
        let step2 := evolve! ev![eq-closure] exp![thm!] dist1 1 1000 
        let ⟨⟨thm, _⟩, _⟩ := step2
        thm 

#check left_right_identities2 

/-
We prove modus-ponens using mixed reasoning, specifically function application and introduction of variables for domains of goals.
-/
def modus_ponens(A B: Prop) :=
  let mp := A → (A → B)→ B
  let ⟨⟨thm, _⟩, _⟩ := 
      evolve! ev![pi-goals, simple-app] exp![mp] exp!{(mp, 0)} 1 1000
  thm

#check modus_ponens

/-
The below examples are elementary. 
-/

-- ∀ (A : Prop), A → A
def implies_self(A: Prop) :=
  let idA := ∀ a : A, A
  let ⟨⟨thm, _⟩, _⟩ := evolve! ev![pi-goals-all] exp![idA] exp!{(idA, 0)} 1 1000
  thm

#check implies_self

-- ∀ (A B : Prop), A → (A → B) → B
def deduction(A B: Prop)(a : A)(f: A → B) :=
  let ⟨⟨thm, _⟩, _⟩ := evolve! ev![app] exp![B] exp!{(f, 0), (a, 0)} 1 1000
  thm

#check deduction

-- ∀ (A : Type) (a : A), a = a
def eql_refl(A: Type) :=
  let p := ∀ a: A, a = a
  let ⟨⟨thm, _⟩, _⟩ := evolve! ev![pi-goals, rfl] exp![p] exp!{(p, 0)} 1 1000
  thm

#check eql_refl

-- ∀ (a b c : Nat), a = b → a = c → b = c
def eql_flip_trans(a b c: Nat)(p: a = b)(q: a = c) :=
    let ⟨⟨thm, _⟩, _⟩ := evolve! ev![eq-closure] exp![b = c, b = a, a = b] exp!{(p, 0), (q, 0)} 1 1000
    thm

#check eql_flip_trans