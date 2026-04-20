using Gtk;

public class WlKbdConfigApp : Gtk.Application {
    public WlKbdConfigApp () {
        Object (
            application_id: "org.example.wlkbdconfig",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate () {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain ("wl-kbd-config", "/usr/share/locale");
        Intl.bind_textdomain_codeset ("wl-kbd-config", "UTF-8");
        Intl.textdomain ("wl-kbd-config");

        var win = new SettingsWindow (this);
        win.set_icon_name ("input-keyboard");
        win.present ();
    }
}

public static int main (string[] args) {
    var app = new WlKbdConfigApp ();
    return app.run (args);
}
