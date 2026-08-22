inductive IsEven : Nat → Prop where
  | zero : IsEven 0
  | add2 {n} : IsEven n → IsEven (n + 2)

example : IsEven 0 := IsEven.zero

theorem IsEven.four : IsEven 4 := add2 (add2 zero)
