using GLib;

public class FlagUtils : Object {
    private const string SHARED_LAYOUTS_CFG = "/usr/share/wl-kbd-assets/xkeyboardconfig/layouts.cfg";
    private const string SHARED_FLAGS_PNG_DIR = "/usr/share/wl-kbd-assets/flags-png";
    private const string SHARED_FLAGS_SVG_DIR = "/usr/share/wl-kbd-assets/flags";
    private const string CONFIG_LAYOUTS_CFG = "/usr/share/wl-kbd-config/xkeyboardconfig/layouts.cfg";
    private const string CONFIG_FLAGS_PNG_DIR = "/usr/share/wl-kbd-config/flags-png";
    private const string CONFIG_FLAGS_SVG_DIR = "/usr/share/wl-kbd-config/flags";
    private const string LEGACY_FLAGS_SVG_DIR = "/usr/share/labwc-keyboard-indicator/flags";

    private static string find_existing_path (string[] candidates, FileTest test) {
        foreach (string candidate in candidates) {
            if (candidate != "" && FileUtils.test (candidate, test)) {
                return candidate;
            }
        }

        return "";
    }

    private static string resolve_source_path (string relative_path, FileTest test) {
        string cwd = Environment.get_current_dir ();
        string[] candidates = {
            Path.build_filename (cwd, "data", relative_path),
            Path.build_filename (cwd, "..", "data", relative_path)
        };

        return find_existing_path (candidates, test);
    }

    public static string build_layouts_config_path () {
        string installed = SHARED_LAYOUTS_CFG;
        string resolved = find_existing_path ({
            SHARED_LAYOUTS_CFG,
            CONFIG_LAYOUTS_CFG,
            installed,
            resolve_source_path (Path.build_filename ("xkeyboardconfig", "layouts.cfg"), FileTest.EXISTS)
        }, FileTest.EXISTS);
        if (resolved != "") {
            return resolved;
        }

        return installed;
    }

    public static string build_flag_dir_path () {
        string installed_png = SHARED_FLAGS_PNG_DIR;
        string resolved_png = find_existing_path ({
            SHARED_FLAGS_PNG_DIR,
            CONFIG_FLAGS_PNG_DIR,
            installed_png,
            resolve_source_path ("flags-png", FileTest.IS_DIR)
        }, FileTest.IS_DIR);
        if (resolved_png != "") {
            return resolved_png;
        }

        string installed_svg = SHARED_FLAGS_SVG_DIR;
        string legacy_installed_svg = LEGACY_FLAGS_SVG_DIR;
        string resolved_svg = find_existing_path ({
            SHARED_FLAGS_SVG_DIR,
            CONFIG_FLAGS_SVG_DIR,
            installed_svg,
            legacy_installed_svg,
            resolve_source_path ("flags", FileTest.IS_DIR)
        }, FileTest.IS_DIR);
        if (resolved_svg != "") {
            return resolved_svg;
        }

        return installed_svg;
    }

    public static string build_svg_flag_dir_path () {
        string installed = SHARED_FLAGS_SVG_DIR;
        string resolved = find_existing_path ({
            SHARED_FLAGS_SVG_DIR,
            CONFIG_FLAGS_SVG_DIR,
            LEGACY_FLAGS_SVG_DIR,
            resolve_source_path ("flags", FileTest.IS_DIR)
        }, FileTest.IS_DIR);
        if (resolved != "") {
            return resolved;
        }

        return installed;
    }

    public static string get_layout_base_code (string code) {
        string base_code = code.down ().strip ();

        int variant_pos = base_code.index_of ("(");
        if (variant_pos > 0) {
            base_code = base_code.substring (0, variant_pos);
        }

        int slash_pos = base_code.index_of ("/");
        if (slash_pos > 0) {
            base_code = base_code.substring (0, slash_pos);
        }

        return base_code.strip ();
    }

    public static string get_layout_icon_code (string layout_code) {
        string base_code = get_layout_base_code (layout_code);
        if (base_code == "") {
            return "us";
        }

        switch (base_code) {
        case "en":
        case "english":
        case "american":
            return "us";
        case "russian":
            return "ru";
        case "ukrainian":
            return "ua";
        case "belarusian":
            return "by";
        case "ara":
        case "arabic":
            return "ar";
        case "armenian":
            return "am";
        case "bengali":
        case "bangla":
            return "bd";
        case "brazilian":
        case "brazil":
            return "br";
        case "bulgarian":
            return "bg";
        case "canadian":
            return "ca";
        case "croatian":
            return "hr";
        case "czech":
            return "cz";
        case "danish":
            return "dk";
        case "estonian":
        case "ee":
            return "et";
        case "persian":
            return "ir";
        case "greek":
            return "gr";
        case "hebrew":
            return "il";
        case "hindi":
            return "in";
        case "japanese":
            return "jp";
        case "korean":
            return "kr";
        case "latam":
        case "latinamerican":
            return "es";
        case "polish":
            return "pl";
        case "romanian":
            return "ro";
        case "serbian":
            return "rs";
        case "slovak":
            return "sk";
        case "slovenian":
            return "si";
        case "swedish":
            return "se";
        case "thai":
            return "th";
        case "turkish":
            return "tr";
        case "jp":
        case "nec-vndr":
        case "nec_vndr":
        case "nec_vndr/jp":
            return "jp";
        default:
            return sanitize_icon_token (base_code);
        }
    }

    public static string sanitize_icon_token (string value) {
        if (value == "") {
            return "";
        }

        var builder = new StringBuilder ();
        bool previous_dash = false;

        for (int i = 0; i < value.length; i++) {
            char c = value[i];

            if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
                builder.append_c (c);
                previous_dash = false;
                continue;
            }

            bool separator = c == '/' || c == ' ' || c == '(' || c == ')' ||
                c == '-' || c == '_' || c == '.' || c == ',';
            if (separator && !previous_dash && builder.len > 0) {
                builder.append_c ('-');
                previous_dash = true;
            }
        }

        string result = builder.str;
        while (result.has_suffix ("-")) {
            result = result.substring (0, result.length - 1);
        }

        return result;
    }

    public static bool has_flag_asset (string layout_code) {
        if (layout_code == "") {
            return false;
        }

        string icon_code = sanitize_icon_token (layout_code.down ());
        string[] flag_dirs = { build_flag_dir_path (), build_svg_flag_dir_path () };

        foreach (string dir in flag_dirs) {
            if (dir == "") {
                continue;
            }

            string png_path = Path.build_filename (dir, icon_code + ".png");
            if (FileUtils.test (png_path, FileTest.EXISTS)) {
                return true;
            }

            string svg_path = Path.build_filename (dir, icon_code + ".svg");
            if (FileUtils.test (svg_path, FileTest.EXISTS)) {
                return true;
            }
        }

        return false;
    }
}
