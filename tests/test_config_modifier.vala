using GLib;

void test_env_exports_idempotent() {
    string tmpfile = Path.build_filename(Environment.get_tmp_dir(),
                                          "kbd_test_%u.txt".printf(Random.next_int()));
    FileUtils.set_contents(tmpfile,
        "#!/bin/bash\nwaybar &\nwl-paste --watch cliphist store &\n");

    var cfg = new WMConfigModifier.XKBConfig();
    cfg.layout = "us,ru";
    cfg.options = "grp:alt_shift_toggle";

    try {
        WMConfigModifier.test_apply_env_exports(tmpfile, cfg);
        string after1; FileUtils.get_contents(tmpfile, out after1);

        WMConfigModifier.test_apply_env_exports(tmpfile, cfg);
        string after2; FileUtils.get_contents(tmpfile, out after2);

        assert_true(after1 == after2);
    } catch (Error e) {
        assert_not_reached();
    } finally {
        FileUtils.remove(tmpfile);
    }
}

void test_env_exports_preserves_content() {
    string tmpfile = Path.build_filename(Environment.get_tmp_dir(),
                                          "kbd_test_%u.txt".printf(Random.next_int()));
    FileUtils.set_contents(tmpfile,
        "#!/bin/bash\nwaybar &\nwl-paste --watch cliphist store &\n");

    var cfg = new WMConfigModifier.XKBConfig();
    cfg.layout = "us,ru";
    cfg.options = "grp:alt_shift_toggle";

    try {
        WMConfigModifier.test_apply_env_exports(tmpfile, cfg);
        string result; FileUtils.get_contents(tmpfile, out result);

        assert_true(result.contains("waybar &"));
        assert_true(result.contains("wl-paste"));
        assert_true(result.contains("BEGIN wl-kbd-config"));
        assert_true(result.contains("XKB_DEFAULT_LAYOUT=\"us,ru\""));
        assert_true(result.contains("XKB_DEFAULT_OPTIONS=\"grp:alt_shift_toggle\""));
    } catch (Error e) {
        assert_not_reached();
    } finally {
        FileUtils.remove(tmpfile);
    }
}

void test_env_exports_migrates_legacy_markers() {
    string tmpfile = Path.build_filename(Environment.get_tmp_dir(),
                                          "kbd_test_%u.txt".printf(Random.next_int()));
    FileUtils.set_contents(tmpfile,
        "before\n# BEGIN labwc-kbd\nexport XKB_DEFAULT_LAYOUT=\"de\"\n# END labwc-kbd\nafter\n");

    var cfg = new WMConfigModifier.XKBConfig();
    cfg.layout = "us,ru";
    cfg.options = "grp:alt_shift_toggle";

    try {
        WMConfigModifier.test_apply_env_exports(tmpfile, cfg);
        string result; FileUtils.get_contents(tmpfile, out result);

        assert_false(result.contains("# BEGIN labwc-kbd"));
        assert_false(result.contains("# END labwc-kbd"));
        assert_true(result.contains("# BEGIN wl-kbd-config"));
        assert_true(result.contains("# END wl-kbd-config"));
    } catch (Error e) {
        assert_not_reached();
    } finally {
        FileUtils.remove(tmpfile);
    }
}

void test_options_merge_preserves_compose() {
    string existing = "compose:ralt,caps:escape,grp:shifts_toggle";
    string new_grp = "grp:alt_shift_toggle";

    var parts = new GLib.Array<string>();
    foreach (unowned string p in existing.split(",")) {
        string t = p.strip();
        if (t != "" && !t.has_prefix("grp:")) {
            parts.append_val(t);
        }
    }
    if (new_grp != "") parts.append_val(new_grp);
    string merged = string.joinv(",", parts.data);

    assert_true(merged.contains("compose:ralt"));
    assert_true(merged.contains("caps:escape"));
    assert_true(merged.contains("grp:alt_shift_toggle"));
    assert_false(merged.contains("grp:shifts_toggle"));
    int count = 0;
    foreach (unowned string p in merged.split(",")) {
        if (p.has_prefix("grp:")) count++;
    }
    assert_true(count == 1);
}

void test_flag_utils_strip_variant_to_base() {
    assert_true(FlagUtils.get_layout_base_code("us(intl)") == "us");
    assert_true(FlagUtils.get_layout_base_code("de(nodeadkeys)") == "de");
}

void test_flag_utils_arabic_uses_existing_flag_asset_code() {
    assert_true(FlagUtils.get_layout_icon_code("ara") == "ar");
    assert_true(FlagUtils.get_layout_icon_code("arabic") == "ar");
}

void test_flag_utils_estonian_uses_et_asset_code() {
    assert_true(FlagUtils.get_layout_icon_code("ee") == "et");
    assert_true(FlagUtils.get_layout_icon_code("estonian") == "et");
}

public static int main(string[] args) {
    GLib.Test.init(ref args);
    GLib.Test.add_func("/config/env_exports_idempotent",    test_env_exports_idempotent);
    GLib.Test.add_func("/config/env_exports_preserves",     test_env_exports_preserves_content);
    GLib.Test.add_func("/config/options_merge_preserves",   test_options_merge_preserves_compose);
    GLib.Test.add_func("/config/migrate_legacy_markers",    test_env_exports_migrates_legacy_markers);
    GLib.Test.add_func("/flags/strip_variant_to_base",      test_flag_utils_strip_variant_to_base);
    GLib.Test.add_func("/flags/arabic_maps_to_ar",          test_flag_utils_arabic_uses_existing_flag_asset_code);
    GLib.Test.add_func("/flags/estonian_maps_to_et",        test_flag_utils_estonian_uses_et_asset_code);
    return GLib.Test.run();
}
