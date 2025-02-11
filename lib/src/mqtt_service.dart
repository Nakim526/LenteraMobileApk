import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final String broker = 'broker.hivemq.com'; // Broker publik
  final int port = 1883;
  final String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

  late MqttServerClient client;

  MqttService() {
    client = MqttServerClient(broker, clientId);
    client.port = port;
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
    client.onUnsubscribed = onUnsubscribed;
  }

  Future<void> connect() async {
    try {
      print('Menghubungkan ke broker MQTT...');

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      client.connectionMessage = connMessage;

      await client.connect();
    } catch (e) {
      print('Koneksi gagal: $e');
      client.disconnect();
    }
  }

  void onConnected() {
    print('Terhubung ke MQTT broker');
  }

  void onDisconnected() {
    print('Terputus dari MQTT broker');
  }

  void onSubscribed(String topic) {
    print('Berlangganan ke topik: $topic');
  }

  void onUnsubscribed(String? topic) {
    print('Berhenti berlangganan dari topik: $topic');
  }

  void subscribe(String topic) {
    client.subscribe(topic, MqttQos.atMostOnce);
  }

  void publish(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  void listen(Function(String, String) onMessageReceived) {
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final recMessage = messages[0].payload as MqttPublishMessage;
      final message =
          MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
      onMessageReceived(messages[0].topic, message);
    });
  }

  void disconnect() {
    client.disconnect();
  }
}
