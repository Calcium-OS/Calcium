#!/usr/bin/env gjs

// resizable-bar-warning.js
//
// Native GTK4/GJS warning window for the Resizable BAR checker.
//
// This is ONLY the graphical warning interface. It performs no
// hardware detection. The Bash checker decides when to invoke it
// and passes the affected GPU and the explanation as arguments.
//
// GJS classic import style is used so that the script runs with:
//
//   gjs /usr/local/bin/resizable-bar-warning.js "GPU" "reason"

imports.gi.versions.Gtk = '4.0';

const Gtk = imports.gi.Gtk;
const Gio = imports.gi.Gio;

// Read the arguments directly from ARGV. They are never passed
// to the application (e.g. application.run(ARGV)), because GIO
// would try to open them as files and fail with
// "This application can not open files."
const gpu = ARGV.length > 0 ? ARGV[0] : 'Unknown GPU';
const reason = ARGV.length > 1
    ? ARGV[1]
    : 'Resizable BAR is supported but does not appear to be fully enabled.';

const application = new Gtk.Application({
    application_id: 'org.local.ResizableBarChecker',
    flags: Gio.ApplicationFlags.NON_UNIQUE
});

// Keep a module-level reference to the window. Without it the
// GJS garbage collector can collect the wrapper after the
// "activate" callback returns, destroying the window and
// quitting the application a few seconds after it appears.
let warningWindow = null;

application.connect('activate', function(app) {

    const window = new Gtk.ApplicationWindow({
        application: app,
        title: 'Resizable BAR is disabled',
        default_width: 620,
        resizable: false
    });

    warningWindow = window;

    // Quit the process when the window is closed.
    window.connect('close-request', function() {
        app.quit();
        return false;
    });

    const outer = new Gtk.Box({
        orientation: Gtk.Orientation.VERTICAL,
        spacing: 0,
        margin_top: 28,
        margin_bottom: 28,
        margin_start: 32,
        margin_end: 32
    });

    // --------------------------------------------------------
    // Header
    // --------------------------------------------------------

    const header = new Gtk.Box({
        orientation: Gtk.Orientation.HORIZONTAL,
        spacing: 18
    });

    const icon = new Gtk.Image({
        icon_name: 'dialog-warning-symbolic',
        pixel_size: 48,
        valign: Gtk.Align.START
    });

    header.append(icon);

    const titleBox = new Gtk.Box({
        orientation: Gtk.Orientation.VERTICAL,
        spacing: 5,
        hexpand: true
    });

    const title = new Gtk.Label({
        label: 'Resizable BAR is disabled',
        xalign: 0,
        wrap: true
    });

    title.add_css_class('title-2');

    const gpuLabel = new Gtk.Label({
        label: gpu,
        xalign: 0,
        wrap: true
    });

    gpuLabel.add_css_class('dim-label');

    titleBox.append(title);
    titleBox.append(gpuLabel);

    header.append(titleBox);
    outer.append(header);

    // --------------------------------------------------------
    // Separator
    // --------------------------------------------------------

    const separator = new Gtk.Separator({
        orientation: Gtk.Orientation.HORIZONTAL,
        margin_top: 22,
        margin_bottom: 22
    });

    outer.append(separator);

    // --------------------------------------------------------
    // Explanation
    // --------------------------------------------------------

    const explanation = new Gtk.Label({
        label: reason,
        xalign: 0,
        wrap: true,
        max_width_chars: 75
    });

    outer.append(explanation);

    // --------------------------------------------------------
    // Instructions
    // --------------------------------------------------------

    const instructionsTitle = new Gtk.Label({
        label: 'How to enable Resizable BAR',
        xalign: 0,
        margin_top: 24,
        margin_bottom: 10
    });

    instructionsTitle.add_css_class('heading');

    outer.append(instructionsTitle);

    const instructions = new Gtk.Label({
        label:
            '1. Restart the computer and enter the motherboard UEFI/BIOS.\n' +
            '2. Disable CSM / Compatibility Support Module.\n' +
            '3. Enable "Above 4G Decoding".\n' +
            '4. Enable "Resizable BAR", "Re-Size BAR", or "Smart Access Memory".\n' +
            '5. Save the changes and reboot.\n' +
            '6. This checker will automatically check again.',
        xalign: 0,
        wrap: true,
        max_width_chars: 75
    });

    outer.append(instructions);

    // --------------------------------------------------------
    // Note
    // --------------------------------------------------------

    const note = new Gtk.Label({
        label:
            'The exact option names vary between motherboard manufacturers.\n' +
            'This checker does not make any BIOS or system changes.',
        xalign: 0,
        wrap: true,
        margin_top: 20
    });

    note.add_css_class('dim-label');

    outer.append(note);

    // --------------------------------------------------------
    // Close button
    // --------------------------------------------------------

    const buttonBox = new Gtk.Box({
        orientation: Gtk.Orientation.HORIZONTAL,
        halign: Gtk.Align.END,
        margin_top: 25
    });

    const closeButton = new Gtk.Button({
        label: 'Close'
    });

    closeButton.add_css_class('suggested-action');

    closeButton.connect('clicked', function() {
        window.close();
    });

    buttonBox.append(closeButton);
    outer.append(buttonBox);

    window.set_child(outer);

    window.present();
});

application.run([]);
