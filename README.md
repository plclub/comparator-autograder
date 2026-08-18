# ComparatorAutograder

Based on <https://github.com/robertylewis/lean4-autograder-main> which is licensed under the Apache 2.0 license.
Some code has also been adapted from <https://github.com/leanprover/comparator>.

Improvement ideas:
- Use comparator via its lean API rather than through the CLI
- Support leaving definition holes using comparator
- Support full project submission with comparator
- Avoid polluting .lake with temporary test files

## Running the demo

```
cd Demo
lake build lean4export Challenge Solution
COMPARATOR_LANDRUN=.lake/packages/comparator/scripts/fake-landrun.sh lake exe comparatorautograder
```