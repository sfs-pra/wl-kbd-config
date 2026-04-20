using GLib;

void test_snapshot_restore () {
    var initial = new SettingsStateSnapshot ("us,ru", "grp:alt_shift_toggle");
    var current = new SettingsStateSnapshot ("de", "grp:ctrl_shift_toggle");

    current.restore_from (initial);

    assert_true (current.layouts_csv == "us,ru");
    assert_true (current.option == "grp:alt_shift_toggle");
}

public static int main (string[] args) {
    GLib.Test.init (ref args);
    GLib.Test.add_func ("/settings/snapshot_restore", test_snapshot_restore);
    return GLib.Test.run ();
}
