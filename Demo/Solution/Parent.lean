def X := 3 -- was 5

def nand (b1 b2 : Bool) : Bool := b1.not.or b2.not

theorem nand_test1 : nand true true = false := by rfl
