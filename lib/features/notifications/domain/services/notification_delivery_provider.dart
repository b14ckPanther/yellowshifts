import 'dart:async';
import '../models/notification_item.dart';

abstract class NotificationDeliveryProvider {
  String get providerId;
  String get channel;
  Future<bool> initialize();
  Future<bool> deliver(NotificationItem notification);
}

class InAppNotificationProvider implements NotificationDeliveryProvider {
  @override
  String get providerId => 'in_app_local';

  @override
  String get channel => 'IN_APP';

  final _controller = StreamController<NotificationItem>.broadcast();
  Stream<NotificationItem> get onNotification => _controller.stream;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> deliver(NotificationItem notification) async {
    _controller.add(notification);
    return true;
  }

  void dispose() {
    _controller.close();
  }
}

class PushNotificationProvider implements NotificationDeliveryProvider {
  final String providerName; // 'fcm', 'apns', 'webpush', 'mock'

  PushNotificationProvider({this.providerName = 'mock'});

  @override
  String get providerId => providerName;

  @override
  String get channel => 'PUSH';

  @override
  Future<bool> initialize() async {
    // Ready for FCM / APNs integration with credentials
    return true;
  }

  @override
  Future<bool> deliver(NotificationItem notification) async {
    // In-app preview / mock delivery handler
    return true;
  }
}
