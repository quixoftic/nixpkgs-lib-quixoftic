self: super:

let

  ## Functions for cleaning local source directories. These are useful
  ## for filtering out files in your local repo that should not
  ## contribute to a Nix hash, so that you can just `src = ./.` in
  ## your derivation, and then filter that attribute after the fact.
  ##
  ## Note that these functions are composable, e.g., cleanSourceNix
  ## (cleanCabalStack ...) is a valid expression. They will also
  ## compose with any `lib.cleanSourceWith` function (but *not* with
  ## `builtins.filterSource`; see the `lib.cleanSourceWith`
  ## documentation).


  # In most cases, I believe that filtering Nix files from the source
  # hash is the right thing to do. They're obviously already evaluated
  # when a nix-build command is executed, so if *what they evaluate*
  # changes they'll cause a rebuild anyway, as they should; while
  # cosmetic changes (comments, formatting, etc.) won't.
  cleanSourceFilterNix = name: type: let baseName = baseNameOf (toString name); in ! (
    type != "directory" && (
      super.lib.hasSuffix ".nix" baseName
    )
  );
  cleanSourceNix = src: super.lib.cleanSourceWith { filter = cleanSourceFilterNix; inherit src; };


  # Clean Haskell projects.
  cleanSourceFilterHaskell = name: type: let baseName = baseNameOf (toString name); in ! (
    type == "directory" && (
      baseName == ".cabal-sandbox" ||
      baseName == ".stack-work"    ||
      baseName == "dist"           ||
      baseName == "dist-newstyle"
    ) ||
    type != "directory" && (
      baseName == ".ghci"                 ||
      baseName == ".stylish-haskell.yaml" ||
      baseName == "cabal.sandbox.config"  ||
      baseName == "cabal.project"         ||
      baseName == "sources.txt"
    )
  );
  cleanSourceHaskell = src: super.lib.cleanSourceWith { filter = cleanSourceFilterHaskell; inherit src; };


  # Clean system cruft, e.g., .DS_Store files on macOS filesystems.
  cleanSourceFilterSystemCruft = name: type: let baseName = baseNameOf (toString name); in ! (
    type != "directory" && (
      baseName == ".DS_Store"
    )
  );
  cleanSourceSystemCruft = src: super.lib.cleanSourceWith { filter = cleanSourceFilterSystemCruft; inherit src; };


  # Clean files related to editors and IDEs.
  cleanSourceFilterEditors = name: type: let baseName = baseNameOf (toString name); in ! (
    type != "directory" && (
      baseName == ".dir-locals.el"                         ||
      baseName == ".netrwhist"                             ||
      baseName == ".projectile"                            ||
      baseName == ".tags"                                  ||
      baseName == ".vim.custom"                            ||
      baseName == ".vscodeignore"                          ||
      builtins.match "^#.*#$" baseName != null             ||
      builtins.match "^\\.#.*$" baseName != null           ||
      builtins.match "^.*_flymake\\..*$" baseName != null  ||
      builtins.match "^flycheck_.*\\.el$" baseName != null
    )
  );
  cleanSourceEditors = src: super.lib.cleanSourceWith { filter = cleanSourceFilterEditors; inherit src; };


  # Clean maintainer files that don't affect Nix builds.
  cleanSourceFilterMaintainer = name: type: let baseName = baseNameOf (toString name); in ! (
    type != "directory" && (
      # Note: .git can be a file when it's in a submodule directory
      baseName == ".git"           ||
      baseName == ".gitattributes" ||
      baseName == ".gitignore"     ||
      baseName == ".gitmodules"    ||
      baseName == ".npmignore"     ||
      baseName == ".travis.yml"
    )
  );
  cleanSourceMaintainer = src: super.lib.cleanSourceWith { filter = cleanSourceFilterMaintainer; inherit src; };


  # A cleaner that combines all of the cleaners defined here, plus
  # `lib.cleanSource` from Nixpkgs.
  cleanSourceAllExtraneous = src:
    cleanSourceMaintainer
      (cleanSourceEditors
        (cleanSourceSystemCruft
          (cleanSourceHaskell
            (cleanSourceNix
              (super.lib.cleanSource src)))));


  # Clean the `src` attribute of a package. This is convenient when
  # you use tools like `cabal2nix` to generate Nix files for local
  # source repos, as these tools generally lack the ability to
  # apply the various `clean*Source` functions to the `src`
  # attribute that they generate. Instead, you can apply this
  # function, plus one or more source cleaners, to a package that
  # is the result of a `callPackage` function application.
  cleanPackage = cleanSrc: pkg: (pkg.overrideAttrs (oldAttrs: {
    src = cleanSrc oldAttrs.src;
  }));


  ## Convenience functions for tests, esp. for Hydras.

  # Aggregates are handy for defining jobs (especially for subsets of
  # platforms), but they don't provide very useful information in
  # Hydra, especially when they die. We use aggregates here to define
  # set of jobs, and then splat them into the output attrset so that
  # they're more visible in Hydra.

  enumerateConstituents = aggregate: super.lib.listToAttrs (
    map (d:
           let
             name = (builtins.parseDrvName d.name).name;
             system = d.system;
           in
             { name = name + "." + system;
               value = d;
             }
         )
        aggregate.constituents
  );

in
{
  lib = (super.lib or {}) // {

    # Filters.
    inherit cleanSourceFilterNix;
    inherit cleanSourceFilterHaskell;
    inherit cleanSourceFilterSystemCruft;
    inherit cleanSourceFilterEditors;
    inherit cleanSourceFilterMaintainer;

    # cleanSource's.
    inherit cleanSourceNix;
    inherit cleanSourceHaskell;
    inherit cleanSourceSystemCruft;
    inherit cleanSourceEditors;
    inherit cleanSourceMaintainer;
    inherit cleanSourceAllExtraneous;

    inherit cleanPackage;

    testing = (super.lib.testing or {}) // {
      inherit enumerateConstituents;
    };

  };
}
