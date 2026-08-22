import Lean

section «https://github.com/leanprover/comparator/blob/575674928e239f5bc452aab72d1dd7b0f1326494/runtests.lean»

/-!
# Comparator Autograder Test Runner

Runs integration tests for the comparator-autograder from `tests/projects/`.
Each test project is a directory containing:
- `Challenge.lean` / `Solution.lean`: the Lean source files
- `expected.json`: the expected json report
- (optional) `lakefile.toml`: custom lake configuration; a default is generated if absent

## Usage

```bash
# Run all tests
lean --run runtests.lean

# Run only tests whose name contains "simple" or "def_hole"
lean --run runtests.lean simple def_hole
```
-/

open Lean System.FilePath IO.FS IO.Process System

structure TestConfig where
  exit_code : Nat
  deriving FromJson, ToJson

inductive TestResult
  | success (projectName : String)
  | failure (projectName : String) (exit : Nat) (expected actual : String)
  | error (projectName : String) (message : String)

def copyFile (src : FilePath) (dst : FilePath) : IO Unit := do
  let contents ← IO.FS.readBinFile src
  IO.FS.writeBinFile dst contents

partial def copyDirContents (src : FilePath) (dst : FilePath) : IO Unit := do
  let entries ← System.FilePath.readDir src
  for entry in entries do
    let srcPath := entry.path
    let relativeName := entry.fileName
    let dstPath := dst / relativeName

    if (← srcPath.isDir) then
      IO.FS.createDirAll dstPath
      copyDirContents srcPath dstPath
    else
      copyFile srcPath dstPath

-- NOTE: This does not take overrides into account
def createAdditionalFiles (rootPath : FilePath) (dir : FilePath) : IO Unit := do
  let lakefileContent :=
r#"name = "comparatortest"
version = "0.1.0"

[[lean_lib]]
name = "Solution"

[[lean_lib]]
name = "Challenge"

[[require]]
name = "comparator-autograder-lib"
git = "https://codeberg.org/xhalo32/comparator-autograder-lib.git"
rev = "40472499fc6f75c6ed58c46e8e7e9e3a00930a13"
"#
  IO.FS.writeFile (dir / "lakefile.toml") lakefileContent
  let overrides := Json.mkObj [
    ⟨"packages", .arr #[Json.mkObj [
      ⟨"dir", .str (rootPath / ".lake/packages/comparator-autograder-lib").toString⟩,
      ⟨"name", .str "«comparator-autograder-lib»"⟩,
      ⟨"inherited", .bool false⟩,
      ⟨"type", .str "path"⟩,
    ]]⟩,
    ⟨"schemaVersion", .str "1.2.0"⟩
  ]
  IO.FS.createDir (dir / ".lake")
  IO.FS.writeFile (dir / ".lake" / "package-overrides.json") overrides.compress
  let manifest :=
r#"
{"version": "1.2.0",
 "packagesDir": ".lake/packages",
 "packages": [],
 "name": "comparatortest",
 "lakeDir": ".lake"
}"#
  IO.FS.writeFile (dir / "lake-manifest.json") manifest

def runCommandInDir (dir : FilePath) (cmd : String) (args : Array String) (env : Array (String × Option String) := #[]) : IO Nat := do
  let output ← IO.Process.spawn {
    cmd := cmd
    args := args
    cwd := some dir
    env
  }
  let exitCode ← output.wait
  pure exitCode.toNat

def getTempDir : IO FilePath := do
  return "/tmp" / s!"lean_test_{← IO.rand 0 999999}"

def runTestProject (rootPath : FilePath) (projectPath : FilePath) (projectName : String) (comparatorPath : FilePath) : IO TestResult := do
  try
    let tempDir ← getTempDir
    IO.FS.createDirAll tempDir

    copyDirContents projectPath tempDir

    copyFile "lean-toolchain" (tempDir / "lean-toolchain")

    createAdditionalFiles rootPath tempDir

    let _ ← runCommandInDir tempDir "lake" #["build", "Challenge", "Solution"]
    let exitCode ← runCommandInDir tempDir "lake"
      #["env", comparatorPath.toString]
      #[⟨"AUTOGRADER_EXPORT_PATH", "actual.json"⟩, ⟨"AUTOGRADER_EXPORT_FORMAT", "json"⟩]
    let expected ← IO.FS.readFile <| tempDir / "expected.json"
    let actual ← IO.FS.readFile <| tempDir / "actual.json"

    IO.FS.removeDirAll tempDir

    if exitCode == 0 ∧ expected = actual then
      return TestResult.success projectName
    else
      return TestResult.failure projectName exitCode expected actual

  catch e =>
    try
      let tempDir ← getTempDir
      if (← tempDir.pathExists) then
        IO.FS.removeDirAll tempDir
    catch _ =>
      pure ()
    return TestResult.error projectName e.toString

def findProjects (testsDir : FilePath) : IO (Array FilePath) := do
  let projectsDir := testsDir / "projects"
  if !(← projectsDir.pathExists) then
    throw <| IO.userError s!"Projects directory not found: {projectsDir}"

  let entries ← System.FilePath.readDir projectsDir
  let mut projects := #[]
  for entry in entries do
    if (← entry.path.isDir) then
      projects := projects.push entry.path
  pure projects

def printTestResult (result : TestResult) : IO Unit := do
  match result with
  | .success name =>
    IO.println s!"✓ {name}: PASSED"
  | .failure name exit expected actual =>
    IO.println s!"✗ {name}: FAILED (exit code {exit})\n  expected: {expected}\n  got:      {actual}"
  | .error name msg =>
    IO.println s!"✗ {name}: ERROR - {msg}"

/-- Run comparator integration tests. When `args` is non-empty, only tests whose
project name contains one of the given strings (as a substring) are executed. -/
def main (args : List String) : IO UInt32 := do
  let testsDir : FilePath := "tests"
  let filters := args

  IO.println "# Running tests\n"

  let allProjects ← findProjects testsDir

  let projects := if filters.isEmpty then
    allProjects
  else
    allProjects.filter fun p => filters.any (p.fileName.get!.contains ·)

  if projects.isEmpty then
    if filters.isEmpty then
      IO.println "No projects found!"
    else
      IO.println s!"No projects matching {filters} found!"
    return 1

  let autograderPath ← IO.FS.realPath <| ".lake" / "build" / "bin" / "comparatorautograder"

  let mut allPassed := true
  let mut results := #[]
  for projectPath in projects do
    let projectName := projectPath.fileName.get!
    IO.println s!"\n## Running test: {projectName}\n"
    let result ← runTestProject (← getCurrentDir) projectPath projectName autograderPath
    results := results.push result
    match result with
    | .success _ => pure ()
    | _ => allPassed := false

  IO.println "\n# Summary\n"

  for result in results do
    printTestResult result

  IO.println ""
  if allPassed then
    IO.println "All tests passed!"
    return 0
  else
    IO.println "Some tests failed."
    return 1

end «https://github.com/leanprover/comparator/blob/575674928e239f5bc452aab72d1dd7b0f1326494/runtests.lean»
