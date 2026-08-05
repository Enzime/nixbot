{
  buildPythonPackage,
  git,
  hatchling,
  nix,
  pytestCheckHook,
  pytest-asyncio,
  pytest-timeout,
  # Optional: the NixOS module reaches this file through nixbot.nix's
  # python.pkgs.callPackage, which cannot supply it. Only the pytest passthru
  # check needs the CLI.
  nixbot-cli ? null,
  # Same: the packages scope supplies itself; the module's copy needs no tests.
  nixbot-effects ? null,
  lib,
}:
buildPythonPackage {
  name = "nixbot-effects";
  pyproject = true;
  src = ./../nixbot_effects;
  build-system = [
    hatchling
  ];

  # Tests run in passthru.tests.pytest to keep the test closure
  # (nix, git, the CLI) out of the package build.
  doCheck = false;

  passthru.tests = lib.optionalAttrs (nixbot-effects != null) {
    pytest = nixbot-effects.overridePythonAttrs {
      name = "nixbot-effects-tests";
      doCheck = true;

      nativeCheckInputs = [
        git
        nix
        pytestCheckHook
        pytest-asyncio
        pytest-timeout
      ]
      # The e2e test (test_e2e_flake_ref.py) runs the CLI.
      ++ lib.optional (nixbot-cli != null) nixbot-cli;

      preCheck = ''
        export HOME=$(mktemp -d)
        # Daemon-less scratch nix store for the eval/e2e tests; the real
        # /nix/store is read-only inside the build sandbox.
        export NIX_STORE_DIR=$TMPDIR/nix/store
        export NIX_STATE_DIR=$TMPDIR/nix/var
        # Compiled in separately from NIX_STATE_DIR.
        export NIX_LOG_DIR=$TMPDIR/nix/var/log/nix
        export NIX_CONF_DIR=$TMPDIR/nix/etc
      '';
    };
  };
}
