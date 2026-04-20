public class SettingsStateSnapshot : Object {
    public string layouts_csv { get; set; default = ""; }
    public string option { get; set; default = ""; }

    public SettingsStateSnapshot (string layouts_csv = "", string option = "") {
        this.layouts_csv = layouts_csv;
        this.option = option;
    }

    public void restore_from (SettingsStateSnapshot other) {
        layouts_csv = other.layouts_csv;
        option = other.option;
    }
}
