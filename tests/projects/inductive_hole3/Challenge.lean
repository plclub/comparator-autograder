import ComparatorAutograderLib

-- This inductive is missing a constructor needed to prove `IsEven.four`
@[autogradedHole]
inductive IsEven : Nat → Prop where
  | zero : IsEven 0

example : IsEven 0 := IsEven.zero

@[autogradedProof 1]
theorem IsEven.four : IsEven 4 := sorry
