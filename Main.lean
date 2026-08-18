import Comparator.MainSupport
import ComparatorAutograder

open Lean ComparatorAutograder

structure Config where
  challengeModule : String
  solutionModule : String
  skipImports : Bool
  deriving Repr

def getModuleOfConst (name : Name) : CoreM (Option Name) := do
  let env ← getEnv
  let decl ← Elab.realizeGlobalConstNoOverloadWithInfo (mkIdent name)
  let mut some idx := env.getModuleIdxFor? decl
    | return none
  let modNames := env.header.moduleNames
  return some modNames[idx]!

/-- Collect all declarations from the environment that have autograding attributes -/
def collectAutograded (config : Config) : ReaderT Environment IO (Array (Name × Rat) × Array Name) := do
  let mut theoremNames := #[]
  let mut holeNames := #[]
  let env := (← read)

  for (name, _constInfo) in env.constants do
    let nameMod ← Core.CoreM.toIO' (getModuleOfConst name)
      { fileName := "", fileMap := default } { env }
    if config.skipImports ∧ nameMod ≠ config.challengeModule.toName then continue
    if let some points := autogradedProofAttr.getParam? env name then
      theoremNames := theoremNames.push ⟨name, points⟩
    else if let some _ := autogradedHoleAttr.getParam? env name then
      holeNames := holeNames.push name
  return ⟨theoremNames, holeNames⟩

-- run_meta
--   let env ← getEnv
--   let n := `Prod
--   let decl ← Elab.realizeGlobalConstNoOverloadWithInfo (mkIdent n)
--   let c ← mkConstWithLevelParams decl
--   IO.println c
--   let mut some idx := env.getModuleIdxFor? decl
--     | throwError "fail"
--   let modNames := env.header.moduleNames
--   IO.println <| env.importPath modNames[idx]!

def main : IO Unit := do
  let challengeModule := (← IO.getEnv "AUTOGRADER_CHALLENGE").getD "Challenge"
  let solutionModule := (← IO.getEnv "AUTOGRADER_SOLUTION").getD "Solution"
  let skipImports := (← IO.getEnv "AUTOGRADER_SKIP_IMPORTS") != some "false" -- true by default
  let config : Config := { challengeModule, solutionModule, skipImports }

  -- Note: this requires the modules to be built with lake first!
  initSearchPath (← findSysroot)
  let env ← Lean.importModules #[{ module := challengeModule.toName }] {}
  let ⟨theoremNames, holeNames⟩ ← (collectAutograded config).run env

  let r ← Comparator.M.run compareIt {
    challenge_module := challengeModule
    solution_module := solutionModule
    theorem_names := theoremNames.map fun n => n.1.toString
    definition_names := some <| holeNames.map Name.toString
    permitted_axioms := #[]
    enable_nanoda := false
  }
  IO.println r
