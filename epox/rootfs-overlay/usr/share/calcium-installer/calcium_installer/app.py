import os
import sys
import threading
import subprocess

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib, Gio

from .backend import InstallerBackend
from .views import WelcomePage, DiskPage, UserPage, SummaryPage, InstallPage, FinishPage


class CalciumInstallerApp(Adw.Application):
    INSTALL_MOUNT = "/mnt/gentoo"

    def __init__(self):
        super().__init__(
            application_id="org.calcium.installer",
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        self.backend = InstallerBackend()
        self.config = {}
        self.selected_disk = None
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        self.win = Adw.ApplicationWindow(application=app)
        self.win.set_default_size(720, 620)
        self.win.set_title("Calcium OS Installer")

        self.nav = Adw.NavigationView()
        self.win.set_content(self.nav)

        self.welcome_page = WelcomePage()
        self.disk_page = DiskPage()
        self.user_page = UserPage()
        self.summary_page = SummaryPage()
        self.install_page = InstallPage()
        self.finish_page = FinishPage()

        self.nav.push(self.welcome_page)

        self.welcome_page.install_btn.connect("clicked", lambda btn: self._go_to_disk())

        self.disk_page.continue_btn.connect("clicked", lambda btn: self._go_to_user())

        self.user_page.continue_btn.connect(
            "clicked", lambda btn: self._go_to_summary()
        )

        self.summary_page.install_btn.connect(
            "clicked", lambda btn: self._start_installation()
        )

        self.finish_page.reboot_btn.connect("clicked", lambda btn: self._reboot())

        self.finish_page.shutdown_btn.connect("clicked", lambda btn: self._shutdown())

        self.win.present()

    def _go_to_disk(self):
        self.nav.push(self.disk_page)
        disks = self.backend.get_disks()
        if not disks:
            dialog = Adw.AlertDialog(
                heading="No disks found",
                body="No available disks detected. Make sure a drive is connected.",
            )
            dialog.add_response("ok", "OK")
            dialog.present(self.win)
            return
        self.disk_page.set_disks(disks)

    def _go_to_user(self):
        self.selected_disk = self.disk_page.get_selected_disk()
        if not self.selected_disk:
            return
        self.nav.push(self.user_page)

    def _go_to_summary(self):
        self.config.update(self.user_page.get_config())
        self.summary_page.set_config(self.config, self.selected_disk)
        self.nav.push(self.summary_page)

    def _start_installation(self):
        if not self.selected_disk:
            return
        self.config["disk_path"] = self.selected_disk["path"]
        self.nav.push(self.install_page)

        def install_thread():
            try:
                self.backend.complete_installation(
                    self.INSTALL_MOUNT, self.config, progress_callback=self._progress_cb
                )
            except Exception as e:
                GLib.idle_add(self._handle_error, str(e))
                return
            GLib.idle_add(self._installation_done)

        thread = threading.Thread(target=install_thread, daemon=True)
        thread.start()

    def _progress_cb(self, step, pct, message):
        GLib.idle_add(self.install_page.update_progress, step, pct, message)
        return True

    def _handle_error(self, msg):
        self.install_page.update_progress("error", 0, f"ERROR: {msg}")
        dialog = Adw.AlertDialog(
            heading="Installation Failed",
            body=f"An error occurred during installation:\n\n{msg}",
        )
        dialog.add_response("ok", "OK")
        dialog.present(self.win)

    def _installation_done(self):
        self.install_page.set_complete()
        self.nav.push(self.finish_page)

    def _reboot(self):
        subprocess.run(["reboot"])

    def _shutdown(self):
        subprocess.run(["poweroff"])
