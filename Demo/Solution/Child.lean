import Solution.Parent

def append (xs ys : List Nat) : List Nat := List.append xs ys

theorem append_test1 : append [1] [2] = [1, 2] := by rfl

theorem X_lt_6 : X ≤ 6 := by simp [X]

-- theorem append_test2 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test3 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test4 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test5 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test6 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test7 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test8 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test9 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test10 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test11 : append [1] [2] = [1, 2] := by rfl
-- theorem append_test12 : append [1] [2] = [1, 2] := by rfl
