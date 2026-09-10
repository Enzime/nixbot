{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.nixbot;
in
{
  options.services.nixbot.niks3 = {
    enable = lib.mkEnableOption "Enable niks3 integration";

    serverUrl = lib.mkOption {
      type = lib.types.str;
      description = "niks3 server URL";
      example = "https://niks3.yourdomain.com";
    };

    authTokenFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the niks3 API authentication token.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      description = "The niks3 package to use. You must add the niks3 flake input and overlay to make this package available.";
    };

    parallelPushes = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 2;
      description = ''
        Pushes `niks3 push --stdin` runs at once (its `--parallel-pushes`);
        null keeps niks3's default. Each push uploads up to
        {option}`maxConcurrentUploads` NARs, so the product bounds the
        request rate and concurrency the bucket sees. Lower both when the
        object store throttles the account.
      '';
    };

    maxConcurrentUploads = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 8;
      description = ''
        Concurrent NAR uploads per push (`--max-concurrent-uploads`); null
        keeps niks3's default.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--batch-size" "20" ];
      description = "Additional arguments appended to `niks3 push --stdin`.";
    };
  };

  config = lib.mkIf cfg.niks3.enable {
    systemd.services.nixbot.serviceConfig.LoadCredential = [
      "niks3-auth-token:${builtins.toString cfg.niks3.authTokenFile}"
    ];

    systemd.services.nixbot.path = [ cfg.niks3.package ];

    services.nixbot.uploaders = [
      {
        name = "niks3";
        environment = {
          NIKS3_SERVER_URL = cfg.niks3.serverUrl;
          # Token via file, never on the command line: /proc/<pid>/cmdline
          # is world-readable.
          NIKS3_AUTH_TOKEN_FILE = "/run/credentials/nixbot.service/niks3-auth-token";
        };
        # One long-running `niks3 push --stdin` (niks3 >= 1.11): each
        # attribute waits only for its own paths, not a shared batch.
        pathsVia = "stream";
        command = [
          "niks3"
          "push"
          "--stdin"
        ]
        ++ lib.optionals (cfg.niks3.parallelPushes != null) [
          "--parallel-pushes"
          (toString cfg.niks3.parallelPushes)
        ]
        ++ lib.optionals (cfg.niks3.maxConcurrentUploads != null) [
          "--max-concurrent-uploads"
          (toString cfg.niks3.maxConcurrentUploads)
        ]
        ++ cfg.niks3.extraArgs;
      }
    ];
  };
}
