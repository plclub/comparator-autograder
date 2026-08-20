import ComparatorAutograderLib
import ComparatorAutograder.Comparator

namespace ComparatorAutograder
open Lean

structure Config where
  challengeModule : String
  solutionModule : String
  skipImports : Bool
  deriving Repr

-- TODO is this a good way to do this?
def getModuleOfConst (name : Name) : CoreM (Option Name) := do
  let env ← getEnv
  let decl ← Elab.realizeGlobalConstNoOverloadWithInfo (mkIdent name)
  let mut some idx := env.getModuleIdxFor? decl
    | return none
  let modNames := env.header.moduleNames
  return some modNames[idx]!

/-- Collect all declarations from the environment that have autograding attributes -/
def collectAutograded (config : Config) : ReaderT Environment IO (Array (ConstWithMod × Rat) × Array ConstWithMod) := do
  let mut theoremNames := #[]
  let mut holeNames := #[]
  let env ← read

  for (name, _constInfo) in env.constants do
    let .some mod := (← Core.CoreM.toIO' (getModuleOfConst name) { fileName := "", fileMap := default } { env })
      | panic! s!"Could not resolve module of {name}"
    if config.skipImports ∧ mod ≠ config.challengeModule.toName then continue
    if let some points := autogradedProofAttr.getParam? env name then
      theoremNames := theoremNames.push ⟨{ const := name, mod }, points⟩
    else if let some _ := autogradedHoleAttr.getParam? env name then
      holeNames := holeNames.push { const := name, mod }
  return ⟨theoremNames, holeNames⟩

def safeLakeBuild (target : Lean.Name) : IO Unit := do
  IO.println s!"Building {target}"
  let cwd ← IO.Process.getCurrentDir
  let leanPrefix ← Comparator.queryLeanPrefix cwd
  let dotLakeDir := cwd / ".lake"

  if !(← System.FilePath.pathExists dotLakeDir) then
    IO.FS.createDir dotLakeDir

  let spawnArgs := {
    cmd := "lake",
    args := #["build", target.toString],
    envPass := #["PATH", "HOME", "LEAN_ABORT_ON_PANIC"]
    envOverride := #[("LEAN_ABORT_ON_PANIC", some "1")]
    readablePaths := #[cwd]
    writablePaths := #[dotLakeDir]
    executablePaths := #[leanPrefix]
  }
  let proc ← IO.Process.spawn {
    cmd := (← IO.getEnv "COMPARATOR_LANDRUN").getD "landrun",
    args := Comparator.buildLandrunArgs spawnArgs,
    env := spawnArgs.envOverride
    cwd
  }
  let ret ← proc.wait
  if ret != 0 then
    throw <| .userError s!"Child exited with {ret}"
