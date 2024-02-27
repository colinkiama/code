/*
* Copyright 2017–2020 elementary, Inc. <https://elementary.io>
*           2011–2013 Mario Guerriero <mefrio.g@gmail.com>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Scratch {
    public class MainWindow : Hdy.Window {
        public const int FONT_SIZE_MAX = 72;
        public const int FONT_SIZE_MIN = 7;
        private const uint MAX_SEARCH_TEXT_LENGTH = 255;

        public Scratch.Application app { get; private set; }
        public bool restore_docs { get; construct; }
        public RestoreOverride restore_override { get; construct set; }

        public Scratch.Widgets.DocumentView document_view;
        public Scratch.Widgets.DocumentViewNext document_view_next;

        // Widgets
        public Scratch.HeaderBar toolbar;
        private Gtk.Revealer search_revealer;
        public Scratch.Widgets.SearchBar search_bar;
        private Code.WelcomeView welcome_view;
        private Code.Terminal terminal;
        private FolderManager.FileView folder_manager_view;
        private Scratch.Services.DocumentManager document_manager;
        private Gtk.EventControllerKey key_controller;
        // Plugins
        private Scratch.Services.PluginsManager plugins;

        // Widgets for Plugins
        public Code.Sidebar sidebar;

        private Granite.Dialog? preferences_dialog = null;
        private Gtk.Paned hp1;
        private Gtk.Paned vp;
        private Gtk.Stack content_stack;

        public Gtk.Clipboard clipboard;

        // Delegates
        delegate void HookFunc ();

        public SimpleActionGroup actions { get; construct; }

        public const string ACTION_GROUP = "win";
        public const string ACTION_PREFIX = ACTION_GROUP + ".";
        public const string ACTION_FIND = "action_find";
        public const string ACTION_FIND_NEXT = "action_find_next";
        public const string ACTION_FIND_PREVIOUS = "action_find_previous";
        public const string ACTION_FIND_GLOBAL = "action_find_global";
        public const string ACTION_OPEN = "action_open";
        public const string ACTION_OPEN_FOLDER = "action_open_folder";
        public const string ACTION_COLLAPSE_ALL_FOLDERS = "action_collapse_all_folders";
        public const string ACTION_ORDER_FOLDERS = "action_order_folders";
        public const string ACTION_GO_TO = "action_go_to";
        public const string ACTION_SORT_LINES = "action_sort_lines";
        public const string ACTION_NEW_TAB = "action_new_tab";
        public const string ACTION_NEW_FROM_CLIPBOARD = "action_new_from_clipboard";
        public const string ACTION_PREFERENCES = "preferences";
        public const string ACTION_UNDO = "action_undo";
        public const string ACTION_REDO = "action_redo";
        public const string ACTION_REVERT = "action_revert";
        public const string ACTION_SAVE = "action_save";
        public const string ACTION_SAVE_AS = "action_save_as";
        public const string ACTION_SHOW_FIND = "action_show_find";
        public const string ACTION_TEMPLATES = "action_templates";
        public const string ACTION_SHOW_REPLACE = "action_show_replace";
        public const string ACTION_TO_LOWER_CASE = "action_to_lower_case";
        public const string ACTION_TO_UPPER_CASE = "action_to_upper_case";
        public const string ACTION_DUPLICATE = "action_duplicate";
        public const string ACTION_FULLSCREEN = "action_fullscreen";
        public const string ACTION_QUIT = "action_quit";
        public const string ACTION_ZOOM_DEFAULT = "action_zoom_default";
        public const string ACTION_ZOOM_IN = "action_zoom_in";
        public const string ACTION_ZOOM_OUT = "action_zoom_out";
        public const string ACTION_TOGGLE_COMMENT = "action_toggle_comment";
        public const string ACTION_TOGGLE_SIDEBAR = "action_toggle_sidebar";
        public const string ACTION_TOGGLE_OUTLINE = "action_toggle_outline";
        public const string ACTION_TOGGLE_TERMINAL = "action-toggle-terminal";
        public const string ACTION_OPEN_IN_TERMINAL = "action-open_in_terminal";
        public const string ACTION_NEXT_TAB = "action_next_tab";
        public const string ACTION_PREVIOUS_TAB = "action_previous_tab";
        public const string ACTION_CLEAR_LINES = "action_clear_lines";
        public const string ACTION_NEW_BRANCH = "action_new_branch";
        public const string ACTION_CLOSE_TAB = "action_close_tab";
        public const string ACTION_CLOSE_PROJECT_DOCS = "action_close_project_docs";
        public const string ACTION_HIDE_PROJECT_DOCS = "action_hide_project_docs";
        public const string ACTION_RESTORE_PROJECT_DOCS = "action_restore_project_docs";

        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();
        private static string base_title;

        private ulong color_scheme_listener_handler_id = 0;

        private Services.GitManager git_manager;

        private const ActionEntry[] ACTION_ENTRIES = {
            { ACTION_FIND, action_fetch, "s" },
            { ACTION_FIND_NEXT, action_find_next },
            { ACTION_FIND_PREVIOUS, action_find_previous },
            { ACTION_FIND_GLOBAL, action_find_global, "s" },
            { ACTION_OPEN, action_open },
            { ACTION_OPEN_FOLDER, action_open_folder, "s" },
            { ACTION_COLLAPSE_ALL_FOLDERS, action_collapse_all_folders },
            { ACTION_ORDER_FOLDERS, action_order_folders },
            { ACTION_PREFERENCES, action_preferences },
            { ACTION_REVERT, action_revert },
            { ACTION_SAVE, action_save },
            { ACTION_SAVE_AS, action_save_as },
            { ACTION_SHOW_FIND, action_show_fetch, null, "false" },
            { ACTION_TEMPLATES, action_templates },
            { ACTION_GO_TO, action_go_to },
            { ACTION_SORT_LINES, action_sort_lines },
            { ACTION_NEW_TAB, action_new_tab },
            { ACTION_NEW_FROM_CLIPBOARD, action_new_tab_from_clipboard },
            { ACTION_PREFERENCES, action_preferences },
            { ACTION_UNDO, action_undo },
            { ACTION_REDO, action_redo },
            { ACTION_SHOW_REPLACE, action_show_replace },
            { ACTION_TO_LOWER_CASE, action_to_lower_case },
            { ACTION_TO_UPPER_CASE, action_to_upper_case },
            { ACTION_DUPLICATE, action_duplicate },
            { ACTION_FULLSCREEN, action_fullscreen },
            { ACTION_QUIT, action_quit },
            { ACTION_ZOOM_DEFAULT, action_set_default_zoom },
            { ACTION_ZOOM_IN, action_zoom_in },
            { ACTION_ZOOM_OUT, action_zoom_out},
            { ACTION_TOGGLE_COMMENT, action_toggle_comment },
            { ACTION_TOGGLE_SIDEBAR, action_toggle_sidebar, null, "true" },
            { ACTION_TOGGLE_TERMINAL, action_toggle_terminal, null, "false"},
            { ACTION_OPEN_IN_TERMINAL, action_open_in_terminal, "s"},
            { ACTION_TOGGLE_OUTLINE, action_toggle_outline, null, "false" },
            { ACTION_NEXT_TAB, action_next_tab },
            { ACTION_PREVIOUS_TAB, action_previous_tab },
            { ACTION_CLEAR_LINES, action_clear_lines },
            { ACTION_NEW_BRANCH, action_new_branch, "s" },
            { ACTION_CLOSE_TAB, action_close_tab, "s"},
            { ACTION_HIDE_PROJECT_DOCS, action_hide_project_docs, "s"},
            { ACTION_CLOSE_PROJECT_DOCS, action_close_project_docs, "s"},
            { ACTION_RESTORE_PROJECT_DOCS, action_restore_project_docs, "s"}
        };

        public MainWindow (bool restore_docs) {
            Object (
                icon_name: Constants.PROJECT_NAME,
                restore_docs: restore_docs
            );
        }

        public MainWindow.with_restore_override (bool restore_docs, RestoreOverride restore_override) {
            Object (
                icon_name: Constants.PROJECT_NAME,
                restore_docs: restore_docs,
                restore_override: restore_override
            );
        }

        static construct {
            action_accelerators.set (ACTION_FIND + "::", "<Control>f");
            action_accelerators.set (ACTION_FIND_NEXT, "<Control>g");
            action_accelerators.set (ACTION_FIND_PREVIOUS, "<Control><shift>g");
            action_accelerators.set (ACTION_FIND_GLOBAL + "::", "<Control><shift>f");
            action_accelerators.set (ACTION_OPEN, "<Control>o");
            action_accelerators.set (ACTION_REVERT, "<Control><shift>o");
            action_accelerators.set (ACTION_SAVE, "<Control>s");
            action_accelerators.set (ACTION_SAVE_AS, "<Control><shift>s");
            action_accelerators.set (ACTION_GO_TO, "<Control>i");
            action_accelerators.set (ACTION_SORT_LINES, "F5");
            action_accelerators.set (ACTION_NEW_TAB, "<Control>n");
            action_accelerators.set (ACTION_UNDO, "<Control>z");
            action_accelerators.set (ACTION_REDO, "<Control><shift>z");
            action_accelerators.set (ACTION_SHOW_REPLACE, "<Control>r");
            action_accelerators.set (ACTION_TO_LOWER_CASE, "<Control>l");
            action_accelerators.set (ACTION_TO_UPPER_CASE, "<Control>u");
            action_accelerators.set (ACTION_DUPLICATE, "<Control>d");
            action_accelerators.set (ACTION_FULLSCREEN, "F11");
            action_accelerators.set (ACTION_QUIT, "<Control>q");
            action_accelerators.set (ACTION_ZOOM_DEFAULT, "<Control>0");
            action_accelerators.set (ACTION_ZOOM_DEFAULT, "<Control>KP_0");
            action_accelerators.set (ACTION_ZOOM_IN, "<Control>plus");
            action_accelerators.set (ACTION_ZOOM_IN, "<Control>equal");
            action_accelerators.set (ACTION_ZOOM_IN, "<Control>KP_Add");
            action_accelerators.set (ACTION_ZOOM_OUT, "<Control>minus");
            action_accelerators.set (ACTION_ZOOM_OUT, "<Control>KP_Subtract");
            action_accelerators.set (ACTION_TOGGLE_COMMENT, "<Control>m");
            action_accelerators.set (ACTION_TOGGLE_COMMENT, "<Control>slash");
            action_accelerators.set (ACTION_TOGGLE_SIDEBAR, "F9"); // GNOME
            action_accelerators.set (ACTION_TOGGLE_SIDEBAR, "<Control>backslash"); // Atom
            action_accelerators.set (ACTION_TOGGLE_TERMINAL, "<Control><Alt>t");
            action_accelerators.set (ACTION_OPEN_IN_TERMINAL + "::", "<Control><Alt><Shift>t");
            action_accelerators.set (ACTION_TOGGLE_OUTLINE, "<Alt>backslash");
            action_accelerators.set (ACTION_NEXT_TAB, "<Control>Tab");
            action_accelerators.set (ACTION_NEXT_TAB, "<Control>Page_Down");
            action_accelerators.set (ACTION_PREVIOUS_TAB, "<Control><Shift>Tab");
            action_accelerators.set (ACTION_PREVIOUS_TAB, "<Control>Page_Up");
            action_accelerators.set (ACTION_CLEAR_LINES, "<Control>K"); //Geany
            action_accelerators.set (ACTION_NEW_BRANCH + "::", "<Control>B");
            action_accelerators.set (ACTION_HIDE_PROJECT_DOCS + "::", "<Control><Shift>h");
            action_accelerators.set (ACTION_RESTORE_PROJECT_DOCS + "::", "<Control><Shift>r");

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("io/elementary/code/Application.css");
            Gtk.StyleContext.add_provider_for_screen (
                Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            if (Constants.BRANCH != "") {
                base_title = _("Code (%s)").printf (Constants.BRANCH);
            } else {
                base_title = _("Code");
            }

            Hdy.init ();
        }

        construct {
            application = ((Gtk.Application)(GLib.Application.get_default ()));
            app = (Scratch.Application)application;
            title = base_title;

            weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
            default_theme.add_resource_path ("/io/elementary/code");

            document_manager = Scratch.Services.DocumentManager.get_instance ();
            git_manager = Services.GitManager.get_instance ();

            actions = new SimpleActionGroup ();
            actions.add_action_entries (ACTION_ENTRIES, this);
            insert_action_group (ACTION_GROUP, actions);

            foreach (var action in action_accelerators.get_keys ()) {
                var accels_array = action_accelerators[action].to_array ();
                accels_array += null;

                app.set_accels_for_action (ACTION_PREFIX + action, accels_array);
            }

            set_size_request (450, 400);
            set_hide_titlebar_when_maximized (false);

            var rect = Gdk.Rectangle ();
            Scratch.saved_state.get ("window-size", "(ii)", out rect.width, out rect.height);

            default_width = rect.width;
            default_height = rect.height;

            update_style ();
            Scratch.settings.changed["follow-system-style"].connect (() => {
                update_style ();
            });

            clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);

            plugins = new Scratch.Services.PluginsManager (this);

            key_controller = new Gtk.EventControllerKey (this) {
                propagation_phase = CAPTURE
            };
            key_controller.key_pressed.connect (on_key_pressed);

            // Set up layout
            init_layout ();

            var window_state = Scratch.saved_state.get_enum ("window-state");
            switch (window_state) {
                case ScratchWindowState.MAXIMIZED:
                    maximize ();
                    break;
                case ScratchWindowState.FULLSCREEN:
                    fullscreen ();
                    break;
                default:
                    break;
            }

            // Show/Hide widgets
            show_all ();

            toolbar.templates_button.visible = (plugins.plugin_iface.template_manager.template_available);
            plugins.plugin_iface.template_manager.notify["template_available"].connect (() => {
                toolbar.templates_button.visible = (plugins.plugin_iface.template_manager.template_available);
            });

            // Restore session
            restore_saved_state_extra ();

            // Create folder for unsaved documents
            create_unsaved_documents_directory ();

            actions.action_state_changed.connect ((name, new_state) => {
                update_toolbar_button (name, new_state.get_boolean ());
            });

            var sidebar_action = Utils.action_from_group (ACTION_TOGGLE_SIDEBAR, actions);
            sidebar_action.set_state (saved_state.get_boolean ("sidebar-visible"));
            update_toolbar_button (ACTION_TOGGLE_SIDEBAR, saved_state.get_boolean ("sidebar-visible"));

            var outline_action = Utils.action_from_group (ACTION_TOGGLE_OUTLINE, actions);
            outline_action.set_state (saved_state.get_boolean ("outline-visible"));
            update_toolbar_button (ACTION_TOGGLE_OUTLINE, saved_state.get_boolean ("outline-visible"));

            var terminal_action = Utils.action_from_group (ACTION_TOGGLE_TERMINAL, actions);
            terminal_action.set_state (saved_state.get_boolean ("terminal-visible"));
            update_toolbar_button (ACTION_TOGGLE_TERMINAL, saved_state.get_boolean ("terminal-visible"));

            Unix.signal_add (Posix.Signal.INT, quit_source_func, Priority.HIGH);
            Unix.signal_add (Posix.Signal.TERM, quit_source_func, Priority.HIGH);
        }

        private void update_style () {
            var gtk_settings = Gtk.Settings.get_default ();
            if (Scratch.settings.get_boolean ("follow-system-style")) {
                var system_prefers_dark = Granite.Settings.get_default ().prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
                gtk_settings.gtk_application_prefer_dark_theme = system_prefers_dark;
                connect_color_scheme_preference_listener ();
            } else {
                disconnect_color_scheme_preference_listener ();
                gtk_settings.gtk_application_prefer_dark_theme = Scratch.settings.get_boolean ("prefer-dark-style");
            }
        }

        private void connect_color_scheme_preference_listener () {
            var gtk_settings = Gtk.Settings.get_default ();
            var granite_settings = Granite.Settings.get_default ();

            color_scheme_listener_handler_id = granite_settings.notify["prefers-color-scheme"].connect (() => {
                gtk_settings.gtk_application_prefer_dark_theme = (
                    granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK
                );
            });
        }

        private void disconnect_color_scheme_preference_listener () {
            if (color_scheme_listener_handler_id != 0) {
                var granite_settings = Granite.Settings.get_default ();
                granite_settings.disconnect (color_scheme_listener_handler_id);
                color_scheme_listener_handler_id = 0;
            }
        }

        private void update_toolbar_button (string name, bool new_state) {
            switch (name) {
                case ACTION_SHOW_FIND:
                    if (new_state) {
                        toolbar.find_button.tooltip_markup = Granite.markup_accel_tooltip (
                            {"Escape"},
                            _("Hide search bar")
                        );
                    } else {
                        toolbar.find_button.tooltip_markup = Granite.markup_accel_tooltip (
                            app.get_accels_for_action (ACTION_PREFIX + name),
                            _("Find on Page…")
                        );
                    }

                    search_revealer.set_reveal_child (new_state);

                    break;
                case ACTION_TOGGLE_SIDEBAR:
                    if (new_state) {
                        toolbar.sidebar_button.tooltip_markup = Granite.markup_accel_tooltip (
                            app.get_accels_for_action (ACTION_PREFIX + name),
                            _("Hide Projects Sidebar")
                        );
                    } else {
                        toolbar.sidebar_button.tooltip_markup = Granite.markup_accel_tooltip (
                            app.get_accels_for_action (ACTION_PREFIX + name),
                            _("Show Projects Sidebar")
                        );
                    }

                    break;
                case ACTION_TOGGLE_OUTLINE:
                    if (new_state) {
                        toolbar.outline_button.tooltip_markup = Granite.markup_accel_tooltip (
                            app.get_accels_for_action (ACTION_PREFIX + name),
                            _("Hide Symbol Outline")
                        );
                    } else {
                        toolbar.outline_button.tooltip_markup = Granite.markup_accel_tooltip (
                            app.get_accels_for_action (ACTION_PREFIX + name),
                            _("Show Symbol Outline")
                        );
                    }

                    break;
                case ACTION_TOGGLE_TERMINAL:
                    if (new_state) {
                        toolbar.terminal_button.tooltip_markup = Granite.markup_accel_tooltip (
                            app.get_accels_for_action (ACTION_PREFIX + name),
                            _("Hide Terminal")
                        );
                    } else {
                        toolbar.terminal_button.tooltip_markup = Granite.markup_accel_tooltip (
                            app.get_accels_for_action (ACTION_PREFIX + name),
                            _("Show Terminal")
                        );
                    }
                    break;
            };
        }

        private void init_layout () {
            toolbar = new Scratch.HeaderBar ();
            toolbar.title = base_title;

            // SearchBar
            search_bar = new Scratch.Widgets.SearchBar (this);
            search_revealer = new Gtk.Revealer ();
            search_revealer.add (search_bar);

            search_bar.map.connect_after ((w) => { /* signalled when reveal child */
                set_search_text ();
            });
            search_bar.search_entry.unmap.connect_after (() => { /* signalled when reveal child */
                search_bar.search_entry.text = "";
                search_bar.highlight_none ();
            });
            search_bar.search_empty.connect (() => {
                folder_manager_view.clear_badges ();
            });

            welcome_view = new Code.WelcomeView (this);
            document_view = new Scratch.Widgets.DocumentView (this);
            document_view_next = new Scratch.Widgets.DocumentViewNext (this);
            // Handle Drag-and-drop for files functionality on welcome screen
            Gtk.TargetEntry target = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (welcome_view, Gtk.DestDefaults.ALL, {target}, Gdk.DragAction.COPY);

            welcome_view.drag_data_received.connect ((ctx, x, y, sel, info, time) => {
                var uris = sel.get_uris ();
                if (uris.length > 0) {
                    for (var i = 0; i < uris.length; i++) {
                        string filename = uris[i];
                        var file = File.new_for_uri (filename);
                        bool is_folder;
                        //TODO Handle folders dropped here
                        if (Scratch.Services.FileHandler.can_open_file (file, out is_folder) && !is_folder) {
                            Scratch.Services.Document doc = new Scratch.Services.Document (actions, file);
                            document_view.open_document (doc);
                        }
                    }

                    Gtk.drag_finish (ctx, true, false, time);
                }
            });

            sidebar = new Code.Sidebar ();

            folder_manager_view = new FolderManager.FileView (plugins);

            sidebar.add_tab (folder_manager_view);
            folder_manager_view.show_all ();

            folder_manager_view.select.connect ((a) => {
                var file = new Scratch.FolderManager.File (a);
                var doc = new Scratch.Services.Document (actions, file.file);

                if (file.is_valid_textfile) {
                    open_document (doc);
                } else {
                    open_binary (file.file);
                }
            });


            folder_manager_view.restore_saved_state ();

            folder_manager_view.rename_request.connect ((file) => {
                var allow = true;
                foreach (var window in app.get_windows ()) {
                    var win = (MainWindow)window;
                    foreach (var doc in win.document_view.docs) {
                        if (doc.file.equal (file.file)) {
                            // Only allow sidebar to rename docs that are in sync with their file in
                            // all windows
                            allow = allow && !doc.locked && doc.saved;
                        }
                    }
                }

                return allow;
            });

            terminal = new Code.Terminal () {
                no_show_all = true,
                visible = false
            };

            var view_grid = new Gtk.Grid () {
                orientation = Gtk.Orientation.VERTICAL
            };
            view_grid.add (search_revealer);
            view_grid.add (document_view);

            content_stack = new Gtk.Stack () {
                expand = true,
                width_request = 200
            };

            content_stack.add (view_grid);  // Must be added first to avoid terminal warnings
            // content_stack.add (welcome_view);
            content_stack.add (document_view_next);
            content_stack.visible_child = view_grid; // Must be visible while restoring

            // Set a proper position for ThinPaned widgets
            int width, height;
            get_size (out width, out height);

            vp = new Gtk.Paned (Gtk.Orientation.VERTICAL);
            vp.position = (height - 150);
            vp.pack1 (content_stack, true, false);
            vp.pack2 (terminal, false, false);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.add (toolbar);
            box.add (vp);

            hp1 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            hp1.pack1 (sidebar, false, false);
            hp1.pack2 (box, true, false);

            add (hp1);

            var header_group = new Hdy.HeaderGroup ();
            header_group.add_header_bar (sidebar.headerbar);
            header_group.add_header_bar (toolbar);

            var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.VERTICAL);
            size_group.add_widget (sidebar.headerbar);
            size_group.add_widget (toolbar);

            search_revealer.set_reveal_child (false);

            realize.connect (() => {
                Scratch.saved_state.bind ("sidebar-visible", sidebar, "visible", SettingsBindFlags.DEFAULT);
                Scratch.saved_state.bind ("outline-visible", document_view , "outline_visible", SettingsBindFlags.DEFAULT);
                Scratch.saved_state.bind ("terminal-visible", terminal, "visible", SettingsBindFlags.DEFAULT);
                // Plugins hook
                HookFunc hook_func = () => {
                    plugins.hook_window (this);
                    plugins.hook_toolbar (toolbar);
                    plugins.hook_share_menu (toolbar.share_menu);
                };

                plugins.extension_added.connect (() => {
                    hook_func ();
                });

                hook_func ();
            });

            document_view.realize.connect (() => {
                if (restore_docs) {
                    restore_opened_documents ();
                }

                document_view.update_outline_visible ();
                update_find_actions ();
            });

            document_view.request_placeholder.connect (() => {
                // content_stack.visible_child = welcome_view;
                content_stack.visible_child = document_view_next;
                title = base_title;
                toolbar.document_available (false);
                set_widgets_sensitive (false);
            });

            document_view.tab_added.connect (() => {
                content_stack.visible_child = view_grid;
                toolbar.document_available (true);
                set_widgets_sensitive (true);
                update_find_actions ();
            });

            document_view.tab_removed.connect ((tab) => {
                update_find_actions ();
                var doc = (Scratch.Services.Document)tab;
                var selected_item = (Scratch.FolderManager.Item?)(folder_manager_view.selected);
                if (selected_item != null && selected_item.file.file.equal (doc.file)) {
                    // Do not leave removed tab selected
                    folder_manager_view.selected = null;
                }
            });

            document_view.document_change.connect ((doc) => {
                if (doc != null) {
                    search_bar.set_text_view (doc.source_view);
                    // Update MainWindow title
                    /// TRANSLATORS: First placeholder is document name, second placeholder is app name
                    title = _("%s - %s").printf (doc.get_basename (), base_title);

                    toolbar.set_document_focus (doc);
                    git_manager.active_project_path = doc.source_view.project.path;
                    folder_manager_view.select_path (doc.file.get_path ());

                    // Must follow setting focus document for editorconfig plug
                    plugins.hook_document (doc);

                    // Set actions sensitive property
                    Utils.action_from_group (ACTION_SAVE_AS, actions).set_enabled (doc.file != null);
                    doc.check_undoable_actions ();
                } else {
                    title = base_title;
                    Utils.action_from_group (ACTION_SAVE_AS, actions).set_enabled (false);
                }
            });

            sidebar.choose_project_button.project_chosen.connect (() => {
                folder_manager_view.collapse_other_projects ();
                if (terminal.visible) {
                    var open_in_terminal_action = Utils.action_from_group (ACTION_OPEN_IN_TERMINAL, actions);
                    var param = new Variant.string (Services.GitManager.get_instance ().get_default_build_dir (null));
                    open_in_terminal_action.activate (param);
                }
            });

            set_widgets_sensitive (false);
        }

        private void open_binary (File file) {
            if (!file.query_exists ()) {
                return;
            }

            try {
                AppInfo.launch_default_for_uri (file.get_uri (), null);
            } catch (Error e) {
                critical (e.message);
            }
        }

        private void restore_opened_documents () {
            if (privacy_settings.get_boolean ("remember-recent-files")) {
                var doc_infos = settings.get_value ("opened-files");
                var doc_info_iter = new VariantIter (doc_infos);
                string focused_document = settings.get_string ("focused-document");
                string uri;
                int pos;
                bool was_restore_overriden = false;
                while (doc_info_iter.next ("(si)", out uri, out pos)) {
                   if (uri != "") {
                        GLib.File file;
                        if (Uri.parse_scheme (uri) != null) {
                            file = File.new_for_uri (uri);
                        } else {
                            file = File.new_for_commandline_arg (uri);
                        }
                        /* Leave it to doc to handle problematic files properly
                           But for files that do not exist we need to make sure that doc won't create a new file
                        */
                        if (file.query_exists ()) {
                            //TODO Check files valid (settings could have been manually altered)
                            var doc = new Scratch.Services.Document (actions, file);
                            bool is_focused = file.get_uri () == focused_document;
                            if (doc.exists () || !doc.is_file_temporary) {
                                if (restore_override != null && (file.get_path () == restore_override.file.get_path ())) {
                                    open_document_at_selected_range (doc, true, restore_override.range, true);
                                    was_restore_overriden = true;
                                } else {
                                    open_document (doc, was_restore_overriden ? false : is_focused, pos);
                                }
                            }

                            if (is_focused) { //Maybe expand to show all opened documents?
                                folder_manager_view.expand_to_path (file.get_path ());
                            }
                        }
                    }
                }
            }

            Idle.add (() => {
                document_view.request_placeholder_if_empty ();
                restore_override = null;
                return Source.REMOVE;
            });
        }

        // private bool on_key_pressed (Gdk.EventKey event) {
        private bool on_key_pressed (uint keyval, uint keycode, Gdk.ModifierType state) {
            switch (Gdk.keyval_name (keyval)) {
                case "Escape":
                    if (search_revealer.get_child_revealed ()) {
                        var fetch_action = Utils.action_from_group (ACTION_SHOW_FIND, actions);
                        fetch_action.set_state (false);
                        document_view.current_document.source_view.grab_focus ();
                    }

                    break;
            }

            // propagate this event to child widgets
            return false;
        }

        protected override bool delete_event (Gdk.EventAny event) {
            action_quit ();
            return true;
        }

        // Set sensitive property for 'delicate' Widgets/GtkActions while
        private void set_widgets_sensitive (bool val) {
            // SearchManager's stuffs
            Utils.action_from_group (ACTION_SHOW_FIND, actions).set_enabled (val);
            Utils.action_from_group (ACTION_GO_TO, actions).set_enabled (val);
            Utils.action_from_group (ACTION_SHOW_REPLACE, actions).set_enabled (val);
            // Toolbar Actions
            Utils.action_from_group (ACTION_SAVE, actions).set_enabled (val);
            Utils.action_from_group (ACTION_SAVE_AS, actions).set_enabled (val);
            Utils.action_from_group (ACTION_UNDO, actions).set_enabled (val);
            Utils.action_from_group (ACTION_REDO, actions).set_enabled (val);
            Utils.action_from_group (ACTION_REVERT, actions).set_enabled (val);
            search_bar.sensitive = val;
            toolbar.share_app_menu.sensitive = val;
        }

        // Get current document
        public Scratch.Services.Document? get_current_document () {
            return document_view.current_document;
        }

        // Get current document if it's focused
        public Scratch.Services.Document? get_focused_document () {
            return document_view.current_document;
        }

        public void open_folder (File folder) {
            var foldermanager_file = new FolderManager.File (folder.get_path ());
            folder_manager_view.open_folder (foldermanager_file);
        }

        public void open_document (Scratch.Services.Document doc,
                                   bool focus = true,
                                   int cursor_position = 0) {

            FolderManager.ProjectFolderItem? project = folder_manager_view.get_project_for_file (doc.file);
            doc.source_view.project = project;
            document_view.open_document (doc, focus, cursor_position);
        }

        public void open_document_at_selected_range (Scratch.Services.Document doc,
                                                     bool focus = true,
                                                     SelectionRange range = SelectionRange.EMPTY,
                                                     bool is_override = false) {
            if (restore_override != null && is_override == false) {
                return;
            }

            FolderManager.ProjectFolderItem? project = folder_manager_view.get_project_for_file (doc.file);
            doc.source_view.project = project;
            document_view.open_document (doc, focus, 0, range);
        }

        // Close a document
        public void close_document (Scratch.Services.Document doc) {
            document_view.close_document (doc);
        }

        // Check that there no unsaved changes and all saves are successful
        private async bool check_unsaved_changes () {
            document_view.is_closing = true;
            foreach (var doc in document_view.docs) {
                if (!yield (doc.do_close (true))) {
                    document_view.current_document = doc;
                    return false;
                }
            }

            return true;
        }

        // Save session information different from window state
        private void restore_saved_state_extra () {
            // Plugin panes size
            hp1.set_position (Scratch.saved_state.get_int ("hp1-size"));
            vp.set_position (Scratch.saved_state.get_int ("vp-size"));
        }

        private void create_unsaved_documents_directory () {
            var directory = File.new_for_path (app.data_home_folder_unsaved);
            if (!directory.query_exists ()) {
                try {
                    directory.make_directory_with_parents ();
                    debug ("created 'unsaved' directory: %s", directory.get_path ());
                } catch (Error e) {
                    critical ("Unable to create the 'unsaved' directory: '%s': %s", directory.get_path (), e.message);
                }
            }
        }

        private void update_saved_state () {
            // Save window state
            var state = get_window ().get_state ();
            if (Gdk.WindowState.MAXIMIZED in state) {
                Scratch.saved_state.set_enum ("window-state", ScratchWindowState.MAXIMIZED);
            } else if (Gdk.WindowState.FULLSCREEN in state) {
                Scratch.saved_state.set_enum ("window-state", ScratchWindowState.FULLSCREEN);
            } else {
                Scratch.saved_state.set_enum ("window-state", ScratchWindowState.NORMAL);
                // Save window size
                int width, height;
                get_size (out width, out height);
                Scratch.saved_state.set ("window-size", "(ii)", width, height);
            }

            // Plugin panes size
            Scratch.saved_state.set_int ("hp1-size", hp1.get_position ());
            Scratch.saved_state.set_int ("vp-size", vp.get_position ());
        }

        // SIGTERM/SIGINT Handling
        public bool quit_source_func () {
            action_quit ();
            return false;
        }

        // For exit cleanup
        private void handle_quit () {
            document_view.save_opened_files ();
            update_saved_state ();
        }

        public void set_default_zoom () {
            terminal.set_default_font_size ();
            Scratch.settings.set_string ("font", get_current_font () + " " + get_default_font_size ().to_string ());
        }

        // Ctrl + scroll
        public void action_zoom_in () {
            terminal.increment_size ();
            zooming (Gdk.ScrollDirection.UP);
        }

        // Ctrl + scroll
        public void action_zoom_out () {
            terminal.decrement_size ();
            zooming (Gdk.ScrollDirection.DOWN);
        }

        private void zooming (Gdk.ScrollDirection direction) {
            string font = get_current_font ();
            int font_size = (int) get_current_font_size ();
            if (Scratch.settings.get_boolean ("use-system-font")) {
                Scratch.settings.set_boolean ("use-system-font", false);
                font = get_default_font ();
                font_size = (int) get_default_font_size ();
            }

            if (direction == Gdk.ScrollDirection.DOWN) {
                font_size --;
                if (font_size < FONT_SIZE_MIN) {
                    return;
                }
            } else if (direction == Gdk.ScrollDirection.UP) {
                font_size ++;
                if (font_size > FONT_SIZE_MAX) {
                    return;
                }
            }

            string new_font = font + " " + font_size.to_string ();
            Scratch.settings.set_string ("font", new_font);
        }

        public string get_current_font () {
            string font = Scratch.settings.get_string ("font");
            string font_family = font.substring (0, font.last_index_of (" "));
            return font_family;
        }

        public double get_current_font_size () {
            string font = Scratch.settings.get_string ("font");
            string font_size = font.substring (font.last_index_of (" ") + 1);
            return double.parse (font_size);
        }

        public string get_default_font () {
            string font = app.default_font;
            string font_family = font.substring (0, font.last_index_of (" "));
            return font_family;
        }

        public double get_default_font_size () {
            string font = app.default_font;
            string font_size = font.substring (font.last_index_of (" ") + 1);
            return double.parse (font_size);
        }

        // Actions functions
        private void action_set_default_zoom () {
            set_default_zoom ();
        }

        private void action_preferences () {
            if (preferences_dialog == null) {
                preferences_dialog = new Scratch.Dialogs.Preferences (this, plugins);
                preferences_dialog.show_all ();

                preferences_dialog.destroy.connect (() => {
                    preferences_dialog = null;
                });
            }

            preferences_dialog.present ();
        }

        private void action_quit () {
            handle_quit ();
            check_unsaved_changes.begin ((obj, res) => {
                if (check_unsaved_changes.end (res)) {
                    destroy ();
                }
            });
        }

        private void action_open () {
            var all_files_filter = new Gtk.FileFilter ();
            all_files_filter.set_filter_name (_("All files"));
            all_files_filter.add_pattern ("*");

            var text_files_filter = new Gtk.FileFilter ();
            text_files_filter.set_filter_name (_("Text files"));
            text_files_filter.add_mime_type ("text/*");

            var file_chooser = new Gtk.FileChooserNative (
                _("Open some files"),
                this,
                Gtk.FileChooserAction.OPEN,
                _("Open"),
                _("Cancel")
            );
            file_chooser.add_filter (text_files_filter);
            file_chooser.add_filter (all_files_filter);
            file_chooser.select_multiple = true;
            file_chooser.set_current_folder_uri (Utils.last_path ?? GLib.Environment.get_home_dir ());

            var response = file_chooser.run ();
            file_chooser.destroy (); // Close now so it does not stay open during lengthy or failed loading

            if (response == Gtk.ResponseType.ACCEPT) {
                foreach (string uri in file_chooser.get_uris ()) {
                    // Update last visited path
                    Utils.last_path = Path.get_dirname (uri);
                    // Open the file
                    var file = File.new_for_uri (uri);
                    var doc = new Scratch.Services.Document (actions, file);
                    open_document (doc);
                }
            }
        }

        private void action_open_folder (SimpleAction action, Variant? param) {
            var path = param.get_string ();
            if (path == "") {
                var chooser = new Gtk.FileChooserNative (
                    "Select a folder.", this, Gtk.FileChooserAction.SELECT_FOLDER,
                    _("_Open"),
                    _("_Cancel")
                );

                chooser.select_multiple = true;

                if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                    chooser.get_files ().foreach ((glib_file) => {
                        var foldermanager_file = new FolderManager.File (glib_file.get_path ());
                        folder_manager_view.open_folder (foldermanager_file);
                    });
                }

                chooser.destroy ();
            } else {
                folder_manager_view.open_folder (new FolderManager.File (path));
            }
        }

        private void action_collapse_all_folders () {
            folder_manager_view.collapse_all ();
        }

        private void action_order_folders () {
            folder_manager_view.order_folders ();
        }

        private void action_save () {
            var doc = get_current_document (); /* may return null */
            if (doc != null) {
                if (doc.is_file_temporary == true) {
                    action_save_as ();
                } else {
                    doc.save_request ();
                }
            }
        }

        private void action_save_as () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.save_as_with_hold.begin ();
            }
        }

        private void action_undo () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.undo ();
            }
        }

        private void action_redo () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.redo ();
            }
        }

        private void action_revert () {
            var confirmation_dialog = new Scratch.Dialogs.RestoreConfirmationDialog (this);
            if (confirmation_dialog.run () == Gtk.ResponseType.ACCEPT) {
                var doc = get_current_document ();
                if (doc != null) {
                    doc.revert ();
                }
            }
            confirmation_dialog.destroy ();
        }

        private void action_duplicate () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.duplicate_selection ();
            }
        }

        private void action_new_tab () {
            document_view.new_document ();
        }

        private void action_new_tab_from_clipboard () {
            string text_from_clipboard = clipboard.wait_for_text ();
            document_view.new_document_from_clipboard (text_from_clipboard);
        }

        private void action_fullscreen () {
            if (Gdk.WindowState.FULLSCREEN in get_window ().get_state ()) {
                unfullscreen ();
            } else {
                fullscreen ();
            }
        }

        private void action_close_tab (SimpleAction action, Variant? param) {
            var close_path = get_target_path_for_actions (param);
            unowned var docs = document_view.docs;
            docs.foreach ((doc) => {
                if (doc.file.get_path () == close_path) {
                    document_view.close_document (doc);
                }
            });
        }

        private void action_hide_project_docs (SimpleAction action, Variant? param) {
            close_project_docs (get_target_path_for_actions (param), true);
        }

        private void action_close_project_docs (SimpleAction action, Variant? param) {
            close_project_docs (get_target_path_for_actions (param), false);
        }

        private void action_restore_project_docs (SimpleAction action, Variant? param) {
            restore_project_docs (get_target_path_for_actions (param));
        }

        private void close_project_docs (string project_path, bool make_restorable) {
            unowned var docs = document_view.docs;
            docs.foreach ((doc) => {
                if (doc.file.get_path ().has_prefix (project_path + Path.DIR_SEPARATOR_S)) {
                    document_view.close_document (doc);
                    if (make_restorable) {
                        document_manager.make_restorable (doc);
                    }
                }
            });

            if (!make_restorable) {
                document_manager.remove_project (project_path);
            }
        }

        private void restore_project_docs (string project_path) {
            document_manager.take_restorable_paths (project_path).@foreach ((doc_path) => {
                var doc = new Scratch.Services.Document (actions, File.new_for_path (doc_path));
                open_document (doc); // Use this to reassociate project and document.
                return true;
            });
        }

        /** Not a toggle action - linked to keyboard short cut (Ctrl-f). **/
        private string current_search_term = "";
        private void action_fetch (SimpleAction action, Variant? param) {
            current_search_term = param != null ? param.get_string () : "";
            if (!search_revealer.child_revealed) {
                var show_find_action = Utils.action_from_group (ACTION_SHOW_FIND, actions);
                if (show_find_action.enabled) {
                    /* Toggling the fetch action causes this function to be called again but the search_revealer child
                     * is still not revealed so nothing more happens.  We use the map signal on the search entry
                     * to set it up once it has been revealed. */
                    show_find_action.set_state (true);
                }
            } else {
                set_search_text ();
            }
        }

        private void action_show_replace (SimpleAction action) {
            action_fetch (action, null);
            // May have to wait for the search bar to be revealed before we can grab focus
            if (search_revealer.child_revealed) {
                search_bar.replace_entry.grab_focus ();
            } else {
                ulong map_handler = 0;
                map_handler = search_bar.map.connect_after (() => {
                    search_bar.replace_entry.grab_focus ();
                    search_bar.disconnect (map_handler);
                });
            }
        }

        private void action_find_next () {
            search_bar.search_next ();
        }

        private void action_find_previous () {
            search_bar.search_previous ();
        }

        private void action_find_global (SimpleAction action, Variant? param) {
            var current_doc = get_current_document ();
            string selected_text = "";
            if (current_doc != null) {
                selected_text = current_doc.get_selected_text (false);
            }

            if (selected_text != "") {
                selected_text = selected_text.split ("\n", 2)[0];
            }
            // If search entry focused use its text for search term, else use selected text
            var term = search_bar.search_entry.has_focus ?
                            search_bar.search_entry.text : selected_text;

            // If no focused selected text fallback to search entry text if visible
            if (term == "" &&
                !search_bar.search_entry.has_focus &&
                search_revealer.reveal_child) {

                term = search_bar.search_entry.text;
            }

            folder_manager_view.search_global (get_target_path_for_actions (param), term);
        }

        private void update_find_actions () {
            // Idle needed to ensure that existence of current_doc is up to date
            Idle.add (() => {
                var is_current_doc = get_current_document () != null;
                Utils.action_from_group (ACTION_FIND, actions).set_enabled (is_current_doc);
                Utils.action_from_group (ACTION_SHOW_FIND, actions).set_enabled (is_current_doc);
                Utils.action_from_group (ACTION_FIND_NEXT, actions).set_enabled (is_current_doc);
                Utils.action_from_group (ACTION_FIND_PREVIOUS, actions).set_enabled (is_current_doc);

                var is_active_project = git_manager.active_project_path != "";
                Utils.action_from_group (ACTION_FIND_GLOBAL, actions).set_enabled (is_active_project);
                return Source.REMOVE;
            });
        }

        private void set_search_text () {
            if (current_search_term != "") {
                search_bar.search_entry.text = current_search_term;
                search_bar.search_entry.grab_focus ();
                search_bar.search_next ();
            } else if (search_bar.search_entry.text != "") {
                // Always search on what is showing in search entry
                current_search_term = search_bar.search_entry.text;
                search_bar.search_entry.grab_focus ();
            } else {
                var current_doc = get_current_document ();
                // This is also called when all documents are closed.
                if (current_doc != null) {
                    var selected_text = current_doc.get_selected_text (false);
                    if (selected_text != "" && selected_text.length < MAX_SEARCH_TEXT_LENGTH) {
                        current_search_term = selected_text.split ("\n", 2)[0];
                        search_bar.search_entry.text = current_search_term;
                    }

                    search_bar.search_entry.grab_focus (); /* causes loss of document selection */
                }
            }

            if (current_search_term != "") {
                search_bar.search_next (); /* this selects the next match (if any) */
            }
        }

        /** Toggle action - linked to toolbar togglebutton. **/
        private void action_show_fetch () {
            var fetch_action = Utils.action_from_group (ACTION_SHOW_FIND, actions);
            fetch_action.set_state (!fetch_action.get_state ().get_boolean ());
        }

        private void action_go_to () {
            toolbar.format_bar.line_menubutton.active = true;
        }

        private void action_templates () {
            plugins.plugin_iface.template_manager.show_window (this);
        }

        private void action_to_lower_case () {
            var doc = document_view.current_document;
            if (doc == null) {
                return;
            }

            var buffer = doc.source_view.buffer;
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            string selected = buffer.get_text (start, end, true);

            buffer.delete (ref start, ref end);
            buffer.insert (ref start, selected.down (), -1);
        }

        private void action_to_upper_case () {
            var doc = document_view.current_document;
            if (doc == null) {
                return;
            }

            var buffer = doc.source_view.buffer;
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            string selected = buffer.get_text (start, end, true);

            buffer.delete (ref start, ref end);
            buffer.insert (ref start, selected.up (), -1);
        }

        private void action_toggle_comment () {
            var doc = get_focused_document ();
            if (doc == null) {
                return;
            }

            var buffer = doc.source_view.buffer;
            if (buffer is Gtk.SourceBuffer) {
                CommentToggler.toggle_comment (buffer as Gtk.SourceBuffer);
            }
        }

        private void action_sort_lines () {
            var doc = get_focused_document ();
            if (doc == null) {
                return;
            }

            doc.source_view.sort_selected_lines ();
        }

        private void action_toggle_sidebar (SimpleAction action) {
            if (sidebar == null) {
                return;
            }

            action.set_state (!action.get_state ().get_boolean ());
            sidebar.visible = action.get_state ().get_boolean ();
        }

        private void action_toggle_terminal () {
            var toggle_terminal_action = Utils.action_from_group (ACTION_TOGGLE_TERMINAL, actions);
            toggle_terminal_action.set_state (!toggle_terminal_action.get_state ().get_boolean ());

            terminal.visible = toggle_terminal_action.get_state ().get_boolean ();

            if (toggle_terminal_action.get_state ().get_boolean ()) {
                terminal.grab_focus ();
            } else if (get_current_document () != null) {
                get_current_document ().focus ();
            }
        }

        private void action_open_in_terminal (SimpleAction action, Variant? param) {
            // Ensure terminal is visible
            if (terminal == null || !terminal.visible) {
                var toggle_terminal_action = Utils.action_from_group (ACTION_TOGGLE_TERMINAL, actions);
                toggle_terminal_action.activate (null);
            }

            //If param is null or empty, the active project path build dir is returned or failing that
            //the active document path
            var target_path = get_target_path_for_actions (param, true);
            terminal.change_location (target_path);
            terminal.terminal.grab_focus ();
        }

        private void action_toggle_outline (SimpleAction action) {
            action.set_state (!action.get_state ().get_boolean ());
            document_view.outline_visible = action.get_state ().get_boolean ();
        }

        private void action_next_tab () {
            document_view.next_document ();
        }

        private void action_previous_tab () {
            document_view.previous_document ();
        }

        private void action_clear_lines () {
            var doc = get_focused_document ();
            if (doc == null) {
                return;
            }

            doc.source_view.clear_selected_lines ();
        }

        private void action_new_branch (SimpleAction action, Variant? param) {
            folder_manager_view.new_branch (get_target_path_for_actions (param));
        }

        private string? get_target_path_for_actions (Variant? path_variant, bool use_build_dir = false) {
             string? path = "";
             if (path_variant != null) {
                 path = path_variant.get_string ();
             }

             if (path == "") { // Happens when keyboard accelerator is used
                 path = git_manager.active_project_path;
                 if (use_build_dir) {
                     path = git_manager.get_default_build_dir (path);
                 }

                 if (path == null) {
                     var current_doc = get_current_document ();
                     if (current_doc != null) {
                         path = current_doc.file.get_path ();
                     } else {
                         return null; // Cannot determine target project
                     }
                 }
             }

             return path;
         }
    }
}


