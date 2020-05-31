/*-
 * Copyright (c) 2014-2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Jeremy Wootten <jeremy@elementaryos.org>
 */

namespace AppCenter.Views {

    public class AppListUpdateView : Gtk.ListBox {
        public signal void show_app (AppCenterCore.Package package);

        private Gtk.Button? update_all_button;

        public Gtk.SizeGroup action_button_group;
        private Gtk.SizeGroup info_grid_group;

        public bool updating_all_apps { get; private set; default = false; }

        construct {
            expand = true;
            activate_on_single_click = true;

            set_sort_func ((Gtk.ListBoxSortFunc) package_row_compare);
            row_activated.connect ((r) => {
                var row = (Widgets.AppListRow)r;
                show_app (row.get_package ());
            });

            action_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
            info_grid_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);

            var loading_view = new Granite.Widgets.AlertView (
                _("Checking for Updates"),
                _("Downloading a list of available updates to the OS and installed apps"),
                "sync-synchronizing"
            );
            loading_view.show_all ();

            set_header_func ((Gtk.ListBoxUpdateHeaderFunc) row_update_header);
            set_placeholder (loading_view);
        }

        public void add_packages (Gee.Collection<AppCenterCore.Package> packages) {
            foreach (var package in packages) {
                add_row_for_package (package);
            }

            invalidate_sort ();
        }

        public void add_package (AppCenterCore.Package package) {
            add_row_for_package (package);
            invalidate_sort ();
        }

        private void add_row_for_package (AppCenterCore.Package package) {
            var needs_update = package.state == AppCenterCore.Package.State.UPDATE_AVAILABLE;

            // Only add row if this package needs an update or it's not a font or plugin
            if (needs_update || (!package.is_plugin && !package.is_font)) {
                var row = new Widgets.PackageRow.installed (package, info_grid_group, action_button_group);
                row.show_all ();
                add (row);
            }
        }

        public void clear () {
            foreach (weak Gtk.Widget r in get_children ()) {
                weak Widgets.AppListRow row = r as Widgets.AppListRow;
                if (row == null) {
                    continue;
                }

                row.destroy ();
            };

            invalidate_sort ();
        }

        public void remove_package (AppCenterCore.Package package) {
            foreach (weak Gtk.Widget r in get_children ()) {
                weak Widgets.AppListRow row = r as Widgets.AppListRow;

                if (row.get_package () == package) {
                    row.destroy ();
                    break;
                }
            }

            invalidate_sort ();
        }

        [CCode (instance_pos = -1)]
        private int package_row_compare (Widgets.AppListRow row1, Widgets.AppListRow row2) {
            bool a_is_updating = row1.get_is_updating ();
            bool b_is_updating = row2.get_is_updating ();

            // The currently updating package is always top of the list
            if (a_is_updating || b_is_updating) {
                return a_is_updating ? -1 : 1;
            }

            bool a_has_updates = row1.get_update_available ();
            bool b_has_updates = row2.get_update_available ();

            bool a_is_os = row1.get_is_os_updates ();
            bool b_is_os = row2.get_is_os_updates ();

            // Sort updatable OS updates first, then other updatable packages
            if (a_has_updates != b_has_updates) {
                if (a_is_os && a_has_updates) {
                    return -1;
                }

                if (b_is_os && b_has_updates) {
                    return 1;
                }

                if (a_has_updates) {
                    return -1;
                }

                if (b_has_updates) {
                    return 1;
                }
            }

            bool a_is_driver = row1.get_is_driver ();
            bool b_is_driver = row2.get_is_driver ();

            if (a_is_driver != b_is_driver) {
                return a_is_driver ? - 1 : 1;
            }

            // Ensures OS updates are sorted to the top amongst up-to-date packages
            if (a_is_os || b_is_os) {
                return a_is_os ? -1 : 1;
            }

            return row1.get_name_label ().collate (row2.get_name_label ()); /* Else sort in name order */
        }

        private Gee.Collection<AppCenterCore.Package> get_packages () {
            var tree_set = new Gee.TreeSet<AppCenterCore.Package> ();
            foreach (weak Gtk.Widget r in get_children ()) {
                weak Widgets.AppListRow row = r as Widgets.AppListRow;
                if (row == null) {
                    continue;
                }

                tree_set.add (row.get_package ());
            }

            return tree_set;
        }

        [CCode (instance_pos = -1)]
        private void row_update_header (Widgets.AppListRow row, Widgets.AppListRow? before) {
            bool update_available = row.get_update_available ();
            bool is_driver = row.get_is_driver ();

            if (update_available) {
                if (before != null && update_available == before.get_update_available ()) {
                    row.set_header (null);
                    return;
                }

                var header = new Widgets.UpdatesGrid ();

                uint update_numbers = 0U;
                uint nag_numbers = 0U;
                uint64 update_real_size = 0ULL;
                bool using_flatpak = false;
                foreach (var package in get_packages ()) {
                    if (package.update_available || package.is_updating) {
                        if (package.should_nag_update) {
                            nag_numbers++;
                        }

                        if (!using_flatpak && package.is_flatpak) {
                            using_flatpak = true;
                        }

                        update_numbers++;
                        update_real_size += package.change_information.size;
                    }
                }

                header.update (update_numbers, update_real_size, false, using_flatpak);

                // Unfortunately the update all button needs to be recreated everytime the header needs to be updated
                if (update_numbers > 0) {
                    update_all_button = new Gtk.Button.with_label (_("Update All"));
                    if (update_numbers == nag_numbers) {
                        update_all_button.sensitive = false;
                    }

                    update_all_button.valign = Gtk.Align.CENTER;
                    update_all_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                    update_all_button.clicked.connect (on_update_all);
                    action_button_group.add_widget (update_all_button);

                    header.add (update_all_button);
                }

                header.show_all ();
                row.set_header (header);
            } else if (is_driver) {
                if (before != null && is_driver == before.get_is_driver ()) {
                    row.set_header (null);
                    return;
                }

                var header = new Widgets.DriverGrid ();
                header.show_all ();
                row.set_header (header);
            } else {
                if (before != null && is_driver == before.get_is_driver () && update_available == before.get_update_available ()) {
                    row.set_header (null);
                    return;
                }

                var header = new Widgets.UpdatedGrid ();
                header.update (0, 0, false, false);
                header.show_all ();
                row.set_header (header);
            }
        }

        private void on_update_all () {
            perform_all_updates.begin ();
        }

        private async void perform_all_updates () {
            foreach (var row in get_children ()) {
                if (row is Widgets.PackageRow) {
                    ((Widgets.PackageRow) row).set_action_sensitive (false);
                }
            };

            updating_all_apps = true;

            // Collect all ready to update apps
            foreach (var package in get_packages ()) {
                if (package.update_available && !package.should_nag_update) {
                    package.notify["state"].connect (on_package_update_state);
                    yield package.update (false);
                    package.notify["state"].disconnect (on_package_update_state);
                }
            }

            updating_all_apps = false;

            unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();
            yield client.refresh_updates ();
        }

        private void on_package_update_state () {
            invalidate_sort ();
        }
    }
}
