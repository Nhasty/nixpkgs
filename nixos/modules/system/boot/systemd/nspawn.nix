{ config, lib, pkgs, utils, ...}:

with utils.systemdUtils.unitOptions;
with utils.systemdUtils.lib;
with lib;

let
  cfg = config.systemd.nspawn;

  checkExec = checkUnitConfig "Exec" [
    (assertOnlyFields [
      "Boot" "ProcessTwo" "Parameters" "Environment" "User" "WorkingDirectory"
      "PivotRoot" "Capability" "DropCapability" "NoNewPrivileges" "KillSignal"
      "Personality" "MachineId" "PrivateUsers" "NotifyReady" "SystemCallFilter"
      "LimitCPU" "LimitFSIZE" "LimitDATA" "LimitSTACK" "LimitCORE" "LimitRSS"
      "LimitNOFILE" "LimitAS" "LimitNPROC" "LimitMEMLOCK" "LimitLOCKS"
      "LimitSIGPENDING" "LimitMSGQUEUE" "LimitNICE" "LimitRTPRIO" "LimitRTTIME"
      "OOMScoreAdjust" "CPUAffinity" "Hostname" "ResolvConf" "Timezone"
      "LinkJournal" "Ephemeral"
    ])
    (assertValueOneOf "Boot" boolValues)
    (assertValueOneOf "ProcessTwo" boolValues)
    (assertValueOneOf "NotifyReady" boolValues)
  ];

  checkFiles = checkUnitConfig "Files" [
    (assertOnlyFields [
      "ReadOnly" "Volatile" "Bind" "BindReadOnly" "TemporaryFileSystem"
      "Overlay" "OverlayReadOnly" "PrivateUsersChown" "BindUser"
      "Inaccessible" "PrivateUsersOwnership"
    ])
    (assertValueOneOf "ReadOnly" boolValues)
    (assertValueOneOf "Volatile" (boolValues ++ [ "state" ]))
    (assertValueOneOf "PrivateUsersChown" boolValues)
    (assertValueOneOf "PrivateUsersOwnership" [ "off" "chown" "map" "auto" ])
  ];

  checkNetwork = checkUnitConfig "Network" [
    (assertOnlyFields [
      "Private" "VirtualEthernet" "VirtualEthernetExtra" "Interface" "MACVLAN"
      "IPVLAN" "Bridge" "Zone" "Port"
    ])
    (assertValueOneOf "Private" boolValues)
    (assertValueOneOf "VirtualEthernet" boolValues)
  ];

  instanceOptions = {
    options =
    (getAttrs [ "enable" ] sharedOptions)
    // {
      execConfig = mkOption {
        default = {};
        example = { Parameters = "/bin/sh"; };
        type = types.addCheck (types.attrsOf unitOption) checkExec;
        description = lib.mdDoc ''
          Each attribute in this set specifies an option in the
          `[Exec]` section of this unit. See
          {manpage}`systemd.nspawn(5)` for details.
        '';
      };

      filesConfig = mkOption {
        default = {};
        example = { Bind = [ "/home/alice" ]; };
        type = types.addCheck (types.attrsOf unitOption) checkFiles;
        description = lib.mdDoc ''
          Each attribute in this set specifies an option in the
          `[Files]` section of this unit. See
          {manpage}`systemd.nspawn(5)` for details.
        '';
      };

      networkConfig = mkOption {
        default = {};
        example = { Private = false; };
        type = types.addCheck (types.attrsOf unitOption) checkNetwork;
        description = lib.mdDoc ''
          Each attribute in this set specifies an option in the
          `[Network]` section of this unit. See
          {manpage}`systemd.nspawn(5)` for details.
        '';
      };

      extraDrvConfig = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = ''
          Extra config for an nspawn-unit that is generated via `nix-build`.
          This is necessary since nspawn doesn't support overrides in
          <literal>/etc/systemd/nspawn</literal> natively and sometimes a derivation
          is needed for configs (e.g. to determine all needed store-paths to bind-mount
          into a machine).
        '';
      };
    };

  };

  makeUnit' = name: def:
    if def.extraDrvConfig == null || !def.enable then makeUnit name def
    else pkgs.runCommand "nspawn-${mkPathSafeName name}-custom"
      { preferLocalBuild = true;
        allowSubstitutes = false;
      } (let
        name' = shellEscape name;
      in ''
        if [ ! -f "${def.extraDrvConfig}" ]; then
          echo "systemd.nspawn.${name}.extraDrvConfig is not a file!"
          exit 1
        fi

        mkdir -p $out
        cat ${makeUnit name def}/${name'} > $out/${name'}
        cat ${def.extraDrvConfig} >> $out/${name'}
      '');

  instanceToUnit = name: def:
    let base = {
      text = ''
        [Exec]
        ${attrsToSection def.execConfig}

        [Files]
        ${attrsToSection def.filesConfig}

        [Network]
        ${attrsToSection def.networkConfig}
      '';
    } // def;
    in base // { unit = makeUnit' name base; };

in {

  options = {

    systemd.nspawn = mkOption {
      default = {};
      type = with types; attrsOf (submodule instanceOptions);
      description = lib.mdDoc "Definition of systemd-nspawn configurations.";
    };

  };

  config =
    let
      units = mapAttrs' (n: v: let nspawnFile = "${n}.nspawn"; in nameValuePair nspawnFile (instanceToUnit nspawnFile v)) cfg;
    in
      mkMerge [
        (mkIf (cfg != {}) {
          environment.etc."systemd/nspawn".source = mkIf (cfg != {}) (generateUnits {
            allowCollisions = false;
            type = "nspawn";
            inherit units;
            upstreamUnits = [];
            upstreamWants = [];
          });
        })
        {
          systemd.targets.multi-user.wants = [ "machines.target" ];

          # Workaround for https://github.com/NixOS/nixpkgs/pull/67232#issuecomment-531315437 and https://github.com/systemd/systemd/issues/13622
          # Once systemd fixes this upstream, we can re-enable -U
          systemd.services."systemd-nspawn@".serviceConfig.ExecStart = [
            ""  # deliberately empty. signals systemd to override the ExecStart
            # Only difference between upstream is that we do not pass the -U flag
            "${config.systemd.package}/bin/systemd-nspawn --quiet --keep-unit --boot --network-veth --settings=override --machine=%i"
          ];
        }
      ];
}
