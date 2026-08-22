import ComparatorAutograderLib

@[autogradedHole]
inductive MyBool where

@[autogradedHole]
def MyBool.not (b : MyBool) : MyBool := sorry

@[autogradedProof 1]
theorem MyBool.not_not {b : MyBool} : b.not.not = b := sorry
