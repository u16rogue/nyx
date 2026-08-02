{ writeShellApplication, coreutils, findutils, ... }: writeShellApplication {
    name = "mkignore";
    runtimeInputs = [ coreutils findutils ];
    text = builtins.readFile ./mkignore;
}
