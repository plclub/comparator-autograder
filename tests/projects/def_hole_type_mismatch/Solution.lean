-- Solution's hole has a different type; should be rejected because `foo : @Eq Int n n` here, but `foo : @Eq Nat n n` in the challenge.
def n : Int := 17

theorem foo : n = n := @Eq.refl Int n
