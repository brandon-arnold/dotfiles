"""voice_overlay — a keyboard-exclusive layer-shell overlay that catches pasted text.

Shared by voice-cmd and ask. Wispr Flow pastes its transcript into whatever has
keyboard focus; this overlay takes that focus (wlr layer shell, EXCLUSIVE keyboard
mode) so the text lands here instead of in the real window, and the caller gets it
once it has stopped changing.

    text, ok, msg = capture(submit=handler)

`submit(text)` runs once the pasted text has been stable for `idle_ms`; it returns
(ok, msg) and the overlay shows msg briefly before closing. SIGUSR1 (sent by the
key-release handler) switches the status line to "transcribing…". Escape cancels.
"""
import signal

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, GtkLayerShell, GLib, Gdk  # noqa: E402

CSS = b"""
window { background: transparent; }
.box { background: rgba(30,30,36,0.95); border: 1px solid #5a5f73;
       border-radius: 10px; padding: 12px 18px; }
.status { color: #9aa0b4; font-size: 12px; }
entry { background: transparent; border: none; color: #e6e6ea;
        font-size: 20px; min-width: 520px; }
.ok { color: #8fd18f; } .err { color: #e08a8a; }
.invisible, .invisible * { opacity: 0; background: transparent; border: none;
                           box-shadow: none; min-width: 1px; min-height: 1px; }
"""


def capture(status="listening…  (hold the key, speak, release)", idle_ms=700,
            wait_s=20, max_hold_s=180, show_result_ms=500, error_ms=1500, submit=None,
            top_margin=160, invisible=False):
    """Show the overlay and return (text, ok, msg). text is None on cancel/timeout.

    The wait for text is `wait_s` counted from the key RELEASE (SIGUSR1), since
    Wispr only transcribes after release; while the key is held the only limit
    is `max_hold_s`.

    invisible=True draws nothing at all: the surface still exists (it has to, to
    hold keyboard focus), but it is fully transparent and closes the moment the
    text has been handed to `submit`.
    """
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    win = Gtk.Window(title="voice-overlay")
    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, top_margin)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.EXCLUSIVE)

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.get_style_context().add_class("box")
    label = Gtk.Label(label=status, xalign=0)
    label.get_style_context().add_class("status")
    entry = Gtk.Entry()
    box.pack_start(label, False, False, 0)
    box.pack_start(entry, False, False, 0)
    win.add(box)
    if invisible:
        win.get_style_context().add_class("invisible")
        box.get_style_context().add_class("invisible")
        win.set_opacity(0.0)
        win.set_default_size(1, 1)
        show_result_ms = error_ms = 1

    result = {"text": None, "ok": False, "msg": "cancelled"}
    state = {"idle_id": None, "done": False, "giveup_id": None}

    def finish(ok, msg):
        if state["done"]:
            return
        state["done"] = True
        result["ok"], result["msg"] = ok, msg
        label.set_text(("✔ " if ok else "✘ ") + msg)
        label.get_style_context().add_class("ok" if ok else "err")
        GLib.timeout_add(show_result_ms if ok else error_ms, Gtk.main_quit)

    def do_submit():
        state["idle_id"] = None
        text = entry.get_text()
        if not text.strip():
            return False
        entry.set_editable(False)
        result["text"] = text
        if submit:
            label.set_text("working…")
            ok, msg = submit(text)
        else:
            ok, msg = True, "ok"
        finish(ok, msg)
        return False

    def on_changed(_entry):
        if state["done"]:
            return
        if state["idle_id"]:
            GLib.source_remove(state["idle_id"])
        state["idle_id"] = GLib.timeout_add(idle_ms, do_submit)
        label.set_text("…")

    def on_key(_w, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()
            return True
        if event.keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            if state["idle_id"]:
                GLib.source_remove(state["idle_id"])
            do_submit()
            return True
        return False

    def give_up():
        if not state["done"] and not entry.get_text():
            finish(False, f"nothing arrived from Wispr Flow in {wait_s} s after release")
        return False

    def on_released(*_):
        if not state["done"] and not entry.get_text():
            label.set_text("transcribing…")
            if state["giveup_id"]:
                GLib.source_remove(state["giveup_id"])
            state["giveup_id"] = GLib.timeout_add_seconds(wait_s, give_up)
        return True

    def hold_limit():
        if not state["done"] and not entry.get_text():
            finish(False, f"key held for {max_hold_s} s with no text, giving up")
        return False

    entry.connect("changed", on_changed)
    win.connect("key-press-event", on_key)
    win.connect("destroy", Gtk.main_quit)
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, on_released)
    state["giveup_id"] = GLib.timeout_add_seconds(max_hold_s, hold_limit)

    win.show_all()
    entry.grab_focus()
    Gtk.main()
    win.disconnect_by_func(Gtk.main_quit)   # destroying after the loop ended must not re-quit
    win.destroy()
    return result["text"], result["ok"], result["msg"]
