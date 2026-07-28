import gi
gi.require_version('GLib', '2.0')
gi.require_version('Gio', '2.0')
from gi.repository import GLib, Gio
import subprocess
import os
import signal
import sys
from pathlib import Path

BUS_NAME = 'org.gnome.SessionManager'
OBJ_PATH = '/org/gnome/SessionManager'

INTROSPECTION_XML = '''<?xml version="1.0"?>
<node>
  <interface name="org.gnome.SessionManager">
    <method name="Logout"><arg type="u" name="mode" direction="in"/></method>
    <method name="Shutdown"/>
    <method name="Reboot"/>
    <method name="CanShutdown"><arg type="b" name="result" direction="out"/></method>
    <method name="IsInhibited"><arg type="u" name="flags" direction="in"/><arg type="b" name="result" direction="out"/></method>
    <property name="SessionIsActive" type="b" access="read"/>
    <signal name="InhibitorAdded"><arg type="o" direction="out"/></signal>
    <signal name="InhibitorRemoved"><arg type="o" direction="out"/></signal>
  </interface>
</node>'''

def call_login1(method, arg):
    try:
        con = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        proxy = Gio.DBusProxy.new_sync(
            con, Gio.DBusProxyFlags.NONE, None,
            'org.freedesktop.login1', '/org/freedesktop/login1',
            'org.freedesktop.login1.Manager', None)
        proxy.call_sync(method, GLib.Variant('(b)', (arg,)),
                        Gio.DBusCallFlags.NONE, -1, None)
        return True
    except Exception as e:
        print(f'login1 {method} failed: {e}', file=sys.stderr)
        return False

def handle_method(connection, sender, object_path, interface_name, method_name, params, invocation):
    print(f'<- {method_name}', file=sys.stderr)
    try:
        if method_name == 'CanShutdown':
            invocation.return_value(GLib.Variant('(b)', (True,)))
        elif method_name == 'Shutdown':
            invocation.return_value(None)
            GLib.timeout_add(200, call_login1, 'PowerOff', True)
        elif method_name == 'Reboot':
            invocation.return_value(None)
            GLib.timeout_add(200, call_login1, 'Reboot', True)
        elif method_name == 'Logout':
            invocation.return_value(None)
            GLib.timeout_add(200, lambda: subprocess.Popen(['gnome-session-quit', '--logout']))
        elif method_name == 'IsInhibited':
            invocation.return_value(GLib.Variant('(b)', (False,)))
        else:
            invocation.return_dbus_error(
                'org.gnome.SessionManager.Error',
                f'Unknown method: {method_name}')
    except Exception as e:
        print(f'Error handling {method_name}: {e}', file=sys.stderr)
        invocation.return_dbus_error(
            'org.gnome.SessionManager.Error', str(e))

def handle_get(connection, sender, object_path, interface_name, property_name):
    if property_name == 'SessionIsActive':
        return GLib.Variant('b', True)
    return None

def handle_set(connection, sender, object_path, interface_name, property_name, value):
    pass

def handle_getall(connection, sender, object_path, interface_name):
    return {'SessionIsActive': GLib.Variant('b', True)}

def main():
    pidfile = Path.home() / '.gnome-session-manager-stub.pid'
    if pidfile.exists():
        try:
            old = int(pidfile.read_text().strip())
            os.kill(old, signal.SIGTERM)
        except (ProcessLookupError, ValueError, OSError):
            pass
    pidfile.write_text(str(os.getpid()))

    node_info = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION_XML)
    con = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    reg_id = con.register_object(
        OBJ_PATH, node_info.interfaces[0],
        handle_method, handle_get, handle_set)

    bus_id = Gio.bus_own_name_on_connection(
        con, BUS_NAME,
        Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT,
        lambda con, name: print(f'Acquired {name}', file=sys.stderr),
        lambda con, name: print(f'Lost {name}', file=sys.stderr))

    print('Running org.gnome.SessionManager stub on session bus', file=sys.stderr)
    try:
        loop = GLib.MainLoop()
        loop.run()
    except KeyboardInterrupt:
        pass
    finally:
	if bus_id:
            Gio.bus_unown_name(bus_id)
        con.unregister_object(reg_id)
        pidfile.unlink(missing_ok=True)

if __name__ == '__main__':
    main()






