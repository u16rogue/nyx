{ lib, ... }: {
    mkMonitor = monitor:
        if !monitor.enabled then
            ''hl.monitor({ output = ${builtins.toJSON monitor.id}, disabled = true })''
        else let
            mode = if monitor.resolution == null then "highrr" else "${toString monitor.resolution.x}x${toString monitor.resolution.y}";
            refreshrate = lib.optionalString (monitor.refreshrate != null) "@${toString monitor.refreshrate}";
            position = if monitor.position == null then "auto" else "${toString monitor.position.x}x${toString monitor.position.y}";
        in ''hl.monitor({ output = ${builtins.toJSON monitor.id}, mode = "${mode}${refreshrate}", position = "${position}", scale = ${toString monitor.scale} })'';
}
