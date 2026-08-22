inductive MyBool where
  | t (n : Nat) (b : MyBool)
  | f (n : Nat) (b : MyBool)

def MyBool.not (b : MyBool) : MyBool := match b with
  | t n b => f n b
  | f n b => t n b

theorem MyBool.not_t {n b} : (t n b).not = f n b := rfl
theorem MyBool.not_f {n b} : (f n b).not = t n b := rfl

theorem MyBool.not_not {b : MyBool} : b.not.not = b := by
  cases b with
  | t => rw [not_t, not_f]
  | f => rw [not_f, not_t]
