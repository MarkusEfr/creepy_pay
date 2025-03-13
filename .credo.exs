%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/priv/"]
      },
      requires: [],
      checks: [
        # --- Design ---
        {Credo.Check.Design.TagTODO, []},
        {Credo.Check.Design.TagFIXME, []},
        {Credo.Check.Design.DuplicatedCode, []},

        # --- Readability ---
        # Disable if not using @moduledoc everywhere
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.FunctionNames, []},
        {Credo.Check.Readability.LargeNumbers, []},
        {Credo.Check.Readability.MaxLineLength, max_length: 120},

        # --- Refactoring ---
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 10},
        {Credo.Check.Refactor.FunctionArity, max_arity: 6},
        {Credo.Check.Refactor.Nesting, max_nesting: 3},

        # --- Consistency ---
        {Credo.Check.Consistency.TabsOrSpaces, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.ParameterPatternMatching, []},

        # --- Warnings & Code Smells ---
        {Credo.Check.Warning.IExPry, []},
        # optional: enable to warn about `IO.inspect/2`
        {Credo.Check.Warning.IoInspect, false},
        {Credo.Check.Warning.UnusedEnumOperation, []},
        {Credo.Check.Warning.UnusedKeywordOperation, []},
        {Credo.Check.Warning.UnusedListOperation, []},
        {Credo.Check.Warning.UnusedStringOperation, []},
        {Credo.Check.Warning.UnusedTupleOperation, []},

        # --- Optional but useful ---
        # allow short pipes like `|> Repo.all`
        {Credo.Check.Readability.SinglePipe, false},
        # enable if you want @spec required
        {Credo.Check.Readability.Specs, false},

        # --- Experimental (can be noisy) ---
        {Credo.Check.Refactor.Apply, false},
        {Credo.Check.Refactor.ABCSize, false}
      ]
    }
  ]
}
