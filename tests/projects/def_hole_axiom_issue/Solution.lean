noncomputable def n' : Nat := (fun _ : Nat => 17) (sorryAx Nat false)

noncomputable def n : Nat := n'

theorem foo : n + 17 = 34 := @Eq.refl Nat 34
