axiom helper {α : Sort u} : α

inductive IsEven : Nat → Prop where
  | zero : IsEven 0
  | add2 {n} : IsEven n → IsEven (n + 2)
  | bad : IsEven helper

theorem IsEven.four : IsEven 4 := add2 (add2 zero)
