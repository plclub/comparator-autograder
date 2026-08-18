import Lean
import Comparator.MainSupport
import ComparatorAutograder.Basic

namespace ComparatorAutograder

open Lean Comparator FailureReason

/- A lot of this is adapted directly from https://github.com/leanprover/comparator/blob/777e7f56119efc0fac34003db4efe831e0b53723/Comparator/Compare.lean -/

structure Context where
  challenge : Export.ExportedEnv
  solution : Export.ExportedEnv
  definitionTargets : Std.HashSet Lean.Name
  target : Lean.Name

abbrev CompareM := ReaderT Context <| StateT Compare.State <| Except FailureReason

def addWorklist (n : Lean.Name) : CompareM Unit := do
  if !(← get).checked.contains n then
    modify fun s => { s with worklist := s.worklist.push n }

def addRelevantConsts (info : Lean.ConstantInfo) : CompareM Unit := do
  runForUsedConsts info addWorklist

partial def loop : CompareM Unit := do
  if (← get).worklist.isEmpty then
    return ()

  let target ← modifyGet fun s => (s.worklist.back!, { s with worklist := s.worklist.pop })
  if (← get).checked.contains target then
    loop
  else
    let some challengeConst := (← read).challenge.constMap[target]?
      | throw <| constNotFoundInChallenge target
    let some solutionConst := (← read).solution.constMap[target]?
      | throw <| constNotFoundInSolution target

    if (← read).definitionTargets.contains solutionConst.name
        || (← read).target == solutionConst.name then
      solutionConst.type.getUsedConstants.forM addWorklist
    else
      if challengeConst != solutionConst then
        throw <| constDoesNotMatch target
      addRelevantConsts solutionConst

    modify fun s => { s with checked := s.checked.insert target }
    loop

def compareTheoremAt (challenge solution : Export.ExportedEnv) (target : Lean.Name)
    (definitionTargets : Array Lean.Name) : StateT Compare.State (Except FailureReason) Unit := do
  let some challengeConst := challenge.constMap[target]?
    | throw <| constNotFoundInChallenge target

  let some solutionConst := solution.constMap[target]?
    | throw <| constNotFoundInSolution target

  let (challengeConst, solutionConst) ←
    match challengeConst, solutionConst with
    | .thmInfo cc, .thmInfo sc
    | .axiomInfo cc, .axiomInfo sc => pure (cc.toConstantVal, sc.toConstantVal)
    | _, _ => throw <| wrongKind target

  if challengeConst != solutionConst then
    throw <| constDoesNotMatch target

  modify fun s => { s with worklist := s.worklist ++ challengeConst.type.getUsedConstants }

  let definitionTargets := Std.HashSet.ofArray definitionTargets
  loop.run { challenge, solution, definitionTargets, target }

def compareDefinitionAt (challenge solution : Export.ExportedEnv) (target : Lean.Name)
    (definitionTargets : Array Lean.Name) : StateT Compare.State (Except FailureReason) Unit := do

  let some challengeConst := challenge.constMap[target]?
    | throw <| constNotFoundInChallenge target

  let some solutionConst := solution.constMap[target]?
    | throw <| constNotFoundInSolution target

  let .defnInfo challengeConst := challengeConst
    | throw <| bug s!"Challenge constant is not a definition: '{target}'"
  let .defnInfo solutionConst := solutionConst
    | throw <| wrongKind target

  if !definitionHoleMatches challengeConst solutionConst then
    throw <| holeDoesNotMatch target

  modify fun s => { s with worklist := s.worklist.push solutionConst.name }

  let definitionTargets := Std.HashSet.ofArray definitionTargets
  loop.run { challenge, solution, definitionTargets, target }

namespace Axioms

def defaultAxioms := #[`propext, `Classical.choice, `Quot.sound]

abbrev AxiomsM := ReaderT Comparator.Axioms.Context <| StateT Comparator.Axioms.State <| Except FailureReason

partial def loop : AxiomsM Unit := do
  if (← get).worklist.isEmpty then
    return ()

  let target ← modifyGet fun s => (s.worklist.back!, { s with worklist := s.worklist.pop })
  if (← get).checked.contains target then
    loop
  else
    let some info := (← read).solution.constMap[target]?
      | throw <| constNotFoundInSolution target

    runForUsedConsts info validateConst

    modify fun s => { s with checked := s.checked.insert target }
    loop
where
  validateConst (n : Lean.Name) : AxiomsM Unit := do
    let some info := (← read).solution.constMap[n]?
      | throw <| constNotFoundInSolution n

    if let .axiomInfo info := info then
      if !(← read).legalAxioms.contains info.name then
        throw <| illegalAxiom n info.name

    if !(← get).checked.contains n then
      modify fun s => { s with worklist := s.worklist.push n }

end Axioms

def compareAndCheckAxioms (challenge solution : Export.ExportedEnv) (definitionNames : Array Name) (name : Name) : StateT Compare.State (Except FailureReason) Unit := do
  compareTheoremAt challenge solution name definitionNames
  Axioms.loop.run { solution, legalAxioms := Std.HashSet.ofArray Axioms.defaultAxioms } |>.run' { worklist := #[name], checked := {} }

def myVerifyMatch (challengeExport : String) (solutionExport : String) :
    M (Array (Name × Except FailureReason Unit)) := do
  let challenge ← Export.parseStream (← stringStream challengeExport)
  let solution ← Export.parseStream (← stringStream solutionExport)
  let theoremNames ← getTheoremNames
  let definitionNames ← getDefinitionNames
  let primitive ← primitiveTargets
  let mut worklist := primitive
  let mut checked := {}
  for name in definitionNames do
    let ⟨_, st⟩ ← IO.ofExcept <| compareDefinitionAt challenge solution name primitive |>.run { worklist, checked }
    worklist := st.worklist
    checked := st.checked
  let mut result := none
  if ← getNanodaEnabled then
    result := result <|> (← runNanoda solutionExport)
  result := result <|> (← runKernel solution)
  if let some error := result then
    throw <| IO.userError error

  let mut results := #[]
  for name in theoremNames do
    match compareAndCheckAxioms challenge solution definitionNames name |>.run { worklist, checked } with
    | .ok ⟨res, st⟩ =>
      results := results.push ⟨name, .ok res⟩
      worklist := st.worklist
      checked := st.checked
    | .error e =>
      results := results.push ⟨name, .error e⟩
  return results

def compareIt : Comparator.M (Array (Name × Except FailureReason Unit)) := do
  let exportTargets := (← builtinTargets) ++ (← getTheoremNames) ++ (← getLegalAxioms)
    ++ (← primitiveTargets) ++ (← getDefinitionNames)

  let challengeModule ← getChallengeModule
  safeLakeBuild challengeModule -- TODO throw `bug` if this fails?
  let challengeExport ← safeExport challengeModule exportTargets

  let solutionModule ← getSolutionModule
  safeLakeBuild solutionModule
  let solutionExport ← safeExport solutionModule exportTargets

  myVerifyMatch challengeExport solutionExport
