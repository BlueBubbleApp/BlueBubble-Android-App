import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:flutter/material.dart';

class QueueItem<T> {
  String event;
  T item;

  QueueItem({required this.event, required this.item});
}

abstract class QueueManager {
  bool isProcessing = false;
  List<QueueItem> queue = [];

  /// Adds an item to the queue and kicks off the processing (if required)
  Future<void> add(QueueItem item) async {
    // Add the item to the queue, no matter what
    this.queue.add(item);

    // Only process this item if we aren't currently processing
    if (!this.isProcessing) this.processNextItem();
  }

  /// Processes the next item in the queue
  Future<void> processNextItem() async {
    // If there are no queued items, we are done processing
    if (this.queue.isEmpty) {
      this.isProcessing = false;
      MethodChannelInterface().closeThread();
      return;
    }

    // Start processing top item
    this.isProcessing = true;
    QueueItem queued = this.queue.removeAt(0);

    try {
      await handleQueueItem(queued);
    } catch (ex, stacktrace) {
      debugPrint("Failed to handle queued item! " + ex.toString());
      debugPrint(stacktrace.toString());
    }

    // Process the next item
    await processNextItem();
  }

  /// Handles the currently passed [item] from the queue
  Future<void> handleQueueItem(QueueItem item);
}
