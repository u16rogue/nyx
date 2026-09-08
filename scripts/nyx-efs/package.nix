{ writeShellApplication, coreutils, util-linux, ... }: writeShellApplication {
    name = "nyx-efs";
    runtimeInputs = [ coreutils util-linux ];
    text = builtins.readFile ./nyx-efs;
}
