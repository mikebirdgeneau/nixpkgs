{ lib
, nix-update-script
, rustPlatform
, fetchFromGitHub
, installShellFiles
, stdenv
, coreutils
, bash
, pkg-config
, openssl
, direnv
, Security
, SystemConfiguration
, mise
, testers
}:

rustPlatform.buildRustPackage rec {
  pname = "mise";
  version = "2024.2.15";

  src = fetchFromGitHub {
    owner = "jdx";
    repo = "mise";
    rev = "v${version}";
    hash = "sha256-vBlO4Xxv5XM5KEZmIplSSb/LgdG485hQkb7RSRrOIyM=";
  };

  cargoHash = "sha256-V+j0Z8voDzVdO2fHFw4boUvlFfCrOId7nkTZsZbCcfg=";

  nativeBuildInputs = [ installShellFiles pkg-config ];
  buildInputs = [ openssl ] ++ lib.optionals stdenv.isDarwin [ Security SystemConfiguration ];

  postPatch = ''
    patchShebangs --build \
      ./test/data/plugins/**/bin/* \
      ./src/fake_asdf.rs \
      ./src/cli/reshim.rs \
      ./test/cwd/.mise/tasks/filetask

    substituteInPlace ./src/env_diff.rs \
      --replace '"bash"' '"${bash}/bin/bash"'

    substituteInPlace ./src/cli/direnv/exec.rs \
      --replace '"env"' '"${coreutils}/bin/env"' \
      --replace 'cmd!("direnv"' 'cmd!("${direnv}/bin/direnv"'
  '';

  checkFlags = [
    # Requires .git directory to be present
    "--skip=cli::plugins::ls::tests::test_plugin_list_urls"
  ];
  cargoTestFlags = [ "--all-features" ];
  # some tests access the same folders, don't test in parallel to avoid race conditions
  dontUseCargoParallelTests = true;

  postInstall = ''
    installManPage ./man/man1/mise.1

    installShellCompletion \
      --bash ./completions/mise.bash \
      --fish ./completions/mise.fish \
      --zsh ./completions/_mise
  '';

  passthru = {
    updateScript = nix-update-script { };
    tests.version = testers.testVersion { package = mise; };
  };

  meta = {
    homepage = "https://mise.jdx.dev";
    description = "The front-end to your dev env";
    changelog = "https://github.com/jdx/mise/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ konradmalik ];
    mainProgram = "mise";
  };
}
