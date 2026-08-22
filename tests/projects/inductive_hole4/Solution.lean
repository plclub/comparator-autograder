/-! This solution demonstrates that existing constructors on the challenge don't need to be kept, which is the currently implemented logic. -/

inductive IsEven : Nat → Prop where
  | two : IsEven 2
  | add2 {n} : IsEven n → IsEven (n + 2)

theorem IsEven.four : IsEven 4 := add2 two
