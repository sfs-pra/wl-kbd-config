using GLib;

public class WMConfigBackup : Object {
    private static string? backup_dir;

    private static string get_old_backup_dir () {
        string? config_dir = Environment.get_user_config_dir ();
        if (config_dir == null) {
            config_dir = Path.build_filename (Environment.get_home_dir (), ".config");
        }
        return Path.build_filename (config_dir, "labwc-kbd", "backups");
    }

    private static string get_new_backup_dir () {
        string? config_dir = Environment.get_user_config_dir ();
        if (config_dir == null) {
            config_dir = Path.build_filename (Environment.get_home_dir (), ".config");
        }
        return Path.build_filename (config_dir, "wl-kbd-config", "backups");
    }

    private static void try_migrate_backup_dir () {
        string old_dir = get_old_backup_dir ();
        string new_dir = get_new_backup_dir ();

        if (!FileUtils.test (old_dir, FileTest.IS_DIR)) {
            return;
        }
        if (FileUtils.test (new_dir, FileTest.IS_DIR)) {
            return;
        }

        try {
            File.new_for_path (Path.get_dirname (new_dir)).make_directory_with_parents ();
            File.new_for_path (old_dir).move (File.new_for_path (new_dir), FileCopyFlags.NONE);
        } catch (Error e) {
            warning ("Failed to migrate backup dir: %s", e.message);
        }
    }

    private static string get_backup_dir () {
        if (backup_dir == null) {
            try_migrate_backup_dir ();
            backup_dir = get_new_backup_dir ();
        }
        return backup_dir;
    }

    public static bool create_backup (string config_path, string wm_name) throws Error {
        if (!FileUtils.test (config_path, FileTest.EXISTS)) {
            return false;
        }

        string dir_path = get_backup_dir ();
        var dir = File.new_for_path (dir_path);
        if (!dir.query_exists ()) {
            dir.make_directory_with_parents ();
        }

        string timestamp = new DateTime.now_local ().format ("%Y%m%d_%H%M%S");
        string backup_name = "%s_%s.backup".printf (wm_name, timestamp);
        string backup_path = Path.build_filename (get_backup_dir (), backup_name);

        var source = File.new_for_path (config_path);
        var dest = File.new_for_path (backup_path);

        source.copy (dest, FileCopyFlags.OVERWRITE);
        return true;
    }

    public static string[] list_backups (string wm_name) {
        var result = new GLib.List<string> ();
        string[] dirs = { get_backup_dir (), get_old_backup_dir () };

        foreach (string dir_path in dirs) {
            var dir = File.new_for_path (dir_path);
            if (!dir.query_exists ()) {
                continue;
            }

            try {
                var enumerator = dir.enumerate_children (
                    "name",
                    FileQueryInfoFlags.NONE
                );

                FileInfo? info;
                while ((info = enumerator.next_file ()) != null) {
                    string name = info.get_name ();
                    if (name.has_prefix (wm_name + "_") && name.has_suffix (".backup")) {
                        result.append (Path.build_filename (dir_path, name));
                    }
                }
            } catch (Error e) {
                warning ("Failed to list backups: %s", e.message);
            }
        }

        var array = new GLib.Array<string> ();
        foreach (unowned string s in result) {
            array.append_val (s);
        }
        return array.data;
    }

    public static bool restore_backup (string backup_path, string config_path) throws Error {
        if (!FileUtils.test (backup_path, FileTest.EXISTS)) {
            return false;
        }

        var source = File.new_for_path (backup_path);
        var dest = File.new_for_path (config_path);

        source.copy (dest, FileCopyFlags.OVERWRITE);
        return true;
    }

    public static bool restore_latest (string wm_name, string config_path) {
        var backups = list_backups (wm_name);
        if (backups.length == 0) {
            return false;
        }

        string latest = backups[0];
        for (int i = 1; i < backups.length; i++) {
            if (strcmp (backups[i], latest) > 0) {
                latest = backups[i];
            }
        }
        try {
            return restore_backup (latest, config_path);
        } catch (Error e) {
            warning ("Failed to restore backup: %s", e.message);
            return false;
        }
    }
}
