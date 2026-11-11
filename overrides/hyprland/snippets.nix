{ lib, ... }: let
    mkOutput = monitor:
        if monitor.edid != null then
            "desc:" + lib.concatStringsSep " " (builtins.filter (part: part != null) [ monitor.edid.make monitor.edid.model monitor.edid.serial ])
        else
            monitor.id;
in {
    mkMonitor = monitor:
        if !monitor.enabled then
            ''hl.monitor({ output = ${builtins.toJSON (mkOutput monitor)}, disabled = true })''
        else let
            mode = if monitor.resolution == null then "highrr" else "${toString monitor.resolution.x}x${toString monitor.resolution.y}";
            refreshrate = lib.optionalString (monitor.refreshrate != null) "@${builtins.toJSON monitor.refreshrate}";
            position = if monitor.position == null then "auto" else "${toString monitor.position.x}x${toString monitor.position.y}";
        in ''hl.monitor({ output = ${builtins.toJSON (mkOutput monitor)}, mode = "${mode}${refreshrate}", position = "${position}", scale = ${toString monitor.scale} })'';
    mkWorkspaces = monitor: lib.mapAttrsToList (workspace: _:
        ''hl.workspace_rule({ workspace = ${builtins.toJSON workspace}, monitor = ${builtins.toJSON (mkOutput monitor)} })''
    ) monitor.workspaces;
}
