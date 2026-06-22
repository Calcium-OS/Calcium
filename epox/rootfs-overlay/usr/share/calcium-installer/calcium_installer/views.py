import subprocess

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib, Pango, Gio


class WelcomePage(Adw.NavigationPage):
    def __init__(self):
        super().__init__(title="Welcome")

        clamp = Adw.Clamp(maximum_width=600)
        self.set_child(clamp)

        box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=24,
            halign=Gtk.Align.CENTER,
            valign=Gtk.Align.CENTER,
        )
        box.set_margin_top(80)
        box.set_margin_bottom(40)
        box.set_margin_start(24)
        box.set_margin_end(24)
        clamp.set_child(box)

        icon_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=8, halign=Gtk.Align.CENTER
        )
        icon = Gtk.Image.new_from_icon_name("computer-symbolic")
        icon.set_pixel_size(96)
        icon.add_css_class("dim-label")
        icon_box.append(icon)

        title = Gtk.Label(label="Install Calcium OS")
        title.add_css_class("display")
        title.set_wrap(True)
        icon_box.append(title)

        subtitle = Gtk.Label(
            label="A modern Gentoo-based Linux distribution\nwith GNOME desktop and OpenRC"
        )
        subtitle.add_css_class("title-4")
        subtitle.set_wrap(True)
        subtitle.set_justify(Gtk.Justification.CENTER)
        icon_box.append(subtitle)
        box.append(icon_box)

        cards = Adw.Clamp(maximum_width=500)
        cards_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        cards.set_child(cards_box)
        box.append(cards)

        info1 = self._make_info_row(
            "drive-multidisk-symbolic",
            "Guided Partitioning",
            "Automatic disk setup with EFI boot",
        )
        cards_box.append(info1)

        info2 = self._make_info_row(
            "avatar-default-symbolic",
            "User Setup",
            "Create your user account and password",
        )
        cards_box.append(info2)

        info3 = self._make_info_row(
            "selection-mode-checked-symbolic",
            "Ready in Minutes",
            "Full GNOME desktop pre-configured",
        )
        cards_box.append(info3)

        button_box = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, halign=Gtk.Align.CENTER, spacing=12
        )
        button_box.set_margin_top(32)
        box.append(button_box)

        self.install_btn = Gtk.Button(
            label="Install Calcium OS", halign=Gtk.Align.CENTER
        )
        self.install_btn.add_css_class("suggested-action")
        self.install_btn.add_css_class("pill")
        self.install_btn.set_size_request(280, -1)
        button_box.append(self.install_btn)

    def _make_info_row(self, icon_name, title, desc):
        row = Adw.ActionRow(title=title, subtitle=desc)
        row.set_icon_name(icon_name)
        return row


class DiskPage(Adw.NavigationPage):
    def __init__(self):
        super().__init__(title="Select Disk")

        clamp = Adw.Clamp(maximum_width=600)
        self.set_child(clamp)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(24)
        box.set_margin_end(24)
        clamp.set_child(box)

        header = Gtk.Label(
            label="Where would you like to install Calcium OS?", halign=Gtk.Align.START
        )
        header.add_css_class("title-1")
        header.set_wrap(True)
        box.append(header)

        subtitle = Gtk.Label(
            label="The selected drive will be completely erased.",
            halign=Gtk.Align.START,
            wrap=True,
        )
        subtitle.add_css_class("body")
        subtitle.add_css_class("dim-label")
        box.append(subtitle)

        self.disk_group = Gtk.ListBox()
        self.disk_group.add_css_class("boxed-list")
        box.append(self.disk_group)

        self.warning_revealer = Gtk.Revealer()
        warning = Adw.Banner(
            title="All data on this drive will be erased during installation.",
            button_label="I understand",
        )
        warning.set_revealed(True)
        warning.connect("button_clicked", lambda w: w.set_revealed(False))
        self.warning_revealer.set_child(warning)
        box.append(self.warning_revealer)

        self.continue_btn = Gtk.Button(
            label="Continue", halign=Gtk.Align.END, sensitive=False
        )
        self.continue_btn.add_css_class("suggested-action")
        self.continue_btn.add_css_class("pill")
        box.append(self.continue_btn)

        self.selected_disk = None
        self.disk_rows = []

    def set_disks(self, disks, on_selected=None):
        for row in self.disk_rows:
            self.disk_group.remove(row)
        self.disk_rows.clear()

        for disk in disks:
            size = disk["size"]
            name = disk["name"]
            model = disk["model"]
            tran = disk["tran"]
            desc = f"{size}"
            if model:
                desc = f"{model}  ·  {desc}"
            if tran:
                desc = f"{desc}  ·  {tran}"
            row = Adw.ActionRow(title=f"/dev/{name}", subtitle=desc)
            if not disk["rotational"]:
                chip = Gtk.Label(label="SSD")
                chip.add_css_class("tag")
                chip.add_css_class("accent")
                row.add_suffix(chip)
            radio = Gtk.CheckButton()
            radio.set_group(None)
            row.set_activatable_widget(radio)
            row.add_prefix(radio)
            self.disk_group.append(row)
            self.disk_rows.append((row, radio, disk))

        def on_row_activated(box, row):
            for r, radio, disk in self.disk_rows:
                if r == row:
                    radio.set_active(True)
                    self.selected_disk = disk
                    self.continue_btn.set_sensitive(True)
                    if on_selected:
                        on_selected(disk)
                    break

        self.disk_group.connect("row-activated", on_row_activated)

    def get_selected_disk(self):
        return self.selected_disk


class UserPage(Adw.NavigationPage):
    def __init__(self):
        super().__init__(title="Set Up User")

        clamp = Adw.Clamp(maximum_width=500)
        self.set_child(clamp)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(24)
        box.set_margin_end(24)
        clamp.set_child(box)

        header = Gtk.Label(
            label="Create your account", halign=Gtk.Align.START, wrap=True
        )
        header.add_css_class("title-1")
        box.append(header)

        group = Adw.PreferencesGroup(title="User Account")
        box.append(group)

        self.hostname_entry = Adw.EntryRow(title="Hostname")
        self.hostname_entry.set_text("calcium")
        group.add(self.hostname_entry)

        self.username_entry = Adw.EntryRow(title="Username")
        self.username_entry.set_text("calcium")
        group.add(self.username_entry)

        self.password_entry = Adw.PasswordEntryRow(title="Password")
        group.add(self.password_entry)

        self.confirm_entry = Adw.PasswordEntryRow(title="Confirm Password")
        group.add(self.confirm_entry)

        adv_group = Adw.PreferencesGroup(title="Advanced")
        adv_group.set_margin_top(16)
        box.append(adv_group)

        tz_row = Adw.ComboRow(title="Timezone", subtitle="Select your timezone")

        try:
            import zoneinfo

            all_tzs = sorted(zoneinfo.available_timezones())
        except ImportError:
            all_tzs = [
                "UTC",
                "America/New_York",
                "America/Chicago",
                "America/Denver",
                "America/Los_Angeles",
                "Europe/London",
                "Europe/Berlin",
                "Europe/Moscow",
                "Asia/Tokyo",
                "Asia/Shanghai",
                "Asia/Kolkata",
                "Australia/Sydney",
                "Pacific/Auckland",
            ]
        tz_model = Gtk.StringList.new(all_tzs)
        tz_row.set_model(tz_model)
        try:
            tz_result = subprocess.run(
                ["cat", "/etc/timezone"], capture_output=True, text=True
            )
            current_tz = tz_result.stdout.strip()
        except Exception:
            current_tz = "UTC"

        for i, tz in enumerate(all_tzs):
            if tz == current_tz:
                tz_row.set_selected(i)
                break

        def on_tz_changed(*args):
            validate()

        tz_row.connect("notify::selected", on_tz_changed)
        adv_group.add(tz_row)
        self.tz_row = tz_row

        button_box = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, halign=Gtk.Align.END, spacing=12
        )
        button_box.set_margin_top(16)
        box.append(button_box)

        self.continue_btn = Gtk.Button(label="Continue", sensitive=False)
        self.continue_btn.add_css_class("suggested-action")
        self.continue_btn.add_css_class("pill")
        button_box.append(self.continue_btn)

        def validate(*_args):
            valid = True
            if not self.username_entry.get_text().strip():
                valid = False
            if not self.password_entry.get_text():
                valid = False
            if self.password_entry.get_text() != self.confirm_entry.get_text():
                valid = False
            self.continue_btn.set_sensitive(valid)

        self.username_entry.connect("changed", validate)
        self.password_entry.connect("changed", validate)
        self.confirm_entry.connect("changed", validate)
        validate()

    def get_config(self):
        pw = self.password_entry.get_text()
        tz_iter = self.tz_row.get_selected_item()
        tz = tz_iter.get_string() if tz_iter else "UTC"
        return {
            "hostname": self.hostname_entry.get_text().strip(),
            "username": self.username_entry.get_text().strip(),
            "password": pw,
            "root_password": pw,
            "timezone": tz,
        }


class SummaryPage(Adw.NavigationPage):
    def __init__(self):
        super().__init__(title="Summary")

        clamp = Adw.Clamp(maximum_width=600)
        self.set_child(clamp)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(24)
        box.set_margin_end(24)
        clamp.set_child(box)

        header = Gtk.Label(
            label="Review your settings", halign=Gtk.Align.START, wrap=True
        )
        header.add_css_class("title-1")
        box.append(header)

        self.disk_group = Adw.PreferencesGroup()
        box.append(self.disk_group)
        self.user_group = Adw.PreferencesGroup()
        box.append(self.user_group)

        warn = Adw.StatusPage(
            title="Ready to install",
            description="Calcium OS will be installed with the settings above. "
            "This may take a few minutes.\n\n"
            "The target disk will be erased.",
        )
        warn.set_icon_name("dialog-warning-symbolic")
        box.append(warn)

        button_box = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, halign=Gtk.Align.END, spacing=12
        )
        button_box.set_margin_top(16)
        box.append(button_box)

        self.install_btn = Gtk.Button(label="Install")
        self.install_btn.add_css_class("suggested-action")
        self.install_btn.add_css_class("pill")
        button_box.append(self.install_btn)

    def set_config(self, config, disk_info):
        for child in list(self.disk_group):
            self.disk_group.remove(child)
        for child in list(self.user_group):
            self.user_group.remove(child)

        disk_row = Adw.ActionRow(title="Target Drive", subtitle=disk_info["path"])
        disk_size = Gtk.Label(label=disk_info["size"])
        disk_size.add_css_class("dim-label")
        disk_row.add_suffix(disk_size)
        self.disk_group.add(disk_row)

        disk_layout = Adw.ActionRow(
            title="Layout", subtitle="EFI System Partition (512MB) + ext4 root"
        )
        self.disk_group.add(disk_layout)

        host_row = Adw.ActionRow(title="Hostname", subtitle=config["hostname"])
        self.user_group.add(host_row)

        user_row = Adw.ActionRow(title="User", subtitle=config["username"])
        self.user_group.add(user_row)

        tz_row = Adw.ActionRow(title="Timezone", subtitle=config["timezone"])
        self.user_group.add(tz_row)


class InstallPage(Adw.NavigationPage):
    def __init__(self):
        super().__init__(title="Installing")
        self.set_can_pop(False)

        clamp = Adw.Clamp(maximum_width=600)
        self.set_child(clamp)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(40)
        box.set_margin_bottom(24)
        box.set_margin_start(24)
        box.set_margin_end(24)
        clamp.set_child(box)

        spinner = Gtk.Spinner()
        spinner.set_size_request(64, 64)
        spinner.start()
        spinner_box = Gtk.Box(halign=Gtk.Align.CENTER)
        spinner_box.append(spinner)
        box.append(spinner_box)

        self.status_label = Gtk.Label(
            label="Preparing installation...", halign=Gtk.Align.CENTER, wrap=True
        )
        self.status_label.add_css_class("title-2")
        box.append(self.status_label)

        self.progress_bar = Gtk.ProgressBar(show_text=False)
        self.progress_bar.add_css_class("osd")
        box.append(self.progress_bar)

        scrolled = Gtk.ScrolledWindow(vexpand=True, hexpand=True)
        scrolled.set_min_content_height(180)
        self.log_buffer = Gtk.TextBuffer()
        self.log_view = Gtk.TextView(
            buffer=self.log_buffer,
            editable=False,
            cursor_visible=False,
            wrap_mode=Gtk.WrapMode.WORD_CHAR,
        )
        self.log_view.add_css_class("monospace")
        self.log_view.set_size_request(-1, 180)
        scrolled.set_child(self.log_view)
        box.append(scrolled)

    def update_progress(self, step, pct, message):
        self.progress_bar.set_fraction(pct / 100.0)
        labels = {
            "partitioning": "Partitioning disk...",
            "formatting": "Formatting partitions...",
            "mounting": "Mounting partitions...",
            "copying": "Copying system files...",
            "configuring": "Configuring system...",
            "finished": "Installation complete!",
        }
        self.status_label.set_text(labels.get(step, message))
        end_iter = self.log_buffer.get_end_iter()
        self.log_buffer.insert(end_iter, f"[{step}] {message}\n")
        adj = (
            self.log_view.get_parent().get_vadjustment()
            if hasattr(self.log_view, "get_parent")
            else None
        )

    def set_complete(self):
        self.progress_bar.set_fraction(1.0)
        self.progress_bar.remove_css_class("osd")
        self.status_label.set_text("Installation complete!")


class FinishPage(Adw.NavigationPage):
    def __init__(self):
        super().__init__(title="Complete")

        clamp = Adw.Clamp(maximum_width=500)
        self.set_child(clamp)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        box.set_margin_top(80)
        box.set_margin_bottom(40)
        box.set_margin_start(24)
        box.set_margin_end(24)
        clamp.set_child(box)

        status = Adw.StatusPage(
            title="Installation Complete",
            description="Calcium OS has been installed.\nYou can now reboot and enjoy your new system.",
            icon_name="checkmark-circle-outline-symbolic",
        )
        box.append(status)

        button_box = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, halign=Gtk.Align.CENTER, spacing=12
        )
        box.append(button_box)

        self.reboot_btn = Gtk.Button(label="Reboot")
        self.reboot_btn.add_css_class("suggested-action")
        self.reboot_btn.add_css_class("pill")
        self.reboot_btn.set_size_request(200, -1)
        button_box.append(self.reboot_btn)

        self.shutdown_btn = Gtk.Button(label="Shut Down")
        self.shutdown_btn.add_css_class("pill")
        self.shutdown_btn.set_size_request(200, -1)
        button_box.append(self.shutdown_btn)
