inputs:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  package = inputs.self.packages.${system}.default;
  configDir =
    "${config.programs.firefox.configPath}/"
    + (lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "Profiles/");

  cfg = config.textfox;
in
{

  imports = [
    ./options.nix
    (lib.mkChangedOptionModule [ "textfox" "profile" ] [ "textfox" "profiles" ] (
      config:
      let
        profile = lib.getAttrFromPath [ "textfox" "profile" ] config;

      in
      [ profile ]
    ))
  ];

  options.textfox = {
    profiles = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "List of Firefox profiles to apply the textfox configuration to";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      profiles = lib.mkMerge (
        map (profile: {
          "${profile}" = {
            extraConfig = builtins.readFile "${package}/user.js";
            containersForce = true;
          };
        }) cfg.profiles
      );
    };

    home.activation = let
      configCss = pkgs.writeText "config.css" cfg.configCss;
    in
      lib.listToAttrs (
        map (
          profile: {
            name = "copyTextfox${profile}";
            value =
              lib.hm.dag.entryAfter
              ["linkGeneration"]
              ''
                cd "${package}"
                SRC_FILES=$(find . -type f | grep ./chrome)
                PROFILE_DIR="${configDir}${profile}"
                cd "$HOME/$PROFILE_DIR"
                for file in $SRC_FILES; do
                  dirname=$(dirname "$file")
                  if [ ! -d "$dirname" ]; then
                    mkdir -p "$dirname"
                  fi
                  cp -L "${package}/$file" "$HOME/$PROFILE_DIR/$file"
                  chmod 744 "$HOME/$PROFILE_DIR/$file"
                done
                cp -L ${configCss} "$HOME/$PROFILE_DIR/chrome/config.css"
                chmod 744 "$HOME/$PROFILE_DIR/chrome/config.css"
              '';
          }
        )
        cfg.profiles
      );
  };
}
