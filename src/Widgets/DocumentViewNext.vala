/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Colin Kiama <colinkiama@gmail.com>
 */

public class Code.DocumentViewNext : Gtk.Box {
    public unowned Scratch.MainWindow window { get; construct; }
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

        tab_view = new Hdy.TabView () {
            hexpand = true,
            vexpand = true
        };

        tab_bar = new Hdy.TabBar () {
            autohide = false,
            expand_tabs = false,
            inverted = true,
            view = tab_view
        };
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
