/*-
 * Copyright 2020 elementary, Inc. (https://elementary.io)
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
 */

public class AppCenterCore.ScreenshotCache : GLib.Object {
    private const int MAX_CACHE_SIZE = 100000000;

    public string screenshot_path;
    private Soup.Session session;

    private GLib.File screenshot_folder;

    private static ScreenshotCache? instance = null;

    construct {
        session = new Soup.Session ();
        session.timeout = 5;

        screenshot_path = Path.build_filename (
            GLib.Environment.get_user_cache_dir (),
            Build.PROJECT_NAME,
            "screenshots"
        );

        debug ("screenshot path is at %s", screenshot_path);

        init ();
    }

    private void init () {
        screenshot_folder = GLib.File.new_for_path (screenshot_path);

        if (!screenshot_folder.query_exists ()) {
            try {
                if (!screenshot_folder.make_directory_with_parents ()) {
                    return;
                }
            } catch (Error e) {
                warning ("Error creating screenshot cache folder: %s", e.message);
                return;
            }
        }

        maintain.begin ();
    }

    public static ScreenshotCache get_default () {
        if (instance == null) {
            instance = new ScreenshotCache ();
        }

        return instance;
    }

    // Prune the cache directory if it exceeds the `MAX_CACHE_SIZE`.
    private async void maintain () {
        uint64 screenshot_usage = 0, dirs = 0, files = 0;
        try {
            if (!yield screenshot_folder.measure_disk_usage_async (FileMeasureFlags.NONE, GLib.Priority.DEFAULT, null, null, out screenshot_usage, out dirs, out files)) {
                return;
            }
        } catch (Error e) {
            warning ("Error measuring size of screenshot cache: %s", e.message);
        }

        debug ("Screenshot folder size is %s", GLib.format_size (screenshot_usage));

        if (screenshot_usage > MAX_CACHE_SIZE) {
            yield delete_oldest_files (screenshot_usage);
        }
    }

    // Delete the oldest files in the screenshot cache until the cache is less than the max size.
    private async void delete_oldest_files (uint64 screenshot_usage) {
        var file_list = new Gee.ArrayList<GLib.FileInfo> ();

        FileEnumerator enumerator;
        try {
            enumerator = yield screenshot_folder.enumerate_children_async (
                string.join (",", "standard::*", GLib.FileAttribute.TIME_CHANGED),
                FileQueryInfoFlags.NONE
            );
        } catch (Error e) {
            warning ("Unable to create enumerator to delete cached screenshots: %s", e.message);
            return;
        }

        FileInfo? info;

        // Get a list of the files in the screenshot cache folder
        try {
            while ((info = enumerator.next_file (null)) != null) {
                if (info.get_file_type () == FileType.REGULAR) {
                    file_list.add (info);
                }
            }
        } catch (Error e) {
            warning ("Error while enumerating screenshot cache dir: %s", e.message);
        }

        // Sort the files by ctime (when file metadata was changed, not content)
        file_list.sort ((a, b) => {
            uint64 a_time = a.get_attribute_uint64 (GLib.FileAttribute.TIME_CHANGED);
            uint64 b_time = b.get_attribute_uint64 (GLib.FileAttribute.TIME_CHANGED);

            if (a_time < b_time) {
                return -1;
            } else if (a_time == b_time) {
                return 0;
            } else {
                return 1;
            }
        });

        // Start deleting files by oldest ctime until we get below the limit
        uint64 current_usage = screenshot_usage;
        foreach (var file_info in file_list) {
            if (current_usage > MAX_CACHE_SIZE) {
                var file = screenshot_folder.resolve_relative_path (file_info.get_name ());
                if (file == null) {
                    continue;
                }

                debug ("deleting screenshot at %s to free cache", file.get_path ());
                try {
                    yield file.delete_async (GLib.Priority.DEFAULT);
                    current_usage -= file_info.get_size ();
                    warning (current_usage.to_string ());
                } catch (Error e) {
                    warning ("Unable to delete cached screenshot file '%s': %s", file.get_path (), e.message);
                }
            } else {
                break;
            }
        }
    }

    // Generate a screenshot path based on the URL to be fetched.
    private string generate_screenshot_path (string url) {
        int ext_pos = url.last_index_of (".");
        string extension = url.slice ((long) ext_pos, (long) url.length);
        if (extension.contains ("/")) {
            extension = "";
        }

        return Path.build_filename (
            screenshot_path,
            "%02x".printf (url.hash ()) + extension
        );
    }

    // Returns true if theres a screenshot to load in the out parameter @path
    public async bool fetch (string url, out string path) {
        path = generate_screenshot_path (url);
        var file = File.new_for_path (path);

        var msg = new Soup.Message ("HEAD", url);

        try {
            yield session.send_async (msg);
        } catch (Error e) {
            warning ("HEAD request of %s failed: %s", url, e.message);

            if (file.query_exists ()) {
                // Just use the cached one anyway
                return true;
            }

            return false;
        }

        var modified = msg.response_headers.get_one ("Last-Modified");

        if (msg.status_code != Soup.Status.OK || modified == null) {
            warning ("HEAD request of %s failed: %s", url, msg.reason_phrase);

            if (file.query_exists ()) {
                // Just use the cached one anyway
                return true;
            }

            return false;
        }

        var time = new Soup.Date.from_string (modified).to_time_t ();

        // Local file is up to date
        if (file.query_exists () && Stat (path).st_mtime == time) {
            warning ("local file up to date");
            return true;
        }

        var remote_file = File.new_for_uri (url);
        try {
            yield remote_file.copy_async (file, FileCopyFlags.OVERWRITE | FileCopyFlags.TARGET_DEFAULT_PERMS);
        } catch (Error e) {
            warning ("Unable to download screenshot from %s: %s", url, e.message);
            return false;
        }

        set_mtime (path, time);

        return true;
    }

    // Used for setting the `Last-Modified` header's value to the screenshot that was downloaded.
    private void set_mtime (string path, time_t mtime) {
        Stat fstat = Stat (path);

        var utimbuf = UTimBuf () {
            actime = fstat.st_atime,
            modtime = mtime
        };

        FileUtils.utime (path, utimbuf);
    }
}
