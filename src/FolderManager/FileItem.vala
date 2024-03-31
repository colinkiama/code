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
            
            var menu = new GLib.Menu ();
            menu.append_item (open_in_terminal_pane_item);
            return menu;
        }
    }
}
