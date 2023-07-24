// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

public class Scratch.Widgets.DocumentView : Granite.Widgets.DynamicNotebook {
    public enum TargetType {
        URI_LIST
    }

    public signal void document_change (Services.Document? document, DocumentView parent);
    public signal void request_placeholder ();

    public unowned MainWindow window { get; construct set; }

    public Services.Document current_document {
        get {
            return (Services.Document) current;
        }
        set {
            current = value;
        }
    }

    public GLib.List<Services.Document> docs;

    public bool is_closing = false;
    public bool outline_visible { get; set; default = false; }

    private Gtk.CssProvider style_provider;

    public DocumentView (MainWindow window) {
        base ();
        allow_restoring = true;
        allow_new_window = true;
        allow_drag = true;
        allow_duplication = true;
        group_name = Constants.PROJECT_NAME;
        this.window = window;
        expand = true;
    }

    construct {
        docs = new GLib.List<Services.Document> ();

        // Layout
        tab_added.connect (on_doc_added);
        tab_removed.connect (on_doc_removed);
        tab_reordered.connect (on_doc_reordered);
        tab_moved.connect (on_doc_moved);

        new_tab_requested.connect (() => {
            new_document ();
        });

        close_tab_requested.connect ((tab) => {
            var document = tab as Services.Document;
            if (!document.is_file_temporary && document.file != null) {
                tab.restore_data = document.get_uri ();
            }

            close_document (document); // Will remove tab if possible
            return false;
        });

        tab_switched.connect ((old_tab, new_tab) => {
            var doc = (Services.Document)new_tab;
            /* The 'document_change' signal may not be emitted if this already has focus so signal here*/
            document_change (doc, this);
            save_focused_document_uri (doc);
        });

        tab_restored.connect ((label, restore_data, icon) => {
            var doc = new Services.Document (window.actions, File.new_for_uri (restore_data));
            open_document (doc);
        });

        tab_duplicated.connect ((tab) => {
            duplicate_document (tab as Services.Document);
        });

        style_provider = new Gtk.CssProvider ();
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        update_inline_tab_colors ();
        Scratch.settings.changed["style-scheme"].connect (update_inline_tab_colors);
        Scratch.settings.changed["follow-system-style"].connect (update_inline_tab_colors);
        var granite_settings = Granite.Settings.get_default ();
        granite_settings.notify["prefers-color-scheme"].connect (update_inline_tab_colors);

        notify["outline-visible"].connect (update_outline_visible);

        // Handle Drag-and-drop of files onto add-tab button to create document
        Gtk.TargetEntry uris = {"text/uri-list", 0, TargetType.URI_LIST};
        Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.COPY);
        drag_data_received.connect (drag_received);
    }

    public void update_outline_visible () {
        docs.@foreach ((doc) => {
            doc.show_outline (outline_visible);
        });
    }

    private void update_inline_tab_colors () {
        var style_scheme = "";
        if (settings.get_boolean ("follow-system-style")) {
            var system_prefers_dark = Granite.Settings.get_default ().prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            if (system_prefers_dark) {
                style_scheme = "elementary-dark";
            } else {
                style_scheme = "elementary-light";
            }
        } else {
            style_scheme = Scratch.settings.get_string ("style-scheme");
        }

        var sssm = Gtk.SourceStyleSchemeManager.get_default ();
        if (style_scheme in sssm.scheme_ids) {
            var theme = sssm.get_scheme (style_scheme);
            var text_color_data = theme.get_style ("text");

            // Default gtksourceview background color is white
            var color = "#FFFFFF";
            if (text_color_data != null) {
                // If the current style has a background color, use that
                color = text_color_data.background;
            }

            var define = "@define-color tab_base_color %s;".printf (color);
            try {
                style_provider.load_from_data (define);
            } catch (Error e) {
                critical ("Unable to set inline tab styling, going back to classic notebook tabs");
            }
        }
    }

    private string unsaved_file_path_builder (string extension = "txt") {
        var timestamp = new DateTime.now_local ();

        string new_text_file = _("Text file from %s:%d").printf (
                                    timestamp.format ("%Y-%m-%d %H:%M:%S"), timestamp.get_microsecond ()
                                );

        return Path.build_filename (window.app.data_home_folder_unsaved, new_text_file) + "." + extension;
    }

    private string unsaved_duplicated_file_path_builder (string original_filename) {
        string extension = "txt";
        string[] parts = original_filename.split (".", 2);
        if (parts.length > 1) {
            extension = parts[parts.length - 1];
        }

        return unsaved_file_path_builder (extension);
    }

    private void insert_document (Scratch.Services.Document doc, int pos) {
        insert_tab (doc, pos);
        if (Scratch.saved_state.get_boolean ("outline-visible")) {
            debug ("setting outline visible");
            doc.show_outline (true);
        }
    }

    public void new_document () {
        var file = File.new_for_path (unsaved_file_path_builder ());
        try {
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.actions, file);
            // Must open document in order to unlock it.
            open_document (doc);
        } catch (Error e) {
            critical (e.message);
        }
    }

    public void new_document_from_clipboard (string clipboard) {
        var file = File.new_for_path (unsaved_file_path_builder ());

        // Set clipboard content
        try {
            file.create (FileCreateFlags.PRIVATE);
            file.replace_contents (clipboard.data, null, false, 0, null);

            var doc = new Services.Document (window.actions, file);

            open_document (doc);

        } catch (Error e) {
            critical ("Cannot insert clipboard: %s", clipboard);
        }
    }

    public void open_document (Services.Document doc, bool focus = true, int cursor_position = 0) {
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
                return;
            }
        }

        insert_document (doc, -1);
        if (focus) {
            current_document = doc;
        }

        Idle.add_full (GLib.Priority.LOW, () => { // This helps ensures new tab is drawn before opening document.
            doc.open.begin (false, (obj, res) => {
                doc.open.end (res);
                if (focus && doc == current_document) {
                    doc.focus ();
                }

                if (cursor_position > 0) {
                    doc.source_view.cursor_position = cursor_position;
                }
                save_opened_files ();
            });

            return false;
        });
    }

    // Set a copy of content
    public void duplicate_document (Services.Document original) {
        try {
            var file = File.new_for_path (unsaved_duplicated_file_path_builder (original.file.get_basename ()));
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.actions, file);
            doc.source_view.set_text (original.get_text ());
            doc.source_view.language = original.source_view.language;
            if (Scratch.settings.get_boolean ("autosave")) {
                doc.save_with_hold.begin (true);
            }

            insert_document (doc, -1);
            current_document = doc;
            doc.focus ();
        } catch (Error e) {
            warning ("Cannot copy \"%s\": %s", original.get_basename (), e.message);
        }
    }

    public void next_document () {
        uint current_index = docs.index (current_document) + 1;
        if (current_index < docs.length ()) {
            var next_doc = docs.nth_data (current_index++);
            current_document = next_doc;
            next_doc.focus ();
        } else if (docs.length () > 0) {
            var next_doc = docs.nth_data (0);
            current_document = next_doc;
            next_doc.focus ();
        }
    }

    public void previous_document () {
        uint current_index = docs.index (current_document);
        if (current_index > 0) {
            var previous_doc = docs.nth_data (--current_index);
            current_document = previous_doc;
            previous_doc.focus ();
        } else if (docs.length () > 0) {
            var previous_doc = docs.nth_data (docs.length () - 1);
            current_document = previous_doc;
            previous_doc.focus ();
        }
    }

    public void close_document (Services.Document doc) {
        doc.do_close.begin (false, (obj, res) => {
            if (doc.do_close.end (res)) {
                remove_tab (doc);
                doc.destroy ();
            }
        });
    }

    public void request_placeholder_if_empty () {
        if (docs.length () == 0) {
            request_placeholder ();
        }
    }

    public new void focus () {
        current_document.focus ();
    }


    private void rename_tabs_with_same_title (Services.Document doc) {
        string doc_tab_name = doc.file.get_basename ();
        foreach (var d in docs) {
            string new_tabname_doc, new_tabname_d;

            if (Utils.find_unique_path (d.file, doc.file, out new_tabname_d, out new_tabname_doc)) {
                if (d.label.length < new_tabname_d.length) {
                    d.tab_name = new_tabname_d;
                }

                if (doc_tab_name.length < new_tabname_doc.length) {
                    doc_tab_name = new_tabname_doc;
                }
            }
        }

        doc.tab_name = doc_tab_name;
    }

    private void on_doc_added (Granite.Widgets.Tab tab) {
        var doc = tab as Services.Document;
        doc.actions = window.actions;

        docs.append (doc);
        Scratch.Services.DocumentManager.get_instance ().add_open_document (doc);

        if (!doc.is_file_temporary) {
            rename_tabs_with_same_title (doc);
        }

        doc.source_view.focus_in_event.connect_after (on_focus_in_event);
    }

    private void on_doc_removed (Granite.Widgets.Tab tab) {
        var doc = tab as Services.Document;

        docs.remove (doc);
        Scratch.Services.DocumentManager.get_instance ().remove_open_document (doc);

        doc.source_view.focus_in_event.disconnect (on_focus_in_event);

        request_placeholder_if_empty ();

        if (docs.length () > 0) {
            if (!doc.is_file_temporary) {
                foreach (var d in docs) {
                    rename_tabs_with_same_title (d);
                }
            }
        }

        if (!is_closing) {
            save_opened_files ();
        }
    }

    private void on_doc_moved (Granite.Widgets.Tab tab, int x, int y) {
        var doc = tab as Services.Document;
        var other_window = new MainWindow (false);
        other_window.move (x, y);

        // We need to make sure switch back to the main thread
        // when we are modifying Gtk widgets shared by two threads.
        Idle.add (() => {
            remove_tab (doc);
            other_window.document_view.insert_document (doc, -1);

            return false;
        });
    }

    private void on_doc_reordered (Granite.Widgets.Tab tab, int new_pos) {
        var doc = tab as Services.Document;

        docs.remove (doc);
        docs.insert (doc, new_pos);

        doc.focus ();

        save_opened_files ();
    }

    private bool on_focus_in_event () {
        var doc = current_document;
        if (doc == null) {
            warning ("Focus event callback cannot get current document");
        } else {
            document_change (doc, this);
        }

        return false;
    }

    private void drag_received (Gtk.Widget w,
                                Gdk.DragContext ctx,
                                int x,
                                int y,
                                Gtk.SelectionData sel,
                                uint info,
                                uint time) {

        if (info == TargetType.URI_LIST) {
            var uris = sel.get_uris ();
            foreach (var filename in uris) {
                var file = File.new_for_uri (filename);
                var doc = new Services.Document (window.actions, file);
                open_document (doc);
            }

            Gtk.drag_finish (ctx, true, false, time);
        }
    }

    public void save_opened_files () {
        if (privacy_settings.get_boolean ("remember-recent-files")) {
            var vb = new VariantBuilder (new VariantType ("a(si)"));
            tabs.foreach ((tab) => {
                var doc = (Scratch.Services.Document)tab;
                if (doc.file != null && doc.exists ()) {
                    vb.add ("(si)", doc.file.get_uri (), doc.source_view.cursor_position);
                }
            });

            Scratch.settings.set_value ("opened-files", vb.end ());
        }
    }

    private void save_focused_document_uri (Services.Document? current_document) {
        if (privacy_settings.get_boolean ("remember-recent-files")) {
            var file_uri = "";

            if (current_document != null) {
                file_uri = current_document.file.get_uri ();
            }

            Scratch.settings.set_string ("focused-document", file_uri);
        }
    }
}
