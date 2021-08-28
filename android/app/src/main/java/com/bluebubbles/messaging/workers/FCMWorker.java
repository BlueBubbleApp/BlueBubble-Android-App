package com.bluebubbles.messaging.workers;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.content.res.AssetManager;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.work.Data;
import androidx.work.ExistingWorkPolicy;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.baseflow.permissionhandler.PermissionHandlerPlugin;
import com.bluebubbles.messaging.helpers.NotifyRunnable;
import com.bluebubbles.messaging.method_call_handler.MethodCallHandler;
import com.bluebubbles.messaging.services.FirebaseMessagingService;
import java.util.concurrent.CountDownLatch;
import com.tekartik.sqflite.SqflitePlugin;

import flutter.plugins.contactsservice.contactsservice.ContactsServicePlugin;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.pathprovider.PathProviderPlugin;
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.FlutterRunArguments;
import io.flutter.FlutterInjector;

import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.embedding.engine.loader.ApplicationInfoLoader;
import io.flutter.embedding.engine.loader.FlutterApplicationInfo;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.PluginRegistry;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.dart.DartExecutor.DartCallback;

import static com.bluebubbles.messaging.MainActivity.engine;
import static com.bluebubbles.messaging.MainActivity.CHANNEL;
import static com.bluebubbles.messaging.method_call_handler.handlers.InitializeBackgroundHandle.BACKGROUND_HANDLE_SHARED_PREF_KEY;
import static com.bluebubbles.messaging.method_call_handler.handlers.InitializeBackgroundHandle.BACKGROUND_SERVICE_SHARED_PREF;

public class FCMWorker extends Worker implements DartWorker {

    public static MethodChannel backgroundChannel;
    public static Handler handler;
    private Context context;

    public static final String TAG = "FCMWorker";

    public FCMWorker(@NonNull Context appContext, @NonNull WorkerParameters workerParams) {
        super(appContext, workerParams);
        this.context = appContext;
    }

    @RequiresApi(api = Build.VERSION_CODES.P)
    @NonNull
    @Override
    public Result doWork() {
        String type = getInputData().getString("type");
        Log.d("BlueBubblesApp", "Doing work");
        if (type.equals("new-message") || type.equals("updated-message")) {

            getBackgroundChannel();
            // changed FCM messaging structure so currently nothing is sent to Dart here
            // We don't want to finish this worker until we know the backgroundChannel is finished
            // The backgroundChannel is manually closed through dart code
            while (backgroundChannel != null && !isStopped()) {
            }
            Log.d("BlueBubblesApp", "Successfully sent notification to Dart");
            return Result.success();
        } else {

            return Result.failure();
        }
    }

    @Override
    public void onStopped() {
        Log.d("Stop", "Stopping FCM Worker...");

        // When this worker gets cancelled, we need to clean up
        destroyHeadlessThread();
        super.onStopped();
    }

    @RequiresApi(api = Build.VERSION_CODES.P)
    private void initHeadlessThread() {
        Context context = (this.context != null) ? this.context : getApplicationContext();
        Log.d("BlueBubblesApp", "Starting FlutterMain");
        FlutterMain.startInitialization(context);
        FlutterMain.ensureInitializationComplete(getApplicationContext(), null);

        Log.d("BlueBubblesApp", "Getting FlutterApplicationInfo");
        FlutterApplicationInfo info = ApplicationInfoLoader.load(context);
        Log.d("BlueBubblesApp", "Getting flutterAssetsDir");
        String appBundlePath = info.flutterAssetsDir;
        Log.d("BlueBubblesApp", "Getting assets");
        AssetManager assets = context.getAssets();

        if (engine == null) {
            Log.d("BlueBubblesApp", "Getting FlutterEngine and DartExecutor");
            engine = new FlutterEngine(context);
            DartExecutor executor = engine.getDartExecutor();
            Log.d("BlueBubblesApp", "Getting callbackHandle and CallbackInformation");
            Long callbackHandle = context.getSharedPreferences(BACKGROUND_SERVICE_SHARED_PREF, Context.MODE_PRIVATE).getLong(BACKGROUND_HANDLE_SHARED_PREF_KEY, -1);
            FlutterCallbackInformation callbackInformation = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle);

            if (callbackInformation == null) {
                Log.e("Error", "Fatal: failed to find callback: " + callbackHandle);
                return;
            }

            Log.d("BlueBubblesApp", "Executing Dart callback");
            DartExecutor.DartCallback dartCallback = new DartExecutor.DartCallback(
                assets,
                appBundlePath,
                callbackInformation
            );
            executor.executeDartCallback(dartCallback);

            Log.d("BlueBubblesApp", "Setting MethodCall handler");
            handler = new Handler(Looper.getMainLooper());
            backgroundChannel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL);
            backgroundChannel.setMethodCallHandler((call, result) -> MethodCallHandler.methodCallHandler(call, result, context, this, null));
        }
    }


    @Override
    public MethodChannel destroyHeadlessThread() {
        if (engine == null) return null;
        new Handler(Looper.getMainLooper()).post(() -> {
            if (engine != null) {
                try {
                    Log.d("Destroy", "Destroying FCM Worker isolate...");
                    engine.destroy();
                    engine = null;
                    handler = null;
                    backgroundChannel = null;
                } catch (Exception e) {
                    Log.d("Destroy", "Failed to destroy FCM Worker isolate!");
                }
            }
        });
        return null;
    }


    @RequiresApi(api = Build.VERSION_CODES.P)
    public MethodChannel getBackgroundChannel() {
        if (backgroundChannel == null) {

            Handler handler = new Handler(Looper.getMainLooper());
            synchronized (handler) {
                NotifyRunnable runnable = new NotifyRunnable(handler, () -> initHeadlessThread());
                handler.post(runnable);
                while (!runnable.isFinished()) {
                    try {
                        handler.wait();
                    } catch (InterruptedException is) {
                        // ignore
                    }
                }
            }
        }
        return backgroundChannel;
    }

    public static void createWorker(Context context, String type, String data) {
        if(engine != null) return;
        OneTimeWorkRequest fcmwork = new OneTimeWorkRequest.Builder(FCMWorker.class)
                .setInputData(
                        new Data.Builder()
                                .putString("type", type)
                                .putString("data", data)
                                .build()
                )
                .addTag(FCMWorker.TAG)
                .build();
        Log.d("BlueBubblesApp", "Queuing work request...");
        WorkManager.getInstance(context).enqueueUniqueWork(FCMWorker.TAG, ExistingWorkPolicy.APPEND_OR_REPLACE, fcmwork);
    }
}
