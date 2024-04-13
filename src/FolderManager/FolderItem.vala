/*-
 * Copyright (c) 2017-2018 elementary LLC. (https://elementary.io),
 *               2013 Julien Spautz <spautz.julien@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3
 * as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

namespace Scratch.FolderManager {
    /**
     * Expandable item in the source list, represents a folder.
     * Monitored for changes inside the directory.
     */
    public class FolderItem : Item {
        private GLib.FileMonitor monitor;
        private bool children_loaded = false;
        private bool has_dummy;
        private Code.Widgets.SourceList.Item dummy; /* Blank item for expanded empty folders */

        public FolderItem (File file, FileView view) requires (file.is_valid_directory) {
            Object (file: file, view: view);
        }

        ~FolderItem () {
            monitor.cancel ();
        }

        construct {
            selectable = false;

            dummy = new Code.Widgets.SourceList.Item ("");
            // Must add dummy on unexpanded folders else expander will not show
            ((Code.Widgets.SourceList.ExpandableItem)this).add (dummy);
            has_dummy = true;

            toggled.connect (on_toggled);

            try {
                monitor = file.file.monitor_directory (GLib.FileMonitorFlags.NONE);
                monitor.changed.connect (on_changed);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        }

        private void on_toggled () {
            var root = get_root_folder ();
            if (!children_loaded &&
                 expanded &&
                 n_children <= 1 &&
                 file.children.size > 0) {

                foreach (var child in file.children) {
                    Code.Widgets.SourceList.Item item = null;
                    if (child.is_valid_directory ()) {
                        item = new FolderItem (child, view);
                    } else if (child.is_valid_textfile) {
                        item = new FileItem (child, view);
                    }

                    if (item != null) {
                        add (item);
                    }
                }

                children_loaded = true;
                if (root != null) {
                    root.child_folder_loaded (this);
                }
            } else if (!expanded &&
                       root != null &&
                       root.monitored_repo != null) {
                //When toggled closed, update status to reflect hidden contents
                root.update_item_status (this);
            }
        }

        public override GLib.Menu? get_context_menu () {
            var open_in_terminal_pane_item = new GLib.MenuItem (_("Open in Terminal Pane"), MainWindow.ACTION_PREFIX
                                                                + MainWindow.ACTION_OPEN_IN_TERMINAL);
            open_in_terminal_pane_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, new Variant.string (file.file.get_path ()));
            open_in_terminal_pane_item.set_attribute_value ("accel", "");

            GLib.FileInfo info = null;

            try {
                info = file.file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, 0);
            } catch (Error e) {
                warning (e.message);
            }

            var file_type = info.get_attribute_string (GLib.FileAttribute.STANDARD_CONTENT_TYPE) ?? "inode/directory";
            var launch_app_action = Utils.action_from_group (FileView.ACTION_LAUNCH_APP_WITH_FILE_PATH, view.actions) as SimpleAction;
            launch_app_action.change_state (new GLib.Variant.string (file_type));

            var rename_menu_item = new GLib.MenuItem (_("Rename"), FileView.ACTION_PREFIX + FileView.ACTION_RENAME_FOLDER);
            view.rename_folder_action.activate.connect (handle_rename_action);

            var delete_menu_item = new GLib.MenuItem (_("Move to Trash"), FileView.ACTION_PREFIX + FileView.ACTION_DELETE);
            delete_menu_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, file.path);

            var open_in_menu = new GLib.Menu ();
            var open_in_top_section = new GLib.Menu ();

            var open_in_app_section = Utils.create_executable_app_items_for_file (file.file, file_type);

            var open_in_extra_section = new GLib.Menu ();
            var open_in_other_menu_item = new GLib.MenuItem (_("Other Application…"), FileView.ACTION_PREFIX + FileView.ACTION_SHOW_APP_CHOOSER);
            open_in_other_menu_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, file.path);
            open_in_extra_section.append_item (open_in_other_menu_item);

            open_in_menu.append_section (null, open_in_top_section);
            open_in_menu.append_section (null, open_in_app_section);
            open_in_menu.append_section (null, open_in_extra_section);

            var contractor_submenu = Utils.create_contract_items_for_file (file.file, file_type);

            var external_actions_menu_section = new GLib.Menu ();
            external_actions_menu_section.append_item (open_in_terminal_pane_item);
            external_actions_menu_section.append_submenu (_("Open In"), open_in_menu);
            if (contractor_submenu.get_n_items () > 0) {
                external_actions_menu_section.append_submenu (_("Other Actions"), contractor_submenu);
            }

            var direct_actions_menu_section = new GLib.Menu ();
            direct_actions_menu_section.append_submenu (_("New"), create_submenu_for_new ());
            direct_actions_menu_section.append_item (rename_menu_item);
            direct_actions_menu_section.append_item (delete_menu_item);

            var search_menu_item = new GLib.MenuItem (_("Find in Folder…"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_FIND_GLOBAL);
            search_menu_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, file.file.get_path ());

            var search_menu_section = new GLib.Menu ();
            search_menu_section.append_item (search_menu_item);

            var menu = new GLib.Menu ();
            menu.append_section (null, external_actions_menu_section);
            menu.append_section (null, direct_actions_menu_section);
            menu.append_section (null, search_menu_section);
            return menu;
        }

        protected Gtk.MenuItem create_submenu_for_open_in (GLib.FileInfo? info, string? file_type) {
            var other_menuitem = new Gtk.MenuItem.with_label (_("Other Application…"));
            other_menuitem.activate.connect (() => show_app_chooser (file));

            file_type = file_type ?? "inode/directory";

            var open_in_menu = new Gtk.Menu ();

            if (info != null) {
                List<AppInfo> external_apps = GLib.AppInfo.get_all_for_type (file_type);

                string this_id = GLib.Application.get_default ().application_id + ".desktop";

                foreach (AppInfo app_info in external_apps) {
                    if (app_info.get_id () == this_id) {
                        continue;
                    }

                    var menuitem_icon = new Gtk.Image.from_gicon (app_info.get_icon (), Gtk.IconSize.MENU);
                    menuitem_icon.pixel_size = 16;

                    var menuitem_grid = new Gtk.Grid ();
                    menuitem_grid.add (menuitem_icon);
                    menuitem_grid.add (new Gtk.Label (app_info.get_name ()));

                    var item_app = new Gtk.MenuItem ();
                    item_app.add (menuitem_grid);

                    item_app.activate.connect (() => {
                        launch_app_with_file (app_info, file.file);
                    });
                    open_in_menu.add (item_app);
                }
            }

            if (open_in_menu.get_children ().length () > 0) {
                open_in_menu.add (new Gtk.SeparatorMenuItem ());
            }

            open_in_menu.add (other_menuitem);

            var open_in_item = new Gtk.MenuItem.with_label (_("Open In"));
            open_in_item.submenu = open_in_menu;

            return open_in_item;
        }

        protected GLib.Menu create_submenu_for_new () {
            var new_folder_item = new GLib.MenuItem (_("Folder"), FileView.ACTION_PREFIX + FileView.ACTION_NEW_FOLDER);
            new_folder_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, file.file.get_path ());

            var new_file_item = new GLib.MenuItem (_("Empty File"), FileView.ACTION_PREFIX + FileView.ACTION_NEW_FILE);
            new_file_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, file.file.get_path ());

            var menu = new GLib.Menu ();
            menu.append_item (new_folder_item);
            menu.append_item (new_file_item);

            return menu;
        }

        public void remove_all_badges () {
            foreach (var child in children) {
                remove_badge (child);
            }
        }

        private void remove_badge (Code.Widgets.SourceList.Item item) {
            if (item is FolderItem) {
                ((FolderItem) item).remove_all_badges ();
            }

            item.badge = "";
        }

        public new void add (Code.Widgets.SourceList.Item item) {
            if (has_dummy && n_children == 1) {
                ((Code.Widgets.SourceList.ExpandableItem)this).remove (dummy);
                has_dummy = false;
            }

            ((Code.Widgets.SourceList.ExpandableItem)this).add (item);
        }

        public new void remove (Code.Widgets.SourceList.Item item) {
            if (item is FolderItem) {
                var folder = (FolderItem)item;
                foreach (var child in folder.children) {
                    folder.remove (child);
                }
            }

            view.ignore_next_select = true;
            ((Code.Widgets.SourceList.ExpandableItem)this).remove (item);
            // Add back dummy if empty unless we are removing a rename item
            if (!(item is RenameItem || has_dummy || n_children > 0)) {
                ((Code.Widgets.SourceList.ExpandableItem)this).add (dummy);
                has_dummy = true;
            }
        }

        public new void clear () {
            ((Code.Widgets.SourceList.ExpandableItem)this).clear ();
            has_dummy = false;
        }

        protected virtual void on_changed (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {
            if (source.get_basename ().has_prefix (".goutputstream")) {
                return; // Ignore changes due to temp files and streams
            }

            view.folder_item_update_hook (source, dest, event);

            if (!children_loaded) { // No child items except dummy, child never expanded
                /* Empty folder with dummy item will come here even if expanded */
                switch (event) {
                    case GLib.FileMonitorEvent.DELETED:
                        file.invalidate_cache (); //TODO Throttle if required
                        if (expanded) {
                            toggled ();
                        }
                        break;
                    case GLib.FileMonitorEvent.CREATED:
                        file.invalidate_cache ();  //TODO Throttle if required
                        if (expanded) {
                            toggled ();
                        }
                        break;
                    case FileMonitorEvent.RENAMED:
                    case FileMonitorEvent.PRE_UNMOUNT:
                    case FileMonitorEvent.UNMOUNTED:
                    case FileMonitorEvent.CHANGED:
                    case FileMonitorEvent.CHANGES_DONE_HINT:
                    case FileMonitorEvent.MOVED:
                    case FileMonitorEvent.MOVED_IN:
                    case FileMonitorEvent.MOVED_OUT:
                    case FileMonitorEvent.ATTRIBUTE_CHANGED:

                        break;
                }
            } else { // Child has been expanded ( but could be closed now) and items loaded (or dummy)
                // No cache invalidation is needed here because the entire state is kept in the tree
                switch (event) {
                    case GLib.FileMonitorEvent.DELETED:
                        // Find item corresponding to deleted file
                        // Note may not be found if deleted file is not valid for display
                        var path_item = find_item_for_path (source.get_path ());
                        if (path_item != null) {
                            remove (path_item);
                        }

                        break;
                    case GLib.FileMonitorEvent.CREATED:
                        if (source.query_exists () == false) {
                            return;
                        }

                        var path_item = find_item_for_path (source.get_path ());
                        if (path_item == null) {
                            var file = new File (source.get_path ());
                            if (file.is_valid_directory ()) {
                                path_item = new FolderItem (file, view);
                            } else if (!file.is_temporary) {
                                path_item = new FileItem (file, view);
                            } else {
                                break;
                            }

                            add (path_item);
                        }

                        break;
                    case FileMonitorEvent.RENAMED:
                    case FileMonitorEvent.PRE_UNMOUNT:
                    case FileMonitorEvent.UNMOUNTED:
                    case FileMonitorEvent.CHANGED:
                    case FileMonitorEvent.CHANGES_DONE_HINT:
                    case FileMonitorEvent.MOVED:
                    case FileMonitorEvent.MOVED_IN:
                    case FileMonitorEvent.MOVED_OUT:
                    case FileMonitorEvent.ATTRIBUTE_CHANGED:
                        break;
                }
            }

            // Reduce spamming of root (still results in multiple signals per change in file being edited
            //TODO Throttle this signal?
            if (event == FileMonitorEvent.CHANGES_DONE_HINT) {
                //TODO Get root folder once as it will not change for the life of this folder
                var root = get_root_folder (this);
                if (root != null) {
                    root.child_folder_changed (this);
                }
            }
        }

        private FolderManager.Item? find_item_for_path (string path) {
            foreach (var item in children) {
                // Item could be dummy
                if ((item is FolderManager.Item) && ((FolderManager.Item) item).path == path) {
                    return (FolderManager.Item)item;
                }
            }

            return null;
        }

        public void on_add_new (bool is_folder) {
            if (!file.is_executable) {
                // This is necessary to avoid infinite loop below
                warning ("Unable to open parent folder");
                return;
            }

            unowned string name = is_folder ? _("untitled folder") : _("new file");
            var new_file = file.file.get_child (name);
            var n = 1;

            while (new_file.query_exists ()) {
                new_file = file.file.get_child (("%s %d").printf (name, n));
                n++;
            }
            expanded = true;
            var rename_item = new RenameItem (new_file.get_basename (), is_folder);
            add (rename_item);
            /* Start editing after finishing signal handler */
            GLib.Idle.add (() => {
                if (view.start_editing_item (rename_item)) {
                    ulong once = 0;
                    once = rename_item.edited.connect (() => {
                        rename_item.disconnect (once);
                        // A name was accepted so create the corresponding file
                        var new_name = rename_item.name;
                        try {
                            var gfile = file.file.get_child_for_display_name (new_name);
                            if (is_folder) {
                                gfile.make_directory ();
                            } else {
                                gfile.create (FileCreateFlags.NONE);
                                view.select (gfile.get_path ());
                            }
                        } catch (Error e) {
                            warning (e.message);
                        }
                    });

                    /* Need to remove rename item even when editing cancelled so cannot use "edited" signal */
                    Timeout.add (200, () => {
                        if (view.editing) {
                            return Source.CONTINUE;
                        } else {
                            remove (rename_item);
                        }

                        return Source.REMOVE;
                    });
                } else {
                    remove (rename_item);
                }


                return Source.REMOVE;
            });
        }

        private void handle_rename_action () {
            selectable = true;
            if (view.start_editing_item (this)) {
                // Need to poll view as no signal emited when editing cancelled and need to set
                // selectable to false anyway.
                Timeout.add (200, () => {
                    if (view.editing) {
                        return Source.CONTINUE;
                    } else {
                        view.unselect_all ();
                        // Must do this *after* unselecting all else sourcelist breaks
                        selectable = false;
                    }

                    return Source.REMOVE;
                });
            } else {
                debug ("Could not rename %s", file.path);
                selectable = false;
            }
        }
    }

    internal class RenameItem : Code.Widgets.SourceList.Item {
        public bool is_folder { get; construct; }

        public RenameItem (string name, bool is_folder) {
            Object (
                name: name,
                is_folder: is_folder
            );
        }

        construct {
            editable = true;
            edited.connect (on_edited);

            if (is_folder) {
                icon = GLib.ContentType.get_icon ("inode/directory");
            } else {
                icon = GLib.ContentType.get_icon ("text");
            }
        }

        private void on_edited (string new_name) {
            if (new_name != "") {
                name = new_name;
            }
        }
    }
}
