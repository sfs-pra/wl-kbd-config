using Gtk;
using Gdk;
using GLib;

public class SettingsWindow : Gtk.ApplicationWindow {
    private Gtk.ListStore layout_store;
    private Gtk.TreeView layout_view;
    private Gtk.ComboBoxText shortcut_combo;
    private Gtk.Entry custom_option_entry;
    private Gtk.Label preview_layout_label;
    private Gtk.Label preview_option_label;
    private Gtk.Button remove_button;
    private Gtk.Button up_button;
    private Gtk.Button down_button;
    private Gtk.Button apply_wm_button;
    private Gtk.Label status_label;
    private SettingsStateSnapshot? initial_snapshot;

    private string env_file_path;
    private string flag_dir_path;
    private string layouts_config_path;
    private WMDetector.WaylandWM detected_wm;

    private Gtk.Button create_icon_button (string icon_name, string label_text) {
        var button = new Gtk.Button ();
        var image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.BUTTON);

        var label = new Gtk.Label (label_text);
        label.halign = Gtk.Align.START;
        label.set_xalign (0.0f);

        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        row.halign = Gtk.Align.START;
        row.margin_start = 4;
        row.pack_start (image, false, false, 0);
        row.pack_start (label, false, false, 0);

        button.add (row);
        return button;
    }

    private void set_uniform_button_width (
        Gtk.Button first,
        Gtk.Button second,
        Gtk.Button third,
        Gtk.Button fourth
    ) {
        Gtk.Requisition nat_req;
        int max_width = 0;

        first.get_preferred_size (null, out nat_req);
        max_width = int.max (max_width, nat_req.width);

        second.get_preferred_size (null, out nat_req);
        max_width = int.max (max_width, nat_req.width);

        third.get_preferred_size (null, out nat_req);
        max_width = int.max (max_width, nat_req.width);

        fourth.get_preferred_size (null, out nat_req);
        max_width = int.max (max_width, nat_req.width);

        first.set_size_request (max_width, -1);
        second.set_size_request (max_width, -1);
        third.set_size_request (max_width, -1);
        fourth.set_size_request (max_width, -1);
    }

    public SettingsWindow (Gtk.Application app) {
        Object (
            application: app,
            title: _("Keyboard Layout"),
            resizable: true
        );

        env_file_path = build_environment_path ();
        flag_dir_path = FlagUtils.build_flag_dir_path ();
        layouts_config_path = FlagUtils.build_layouts_config_path ();
        detected_wm = WMDetector.detect ();

        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        root.margin_top = 12;
        root.margin_bottom = 12;
        root.margin_start = 12;
        root.margin_end = 12;
        add (root);

        string wm_name = WMDetector.get_name (detected_wm);
        var subtitle = new Gtk.Label (_("Configure layouts and switching for %s").printf (wm_name));
        subtitle.halign = Gtk.Align.START;
        root.pack_start (subtitle, false, false, 0);

        root.pack_start (build_layouts_frame (), false, false, 0);
        root.pack_start (build_switching_frame (), false, false, 0);

        // ── Bottom area: status above right-aligned actions
        status_label = new Gtk.Label (" ");
        status_label.halign = Gtk.Align.END;
        status_label.set_single_line_mode (true);
        status_label.ellipsize = Pango.EllipsizeMode.END;
        var action_bar = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        action_bar.layout_style = Gtk.ButtonBoxStyle.END;
        action_bar.spacing = 6;

        var cancel_btn = create_icon_button ("window-close", _("Cancel"));
        cancel_btn.set_tooltip_text (_("Restore values from window open"));
        cancel_btn.clicked.connect (() => { restore_initial_state (); });
        action_bar.add (cancel_btn);

        var apply_btn = create_icon_button ("document-save", _("Apply"));
        apply_btn.set_tooltip_text (_("Apply keyboard settings to WM config"));
        apply_btn.clicked.connect (() => { apply_changes (); });
        action_bar.add (apply_btn);

        var close_btn = create_icon_button ("window-close", _("Close"));
        close_btn.set_tooltip_text (_("Close this window"));
        close_btn.clicked.connect (() => { this.close (); });
        action_bar.add (close_btn);

        if (detected_wm != WMDetector.WaylandWM.UNKNOWN && detected_wm != WMDetector.WaylandWM.LABWC) {
            apply_wm_button = create_icon_button ("document-save", _("Apply to WM"));
            apply_wm_button.set_tooltip_text (_("Apply current XKB settings to the detected window manager"));
            apply_wm_button.clicked.connect (() => {
                apply_to_wm ();
            });
            action_bar.add (apply_wm_button);
        }

        var bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        bottom_box.pack_start (status_label, false, false, 0);
        bottom_box.pack_start (action_bar, false, false, 0);
        root.pack_end (bottom_box, false, false, 0);

        load_environment ();
        initial_snapshot = capture_current_state ();
        update_preview ();
        update_layout_buttons ();
        update_custom_option_state ();
        show_all ();
    }

    private void clear_status () {
        status_label.label = " ";
    }

    private SettingsStateSnapshot capture_current_state () {
        return new SettingsStateSnapshot (collect_layouts_csv (), get_effective_option ());
    }

    private void restore_initial_state () {
        if (initial_snapshot == null) {
            return;
        }

        populate_layout_store (initial_snapshot.layouts_csv);
        apply_option_to_controls (initial_snapshot.option);
        update_custom_option_state ();
        update_preview ();
        update_layout_buttons ();
        clear_status ();
    }

    private Gtk.Widget build_layouts_frame () {
        var frame = new Gtk.Frame (null);
        var title_label = new Gtk.Label (_("Configured layouts"));
        title_label.halign = Gtk.Align.START;
        frame.label_widget = title_label;

        var grid = new Gtk.Grid ();
        grid.margin_top = 8;
        grid.margin_bottom = 8;
        grid.margin_start = 8;
        grid.margin_end = 8;
        grid.column_spacing = 10;
        frame.add (grid);

        layout_store = new Gtk.ListStore (2, typeof (Gdk.Pixbuf), typeof (string));
        layout_view = new Gtk.TreeView.with_model (layout_store);
        layout_view.headers_visible = false;
        layout_view.set_tooltip_text (_("Configured keyboard layouts"));

        var flag_renderer = new Gtk.CellRendererPixbuf ();
        var flag_column = new Gtk.TreeViewColumn ();
        flag_column.pack_start (flag_renderer, false);
        flag_column.add_attribute (flag_renderer, "pixbuf", 0);
        layout_view.append_column (flag_column);

        var renderer = new Gtk.CellRendererText ();
        var column = new Gtk.TreeViewColumn ();
        column.pack_start (renderer, true);
        column.add_attribute (renderer, "text", 1);
        layout_view.append_column (column);

        var selection = layout_view.get_selection ();
        selection.mode = Gtk.SelectionMode.SINGLE;
        selection.changed.connect (() => {
            update_layout_buttons ();
        });

        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.set_size_request (260, -1);
        scroll.add (layout_view);
        grid.attach (scroll, 0, 0, 1, 1);

        var controls = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        controls.halign = Gtk.Align.START;
        controls.valign = Gtk.Align.START;
        controls.homogeneous = true;
        grid.attach (controls, 1, 0, 1, 1);

        var add_button = create_icon_button ("list-add", _("Add..."));
        add_button.halign = Gtk.Align.START;
        add_button.set_tooltip_text (_("Add new keyboard layout"));
        add_button.clicked.connect (() => {
            add_layout_dialog ();
        });
        controls.pack_start (add_button, false, false, 0);

        remove_button = create_icon_button ("list-remove", _("Remove"));
        remove_button.halign = Gtk.Align.START;
        remove_button.set_tooltip_text (_("Remove selected layout"));
        remove_button.clicked.connect (() => {
            remove_selected_layout ();
        });
        controls.pack_start (remove_button, false, false, 0);

        up_button = create_icon_button ("go-up", _("Up"));
        up_button.halign = Gtk.Align.START;
        up_button.set_tooltip_text (_("Move selected layout up in priority"));
        up_button.clicked.connect (() => {
            move_selected_layout (-1);
        });
        controls.pack_start (up_button, false, false, 0);

        down_button = create_icon_button ("go-down", _("Down"));
        down_button.halign = Gtk.Align.START;
        down_button.set_tooltip_text (_("Move selected layout down in priority"));
        down_button.clicked.connect (() => {
            move_selected_layout (1);
        });
        controls.pack_start (down_button, false, false, 0);

        set_uniform_button_width (add_button, remove_button, up_button, down_button);
        Idle.add (() => {
            set_uniform_button_width (add_button, remove_button, up_button, down_button);
            return false;
        });

        return frame;
    }

    private Gtk.Widget build_switching_frame () {
        var frame = new Gtk.Frame (null);
        var title_label = new Gtk.Label (_("Switching"));
        title_label.halign = Gtk.Align.START;
        frame.label_widget = title_label;

        var grid = new Gtk.Grid ();
        grid.margin_top = 8;
        grid.margin_bottom = 8;
        grid.margin_start = 8;
        grid.margin_end = 8;
        grid.row_spacing = 6;
        grid.column_spacing = 8;
        frame.add (grid);

        var shortcut_title = new Gtk.Label (_("Shortcut:"));
        shortcut_title.halign = Gtk.Align.START;
        shortcut_title.set_tooltip_text (_("Keyboard shortcut to switch between layouts"));
        shortcut_combo = new Gtk.ComboBoxText ();
        shortcut_combo.set_tooltip_text (_("Select keyboard layout switching shortcut"));
        shortcut_combo.append ("grp:alt_shift_toggle",  _("Alt+Shift"));
        shortcut_combo.append ("grp:shifts_toggle",      _("Both Shifts"));
        shortcut_combo.append ("grp:ctrl_shift_toggle",  _("Ctrl+Shift"));
        shortcut_combo.append ("grp:caps_toggle",        _("Caps Lock"));
        shortcut_combo.append ("grp:win_space_toggle",   _("Win+Space"));
        shortcut_combo.append ("grp:menu_toggle",        _("Menu key"));
        shortcut_combo.append ("grp:lwin_toggle",        _("Left Win"));
        shortcut_combo.append ("grp:ralt_toggle",        _("Right Alt"));
        shortcut_combo.append ("",                       _("User-defined"));
        shortcut_combo.changed.connect (() => {
            update_custom_option_state ();
            update_preview ();
        });

        var custom_title = new Gtk.Label (_("Custom XKB option:"));
        custom_title.halign = Gtk.Align.START;
        custom_title.set_tooltip_text (_("Custom XKB option for layout switching"));
        custom_option_entry = new Gtk.Entry ();
        custom_option_entry.set_tooltip_text (_("Custom XKB options (e.g., grp:ctrl_shift_toggle)"));
        custom_option_entry.changed.connect (() => {
            update_preview ();
        });

        grid.attach (shortcut_title, 0, 0, 1, 1);
        grid.attach (shortcut_combo, 1, 0, 1, 1);
        grid.attach (custom_title, 0, 1, 1, 1);
        grid.attach (custom_option_entry, 1, 1, 1, 1);

        preview_layout_label = new Gtk.Label (_("XKB_DEFAULT_LAYOUT=") + "us,ru");
        preview_layout_label.halign = Gtk.Align.START;
        preview_layout_label.selectable = true;
        preview_layout_label.set_tooltip_text (_("Preview of XKB_DEFAULT_LAYOUT environment variable"));

        preview_option_label = new Gtk.Label (_("XKB_DEFAULT_OPTIONS=") + "grp:alt_shift_toggle");
        preview_option_label.halign = Gtk.Align.START;
        preview_option_label.selectable = true;
        preview_option_label.set_tooltip_text (_("Preview of XKB_DEFAULT_OPTIONS environment variable"));

        grid.attach (preview_layout_label, 0, 2, 2, 1);
        grid.attach (preview_option_label, 0, 3, 2, 1);

        return frame;
    }

    private string build_environment_path () {
        string config_home = Environment.get_variable ("XDG_CONFIG_HOME");
        if (config_home == null || config_home == "") {
            config_home = Path.build_filename (Environment.get_home_dir (), ".config");
        }

        return Path.build_filename (config_home, "labwc", "environment");
    }

    private static Gdk.Pixbuf? load_flag_pixbuf(string flag_dir_path,
                                              string layout_code, int size) {
        string icon_code = FlagUtils.get_layout_icon_code(layout_code);
        foreach (string ext in new string[]{".svg", ".png"}) {
            string path = Path.build_filename(flag_dir_path, icon_code + ext);
            if (FileUtils.test(path, FileTest.EXISTS)) {
                try {
                    return new Gdk.Pixbuf.from_file_at_scale(path, size, size, true);
                } catch (Error e) {
                    warning("load_flag_pixbuf %s: %s", path, e.message);
                }
            }
        }
        return null;
    }

    private void ensure_environment_file () {
        string labwc_dir = Path.get_dirname (env_file_path);
        DirUtils.create_with_parents (labwc_dir, 0755);

        if (!FileUtils.test (env_file_path, FileTest.EXISTS)) {
            string defaults = "XKB_DEFAULT_LAYOUT=us,ru\nXKB_DEFAULT_OPTIONS=grp:alt_shift_toggle\n";
            try {
                FileUtils.set_contents (env_file_path, defaults);
            } catch (Error e) {
                show_error_dialog (_("Failed to initialize environment file"), e.message);
            }
        }
    }

    private string read_env_key (string key) {
        string content;
        try {
            if (!FileUtils.get_contents (env_file_path, out content)) {
                return "";
            }
        } catch (Error e) {
            return "";
        }

        foreach (string line in content.split ("\n")) {
            if (line.has_prefix (key + "=")) {
                return line.substring ((key + "=").length);
            }
        }

        return "";
    }

    private void load_environment () {
        ensure_environment_file ();

        string layouts = read_env_key ("XKB_DEFAULT_LAYOUT");
        if (layouts == "") {
            layouts = "us,ru";
        }

        string option = read_env_key ("XKB_DEFAULT_OPTIONS");
        if (option == "") {
            option = "grp:alt_shift_toggle";
        }

        populate_layout_store (layouts);
        apply_option_to_controls (option);

    }

    private void populate_layout_store (string layouts_csv) {
        layout_store.clear ();

        foreach (string raw in layouts_csv.split (",")) {
            string code = raw.strip ();
            if (code == "") {
                continue;
            }

            Gtk.TreeIter iter;
            layout_store.append (out iter);
            layout_store.set (iter, 0, load_flag_pixbuf (flag_dir_path, code, 32), 1, code);
        }

        if (layout_store.iter_n_children (null) > 0) {
            Gtk.TreeIter first;
            if (layout_store.iter_nth_child (out first, null, 0)) {
                layout_view.get_selection ().select_iter (first);
            }
        }
    }

    private string shortcut_label_from_option (string option) {
        // unused after T7 fix
        switch (option) {
        case "grp:alt_shift_toggle":
            return _("Alt+Shift");
        case "grp:shift_caps_toggle":
            return _("Shift+Caps Lock");
        case "grp:ctrl_shift_toggle":
            return _("Ctrl+Shift");
        case "grp:caps_toggle":
            return _("Caps Lock");
        case "grp:win_space_toggle":
            return _("Win+Space");
        case "grp:menu_toggle":
            return _("Menu");
        case "grp:ralt_toggle":
            return _("Right Alt");
        default:
            return _("User-defined");
        }
    }

    private string option_from_shortcut_label (string shortcut_label) {
        // unused after T7 fix
        switch (shortcut_label) {
        case "Alt+Shift":
            return "grp:alt_shift_toggle";
        case "Shift+Caps Lock":
            return "grp:shift_caps_toggle";
        case "Ctrl+Shift":
            return "grp:ctrl_shift_toggle";
        case "Caps Lock":
            return "grp:caps_toggle";
        case "Win+Space":
            return "grp:win_space_toggle";
        case "Menu":
            return "grp:menu_toggle";
        case "Right Alt":
            return "grp:ralt_toggle";
        default:
            return "";
        }
    }

    private void apply_option_to_controls (string option) {
        string current_grp_option = "";
        foreach (unowned string p in option.split (",")) {
            string t = p.strip ();
            if (t.has_prefix ("grp:")) {
                current_grp_option = t;
                break;
            }
        }

        shortcut_combo.active_id = current_grp_option;
        if (shortcut_combo.active_id == null) {
            shortcut_combo.active_id = "";
        }

        if (shortcut_combo.active_id == "") {
            custom_option_entry.text = option;
        } else {
            custom_option_entry.text = "";
        }
    }

    private void update_custom_option_state () {
        /* Keep the field always editable.
         * The combo selection still decides whether the custom value is used:
         * get_effective_option() reads custom_option_entry only when Custom is selected. */
        custom_option_entry.sensitive = true;
    }

    private string merge_grp_option (string existing_options, string new_grp) {
        var parts = new GLib.Array<string> ();
        if (existing_options != "") {
            foreach (unowned string p in existing_options.split (",")) {
                string t = p.strip ();
                if (t != "" && !t.has_prefix ("grp:")) {
                    parts.append_val (t);
                }
            }
        }
        if (new_grp != "") {
            parts.append_val (new_grp);
        }
        return string.joinv (",", parts.data);
    }

    private string collect_layouts_csv () {
        StringBuilder builder = new StringBuilder ();
        Gtk.TreeIter iter;
        bool valid = layout_store.get_iter_first (out iter);
        bool first = true;

        while (valid) {
            string code;
            layout_store.get (iter, 1, out code);
            if (!first) {
                builder.append (",");
            }
            builder.append (code);
            first = false;
            valid = layout_store.iter_next (ref iter);
        }

        return builder.str;
    }

    private string get_effective_option () {
        string selected = shortcut_combo.active_id ?? "grp:alt_shift_toggle";
        if (selected != "") {
            return selected;
        }

        string custom = custom_option_entry.text.strip ();
        if (custom == "") {
            return "";
        }

        if (custom.has_prefix ("grp:")) {
            return custom;
        }

        return "grp:" + custom;
    }

    private void update_preview () {
        preview_layout_label.label = _("XKB_DEFAULT_LAYOUT=") + collect_layouts_csv ();
        preview_option_label.label = _("XKB_DEFAULT_OPTIONS=") + get_effective_option ();
    }

    private void add_layout_dialog () {
        var catalog_store = build_layout_catalog_store ();
        if (catalog_store.iter_n_children (null) == 0) {
            show_error_dialog (
                _("No layouts found"),
                _("Unable to read bundled keyboard layouts catalog")
            );
            return;
        }

        var dialog = new Gtk.Dialog.with_buttons (
            _("Add Layout"),
            this,
            Gtk.DialogFlags.MODAL,
            _("Cancel"), Gtk.ResponseType.CANCEL,
            _("Add"), Gtk.ResponseType.OK
        );
        dialog.set_default_size (640, 480);

        var cancel_button = dialog.get_widget_for_response (Gtk.ResponseType.CANCEL) as Gtk.Button;
        if (cancel_button != null) {
            cancel_button.label = _("Cancel");
            cancel_button.set_tooltip_text (_("Cancel and close dialog"));
            cancel_button.set_image (new Gtk.Image.from_icon_name ("window-close", Gtk.IconSize.BUTTON));
            cancel_button.always_show_image = true;
        }

        var add_dialog_button = dialog.get_widget_for_response (Gtk.ResponseType.OK) as Gtk.Button;
        if (add_dialog_button != null) {
            add_dialog_button.label = _("Add");
            add_dialog_button.set_tooltip_text (_("Add selected layout to the list"));
            add_dialog_button.set_image (new Gtk.Image.from_icon_name ("list-add", Gtk.IconSize.BUTTON));
            add_dialog_button.always_show_image = true;
        }

        Gtk.Box content = dialog.get_content_area ();
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        box.margin_top = 10;
        box.margin_bottom = 10;
        box.margin_start = 10;
        box.margin_end = 10;
        content.pack_start (box, true, true, 0);

        var hint = new Gtk.Label (_("Select a layout or enter a manual code below"));
        hint.halign = Gtk.Align.START;
        hint.set_tooltip_text (_("Select a layout from the list or enter it manually below"));
        box.pack_start (hint, false, false, 0);

        var search_entry = new Gtk.SearchEntry ();
        search_entry.set_tooltip_text (_("Search layouts by code or description"));
        search_entry.placeholder_text = _("Search by code or description");
        box.pack_start (search_entry, false, false, 0);

        var filter_model = new Gtk.TreeModelFilter (catalog_store, null);
        filter_model.set_visible_func ((model, iter) => {
            string text = search_entry.text.strip ();
            if (text == "") {
                return true;
            }

            return catalog_row_matches (model, iter, text.down ());
        });

        var sort_model = new Gtk.TreeModelSort.with_model (filter_model);
        var tree_view = new Gtk.TreeView.with_model (sort_model);
        tree_view.headers_visible = true;
        tree_view.set_tooltip_text (_("Select a keyboard layout or variant"));
        tree_view.get_selection ().mode = Gtk.SelectionMode.SINGLE;
        tree_view.row_activated.connect ((path, column) => {
            dialog.response (Gtk.ResponseType.OK);
        });

        search_entry.changed.connect (() => {
            filter_model.refilter ();
            tree_view.collapse_all ();
        });

        var flag_renderer = new Gtk.CellRendererPixbuf ();
        var flag_column = new Gtk.TreeViewColumn ();
        flag_column.title = _("Flag");
        flag_column.pack_start (flag_renderer, false);
        flag_column.add_attribute (flag_renderer, "pixbuf", 0);
        tree_view.append_column (flag_column);

        var code_renderer = new Gtk.CellRendererText ();
        var code_column = new Gtk.TreeViewColumn ();
        code_column.title = _("Layout");
        code_column.pack_start (code_renderer, true);
        code_column.add_attribute (code_renderer, "text", 1);
        code_column.set_sort_column_id (1);
        tree_view.append_column (code_column);

        var desc_renderer = new Gtk.CellRendererText ();
        var desc_column = new Gtk.TreeViewColumn ();
        desc_column.title = _("Description");
        desc_column.pack_start (desc_renderer, true);
        desc_column.add_attribute (desc_renderer, "text", 2);
        desc_column.set_sort_column_id (2);
        tree_view.append_column (desc_column);
        tree_view.set_search_column (2);
        tree_view.enable_search = false;
        sort_model.set_sort_column_id (2, Gtk.SortType.ASCENDING);

        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scroll.add (tree_view);
        box.pack_start (scroll, true, true, 0);

        var manual_title = new Gtk.Label (_("Manual layout code:"));
        manual_title.halign = Gtk.Align.START;
        manual_title.set_tooltip_text (_("Enter layout code manually (e.g., us, ru, de)"));
        box.pack_start (manual_title, false, false, 0);

        var manual_entry = new Gtk.Entry ();
        manual_entry.set_tooltip_text (_("Enter layout code manually (e.g., us, ru, de, us(intl))"));
        manual_entry.placeholder_text = _("e.g., us, ru, de, us(intl)");
        box.pack_start (manual_entry, false, false, 0);

        dialog.set_default_response (Gtk.ResponseType.OK);
        dialog.show_all ();
        tree_view.collapse_all ();
        search_entry.grab_focus ();

        if (dialog.run () == Gtk.ResponseType.OK) {
            string code = manual_entry.text.strip ();

            if (code == "") {
                Gtk.TreeModel selected_model;
                Gtk.TreeIter selected_iter;
                if (tree_view.get_selection ().get_selected (out selected_model, out selected_iter)) {
                    Gtk.TreeIter child_iter;
                    sort_model.convert_iter_to_child_iter (out child_iter, selected_iter);

                    Gtk.TreeIter filter_iter;
                    filter_model.convert_iter_to_child_iter (out filter_iter, child_iter);
                    catalog_store.get (filter_iter, 1, out code);
                }
            }

            if (code == null || code == "") {
                show_error_dialog (_("Invalid layout"), _("Select a layout or enter a layout code."));
            } else if (!is_valid_layout_code (code)) {
                show_error_dialog (_("Invalid layout code"), _("Layout code contains invalid characters."));
            } else if (layout_exists (code)) {
                show_error_dialog (_("Duplicate layout"), _("This layout is already in the list."));
            } else {
                Gtk.TreeIter new_iter;
                layout_store.append (out new_iter);
                layout_store.set (
                    new_iter,
                    0,
                    load_flag_pixbuf (flag_dir_path, code, 32),
                    1,
                    code
                );
                layout_view.get_selection ().select_iter (new_iter);
                update_preview ();
                update_layout_buttons ();
            }
        }

        dialog.destroy ();
    }

    private Gtk.TreeStore build_layout_catalog_store () {
        var store = new Gtk.TreeStore (3, typeof (Gdk.Pixbuf), typeof (string), typeof (string));
        var seen = new HashTable<string, bool> (str_hash, str_equal);

        try {
            var key_file = new KeyFile ();
            key_file.load_from_file (layouts_config_path, KeyFileFlags.NONE);

            string[] keys = key_file.get_keys ("LAYOUTS");
            foreach (string key in keys) {
                string code = key.strip ();
                string description = translate_xkeyboard_config (
                    key_file.get_string ("LAYOUTS", key).strip ()
                );

                if (code.index_of ("(") < 0) {
                    add_catalog_layout_row (store, seen, code, description);
                    continue;
                }

                int open_pos = code.index_of ("(");
                int close_pos = code.last_index_of (")");
                if (open_pos <= 0 || close_pos <= open_pos + 1) {
                    continue;
                }

                string layout = code.substring (0, open_pos).strip ();
                add_catalog_variant_row (store, seen, layout, code, description);
            }
        } catch (Error e) {
            return store;
        }

        store.set_sort_column_id (2, Gtk.SortType.ASCENDING);

        return store;
    }

    private void add_catalog_layout_row (
        Gtk.TreeStore store,
        HashTable<string, bool> seen,
        string code,
        string description
    ) {
        if (!is_valid_layout_code (code)) {
            return;
        }

        if (seen.contains (code)) {
            return;
        }

        seen.insert (code, true);
        Gtk.TreeIter iter;
        store.append (out iter, null);
        store.set (iter, 0, load_flag_pixbuf (flag_dir_path, code, 32), 1, code, 2, description);
    }

    private void add_catalog_variant_row (
        Gtk.TreeStore store,
        HashTable<string, bool> seen,
        string layout,
        string code,
        string description
    ) {
        if (!is_valid_layout_code (code)) {
            return;
        }

        if (seen.contains (code)) {
            return;
        }

        Gtk.TreeIter parent_iter;
        if (!find_catalog_parent_iter (store, layout, out parent_iter)) {
            return;
        }

        seen.insert (code, true);
        Gtk.TreeIter iter;
        store.append (out iter, parent_iter);
        store.set (iter, 0, load_flag_pixbuf (flag_dir_path, layout, 32), 1, code, 2, description);
    }

    private bool find_catalog_parent_iter (Gtk.TreeStore store, string layout, out Gtk.TreeIter iter) {
        Gtk.TreeIter current;
        if (store.get_iter_first (out current)) {
            do {
                string code;
                store.get (current, 1, out code);
                if (code == layout) {
                    iter = current;
                    return true;
                }
            } while (store.iter_next (ref current));
        }

        iter = Gtk.TreeIter ();
        return false;
    }

    private bool catalog_row_matches (Gtk.TreeModel model, Gtk.TreeIter iter, string needle) {
        Gtk.TreeIter parent;
        if (model.iter_parent (out parent, iter)) {
            // Child: visible when parent matches (keeps expander arrow working)
            string pc, pd;
            model.get (parent, 1, out pc, 2, out pd);
            return catalog_text_matches (pc, needle) || catalog_text_matches (pd, needle);
        }

        // Top-level: match against search
        string code, description;
        model.get (iter, 1, out code, 2, out description);
        return catalog_text_matches (code, needle) || catalog_text_matches (description, needle);
    }

    private bool catalog_text_matches (string text, string needle) {
        string lowered = text.down ();
        if (lowered.has_prefix (needle)) {
            return true;
        }

        string[] separators = {" ", "(", ")", ",", ".", "/", "-", "_"};
        foreach (string separator in separators) {
            if (lowered.contains (separator + needle)) {
                return true;
            }
        }

        return false;
    }

    private string translate_xkeyboard_config (string text) {
        string translated = dgettext ("xkeyboard-config", text);
        if (translated == null || translated == "") {
            return text;
        }

        return translated;
    }

    private bool layout_exists (string code) {
        Gtk.TreeIter iter;
        bool valid = layout_store.get_iter_first (out iter);
        while (valid) {
            string current;
            layout_store.get (iter, 1, out current);
            if (current == code) {
                return true;
            }
            valid = layout_store.iter_next (ref iter);
        }

        return false;
    }

    private bool is_valid_layout_code (string code) {
        if (code == "") {
            return false;
        }

        try {
            var regex = new Regex ("^[A-Za-z0-9_-]+(\\([A-Za-z0-9_-]+\\))?$");
            return regex.match (code);
        } catch (RegexError e) {
            return false;
        }
    }

    private int get_selected_index (out Gtk.TreeIter selected_iter) {
        Gtk.TreeModel model;
        if (!layout_view.get_selection ().get_selected (out model, out selected_iter)) {
            return -1;
        }

        Gtk.TreePath? path = model.get_path (selected_iter);
        if (path == null) {
            return -1;
        }

        int[] indices = path.get_indices ();
        if (indices.length == 0) {
            return -1;
        }

        return indices[0];
    }

    private void remove_selected_layout () {
        Gtk.TreeIter iter;
        int selected = get_selected_index (out iter);
        if (selected < 0) {
            return;
        }

        layout_store.remove (ref iter);
        int count = layout_store.iter_n_children (null);

        if (count > 0) {
            int next_index = selected;
            if (next_index >= count) {
                next_index = count - 1;
            }

            Gtk.TreeIter new_iter;
            if (layout_store.iter_nth_child (out new_iter, null, next_index)) {
                layout_view.get_selection ().select_iter (new_iter);
            }
        }

        update_preview ();
        update_layout_buttons ();
    }

    private void move_selected_layout (int direction) {
        Gtk.TreeIter selected_iter;
        int selected = get_selected_index (out selected_iter);
        if (selected < 0) {
            return;
        }

        int target_index = selected + direction;
        int count = layout_store.iter_n_children (null);
        if (target_index < 0 || target_index >= count) {
            return;
        }

        Gtk.TreeIter target_iter;
        if (!layout_store.iter_nth_child (out target_iter, null, target_index)) {
            return;
        }

        layout_store.swap (selected_iter, target_iter);

        Gtk.TreeIter new_selected;
        if (layout_store.iter_nth_child (out new_selected, null, target_index)) {
            layout_view.get_selection ().select_iter (new_selected);
        }

        update_preview ();
        update_layout_buttons ();
    }

    private void update_layout_buttons () {
        Gtk.TreeIter iter;
        int selected = get_selected_index (out iter);
        int count = layout_store.iter_n_children (null);

        bool has_selection = selected >= 0;
        remove_button.sensitive = has_selection;
        up_button.sensitive = has_selection && selected > 0;
        down_button.sensitive = has_selection && selected >= 0 && selected < (count - 1);
    }

    private bool validate_form (out string message) {
        if (layout_store.iter_n_children (null) == 0) {
            message = _("Add at least one layout.");
            return false;
        }

        Gtk.TreeIter iter;
        bool valid = layout_store.get_iter_first (out iter);
        while (valid) {
            string code;
            layout_store.get (iter, 1, out code);
            if (!is_valid_layout_code (code)) {
                message = _("Invalid layout code:") + " " + code;
                return false;
            }
            valid = layout_store.iter_next (ref iter);
        }

        string option = get_effective_option ();
        if (option == "") {
            message = _("Custom XKB option cannot be empty.");
            return false;
        }

        message = "";
        return true;
    }

    private bool write_environment (string layouts_csv, string option, out string error_message) {
        string content = "";
        try {
            FileUtils.get_contents (env_file_path, out content);
        } catch (Error e) {
            content = "";
        }

        bool wrote_layout = false;
        bool wrote_option = false;
        var out_text = new StringBuilder ();

        foreach (string line in content.split ("\n")) {
            if (line.has_prefix ("XKB_DEFAULT_LAYOUT=")) {
                out_text.append ("XKB_DEFAULT_LAYOUT=" + layouts_csv + "\n");
                wrote_layout = true;
                continue;
            }

            if (line.has_prefix ("XKB_DEFAULT_OPTIONS=")) {
                out_text.append ("XKB_DEFAULT_OPTIONS=" + option + "\n");
                wrote_option = true;
                continue;
            }

            if (line.has_prefix ("XKB_DEFAULT_MODEL=")) {
                continue;
            }

            if (line != "") {
                out_text.append (line + "\n");
            }
        }

        if (!wrote_layout) {
            out_text.append ("XKB_DEFAULT_LAYOUT=" + layouts_csv + "\n");
        }

        if (!wrote_option) {
            out_text.append ("XKB_DEFAULT_OPTIONS=" + option + "\n");
        }

        try {
            FileUtils.set_contents (env_file_path, out_text.str);
        } catch (Error e) {
            error_message = e.message;
            return false;
        }

        error_message = "";
        return true;
    }

    private bool reload_labwc (out string error_message) {
        string? labwc_path = Environment.find_program_in_path ("labwc");
        if (labwc_path == null || labwc_path == "") {
            error_message = "'labwc' is not available in PATH.";
            return false;
        }

        int status = 1;
        string std_out;
        string std_err;

        try {
            Process.spawn_command_line_sync ("labwc -r", out std_out, out std_err, out status);
        } catch (SpawnError e) {
            error_message = e.message;
            return false;
        }

        if (status != 0) {
            error_message = std_err != "" ? std_err : _("labwc reload failed");
            return false;
        }

        error_message = "";
        return true;
    }

    private void apply_changes () {
        string validation_error;
        if (!validate_form (out validation_error)) {
            show_error_dialog (_("Cannot apply settings"), validation_error);
            status_label.show ();
            status_label.set_markup ("<span foreground='red'>✗ " + validation_error + "</span>");
            return;
        }

        string layouts_csv = collect_layouts_csv ();
        string option = get_effective_option ();

        string save_error;
        if (!write_environment (layouts_csv, option, out save_error)) {
            show_error_dialog (_("Failed to save environment"), save_error);
            status_label.show ();
            status_label.set_markup ("<span foreground='red'>✗ " + save_error + "</span>");
            return;
        }

        string reload_error;
        if (!reload_labwc (out reload_error)) {
            show_error_dialog (
                _("Settings saved"),
                _("Configuration was written, but reload failed: ") + reload_error
            );
            status_label.show ();
            status_label.set_markup ("<span foreground='red'>✗ " + reload_error + "</span>");
            return;
        }

        status_label.show ();
        status_label.set_markup ("<span foreground='green'>✓ " +
            _("Changes applied. labwc was reloaded.") + "</span>");
        GLib.Timeout.add (5000, () => {
            clear_status ();
            return Source.REMOVE;
        });
    }

    private void apply_to_wm () {
        if (detected_wm == WMDetector.WaylandWM.UNKNOWN || detected_wm == WMDetector.WaylandWM.LABWC) {
            return;
        }

        string validation_error;
        if (!validate_form (out validation_error)) {
            show_error_dialog (_("Cannot apply to WM"), validation_error);
            status_label.show ();
            status_label.set_markup ("<span foreground='red'>✗ " + validation_error + "</span>");
            return;
        }

        var confirm_dialog = new Gtk.MessageDialog (
            this,
            Gtk.DialogFlags.MODAL,
            Gtk.MessageType.QUESTION,
            Gtk.ButtonsType.YES_NO,
            _("Apply XKB configuration to %s?"),
            WMDetector.get_name (detected_wm)
        );
        confirm_dialog.secondary_text = _(
            "This will modify your %s configuration file.\n" +
            "A backup will be created automatically before applying.\n\n" +
            "Do you want to continue?"
        ).printf (WMDetector.get_name (detected_wm));

        int response = confirm_dialog.run ();
        confirm_dialog.destroy ();

        if (response != Gtk.ResponseType.YES) {
            return;
        }

        string layouts_csv = collect_layouts_csv ();
        string option = get_effective_option ();

        WMConfigModifier.XKBConfig? current_config = null;
        try {
            current_config = WMConfigModifier.read_from_wm (detected_wm);
        } catch (Error e) {
            current_config = null;
        }

        var xkb_config = new WMConfigModifier.XKBConfig ();
        xkb_config.layout = layouts_csv;
        string current_opts = (current_config != null) ? current_config.options : "";
        xkb_config.options = merge_grp_option (current_opts, option);

        try {
            string config_path = WMDetector.get_config_path (detected_wm);
            WMConfigBackup.create_backup (config_path, WMDetector.get_name (detected_wm));

            if (!WMConfigModifier.apply_to_wm (detected_wm, xkb_config)) {
                show_error_dialog (
                    _("Failed to apply to WM"),
                    _("Could not modify %s configuration.").printf (WMDetector.get_name (detected_wm))
                );
                status_label.set_markup ("<span foreground='red'>✗ " +
                    _("Could not modify %s configuration.").printf (WMDetector.get_name (detected_wm)) +
                    "</span>");
                return;
            }

            status_label.show ();
        status_label.set_markup ("<span foreground='green'>✓ " +
                _("Changes saved. Restart your WM to see the result.") + "</span>");
            GLib.Timeout.add (5000, () => {
                clear_status ();
                return Source.REMOVE;
            });
        } catch (Error e) {
            show_error_dialog (_("Error applying to WM"), e.message);
            status_label.show ();
            status_label.set_markup ("<span foreground='red'>✗ " + e.message + "</span>");
        }
    }

    private void show_error_dialog (string title, string details) {
        var dialog = new Gtk.MessageDialog (
            this,
            Gtk.DialogFlags.MODAL,
            Gtk.MessageType.ERROR,
            Gtk.ButtonsType.CLOSE,
            "%s",
            title
        );
        dialog.secondary_text = details;
        dialog.run ();
        dialog.destroy ();
    }
}
