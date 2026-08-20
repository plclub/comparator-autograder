-- Solution tries to satisfy the hole with an axiom rather than a def.
-- Should be rejected because the kind does not match.
axiom n : Nat

theorem foo : n = n := @Eq.refl Nat n
