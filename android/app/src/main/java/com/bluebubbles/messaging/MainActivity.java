package com.bluebubbles.messaging;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ClipData;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.PersistableBundle;
import android.provider.OpenableColumns;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.work.WorkManager;

import com.bluebubbles.messaging.method_call_handler.MethodCallHandler;
import com.bluebubbles.messaging.method_call_handler.handlers.SocketIssueWarning;
import com.bluebubbles.messaging.sharing.ShareShortcutManager;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class MainActivity extends FlutterFragmentActivity {
    public static final String CHANNEL = "com.bluebubbles.messaging";
    private static final String TAG = "MainActivity";
    public static FlutterEngine engine;
    private String startingChat;

    public static int PICK_IMAGE = 1000;
    public static int OPEN_CAMERA = 2000;
    public MethodChannel.Result result = null;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        engine = flutterEngine;

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(((call, result) -> MethodCallHandler.methodCallHandler(call, result, MainActivity.this, null, null)));
        GeneratedPluginRegistrant.registerWith(flutterEngine);
    }


    protected void onNewIntent(Intent intent) {
        // Get intent, action and MIME type
        String action = intent.getAction();
        String type = intent.getType();
        if (type == null) return;

        if (Intent.ACTION_SEND.equals(action)) {
            if (type.startsWith("text/")) {
                handleSendText(intent); // Handle text being sent
            } else {
                handleShareFile(intent);
            }
        } else if (Intent.ACTION_SEND_MULTIPLE.equals(action) && type != null) {
            handleSendMultipleImages(intent);
        } else {
            if (type.equals("NotificationOpen") || type.equals("DirectShare")) {
                Log.d("Notifications", "Tapped on notification with ID: " + intent.getExtras().getInt("id"));
                startingChat = intent.getStringExtra("chatGuid");
                // just in case
                if (engine == null) {
                    engine = new FlutterEngine(getApplicationContext());
                }
                Log.d("Notifications", "Opening Chat with GUID: " + startingChat);
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("ChatOpen", intent.getExtras().getString("chatGuid"));
            } else if (type.equals(SocketIssueWarning.TYPE)) {
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("socket-error-open", null);
            }
        }

    }

    // Used during the result after file picking
    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == PICK_IMAGE) {
            if (resultCode == RESULT_OK) {
                List<String> images = readPathsFromIntent(data);
                if (result != null) {
                    result.success(images);
                }
            } else {
                Log.d("PICK_FILE", "Nothing selected, or something went wrong");
                result.success(null);
            }
            result = null;
        } else if (requestCode == OPEN_CAMERA) {
            if (resultCode == RESULT_OK) {
                result.success(null);
            } else {
                Log.d("OPEN_CAMERA", "Something went wrong");
                result.success(null);
            }
        }
    }

    List<String> readPathsFromIntent(Intent intent) {
        // Try to get the initial data
        Uri fileUri = intent.getData();
        List<Uri> fileUris = new ArrayList<Uri>();
        List<String> images = new ArrayList<String>();

        // If the initial data is null, we need to get the clip data
        if (fileUri == null) {
            ClipData clipData = intent.getClipData();

            // If we have clip data, pull out all the URIs of the items in it
            if (clipData != null) {
                for (int i = 0; i < clipData.getItemCount(); i++) {
                    fileUris.add(clipData.getItemAt(i).getUri());
                }
            }
        } else {
            fileUris.add(fileUri);
        }

        // Create the shared files directory if it doesn't exist
        File filesDir = new File(getFilesDir().getPath() + "/sharedFiles/");
        if (!filesDir.exists()) {
            filesDir.mkdir();
        }

        // For each of the URIs, write the attachments to the shared directory
        for (Uri uri : fileUris) {
            try {
                File file = new File(getFilesDir().getPath() + "/sharedFiles/" + getFileName(uri));
                file.createNewFile();
                images.add(file.getPath());
                writeBytesFromURI(uri, file);
            } catch (Exception e) {
                Log.d("share", "FAILURE");
                e.printStackTrace();
            }
        }

        // Return the new local file paths
        return images;
    }


    void handleSendText(Intent intent) {
        String sharedText = intent.getStringExtra(Intent.EXTRA_TEXT);
        if (sharedText != null) {
            HashMap<String, Object> input = new HashMap<>();
            input.put("text", sharedText);
            String id = null;
            if (intent.hasExtra(Intent.EXTRA_SHORTCUT_ID))
                id = intent.getStringExtra(Intent.EXTRA_SHORTCUT_ID);
            input.put("id", id);
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareText", input);
        }
    }

    void handleShareFile(Intent intent) {
        List<String> images = new ArrayList<>();
        Uri imageUri = (Uri) intent.getParcelableExtra(Intent.EXTRA_STREAM);
        if (imageUri != null) {
            try {
                File filesDir = new File(getFilesDir().getPath() + "/sharedFiles/");
                if (!filesDir.exists()) {
                    filesDir.mkdir();
                }
                File file = new File(getFilesDir().getPath() + "/sharedFiles/" + getFileName(imageUri));
                file.createNewFile();
                writeBytesFromURI(imageUri, file);
                images.add(file.getPath());
                HashMap<String, Object> input = new HashMap<>();
                input.put("attachments", images);

                String id = null;
                if (intent.hasExtra(Intent.EXTRA_SHORTCUT_ID))
                    id = intent.getStringExtra(Intent.EXTRA_SHORTCUT_ID);
                input.put("id", id);
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareAttachments", input);
            } catch (Exception e) {
                Log.d("ShareImage", "FAILURE");
                e.printStackTrace();
            }
        }
    }

    public void writeBytesFromURI(Uri contentUri, File file) {
        final int buffer_size = 4096;
        try {
            InputStream inputStream = getContentResolver().openInputStream(contentUri);
            BufferedOutputStream outputStream = new BufferedOutputStream(new FileOutputStream(file));
            byte[] bytes = new byte[buffer_size];
            for (int count = 0, prog = 0; count != -1; ) {
                count = inputStream.read(bytes);
                if (count != -1) {
                    outputStream.write(bytes, 0, count);
                    prog = prog + count;
                }
            }
            outputStream.flush();
            inputStream.close();
            outputStream.close();
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public String getFileName(Uri uri) {
        String result = null;
        if (uri.getScheme().equals("content")) {
            Cursor cursor = getContentResolver().query(uri, null, null, null, null);
            try {
                if (cursor != null && cursor.moveToFirst()) {
                    result = cursor.getString(cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME));
                }
            } finally {
                cursor.close();
            }
        }
        if (result == null) {
            result = uri.getPath();
            int cut = result.lastIndexOf('/');
            if (cut != -1) {
                result = result.substring(cut + 1);
            }
        }
        return result;
    }

    void handleSendMultipleImages(Intent intent) {
        ArrayList<Uri> imageUris = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
        List<String> images = new ArrayList<>();
        File filesDir = new File(getFilesDir().getPath() + "/sharedFiles/");
        if (!filesDir.exists()) {
            filesDir.mkdir();
        }
        if (imageUris != null) {
            for (Uri imageUri : imageUris) {
                try {
                    File file = new File(getFilesDir().getPath() + "/sharedFiles/" + getFileName(imageUri));
                    file.createNewFile();
                    images.add(file.getPath());
                    writeBytesFromURI(imageUri, file);
                } catch (Exception e) {
                    Log.d("share", "FAILURE");
                    e.printStackTrace();
                }
            }
            Log.d("share", images.toString());
            HashMap<String, Object> input = new HashMap<>();
            input.put("attachments", images);

            String id = null;
            if (intent.hasExtra(Intent.EXTRA_SHORTCUT_ID))
                id = intent.getStringExtra(Intent.EXTRA_SHORTCUT_ID);
            input.put("id", id);
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareAttachments", input);
        }
    }


    @Override
    protected void onStart() {
        LocalBroadcastManager.getInstance(this).registerReceiver(mMessageReceiver, new IntentFilter("MyData"));
        WorkManager.getInstance(getApplicationContext()).cancelAllWork();
        super.onStart();
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    protected void onDestroy() {
        Log.d("MainActivity", "Removing Activity from memory");
        engine = null;
        super.onDestroy();
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    protected void onStop() {
        Log.d("MainActivity", "Stopping Activity (isFinishing: " + isFinishing() + ")");
        engine = null;
        super.onStop();
    }

    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            Log.d("notification", "on receive");
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod(intent.getExtras().getString("type"), intent.getExtras().getString("data"));
        }
    };


}
