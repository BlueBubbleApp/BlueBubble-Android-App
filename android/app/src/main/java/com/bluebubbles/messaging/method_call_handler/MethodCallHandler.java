package com.bluebubbles.messaging.method_call_handler;

import android.annotation.SuppressLint;
import android.app.AlarmManager;
import android.content.Context;
import android.os.Build;

import androidx.annotation.RequiresApi;

import com.bluebubbles.messaging.MainActivity;
import com.bluebubbles.messaging.method_call_handler.handlers.AlarmScheduler;
import com.bluebubbles.messaging.method_call_handler.handlers.ClearChatNotifs;
import com.bluebubbles.messaging.method_call_handler.handlers.ClearFailedToSend;
import com.bluebubbles.messaging.method_call_handler.handlers.ClearSocketIssue;
import com.bluebubbles.messaging.method_call_handler.handlers.CreateNotificationChannel;
import com.bluebubbles.messaging.method_call_handler.handlers.DownloadHandler;
import com.bluebubbles.messaging.method_call_handler.handlers.FailedToSend;
import com.bluebubbles.messaging.method_call_handler.handlers.FetchMessagesHandler;
import com.bluebubbles.messaging.method_call_handler.handlers.FirebaseAuth;
import com.bluebubbles.messaging.method_call_handler.handlers.GetLastLocation;
import com.bluebubbles.messaging.method_call_handler.handlers.GetServerUrl;
import com.bluebubbles.messaging.method_call_handler.handlers.InitializeBackgroundHandle;
import com.bluebubbles.messaging.method_call_handler.handlers.NewMessageNotification;
import com.bluebubbles.messaging.method_call_handler.handlers.OpenCamera;
import com.bluebubbles.messaging.method_call_handler.handlers.OpenFile;
import com.bluebubbles.messaging.method_call_handler.handlers.OpenLink;
import com.bluebubbles.messaging.method_call_handler.handlers.PickFile;
import com.bluebubbles.messaging.method_call_handler.handlers.PushShareTargets;
import com.bluebubbles.messaging.method_call_handler.handlers.SaveToFile;
import com.bluebubbles.messaging.method_call_handler.handlers.SocketIssueWarning;
import com.bluebubbles.messaging.method_call_handler.handlers.SetNextRestart;
import com.bluebubbles.messaging.method_call_handler.handlers.OpenContactForm;
import com.bluebubbles.messaging.method_call_handler.handlers.ViewContactForm;
import com.bluebubbles.messaging.workers.DartWorker;
import com.bluebubbles.messaging.services.FlutterFirebaseMessagingBackgroundExecutor;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import static com.bluebubbles.messaging.MainActivity.engine;
import android.util.Log;

public class MethodCallHandler {
    public static boolean isInitialized = false;

    @SuppressLint("RestrictedApi")
    @RequiresApi(api = Build.VERSION_CODES.P)
    public static void methodCallHandler(MethodCall call, MethodChannel.Result result, Context context, DartWorker worker, FlutterFirebaseMessagingBackgroundExecutor executor) {
        if (call.method.equals(FirebaseAuth.TAG)) {
            new FirebaseAuth(context, call, result).Handle();
        } else if (call.method.equals("close-background-isolate")) {
            if (worker != null) {
                worker.destroyHeadlessThread();
            }
            result.success("");
        } else if(call.method.equals(FetchMessagesHandler.TAG)) {
            new FetchMessagesHandler(context, call, result).Handle();
        } else if (call.method.equals(CreateNotificationChannel.TAG)) {
            new CreateNotificationChannel(context, call, result).Handle();
        } else if (call.method.equals(NewMessageNotification.TAG)) {
            new NewMessageNotification(context, call, result).Handle();
        } else if (call.method.equals(SocketIssueWarning.TAG)) {
            new SocketIssueWarning(context, call, result).Handle();
        } else if (call.method.equals(ClearSocketIssue.TAG)) {
            new ClearSocketIssue(context, call, result).Handle();
        } else if (call.method.equals(OpenFile.TAG)) {
            new OpenFile(context, call, result).Handle();
        } else if (call.method.equals(OpenLink.TAG)) {
            new OpenLink(context, call, result).Handle();
        } else if (call.method.equals(ClearChatNotifs.TAG)) {
            new ClearChatNotifs(context, call, result).Handle();
        } else if (call.method.equals(GetLastLocation.TAG)) {
            new GetLastLocation(context, call, result).Handle();
        } else if (call.method.equals(SaveToFile.TAG)) {
            new SaveToFile(context, call, result).Handle();
        } else if(call.method.equals(PushShareTargets.TAG)) {
            new PushShareTargets(context, call, result).Handle();
        } else if (call.method.equals("get-starting-intent")) {
            String intent = ((MainActivity) context).getIntent().getStringExtra("chatGuid");
            ((MainActivity) context).getIntent().putExtra("chatGuid", (String) null);
            result.success(intent);
        } else if (call.method.equals(InitializeBackgroundHandle.TAG)) {
            new InitializeBackgroundHandle(context, call, result).Handle();
        } else if (call.method.equals(GetServerUrl.TAG)) {
            new GetServerUrl(context, call, result).Handle();
        } else if (call.method.equals(PickFile.TAG)) {
            new PickFile(context, call, result).Handle();
        } else if(call.method.equals(OpenCamera.TAG)) {
            new OpenCamera(context, call, result).Handle();
        } else if (call.method.equals(AlarmScheduler.TAG)) {
            new AlarmScheduler(context, call, result).Handle();
        } else if (call.method.equals(SetNextRestart.TAG)) {
            new SetNextRestart(context, call, result).Handle();
        } else if (call.method.equals(DownloadHandler.TAG)) {
            new DownloadHandler(context, call, result).Handle();
        } else if (call.method.equals(OpenContactForm.TAG)) {
            new OpenContactForm(context, call, result).Handle();
        } else if (call.method.equals(ViewContactForm.TAG)) {
            new ViewContactForm(context, call, result).Handle();
        } else if (call.method.equals(FailedToSend.TAG)) {
            new FailedToSend(context, call, result).Handle();
        } else if (call.method.equals(ClearFailedToSend.TAG)) {
            new ClearFailedToSend(context, call, result).Handle();
        } else if (call.method.equals("MessagingBackground#initialized")) {
            // This message is sent by the background method channel as soon as the background isolate
            // is running. From this point forward, the Android side of this plugin can send
            // callback handles through the background method channel, and the Dart side will execute
            // the Dart methods corresponding to those callback handles.
            if (executor != null) {
                executor.onInitialized();
            }
            isInitialized = true;
            result.success("");
        } else {
            result.notImplemented();
        }
    }
}
