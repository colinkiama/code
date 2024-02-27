/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Colin Kiama <colinkiama@gmail.com>
 */

public class Scratch.Widgets.DocumentViewNext : Gtk.Box {
     public enum TargetType {
        URI_LIST
    }

    public GLib.List<Services.DocumentNext> docs;

    private Services.DocumentNext _current_document;
    public Services.DocumentNext current_document {
        get {
            return _current_document;
        }
        set {
            _current_document = value;
        }
    }

    public unowned MainWindow window { get; construct; }
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
        docs = new GLib.List<Services.DocumentNext> ();
        var app_instance = (Gtk.Application) GLib.Application.get_default ();
        tab_view = new Hdy.TabView () {
            hexpand = true,
            vexpand = true
        };


        var new_tab_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
            relief = Gtk.ReliefStyle.NONE,
            tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (MainWindow.ACTION_PREFIX + MainWindow.ACTION_NEW_TAB),
                _("New Tab")
            )
        };

        new_tab_button.clicked.connect (() => {
            new_document ();
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

        // TabView tab events
        tab_view.close_page.connect ((tab) => {
            var doc = search_for_document_in_tab (tab);
            if (doc == null) {
                tab_view.close_page_finish (tab, true);
            } else {
                doc.do_close.begin (false, (obj, res) => {
                    var should_close = doc.do_close.end (res);
                    tab_view.close_page_finish (tab, should_close);
                });
            }

            return true;
        });

        // tab_view.page_detached.connect (on_doc_removed);
        // tab_vew.page_reordered.connect (on_doc_reordered);
        // tab_moved.connect (on_doc_moved);

        // Handle Drag-and-drop of files onto add-tab button to create document
        Gtk.TargetEntry uris = {"text/uri-list", 0, TargetType.URI_LIST};
        var drag_dest_targets = new Gtk.TargetList ({uris});
        tab_bar.set_extra_drag_dest_targets (drag_dest_targets);
        // tab_bar.extra_drag_data_received (drag_received);

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

    public Services.DocumentNext search_for_document_in_tab (Hdy.TabPage tab) {
        unowned var current = docs;

        bool should_end_search = false;
        Services.DocumentNext matching_document = null;

        while (!should_end_search) {
            if (current == null || current.length () == 0) {
                should_end_search = true;
            } else {
                var doc = current.data;
                if (doc.tab == tab) {
                    matching_document = doc;
                    should_end_search = true;
                }

                current = current.next;
            }

        }

        return matching_document;
    }



    public void new_document () {
        var file = File.new_for_path (unsaved_file_path_builder ());
        try {
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.DocumentNext (window.actions, file);
            // Must open document in order to unlock it.
            open_document (doc);
        } catch (Error e) {
            critical (e.message);
        }
    }

    public void open_document (Services.DocumentNext doc, bool focus = true, int cursor_position = 0, SelectionRange range = SelectionRange.EMPTY) {
       for (int n = 0; n <= docs.length (); n++) {
            var nth_doc = docs.nth_data (n);
            if (nth_doc == null) {
                continue;
            }

            if (nth_doc.file != null && nth_doc.file.get_uri () == doc.file.get_uri ()) {
                if (focus) {
                    current_document = nth_doc;
                }

                debug ("This Document was already opened! Not opening a duplicate!");
                if (range != SelectionRange.EMPTY) {
                    Idle.add_full (GLib.Priority.LOW, () => { // This helps ensures new tab is drawn before opening document.
                        current_document.source_view.select_range (range);
                        // save_opened_files ();

                        return false;
                    });
                }

                return;
            }
        }

        insert_document (doc, (int) docs.length ());
        if (focus) {
            current_document = doc;
        }

        Idle.add_full (GLib.Priority.LOW, () => { // This helps ensures new tab is drawn before opening document.
            doc.open.begin (false, (obj, res) => {
                doc.open.end (res);
                if (focus && doc == current_document) {
                    doc.focus ();
                }

                if (range != SelectionRange.EMPTY) {
                    doc.source_view.select_range (range);
                } else if (cursor_position > 0) {
                    doc.source_view.cursor_position = cursor_position;
                }

                //  save_opened_files ();
            });

            return false;
        });
    }

    private void insert_document (Scratch.Services.DocumentNext doc, int pos) {
        var page = tab_view.insert (doc, pos);
        doc.init_tab (page);
        on_doc_added (doc);
        if (Scratch.saved_state.get_boolean ("outline-visible")) {
            debug ("setting outline visible");
            doc.show_outline (true);
        }
    }

    private string unsaved_file_path_builder (string extension = "txt") {
        var timestamp = new DateTime.now_local ();

        string new_text_file = _("Text file from %s:%d").printf (
                                    timestamp.format ("%Y-%m-%d %H:%M:%S"), timestamp.get_microsecond ()
                                );

        return Path.build_filename (window.app.data_home_folder_unsaved, new_text_file) + "." + extension;
    }

    private void on_doc_added (Services.DocumentNext doc) {
        //  var doc = search_for_document_in_tab (tab);
        //  if (doc == null) {
        //      print ("No tab!\n");
        //      return;
        //  }

        docs.append (doc);
        doc.actions = window.actions;

        // Scratch.Services.DocumentManager.get_instance ().add_open_document (doc);

        // if (!doc.is_file_temporary) {
        //     rename_tabs_with_same_title (doc);
        // }

        // doc.source_view.focus_in_event.connect_after (on_focus_in_event);

    }
}
