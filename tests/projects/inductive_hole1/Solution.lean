inductive MyBool where
  | t
  | f

def MyBool.not (b : MyBool) : MyBool := match b with
  | t => f
  | f => t

theorem MyBool.not_t : t.not = f := rfl
theorem MyBool.not_f : f.not = t := rfl

theorem MyBool.not_not {b : MyBool} : b.not.not = b := by
  cases b with
  | t => rw [not_t, not_f]
  | f => rw [not_f, not_t]
