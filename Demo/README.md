# Demo

Remember to build `lean4export` at top-level with `lake build lean4export` (or `lake build lean4export comparatorautograder`).

## Results

```
AUTOGRADER_EXPORT_PATH=output.json AUTOGRADER_EXPORT_FORMAT=json AUTOGRADER_CHALLENGE=Challenge.Child AUTOGRADER_SOLUTION=Solution.Child COMPARATOR_LANDRUN=../.lake/packages/comparator/scripts/fake-landrun.sh COMPARATOR_LEAN4EXPORT=../.lake/packages/lean4export/.lake/build/bin/lean4export lake env ../.lake/build/bin/comparatorautograder
```

writes

```json
{
  "theoremReports": [
    {
      "error": null,
      "name": {
        "const": "append_test1",
        "mod": "Challenge.Child"
      },
      "points": {
        "den": 1,
        "num": 1
      }
    },
    {
      "error": {
        "constDoesNotMatch": {
          "target": "X"
        }
      },
      "name": {
        "const": "X_lt_6",
        "mod": "Challenge.Child"
      },
      "points": {
        "den": 1,
        "num": 1
      }
    }
  ]
}
```

---

```
AUTOGRADER_EXPORT_PATH=output.json AUTOGRADER_EXPORT_FORMAT=json AUTOGRADER_SKIP_IMPORTS=false AUTOGRADER_CHALLENGE=Challenge.Child AUTOGRADER_SOLUTION=Solution.Child COMPARATOR_LANDRUN=../.lake/packages/comparator/scripts/fake-landrun.sh COMPARATOR_LEAN4EXPORT=../.lake/packages/lean4export/.lake/build/bin/lean4export lake env ../.lake/build/bin/comparatorautograder
```

writes

```json
{
  "theoremReports": [
    {
      "error": null,
      "name": {
        "const": "append_test1",
        "mod": "Challenge.Child"
      },
      "points": {
        "den": 1,
        "num": 1
      }
    },
    {
      "error": {
        "constDoesNotMatch": {
          "target": "X"
        }
      },
      "name": {
        "const": "X_lt_6",
        "mod": "Challenge.Child"
      },
      "points": {
        "den": 1,
        "num": 1
      }
    },
    {
      "error": null,
      "name": {
        "const": "nand_test1",
        "mod": "Challenge.Parent"
      },
      "points": {
        "den": 1,
        "num": 1
      }
    }
  ]
}
```
