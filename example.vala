using GLib;
using Cm;

private MainLoop main_loop;

private static void on_sync (Cm.Client client,
                             Cm.Room? room,
                             GLib.GenericArray<Cm.Event> events,
                             GLib.Error? error) {
    if (error != null) {
        printerr ("Sync error: %s\n", error.message);
        return;
    }

    if (room == null)
        return;

    for (uint i = 0; i < events.length; i++) {
        var event = events.get (i);

        if (event is Cm.RoomMessageEvent) {
            var message = (Cm.RoomMessageEvent) event;
            stdout.printf (
                "[%s] %s\n",
                room.get_name () ?? room.get_id (),
                message.get_body ()
            );
        }
    }
}

private async void run_client (string user_id,
                               string password,
                               string? homeserver) {
    try {
        Cm.init (true);

        var data_dir = Path.build_filename (
            Environment.get_user_data_dir (), "libcmatrix"
        );
        var cache_dir = Path.build_filename (
            Environment.get_user_cache_dir (), "libcmatrix"
        );

        DirUtils.create_with_parents (data_dir, 0700);
        DirUtils.create_with_parents (cache_dir, 0700);

        var matrix = new Cm.Matrix (
            data_dir,
            cache_dir,
            "org.example.SimpleClient",
            false
        );

        yield matrix.open_async (
            Path.build_filename (data_dir, "matrix.db"),
            "simple-client",
            null
        );

        var client = matrix.client_new ();
        client.set_user_id (user_id);
        client.set_password (password);
        client.set_device_name ("libcmatrix Vala client");
        client.set_sync_callback (on_sync);

        if (homeserver != null) {
            if (!client.set_homeserver (homeserver))
                throw new IOError.FAILED ("Invalid homeserver");
        } else {
            yield client.get_homeserver_async (null);
        }

        client.set_enabled (true);

        stdout.printf (
            "Logging in as %s on %s\n",
            user_id,
            client.get_homeserver () ?? "(unknown)"
        );
    } catch (GLib.Error error) {
        printerr ("Error: %s\n", error.message);
        main_loop.quit ();
    }
}

public static int main (string[] args) {
    if (args.length < 3) {
        stderr.printf (
            "Usage: %s USER_ID PASSWORD [HOMESERVER]\n",
            args[0]
        );
        return 1;
    }

    main_loop = new MainLoop ();

    run_client.begin (
        args[1],
        args[2],
        args.length > 3 ? args[3] : null
    );

    main_loop.run ();
    return 0;
}
