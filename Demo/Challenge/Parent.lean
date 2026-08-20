import ComparatorAutograderLib

def X := 5

@[autogradedHole]
def nand (b1 b2 : Bool) : Bool := (b1.and b2).not

@[autogradedProof 1]
theorem nand_test1 : nand true true = false := by rfl
