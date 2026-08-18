import Lean

namespace ComparatorAutograder

open Lean

inductive FailureReason
  | constNotFoundInChallenge (target : Name) -- TODO this is practically a bug
  | constNotFoundInSolution (target : Name)
  | wrongKind (target : Name)
  | constDoesNotMatch (target : Name)
  | holeDoesNotMatch (target : Name)
  | illegalAxiom (target : Name) (axiomName : Name)
  | bug (msg : String)
  deriving Repr

def FailureReason.toString (self : FailureReason) := match self with
  | constNotFoundInChallenge (target : Name) => s!"Constant not found in challenge '{target}'"
  | constNotFoundInSolution (target : Name) => s!"Constant not found in solution '{target}'"
  | wrongKind (target : Name) => s!"Challenge and solution constant kinds don't match: '{target}'"
  | constDoesNotMatch (target : Name) => s!"Const does not match between challenge and target '{target}'"
  | holeDoesNotMatch (target : Name) => s!"Const (definition hole) does not match between challenge and target '{target}'"
  | illegalAxiom (target : Name) (axiomName : Name) => s!"Illegal axiom detected: '{axiomName}' used in '{target}'"
  | bug (msg : String) => s!"Unexpected error: {msg}"

instance : ToString FailureReason where
  toString := FailureReason.toString
