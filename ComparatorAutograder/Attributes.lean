import Lean

open Lean Lean.Elab.Tactic

/- This is adapted from lean4-autograder-main -/
section «https://github.com/robertylewis/lean4-autograder-main/blob/6949f27443678fb588a3c3bd5029e05e46cf39d9/AutograderLib.lean#L6-L53»

declare_syntax_cat ptVal
syntax num : ptVal
syntax scientific : ptVal
syntax num "/" num : ptVal

syntax (name := autograded_proof) "autogradedProof" ptVal : attr
syntax (name := autograded_hole) "autogradedHole" : attr

initialize autogradedProofAttr : ParametricAttribute Rat ←
  registerParametricAttribute {
    name := `autograded_proof
    descr := "Specifies the point value of a problem"
    getParam := λ _ stx => match stx with
      | `(attr| autogradedProof $pts:num) => return pts.getNat
      | `(attr| autogradedProof $pts:scientific) =>
        let (n, s, d) := pts.getScientific
        return Rat.ofScientific n s d
      | `(attr| autogradedProof $num:num / $den:num) =>
        if hden : den.getNat = 0 then
          throwError "Invalid autograded proof attribute"
        else if hreduced : num.getNat.Coprime den.getNat then
          return Rat.mk' num.getNat den.getNat hden hreduced
        else
          throwError "Invalid autograded proof attribute"
      | _  => throwError "Invalid autograded proof attribute"
    afterSet := λ _ _ => do pure ()
  }

initialize autogradedHoleAttr : ParametricAttribute Unit ←
  registerParametricAttribute {
    name := `autograded_hole
    descr := "Specifies a definition to be a hole"
    getParam := λ _ stx => match stx with
      | `(attr| autogradedHole) => return ()
      | _  => throwError "Invalid attribute"
    afterSet := λ _ _ => do pure ()
  }

end «https://github.com/robertylewis/lean4-autograder-main/blob/6949f27443678fb588a3c3bd5029e05e46cf39d9/AutograderLib.lean#L6-L53»
