import Lean
import Comparator.MainSupport
import ComparatorAutograder.Basic

namespace ComparatorAutograder

open Lean Comparator FailureReason

/- A lot of this is adapted directly from https://github.com/leanprover/comparator/blob/777e7f56119efc0fac34003db4efe831e0b53723/Comparator/Compare.lean -/

structure Context where
  challenge : Export.ExportedEnv
  solution : Export.ExportedEnv
  holes : Std.HashSet Lean.Name
  legalAxioms : Std.HashSet Lean.Name
  target : Lean.Name

structure State where
  compareWorklist : Array Lean.Name
  compareChecked : Std.HashSet Lean.Name
  axiomsWorklist : Array Lean.Name
  axiomsChecked : Std.HashSet Lean.Name

-- Change `Id` to `IO` to have access to IO.
-- In `myVerifyMatch` write `let r : IO _ := compareTheoremAt` for `match ← r` to work.
abbrev CompareM := ReaderT Context <| StateT State <| ExceptT FailureReason Id

def addCompareWorklist (n : Lean.Name) : CompareM Unit := do
  if !(← get).compareChecked.contains n then
    modify fun s => { s with compareWorklist := s.compareWorklist.push n }

def addAxiomsWorklist (n : Lean.Name) : CompareM Unit := do
  if !(← get).axiomsChecked.contains n then
    modify fun s => { s with axiomsWorklist := s.axiomsWorklist.push n }

def addRelevantConsts (info : Lean.ConstantInfo) : CompareM Unit := do
  runForUsedConsts info addCompareWorklist

namespace Axioms

partial def loop : CompareM Unit := do
  if (← get).axiomsWorklist.isEmpty then
    return ()

  let target ← modifyGet fun s => (s.axiomsWorklist.back!, { s with axiomsWorklist := s.axiomsWorklist.pop })
  if (← get).axiomsChecked.contains target then
    loop
  else
    let some info := (← read).solution.constMap[target]?
      | throw <| constNotFoundInSolution target

    runForUsedConsts info validateConst

    modify fun s => { s with axiomsChecked := s.axiomsChecked.insert target }
    loop
where
  validateConst (n : Lean.Name) : CompareM Unit := do
    let some info := (← read).solution.constMap[n]?
      | throw <| constNotFoundInSolution n

    if let .axiomInfo info := info then
      if !(← read).legalAxioms.contains info.name then
        throw <| illegalAxiom n info.name

    addAxiomsWorklist n

end Axioms

/- There is quite a bit of room to specify restraints on the inductive: number of constructors, can it be recursive, etc. We opt for just its type (via `toConstantVal`) and safety. -/
def inductiveHoleMatches (challengeHole solutionHole : Lean.InductiveVal) : Bool :=
  challengeHole.toConstantVal == solutionHole.toConstantVal
    && challengeHole.isUnsafe == solutionHole.isUnsafe

partial def loop : CompareM Unit := do
  if (← get).compareWorklist.isEmpty then
    return ()

  let target ← modifyGet fun s => (s.compareWorklist.back!, { s with compareWorklist := s.compareWorklist.pop })
  if (← get).compareChecked.contains target then
    loop
  else
    let some challengeConst := (← read).challenge.constMap[target]?
      | throw <| constNotFoundInChallenge target
    let some solutionConst := (← read).solution.constMap[target]?
      | throw <| constNotFoundInSolution target

    if (← read).holes.contains solutionConst.name then
      match challengeConst with
      | .inductInfo challengeConst =>
        let .inductInfo solutionConst := solutionConst
          | throw <| wrongKind target

        if !inductiveHoleMatches challengeConst solutionConst then
          throw <| holeDoesNotMatch target

      | .defnInfo challengeConst =>
        let .defnInfo solutionConst := solutionConst
          | throw <| wrongKind target

        if !definitionHoleMatches challengeConst solutionConst then
          throw <| holeDoesNotMatch target
      | _ => throw <| bug s!"Hole in challenge is neither a definition nor an inductive: '{target}'"

    addAxiomsWorklist target
    Axioms.loop

    if (← read).holes.contains solutionConst.name
        || (← read).target == solutionConst.name then
      -- TODO is `getUsedConstants` correct for inductives?
      solutionConst.type.getUsedConstants.forM addCompareWorklist
    else
      if challengeConst != solutionConst then
        throw <| constDoesNotMatch target
      addRelevantConsts solutionConst

    modify fun s => { s with compareChecked := s.compareChecked.insert target }
    loop

def compareTheoremAt : CompareM Unit := do
  let target := (← read).target
  let some challengeConst := (← read).challenge.constMap[target]?
    | throw <| constNotFoundInChallenge target

  let some solutionConst := (← read).solution.constMap[target]?
    | throw <| constNotFoundInSolution target

  let (challengeConst, solutionConst) ←
    match challengeConst, solutionConst with
    | .thmInfo cc, .thmInfo sc
    | .axiomInfo cc, .axiomInfo sc => pure (cc.toConstantVal, sc.toConstantVal)
    | _, _ => throw <| wrongKind target

  if challengeConst != solutionConst then
    throw <| constDoesNotMatch target

  modify fun s => { s with compareWorklist := s.compareWorklist ++ challengeConst.type.getUsedConstants }
  loop

  -- Check axioms last to favor showing other errors
  addAxiomsWorklist target
  Axioms.loop

def myVerifyMatch (challengeExport : String) (solutionExport : String) :
    M (Array (Name × Except FailureReason Unit)) := do
  let challenge ← Export.parseStream (← stringStream challengeExport)
  let solution ← Export.parseStream (← stringStream solutionExport)
  let theoremNames ← getTheoremNames
  let holes := Std.HashSet.ofArray (← getDefinitionNames)
  let legalAxioms := Std.HashSet.ofArray (← getLegalAxioms)
  let primitive ← primitiveTargets

  let mut result := none
  if ← getNanodaEnabled then
    result := result <|> (← runNanoda solutionExport)
  result := result <|> (← runKernel solution)
  if let some error := result then
    throw <| IO.userError error

  let mut st := {
    compareWorklist := primitive
    compareChecked := {}
    axiomsWorklist := #[]
    axiomsChecked := {}
  }
  let mut results := #[]
  for name in theoremNames do
    let r := compareTheoremAt |>.run { challenge, solution, holes, legalAxioms, target := name } |>.run st
    match r with
    | .ok ⟨res, st'⟩ =>
      results := results.push ⟨name, .ok res⟩
      st := st'
    | .error e =>
      results := results.push ⟨name, .error e⟩
  return results

def compareIt : Comparator.M (Array (Name × Except FailureReason Unit)) := do
  let exportTargets := (← builtinTargets) ++ (← getTheoremNames) ++ (← getLegalAxioms)
    ++ (← primitiveTargets) ++ (← getDefinitionNames)

  let challengeModule ← getChallengeModule
  safeLakeBuild challengeModule -- Note: this is already built in main
  let challengeExport ← safeExport challengeModule exportTargets

  let solutionModule ← getSolutionModule
  safeLakeBuild solutionModule
  let solutionExport ← safeExport solutionModule exportTargets

  myVerifyMatch challengeExport solutionExport
