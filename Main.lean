import Comparator.MainSupport
import ComparatorAutograder.MainSupport
import ComparatorAutograder.Report

open Lean ComparatorAutograder

def main : IO UInt32 := do
  let challengeModule := (← IO.getEnv "AUTOGRADER_CHALLENGE").getD "Challenge"
  let solutionModule := (← IO.getEnv "AUTOGRADER_SOLUTION").getD "Solution"
  let skipImports := (← IO.getEnv "AUTOGRADER_SKIP_IMPORTS") != some "false" -- true by default
  let exportFormat := (← IO.getEnv "AUTOGRADER_EXPORT_FORMAT").getD "human"
  let exportPath := (← IO.getEnv "AUTOGRADER_EXPORT_PATH").getD "/proc/self/fd/1"
  let config : Config := { challengeModule, solutionModule, skipImports }

  safeLakeBuild challengeModule.toName

  initSearchPath (← findSysroot)
  let env ← Lean.importModules #[{ module := challengeModule.toName }] {}
  let ⟨theoremNames, holeNames⟩ ← (collectAutograded config).run env

  let r ← Comparator.M.run compareIt {
    challenge_module := challengeModule
    solution_module := solutionModule
    theorem_names := theoremNames.map fun n => n.1.const.toString
    definition_names := some <| holeNames.map fun n => n.const.toString
    permitted_axioms := #["propext", "Classical.choice", "Quot.sound"]
    enable_nanoda? := none
    external_kernels? := none
  }

  let report := compileReport theoremNames r
  let report := match exportFormat with
    | "human" => report.toString
    | "json" => (toJson report).compress
    | _ => panic! s!"unexpected export format '{exportFormat}'"
  try
    let fd3 ← IO.FS.Handle.mk exportPath IO.FS.Mode.write
    fd3.write report.toByteArray
    return 0
  catch e =>
    IO.eprintln s!"failed to open {exportPath}: {e}"
    IO.println report
    return 1
