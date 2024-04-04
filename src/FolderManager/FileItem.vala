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
     * Normal item in the source list, represents a textfile.
     */
    public class FileItem : Item {
        public FileItem (File file, FileView view) {
            Object (file: file, view: view);
        }

        public override GLib.Menu? get_context_menu () {
            var toplevel_actions = view.toplevel_action_group as SimpleActionGroup;

            var open_in_terminal_pane_item = new GLib.MenuItem (_("Open in Terminal Pane"), MainWindow.ACTION_PREFIX
                                                                + MainWindow.ACTION_OPEN_IN_TERMINAL);
            open_in_terminal_pane_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, new Variant.string (file.file.get_parent ().get_path ()));

            var new_window_menu_item = new GLib.MenuItem (_("New Window"), MainWindow.ACTION_PREFIX
                                                          + MainWindow.ACTION_OPEN_IN_NEW_WINDOW);
            new_window_menu_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, new Variant.string (file.file.get_path ()));

            GLib.FileInfo info = null;

            try {
                info = file.file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, 0);
            } catch (Error e) {
                warning (e.message);
            }

            var file_type = info.get_attribute_string (GLib.FileAttribute.STANDARD_CONTENT_TYPE);
            var launch_app_action = Utils.action_from_group (MainWindow.ACTION_LAUNCH_APP_WITH_FILE_PATH, toplevel_actions) as SimpleAction;
            launch_app_action.change_state (new GLib.Variant.string (file_type));

            var rename_menu_item = new GLib.MenuItem (_("Rename"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_RENAME_FILE);
            rename_menu_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, file.path);

            var rename_file_action = Utils.action_from_group (MainWindow.ACTION_RENAME_FILE, toplevel_actions) as SimpleAction;
            rename_file_action.set_enabled (view.rename_request (file));

            var open_in_menu = Utils.create_executable_app_items_for_file (file.file, file_type);

            var external_actions_menu_section = new GLib.Menu ();
            external_actions_menu_section.append_submenu (_("Open In"), open_in_menu);
            external_actions_menu_section.append_item (open_in_terminal_pane_item);

            var direct_actions_menu_section = new GLib.Menu ();
            direct_actions_menu_section.append_item (rename_menu_item);

            var menu = new GLib.Menu ();
            menu.append_section (null, external_actions_menu_section);
            menu.append_section (null, direct_actions_menu_section);
            return menu;
        }
    }
}
