using GLib;

public class WMDetector : Object {
    public enum WaylandWM {
        LABWC,
        SWAY,
        WAYFIRE,
        RIVER,
        HYPRLAND,
        UNKNOWN
    }

    public static WaylandWM detect () {
        string? desktop = Environment.get_variable ("XDG_CURRENT_DESKTOP");
        if (desktop != null) {
            string lower = desktop.down ();
            if (lower.contains ("labwc")) return WaylandWM.LABWC;
            if (lower.contains ("sway")) return WaylandWM.SWAY;
            if (lower.contains ("wayfire")) return WaylandWM.WAYFIRE;
            if (lower.contains ("river")) return WaylandWM.RIVER;
            if (lower.contains ("hyprland")) return WaylandWM.HYPRLAND;
        }

        string? session = Environment.get_variable ("DESKTOP_SESSION");
        if (session != null) {
            string lower = session.down ();
            if (lower.contains ("labwc")) return WaylandWM.LABWC;
            if (lower.contains ("sway")) return WaylandWM.SWAY;
            if (lower.contains ("wayfire")) return WaylandWM.WAYFIRE;
            if (lower.contains ("river")) return WaylandWM.RIVER;
            if (lower.contains ("hyprland")) return WaylandWM.HYPRLAND;
        }

        return WaylandWM.UNKNOWN;
    }

    public static string get_name (WaylandWM wm) {
        switch (wm) {
        case WaylandWM.LABWC: return "labwc";
        case WaylandWM.SWAY: return "sway";
        case WaylandWM.WAYFIRE: return "wayfire";
        case WaylandWM.RIVER: return "river";
        case WaylandWM.HYPRLAND: return "hyprland";
        default: return "unknown";
        }
    }

    public static string get_config_path (WaylandWM wm) {
        string home = Environment.get_home_dir ();
        switch (wm) {
        case WaylandWM.LABWC:
            return Path.build_filename (home, ".config", "labwc", "autostart");
        case WaylandWM.SWAY:
            return Path.build_filename (home, ".config", "sway", "config");
        case WaylandWM.WAYFIRE:
            return Path.build_filename (home, ".config", "wayfire.ini");
        case WaylandWM.RIVER:
            return Path.build_filename (home, ".config", "river", "init");
        case WaylandWM.HYPRLAND:
            return Path.build_filename (home, ".config", "hypr", "hyprland.conf");
        default:
            return "";
        }
    }

    public static bool config_exists (WaylandWM wm) {
        string path = get_config_path (wm);
        return path != "" && FileUtils.test (path, FileTest.EXISTS);
    }
}
