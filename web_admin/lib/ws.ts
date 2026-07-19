import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';

const WS_URL = process.env.NEXT_PUBLIC_WS_URL ?? 'http://localhost:8080/ws';

export function createStompClient(onConnect: (client: Client) => void): Client {
  const client = new Client({
    webSocketFactory: () => new SockJS(WS_URL) as unknown as WebSocket,
    reconnectDelay: 5000,
  });
  client.onConnect = () => onConnect(client);
  client.activate();
  return client;
}
