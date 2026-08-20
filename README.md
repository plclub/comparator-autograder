# ComparatorAutograder

This project aims to be a minimal homework autograding solution for Lean 4 built on top of [comparator][comparator].

[comparator]: <https://github.com/leanprover/comparator>

Based on [lean4-autograder-main][lean4-autograder-main] which is licensed under the Apache 2.0 license.
Some code has also been adapted from [comparator][comparator].

[lean4-autograder-main]: <https://github.com/robertylewis/lean4-autograder-main>

## Options

All options are read through environment variables.

| Name | Description | Example | Default |
|---|---|---|---|
| `AUTOGRADER_CHALLENGE` | The module to use as the challenge for comparator | `Challenge.Child` | `Challenge` |
| `AUTOGRADER_SOLUTION` | The module to use as the solution for comparator | `Solution.Child` | `Solution` |
| `AUTOGRADER_SKIP_IMPORTS` | Whether to skip autograding `AUTOGRADER_CHALLENGE`'s imports | `false` | `true` |
| `AUTOGRADER_EXPORT_PATH` | Where to write the report. | `output.json` | `/proc/self/fd/1` |
| `AUTOGRADER_EXPORT_FORMAT` | Report format. One of: `human`, `json`. | `json` | `human` |

## Exit code

Exit code 0 doesn't mean all the tests passed, the report contains that information.

## Attributes

Attributse are defined in [comparator-autograder-lib](https://codeberg.org/xhalo32/comparator-autograder-lib):

- `@[autogradedProof <points>]` where `<points>` is a number (supports scientific notation) or a reduced fraction. Tells the autograder to grade the theorem.
- `@[autogradedHole]`: tells comparator that a definition is a [hole](https://github.com/leanprover/comparator/#definition-holes).

## Running the demo

```
cd Demo
lake build lean4export Challenge Solution
COMPARATOR_LANDRUN=.lake/packages/comparator/scripts/fake-landrun.sh lake exe comparatorautograder
```