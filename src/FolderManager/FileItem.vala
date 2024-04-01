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
            var launch_app_action = Utils.action_from_group (MainWindow.ACTION_LAUNCH_APP_WITH_FILE_PATH, view.toplevel_action_group as SimpleActionGroup) as SimpleAction;
            launch_app_action.change_state (new GLib.Variant.string (file_type));

            var open_in_menu = Utils.create_executable_app_items_for_file (file.file, file_type);

            var menu = new GLib.Menu ();
            menu.append_submenu (_("Open In"), open_in_menu);
            menu.append_item (open_in_terminal_pane_item);
            return menu;
        }
    }
}
