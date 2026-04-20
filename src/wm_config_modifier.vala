using GLib;

public class WMConfigModifier : Object {
    private const string LEGACY_BEGIN_MARKER = "# BEGIN labwc-kbd\n";
    private const string LEGACY_END_MARKER = "# END labwc-kbd\n";
    private const string CURRENT_BEGIN_MARKER = "# BEGIN wl-kbd-config\n";
    private const string CURRENT_END_MARKER = "# END wl-kbd-config\n";

    public class XKBConfig {
        public string layout { get; set; default = "us"; }
        public string variant { get; set; default = ""; }
        public string options { get; set; default = ""; }

        public string to_env_string () {
            var sb = new StringBuilder ();
            sb.append ("XKB_DEFAULT_LAYOUT=");
            sb.append (layout);
            if (variant != "") {
                sb.append (",");
                sb.append (variant);
            }
            if (options != "") {
                sb.append_c ('\n');
                sb.append ("XKB_DEFAULT_OPTIONS=");
                sb.append (options);
            }
            return sb.str;
        }
    }

    public static XKBConfig? read_from_wm (WMDetector.WaylandWM wm) throws Error {
        switch (wm) {
        case WMDetector.WaylandWM.LABWC:
            return read_labwc_config ();
        case WMDetector.WaylandWM.SWAY:
            return read_sway_config ();
        case WMDetector.WaylandWM.WAYFIRE:
            return read_wayfire_config ();
        case WMDetector.WaylandWM.RIVER:
            return read_river_config ();
        case WMDetector.WaylandWM.HYPRLAND:
            return read_hyprland_config ();
        default:
            return null;
        }
    }

    public static bool apply_to_wm (WMDetector.WaylandWM wm, XKBConfig config) throws Error {
        string config_path = WMDetector.get_config_path (wm);

        if (!FileUtils.test (config_path, FileTest.EXISTS)) {
            return false;
        }

        switch (wm) {
        case WMDetector.WaylandWM.LABWC:
            return apply_to_labwc (config);
        case WMDetector.WaylandWM.SWAY:
            return apply_to_sway (config);
        case WMDetector.WaylandWM.WAYFIRE:
            return apply_to_wayfire (config);
        case WMDetector.WaylandWM.RIVER:
            return apply_to_river (config);
        case WMDetector.WaylandWM.HYPRLAND:
            return apply_to_hyprland (config);
        default:
            return false;
        }
    }

    private static XKBConfig? read_labwc_config () {
        var config = new XKBConfig ();
        config.layout = Environment.get_variable ("XKB_DEFAULT_LAYOUT") ?? "us";
        config.variant = Environment.get_variable ("XKB_DEFAULT_VARIANT") ?? "";
        config.options = Environment.get_variable ("XKB_DEFAULT_OPTIONS") ?? "";
        return config;
    }

    private static XKBConfig? read_sway_config () {
        return read_xkb_from_config_file (
            Path.build_filename (Environment.get_home_dir (), ".config", "sway", "config")
        );
    }

    private static XKBConfig? read_wayfire_config () {
        return read_xkb_from_config_file (
            Path.build_filename (Environment.get_home_dir (), ".config", "wayfire.ini")
        );
    }

    private static XKBConfig? read_river_config () {
        var config = new XKBConfig ();
        string init_path = Path.build_filename (Environment.get_home_dir (), ".config", "river", "init");

        if (!FileUtils.test (init_path, FileTest.EXISTS)) {
            return null;
        }

        try {
            string content;
            FileUtils.get_contents (init_path, out content);
            string[] lines = content.split ("\n");

            foreach (var line in lines) {
                if (line.contains ("XKB_DEFAULT_LAYOUT")) {
                    string value = extract_env_value (line, "XKB_DEFAULT_LAYOUT");
                    if (value != "") {
                        config.layout = value;
                    }
                } else if (line.contains ("XKB_DEFAULT_OPTIONS")) {
                    string value = extract_env_value (line, "XKB_DEFAULT_OPTIONS");
                    if (value != "") {
                        config.options = value;
                    }
                }
            }
        } catch (Error e) {
            warning ("Failed to read river config: %s", e.message);
        }

        return config;
    }

    private static string extract_env_value (string line, string var_name) {
        int start = line.index_of (var_name);
        if (start < 0) return "";
        
        int eq_pos = line.index_of_char ('=', start);
        if (eq_pos < 0) return "";
        
        string rest = line.substring (eq_pos + 1).strip ();
        if (rest.has_prefix ("\"")) {
            int end = rest.last_index_of ("\"");
            if (end > 1) {
                return rest.substring (1, end - 1);
            }
        }
        if (rest.has_prefix ("'")) {
            int end = rest.last_index_of ("'");
            if (end > 1) {
                return rest.substring (1, end - 1);
            }
        }
        
        var parts = rest.split (" ");
        return parts[0];
    }

    private static XKBConfig? read_hyprland_config () {
        var config = new XKBConfig ();
        string conf_path = Path.build_filename (Environment.get_home_dir (), ".config", "hypr", "hyprland.conf");

        if (!FileUtils.test (conf_path, FileTest.EXISTS)) {
            return null;
        }

        try {
            string content;
            FileUtils.get_contents (conf_path, out content);
            string[] lines = content.split ("\n");

            foreach (var line in lines) {
                if (line.has_prefix ("env = XKB_DEFAULT_LAYOUT") || line.has_prefix ("env=XKB_DEFAULT_LAYOUT")) {
                    var parts = line.split (",");
                    if (parts.length >= 2) {
                        config.layout = parts[1].strip ();
                    }
                } else if (line.has_prefix ("env = XKB_DEFAULT_OPTIONS") || line.has_prefix ("env=XKB_DEFAULT_OPTIONS")) {
                    var parts = line.split (",");
                    if (parts.length >= 2) {
                        config.options = parts[1].strip ();
                    }
                }
            }
        } catch (Error e) {
            warning ("Failed to read hyprland config: %s", e.message);
        }

        return config;
    }

    private static XKBConfig? read_xkb_from_config_file (string path) {
        var config = new XKBConfig ();

        if (!FileUtils.test (path, FileTest.EXISTS)) {
            return null;
        }

        try {
            string content;
            FileUtils.get_contents (path, out content);
            string[] lines = content.split ("\n");

            foreach (var line in lines) {
                string trimmed = line.strip ();
                if (trimmed.has_prefix ("xkb_layout")) {
                    var parts = trimmed.split (" ");
                    if (parts.length >= 2) {
                        config.layout = parts[1];
                    }
                } else if (trimmed.has_prefix ("xkb_options")) {
                    var parts = trimmed.split (" ");
                    if (parts.length >= 2) {
                        config.options = parts[1];
                    }
                } else if (trimmed.has_prefix ("kb_layout")) {
                    var parts = trimmed.split ("=");
                    if (parts.length >= 2) {
                        config.layout = parts[1].strip ();
                    }
                } else if (trimmed.has_prefix ("kb_options")) {
                    var parts = trimmed.split ("=");
                    if (parts.length >= 2) {
                        config.options = parts[1].strip ();
                    }
                }
            }
        } catch (Error e) {
            warning ("Failed to read config: %s", e.message);
        }

        return config;
    }

    private static bool apply_to_labwc (XKBConfig config) throws Error {
        return apply_env_exports (
            Path.build_filename (Environment.get_home_dir (), ".config", "labwc", "autostart"),
            config
        );
    }

    private static bool apply_to_sway (XKBConfig config) throws Error {
        string config_path = Path.build_filename (Environment.get_home_dir (), ".config", "sway", "config");
        return apply_input_block (config_path, "input *", config);
    }

    private static bool apply_to_wayfire (XKBConfig config) throws Error {
        string config_path = Path.build_filename (Environment.get_home_dir (), ".config", "wayfire.ini");
        return apply_wayfire_section (config_path, config);
    }

    private static bool apply_to_river (XKBConfig config) throws Error {
        return apply_env_exports (
            Path.build_filename (Environment.get_home_dir (), ".config", "river", "init"),
            config
        );
    }

    private static bool apply_to_hyprland (XKBConfig config) throws Error {
        return apply_hyprland_env (
            Path.build_filename (Environment.get_home_dir (), ".config", "hypr", "hyprland.conf"),
            config
        );
    }

    private static bool apply_env_exports (string path, XKBConfig config) throws Error {
        string existing = "";
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.get_contents (path, out existing);
        }
        // Remove previous managed blocks if present (legacy + current markers).
        string[] begin_markers = { LEGACY_BEGIN_MARKER, CURRENT_BEGIN_MARKER };
        string[] end_markers = { LEGACY_END_MARKER, CURRENT_END_MARKER };
        for (int i = 0; i < begin_markers.length; i++) {
            while (true) {
                int begin_pos = existing.index_of (begin_markers[i]);
                int end_pos = existing.index_of (end_markers[i]);
                if (begin_pos < 0 || end_pos <= begin_pos) {
                    break;
                }
                existing = existing[0:begin_pos]
                         + existing[end_pos + end_markers[i].length:existing.length];
            }
        }
        existing = existing.strip ();

        var sb = new StringBuilder ();
        if (existing.length > 0) {
            sb.append (existing);
            sb.append ("\n\n");
        }
        sb.append (CURRENT_BEGIN_MARKER);
        sb.append ("export XKB_DEFAULT_LAYOUT=\"%s\"\n".printf (config.layout));
        if (config.options != "") {
            sb.append ("export XKB_DEFAULT_OPTIONS=\"%s\"\n".printf (config.options));
        }
        sb.append (CURRENT_END_MARKER);

        FileUtils.set_contents (path, sb.str);
        return true;
    }

    private static bool apply_input_block (string path, string block_prefix, XKBConfig config) throws Error {
        if (!FileUtils.test (path, FileTest.EXISTS)) {
            return false;
        }

        string content;
        FileUtils.get_contents (path, out content);
        string[] lines = content.split ("\n");
        var result = new StringBuilder ();
        bool found_block = false;

        foreach (var line in lines) {
            if (line.strip ().has_prefix (block_prefix)) {
                found_block = true;
                result.append ("%s { xkb_layout \"%s\" xkb_options \"%s\" }".printf (
                    block_prefix, config.layout, config.options));
            } else if (found_block && line.strip ().has_prefix ("}")) {
                found_block = false;
                continue;
            } else if (!found_block) {
                result.append (line + "\n");
            }
        }

        if (!found_block) {
            result.append ("%s { xkb_layout \"%s\" xkb_options \"%s\" }".printf (
                block_prefix, config.layout, config.options));
        }

        FileUtils.set_contents (path, result.str);
        return true;
    }

    private static bool apply_wayfire_section (string path, XKBConfig config) throws Error {
        if (!FileUtils.test (path, FileTest.EXISTS)) {
            return false;
        }

        string content;
        FileUtils.get_contents (path, out content);
        string[] lines = content.split ("\n");
        var result = new StringBuilder ();
        bool in_input = false;

        foreach (var line in lines) {
            string trimmed = line.strip ();
            if (trimmed == "[input]") {
                result.append (line + "\n");
                in_input = true;
            } else if (in_input && trimmed.has_prefix ("[")) {
                in_input = false;
                result.append ("kb_layout = %s".printf (config.layout));
                result.append ("kb_options = %s".printf (config.options));
                result.append_c ('\n');
                result.append (line + "\n");
            } else if (in_input && (trimmed.has_prefix ("kb_layout") || trimmed.has_prefix ("kb_options"))) {
                continue;
            } else {
                result.append (line + "\n");
            }
        }

        FileUtils.set_contents (path, result.str);
        return true;
    }

    private static bool apply_hyprland_env (string path, XKBConfig config) throws Error {
        if (!FileUtils.test (path, FileTest.EXISTS)) {
            return false;
        }

        string content;
        FileUtils.get_contents (path, out content);
        string[] lines = content.split ("\n");
        var result = new StringBuilder ();
        bool layout_found = false;
        bool options_found = false;

        foreach (var line in lines) {
            string trimmed = line.strip ();
            if (trimmed.has_prefix ("env = XKB_DEFAULT_LAYOUT") || trimmed.has_prefix ("env=XKB_DEFAULT_LAYOUT")) {
                result.append ("env = XKB_DEFAULT_LAYOUT,%s".printf (config.layout));
                layout_found = true;
            } else if (trimmed.has_prefix ("env = XKB_DEFAULT_OPTIONS") || trimmed.has_prefix ("env=XKB_DEFAULT_OPTIONS")) {
                result.append ("env = XKB_DEFAULT_OPTIONS,%s".printf (config.options));
                options_found = true;
            } else {
                result.append (line + "\n");
            }
        }

        if (!layout_found) {
            result.append ("env = XKB_DEFAULT_LAYOUT,%s".printf (config.layout));
        }
        if (!options_found && config.options != "") {
            result.append ("env = XKB_DEFAULT_OPTIONS,%s".printf (config.options));
        }

        FileUtils.set_contents (path, result.str);
        return true;
    }

#if UNIT_TEST
    public static bool test_apply_env_exports(string path, XKBConfig config) throws Error {
        return apply_env_exports(path, config);
    }
#endif
}
