import Solution.Parent

def append (xs ys : List Nat) : List Nat := List.append xs ys

theorem append_test1 : append [1] [2] = [1, 2] := by rfl

theorem X_lt_6 : X ≤ 6 := by simp [X]
