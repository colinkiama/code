/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Colin Kiama <colinkiama@gmail.com>
 */

public class Code.DocumentViewNext : Gtk.Box {
     public enum TargetType {
        URI_LIST
    }

    public unowned Scratch.MainWindow window { get; construct; }
    public signal void request_placeholder ();

    public bool is_closing = false;
    public bool outline_visible { get; set; default = false; }
    public int outline_width { get; set; }


    private Hdy.TabView tab_view;
    private Hdy.TabBar tab_bar;

    public DocumentViewNext (Scratch.MainWindow window) {
        Object (
            window: window,
            orientation: Gtk.Orientation.VERTICAL,
            hexpand: true,
            vexpand: true
        );
    }

    construct {
        var app_instance = (Gtk.Application) GLib.Application.get_default ();
        tab_view = new Hdy.TabView () {
            hexpand = true,
            vexpand = true
        };

        var new_tab_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
            relief = Gtk.ReliefStyle.NONE,
            tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_NEW_TAB),
                _("New Tab")
            )
        };

        new_tab_button.clicked.connect (() => {
            print ("Hello Universe!");
        });

        var tab_history_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("document-open-recent-symbolic", Gtk.IconSize.MENU),
            tooltip_text = _("Closed Tabs"),
            use_popover = false
        };

        tab_bar = new Hdy.TabBar () {
            autohide = false,
            expand_tabs = false,
            inverted = true,
            start_action_widget = new_tab_button,
            end_action_widget = tab_history_button,
            view = tab_view,
        };

         // Layout
        // tab_view.page_attached.connect (on_doc_added);
        // tab_view.page_detached.connect (on_doc_removed);
        // tab_vew.page_reordered.connect (on_doc_reordered);
        // tab_moved.connect (on_doc_moved);

        add (tab_bar);
        add (tab_view);

        var tab_page = tab_view.append (my_custom_view ());
        tab_page.title = "Custom View tab!";
    }

    public Gtk.Box my_custom_view () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            hexpand = true,
            vexpand = true,
        };

        box.add (new Gtk.Label ("Line 1"));
        box.add (new Gtk.Label ("Line 2"));
        box.add (new Gtk.Label ("Line 3"));

        return box;
    }
}
