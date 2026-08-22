import Lean
import ComparatorAutograder.Basic

def Except.toErr (self : Except ε α) := match self with
  | .ok _ => none
  | .error e => some e

namespace ComparatorAutograder

local instance : Lean.ToJson Rat where
  toJson r := Lean.Json.mkObj [⟨"num", r.num⟩, ⟨"den", r.den⟩]

structure TheoremReport where
  name : ConstWithMod
  points : Rat
  error : Option FailureReason
  deriving Repr, Inhabited, Lean.ToJson

def TheoremReport.toString (self : TheoremReport) : String :=
  let base := s!"{self.name.mod}: {self.name.const} ({self.points} points):"
  match self.error with
  | none => s!"{base} passed"
  | .some e => s!"{base} failed: {e}"

instance : ToString TheoremReport where
  toString := TheoremReport.toString

structure Report where
  theoremReports : Array TheoremReport
  deriving Repr, Inhabited, Lean.ToJson

def Report.toString (self : Report) : String := Id.run do
  let mut out := ""
  for r in self.theoremReports do
    out := s!"{out}{r}\n"
  out

instance : ToString Report where
  toString := Report.toString

/-- `theoremNames` and `comparatorResult` must have the same "keys" in the same order -/
def compileReport (theoremNames : Array (ConstWithMod × Rat)) (comparatorResult : Array (Lean.Name × Except FailureReason Unit)) : Report := Id.run do
  assert! theoremNames.size = comparatorResult.size
  assert! List.Nodup (comparatorResult.toList.map Prod.fst)
  let theoremReports : Array TheoremReport := theoremNames.zipWith
    (fun ⟨n1, points⟩ ⟨n2, result⟩ => assert! n1.const == n2; { name := n1, points, error := result.toErr }) comparatorResult
  { theoremReports }
